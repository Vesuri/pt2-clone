#!/usr/bin/env python3
"""
sysex_to_jrm.py — Novation Supernova II OS2 sysex bank → pt2-clone protracker.jrm

Reads a single-bank sysex MIDI file (pbanka.mid through pbankh.mid) and writes a
protracker.jrm containing all 128 programs, ready for use as the global program
library at startup.

Usage:
    python3 sysex_to_jrm.py <bank.mid>               # writes <bank.jrm>
    python3 sysex_to_jrm.py <bank.mid> <output.jrm>  # explicit output path

Install:
    cp output.jrm ~/.config/protracker/protracker.jrm

Mapping completeness (see SYSEX_FORMAT.md for details):
  Confirmed:   oscillator waveforms, mix levels/mods, width/sync/pitch mods,
               filter cutoff/resonance and mods, all envelope ADS,
               LFO1+2 speed (range-aware, params[164]/[165]) + waveform, FM flags
  Approximate: filter frequency/resonance (linear — pt2_synth Hz calibration pending)
               LFO2 waveform (partial — SAW/SQUARE indistinguishable at some ranges)
               modulation depths (linear — pt2_synth depth calibration pending)
  Calibrated:  envelope attack/decay (exponential from hardware sweep),
               envelope sustain (power-law from hardware sweep),
               LFO speed (quadratic per range from hardware sweep)
"""

import struct
import sys

# ── pt2_synth waveform enum values ────────────────────────────────────────────

WAVEFORM_SAW      = 0
WAVEFORM_SQUARE_1 = 256    # narrow pulse width
WAVEFORM_SQUARE_2 = 512    # medium pulse width (~50%)
WAVEFORM_SQUARE_3 = 768    # wide pulse width
WAVEFORM_NOISE    = 1024   # (not used as osc waveform in Supernova II)
WAVEFORM_SINUS    = 1280   # (not a Supernova waveform; SQUARE+hardness=0 produces sine)

WAVEFORM_LFO_SAW      = 0
WAVEFORM_LFO_SQUARE   = 4096
WAVEFORM_LFO_TRIANGLE = 8192

# ── Value scaling ─────────────────────────────────────────────────────────────

_SR = 22050  # pt2_synth synthesis sample rate

def u7_to_u12(v):
    """7-bit sysex (0-127) → 12-bit pt2_synth unsigned (0-4095). Linear."""
    return (v * 4095) // 127

def bipolar_to_s12(v):
    """
    Sysex bipolar byte (0-127, 64=center) → signed modulation depth (-2047..+2047).
    Formula: (v - 64) * 32, clamped to ±2047.
    """
    return max(-2047, min(2047, (v - 64) * 32))

def bipolar_to_u12_width(v):
    """
    Sysex bipolar Width byte (0-127, 64=center/50% duty) → unsigned 12-bit (0-4095).
    Center (sysex=64) maps to pt2_synth width=2048.
    """
    return max(0, min(4095, (v - 64) * 32 + 2048))

# ── Calibrated envelope mappings ──────────────────────────────────────────────
#
# Derived from hardware sweep recordings (see analysis/ directory).
# pt2_synth time formula (doubled-range version):
#   time_s = (value + 1) × 16 / SAMPLERATE
#   → value  = T_ms × SAMPLERATE / 16000 − 1
# Maximum reproducible time: (0xFFF+1)×16/22050 ≈ 2.97 s.

def sn_attack_to_u12(v):
    """
    Supernova env attack (0-127) → pt2_synth u12 (0-0xFFF).
    Measured: T_ms ≈ 2 × 2^(v/10).  Values ≥ 106 exceed 2.97 s → clamped.
    """
    T_ms = 2.0 * (2.0 ** (v / 10.0))
    return max(0, min(0xFFF, round(T_ms * _SR / 16000.0 - 1)))

def sn_decay_to_u12(v):
    """
    Supernova env decay (0-127) → pt2_synth u12 (0-0xFFF).
    Measured: T_ms ≈ 0.625 × 2^(v/10).  Values ≥ 123 exceed 2.97 s → clamped.
    """
    T_ms = 0.625 * (2.0 ** (v / 10.0))
    return max(0, min(0xFFF, round(T_ms * _SR / 16000.0 - 1)))

def sn_sustain_to_u12(v):
    """
    Supernova env sustain (0-127) → pt2_synth u12 (0-0xFFF).
    Measured: amplitude fraction ≈ (v/127)^1.81.
    """
    if v == 0:
        return 0
    return round((v / 127.0) ** 1.81 * 0xFFF)

# ── Calibrated LFO speed mapping ──────────────────────────────────────────────
#
# Supernova LFO speed ∝ v² within each range (confirmed Slow and Normal from
# hardware sweep; Fast extrapolated as 10× Normal).
# pt2_synth: f_Hz = speed / 1024  (from position-increment formula).
# Range stored at params[164] (LFO1) and params[165] (LFO2).
# Packed NRPN 1 values: 28/31=Slow, 29/32=Normal, 30/33=Fast.

_LFO_COEFF = {
    28: 0.625,  29: 6.25,  30: 62.5,   # LFO1: Slow/Normal/Fast
    31: 0.625,  32: 6.25,  33: 62.5,   # LFO2: Slow/Normal/Fast
}

def sn_lfo_speed_to_u15(v, range_byte):
    """
    Supernova LFO speed (0-127) → pt2_synth u15 (0-0x7FFF).
    range_byte: params[164] for LFO1, params[165] for LFO2 (see _LFO_COEFF).
    Defaults to Normal (6.25) if range_byte is not in table.
    Normal-range values ≥ 73 and Fast-range values ≥ 23 saturate at 0x7FFF.
    """
    if v == 0:
        return 0
    return min(0x7FFF, round(_LFO_COEFF.get(range_byte, 6.25) * v * v))

# ── Waveform conversion ───────────────────────────────────────────────────────

def osc_waveform(syx_byte):
    """
    Convert type-1F oscillator waveform byte to pt2_synth waveform enum.

    Sysex encoding (type-1F[8]=Osc1, [7]=Osc2, [1]=Osc3):
      0       = SQUARE at 50% duty cycle → WAVEFORM_SQUARE_2
      1–21    = SQUARE, narrower PW      → WAVEFORM_SQUARE_1
      22–42   = SQUARE, medium PW        → WAVEFORM_SQUARE_2
      43–63   = SQUARE, wider PW         → WAVEFORM_SQUARE_3
      64      = SAW                      → WAVEFORM_SAW
      65–127  = Special (Double Saw, Audio inputs) → WAVEFORM_SAW (closest)

    TODO: verify which SQUARE_N variant best matches each PW range once the
    pt2_synth waveform table duty cycles are documented.
    """
    if syx_byte >= 64:
        return WAVEFORM_SAW
    if syx_byte == 0:
        return WAVEFORM_SQUARE_2
    if syx_byte <= 21:
        return WAVEFORM_SQUARE_1
    if syx_byte <= 42:
        return WAVEFORM_SQUARE_2
    return WAVEFORM_SQUARE_3

def lfo1_waveform(params_145):
    """
    Convert params[145] to LFO1 waveform enum.

    Confirmed codes (SYSEX_FORMAT.md § LFO region):
      16 = SQUARE,   17 = SAW,   18 = TRIANGLE (default),   19 = S/H → TRIANGLE
    S/H is not implemented in pt2_synth; TRIANGLE is the closest approximation.
    """
    if params_145 == 16:
        return WAVEFORM_LFO_SQUARE
    if params_145 == 17:
        return WAVEFORM_LFO_SAW
    return WAVEFORM_LFO_TRIANGLE  # 18=triangle, 19=s/h, anything else

def lfo2_waveform(params_155):
    """
    Convert params[155] to LFO2 waveform enum.

    Packed NRPN 1 values (OS 2.0 manual p.149), confirmed against 7 hardware programs:
      20 = SQUARE,   21 = SAW,   22 = TRIANGLE (default),   23 = S/H → TRIANGLE
    S/H is not implemented in pt2_synth; TRIANGLE is the closest approximation.
    Mirrors LFO1 layout: [154]=Delay, [155]=waveform, [157]=Speed.
    """
    if params_155 == 20:
        return WAVEFORM_LFO_SQUARE
    if params_155 == 21:
        return WAVEFORM_LFO_SAW
    return WAVEFORM_LFO_TRIANGLE  # 22=triangle, 23=s/h, anything else

def lfo_wf_for_jrm(wf_enum):
    """
    Convert LFO waveform enum to the on-disk encoding used by synthSave().
    Formula: enum_value * 2 + 1536  (stores the 68k waveform table byte offsets).
      WAVEFORM_LFO_SAW=0      → 1536
      WAVEFORM_LFO_SQUARE=4096  → 9728
      WAVEFORM_LFO_TRIANGLE=8192 → 17920
    """
    return wf_enum * 2 + 1536

# ── Sysex MIDI parser ─────────────────────────────────────────────────────────

def parse_sysex_bank(path):
    """
    Parse a Novation OS2 sysex bank MIDI file.

    Returns (p02, p1f) dicts keyed by program index (0-127):
      p02[n][0:16]  = 16-byte program name
      p02[n][16:]   = 270-byte type-02 params block  (p02[n][16+N] = params[N])
      p1f[n]        = 88-byte type-1F data block     (p1f[n][N]    = type-1F byte N)
    """
    data = open(path, "rb").read()

    def read_varlen(pos):
        val = 0
        while True:
            b = data[pos]; pos += 1
            val = (val << 7) | (b & 0x7F)
            if not (b & 0x80):
                return val, pos

    pos = 8 + int.from_bytes(data[4:8], 'big')
    msgs = []
    while pos < len(data):
        if data[pos:pos+4] == b'MTrk':
            chunk_len = int.from_bytes(data[pos+4:pos+8], 'big')
            end = pos + 8 + chunk_len; pos += 8
            while pos < end:
                _, pos = read_varlen(pos)
                if data[pos] == 0xF0:
                    pos += 1
                    length, pos = read_varlen(pos)
                    msgs.append(data[pos:pos+length])
                    pos += length
                elif data[pos] == 0xFF:
                    pos += 2
                    length, pos = read_varlen(pos)
                    pos += length
                else:
                    status = data[pos]; pos += 1
                    if status & 0x80:
                        pos += 2 if (status >> 4) in (0x8, 0x9, 0xA, 0xB, 0xE) else 1
        else:
            break

    # Header layout: [0-2]=manuf, [3]=dev, [4]=prod, [5]=7F, [6]=type, [7]=bank, [8]=prog
    p02 = {m[8]: m[9:-1] for m in msgs if len(m) > 9 and m[6] == 0x02}
    p1f = {m[8]: m[9:-1] for m in msgs if len(m) > 9 and m[6] == 0x1F}
    return p02, p1f

# ── Oscillator pitch conversion ───────────────────────────────────────────────
#
# Each oscillator's pitch is stored in the 3 bytes immediately before its block:
#   Osc1: oct=params[7], semi=params[8], fine=params[9]
#   Osc2: oct=params[41], semi=params[42], fine=params[43]
#   Osc3: oct=params[75], semi=params[76], fine=params[77]
#
# Encoding (confirmed from hardware cross-reference):
#   octave:    stored = 32 + oct      (all oscillators; center=32)
#   semitone:  stored = C  + semi     (C=57/82/107 for Osc1/2/3 respectively)
#   fine tune: stored = 64 + cents    (bipolar, center=64; all oscillators)
#
# Keyboard tracking (relative offset 0 of each block = params[11/45/79]) is
# ignored — it cannot be replicated in a render-based synthesizer.

OSC_OCT_POS    = {1:  7, 2: 41, 3: 75}
OSC_SEMI_POS   = {1:  8, 2: 42, 3: 76}
OSC_FINE_POS   = {1:  9, 2: 43, 3: 77}
OSC_OCT_CENTER  = {1: 32, 2: 37, 3: 42}   # confirmed per-oscillator centers
OSC_SEMI_CENTER = {1: 57, 2: 82, 3: 107}  # increment of 25 per oscillator
# Fine tune center is always 64 (standard bipolar) for all three oscillators

PITCH_NEUTRAL = 0xAF  # pt2_synth pitch value for no transposition (oct=0, semi=0, fine=0)

def osc_pitch_jrm(p, osc):
    """
    Compute pt2_synth oscillator_N_pitch from type-02 params.

    Formula: pitch = round(0xAF * 2^((oct*12 + semi + cents/100) / 12))
    where 0xAF is the neutral pitch for no transposition.
    Clamped to 0x000–0x7FF (pt2_synth range).
    """
    oct_hw  = p[OSC_OCT_POS[osc]]  - OSC_OCT_CENTER[osc]
    semi_hw = p[OSC_SEMI_POS[osc]] - OSC_SEMI_CENTER[osc]
    fine_hw = p[OSC_FINE_POS[osc]] - 64  # in cents, ±64
    total_semi = oct_hw * 12 + semi_hw + fine_hw / 100.0
    pitch = round(PITCH_NEUTRAL * (2 ** (total_semi / 12)))
    return max(0, min(0x7FF, pitch))

# ── Parameter layout constants ────────────────────────────────────────────────
#
# Per-oscillator block base addresses in type-02 params[]:
#   Osc1: params[11..44],  Osc2: params[45..78],  Osc3: params[79..107]
#
# Within each block, group relative offsets (all groups use same order):
#   [Level(+0), Wheel(+1), Env2(+2), Env3(+3), LFO1(+4), LFO2(+5)]
#
# Mix group base addresses (same [Level, Wheel, Env2, Env3, LFO1, LFO2] order):
#   Osc1=108, Osc2=114, Osc3=120, Osc1x3=126, Osc2x3=132, Noise=138

OSC_BASE    = {1: 11,  2: 45,  3: 79}
MIX_BASE    = {1: 108, 2: 114, 3: 120, '13': 126, '23': 132, 'noise': 138}

REL_PITCH   = 0    # pitch group base within oscillator block
REL_WIDTH   = 14   # width group base
REL_SYNC    = 20   # sync group base
# (Hardness group at REL=8 is not implemented in pt2_synth)

# Slot offsets within each group:
SLOT_LEVEL  = 0
SLOT_WHEEL  = 1  # not in pt2_synth — skipped
SLOT_ENV2   = 2
SLOT_ENV3   = 3
SLOT_LFO1   = 4
SLOT_LFO2   = 5

# ── Struct packing helpers ────────────────────────────────────────────────────

def pu16(v): return struct.pack(">H", v & 0xFFFF)
def ps16(v): return struct.pack(">h", max(-32768, min(32767, v)))

# ── Program conversion ────────────────────────────────────────────────────────

def convert_program(msg02, msg1f):
    """
    Convert one program from raw sysex bytes to a 222-byte big-endian program_t record.

    msg02: 286-byte block (name[16] + params[270])
    msg1f: 88-byte type-1F data block
    """
    name16 = msg02[0:16]
    p = msg02[16:]   # type-02 params block, p[N] = params[N]
    f = msg1f        # type-1F data block,   f[N] = type-1F byte N

    out = bytearray(name16)

    # ── Oscillators 1, 2, 3 ──────────────────────────────────────────────────
    OSC_WF_BYTE = {1: 8, 2: 7, 3: 1}  # type-1F indices for waveform

    for osc in (1, 2, 3):
        base = OSC_BASE[osc]
        mbase = MIX_BASE[osc]

        # Waveform
        out += pu16(osc_waveform(f[OSC_WF_BYTE[osc]]))

        # Mix: level (direct 0-127 → u12), then lfo1/lfo2/env2/env3 (bipolar)
        out += pu16(u7_to_u12(p[mbase + SLOT_LEVEL]))
        out += ps16(bipolar_to_s12(p[mbase + SLOT_LFO1]))
        out += ps16(bipolar_to_s12(p[mbase + SLOT_LFO2]))
        out += ps16(bipolar_to_s12(p[mbase + SLOT_ENV2]))
        out += ps16(bipolar_to_s12(p[mbase + SLOT_ENV3]))

        # Pitch: combined from Octave+Semitone+Cents (see SYSEX_FORMAT.md § Per-oscillator data).
        # Keyboard tracking (params[base+0]) is intentionally ignored.
        out += pu16(osc_pitch_jrm(p, osc))
        out += ps16(bipolar_to_s12(p[base + REL_PITCH + SLOT_LFO1]))
        out += ps16(bipolar_to_s12(p[base + REL_PITCH + SLOT_LFO2]))
        out += ps16(bipolar_to_s12(p[base + REL_PITCH + SLOT_ENV2]))
        out += ps16(bipolar_to_s12(p[base + REL_PITCH + SLOT_ENV3]))

        # Width: level (bipolar, center=64 → pt2_synth center=2048), then mods
        out += pu16(bipolar_to_u12_width(p[base + REL_WIDTH + SLOT_LEVEL]))
        out += ps16(bipolar_to_s12(p[base + REL_WIDTH + SLOT_LFO1]))
        out += ps16(bipolar_to_s12(p[base + REL_WIDTH + SLOT_LFO2]))
        out += ps16(bipolar_to_s12(p[base + REL_WIDTH + SLOT_ENV2]))
        out += ps16(bipolar_to_s12(p[base + REL_WIDTH + SLOT_ENV3]))

        # Sync: level (direct 0-127 → u12), then mods (bipolar)
        out += pu16(u7_to_u12(p[base + REL_SYNC + SLOT_LEVEL]))
        out += ps16(bipolar_to_s12(p[base + REL_SYNC + SLOT_LFO1]))
        out += ps16(bipolar_to_s12(p[base + REL_SYNC + SLOT_LFO2]))
        out += ps16(bipolar_to_s12(p[base + REL_SYNC + SLOT_ENV2]))
        out += ps16(bipolar_to_s12(p[base + REL_SYNC + SLOT_ENV3]))

    # ── Noise mix ─────────────────────────────────────────────────────────────
    nb = MIX_BASE['noise']
    out += pu16(u7_to_u12(p[nb + SLOT_LEVEL]))
    out += ps16(bipolar_to_s12(p[nb + SLOT_LFO1]))
    out += ps16(bipolar_to_s12(p[nb + SLOT_LFO2]))
    out += ps16(bipolar_to_s12(p[nb + SLOT_ENV2]))
    out += ps16(bipolar_to_s12(p[nb + SLOT_ENV3]))

    # ── Osc 1×3 ring mod / FM ────────────────────────────────────────────────
    b13 = MIX_BASE['13']
    out += pu16(u7_to_u12(p[b13 + SLOT_LEVEL]))
    out += ps16(bipolar_to_s12(p[b13 + SLOT_LFO1]))
    out += ps16(bipolar_to_s12(p[b13 + SLOT_LFO2]))
    out += ps16(bipolar_to_s12(p[b13 + SLOT_ENV2]))
    out += ps16(bipolar_to_s12(p[b13 + SLOT_ENV3]))
    out += pu16(1 if (f[3] & 0x01) else 0)  # FM flag (type-1F[3] bit 0)

    # ── Osc 2×3 ring mod / FM ────────────────────────────────────────────────
    b23 = MIX_BASE['23']
    out += pu16(u7_to_u12(p[b23 + SLOT_LEVEL]))
    out += ps16(bipolar_to_s12(p[b23 + SLOT_LFO1]))
    out += ps16(bipolar_to_s12(p[b23 + SLOT_LFO2]))
    out += ps16(bipolar_to_s12(p[b23 + SLOT_ENV2]))
    out += ps16(bipolar_to_s12(p[b23 + SLOT_ENV3]))
    out += pu16(1 if (f[3] & 0x02) else 0)  # FM flag (type-1F[3] bit 1)

    # ── Filter ────────────────────────────────────────────────────────────────
    out += pu16(u7_to_u12(p[195]))            # frequency   (direct 0-127)
    out += ps16(bipolar_to_s12(p[200]))       # freq lfo_1
    out += ps16(bipolar_to_s12(p[201]))       # freq lfo_2
    out += ps16(bipolar_to_s12(p[198]))       # freq env_2
    out += ps16(bipolar_to_s12(p[199]))       # freq env_3
    out += pu16(u7_to_u12(p[205]))            # resonance (direct 0-127)
    # "Resonance/Width" mods: hardware displays as "width mod" for standard filter types
    # (12/18/24dB, HPF, BPF) but the destination is Resonance, not Width.
    # Only the Special dual-filter type uses true Width. See manual pp.85-87.
    out += ps16(bipolar_to_s12(p[210]))       # res lfo_1
    out += ps16(bipolar_to_s12(p[211]))       # res lfo_2
    out += ps16(bipolar_to_s12(p[208]))       # res env_2
    out += ps16(bipolar_to_s12(p[209]))       # res env_3

    # ── Envelopes (ADS — pt2_synth does not use Release) ─────────────────────
    # Env1 (amplifier):  params[178]=Attack, [179]=Decay, [180]=Sustain
    out += pu16(sn_attack_to_u12(p[178]))
    out += pu16(sn_decay_to_u12(p[179]))
    out += pu16(sn_sustain_to_u12(p[180]))
    # Env2 (modulation): params[172]=Attack, [173]=Decay, [174]=Sustain
    out += pu16(sn_attack_to_u12(p[172]))
    out += pu16(sn_decay_to_u12(p[173]))
    out += pu16(sn_sustain_to_u12(p[174]))
    # Env3 (modulation): params[166]=Attack, [167]=Decay, [168]=Sustain
    out += pu16(sn_attack_to_u12(p[166]))
    out += pu16(sn_decay_to_u12(p[167]))
    out += pu16(sn_sustain_to_u12(p[168]))

    # ── LFOs ──────────────────────────────────────────────────────────────────
    # LFO waveforms stored on disk as: enum_value * 2 + 1536 (68k byte offset).
    # LFO range: params[164]=LFO1 range byte, params[165]=LFO2 range byte.
    out += pu16(sn_lfo_speed_to_u15(p[147], p[164]))     # LFO1 speed
    out += pu16(lfo_wf_for_jrm(lfo1_waveform(p[145])))   # LFO1 waveform
    out += pu16(sn_lfo_speed_to_u15(p[157], p[165]))     # LFO2 speed
    out += pu16(lfo_wf_for_jrm(lfo2_waveform(p[155])))   # LFO2 waveform

    assert len(out) == 222, f"program_t size error: {len(out)}"
    return bytes(out)

# ── JRM file writer ───────────────────────────────────────────────────────────

PART_VOLUME     = 64     # standard full volume (renderPart: output = b4 * volume >> 11)
PART_SAMPLERATE = 22050  # concert pitch (oscillator delta = (pitch << 16) / sampleRate << 8)
PART_OFFSET     = 0      # start at beginning of sample buffer

def make_part(program_idx):
    """One active part pointing to program_idx at standard volume and pitch."""
    return struct.pack(">BBHHH",
        program_idx & 0x7F, 0,
        PART_VOLUME, PART_SAMPLERATE, PART_OFFSET)

def make_blank_part():
    """Inactive part: volume=0 causes renderPart to skip it."""
    return b'\x00' * 8

def write_jrm(programs, program_names, out_path):
    """
    Write a protracker.jrm containing all 128 program slots and 31 performances.

    Performance N uses program N as part 0, named after that program. This maps
    each of ProTracker's 31 sample slots directly to the corresponding synth program.
    Programs 31-127 are in the library but need manual performance assignment.
    """
    buf = bytearray()

    buf += struct.pack(">I", 0x7FFFFFFF)
    buf += struct.pack(">IIII", *([0xFFFFFFFF] * 4))

    for perf_idx in range(31):
        name = program_names.get(perf_idx, b'\x00' * 16)
        buf += (name[:16] + b'\x00' * 16)[:16]
        buf += make_part(perf_idx)
        buf += make_blank_part() * 7

    for idx in range(128):
        buf += programs.get(idx, b'\x00' * 222)

    with open(out_path, 'wb') as f:
        f.write(buf)

    print(f"Wrote {len(buf):,} bytes → {out_path}", file=sys.stderr)
    print(f"  {len(programs)} programs, 31 performances", file=sys.stderr)
    print(f"  Copy to ~/.config/protracker/protracker.jrm to use at startup",
          file=sys.stderr)

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <bank.mid> [output.jrm]", file=sys.stderr)
        sys.exit(1)

    in_path = sys.argv[1]
    if len(sys.argv) >= 3:
        out_path = sys.argv[2]
    elif in_path.lower().endswith('.mid'):
        out_path = in_path[:-4] + '.jrm'
    else:
        out_path = in_path + '.jrm'

    p02, p1f = parse_sysex_bank(in_path)
    print(f"Parsed {len(p02)} programs from {in_path}", file=sys.stderr)

    programs = {}
    program_names = {}
    errors = []
    for idx in range(128):
        if idx in p02 and idx in p1f:
            program_names[idx] = p02[idx][0:16]
            try:
                programs[idx] = convert_program(p02[idx], p1f[idx])
            except Exception as e:
                errors.append(f"  program {idx}: {e}")

    if errors:
        print("Conversion errors:", file=sys.stderr)
        for e in errors:
            print(e, file=sys.stderr)

    write_jrm(programs, program_names, out_path)

if __name__ == '__main__':
    main()
