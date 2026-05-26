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
  Confirmed:   oscillator waveforms, mix levels/mods, width/pitch mods,
               filter cutoff/resonance and mods, all envelope ADS,
               LFO1+2 speed (range-aware, params[164]/[165]) + waveform, FM flags
  Approximate: filter resonance (linear — pt2_synth Hz calibration pending)
               LFO2 waveform (partial — SAW/SQUARE indistinguishable at some ranges)
               resonance modulation depths (linear — pt2_synth depth calibration pending)
  Calibrated:  filter frequency (log-linear interp from hardware sweep anchor points),
               filter freq modulation depths (computed from actual Hz swing via sn_ff_to_u12)
  Calibrated:  envelope attack/decay (exponential from hardware sweep),
               envelope sustain (power-law from hardware sweep),
               LFO speed (quadratic per range from hardware sweep),
               oscillator sync level (quadratic — Supernova sync barely audible at low
                 values, accelerates at high values; hardware sweep calibrated),
               FM mix depth (quadratic — Supernova FM barely audible at low values;
                 calibrated for pt2_synth PM+sine implementation at <<16 depth)
"""

import math
import struct
import sys

# ── pt2_synth filter_type_t enum values ───────────────────────────────────────

FILTER_TYPE_LPF_24DB = 0
FILTER_TYPE_LPF_12DB = 1
FILTER_TYPE_LPF_18DB = 2
FILTER_TYPE_HPF_12DB = 3
FILTER_TYPE_BPF_12DB = 4

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

def bipolar_to_sync_s12(v):
    """
    Sysex bipolar sync modulation depth → pt2_synth signed depth (LFO and env).

    The sync base uses a quadratic mapping (sn_sync_to_u12).  Both LFO waveforms
    and the envelope (0xffff >> 4 = 4095) peak at ±4095, so both modulation sources
    contribute  2 × depth  at peak.  To produce the correct pt2_synth swing at that
    peak (calibrated for sync_base=0):

      2 × depth = sn_sync_to_u12(|net|)  →  depth = sn_sync_to_u12(|net|) / 2

    For non-zero sync bases the calibration is approximate (hardware modulates in
    pre-quadratic Supernova space; pt2_synth modulates post-conversion).  This formula
    correctly reproduces the zero-to-N swing; the positive swing from a non-zero base
    is underestimated by ~50% at high base values, but is far better than bipolar_to_s12.
    """
    net = v - 64
    depth = round(sn_sync_to_u12(abs(net)) / 2)
    return depth if net >= 0 else -depth

def bipolar_to_fm_mix_s12(v):
    """
    Sysex bipolar FM/ring-mod mix modulation depth → pt2_synth signed depth (LFO and env).

    FM mix base uses sn_fm_mix_to_u12 (quadratic calibration for PM+sine at <<16).
    Both LFO and env peak at ±4095 → contribution = 2 × depth at peak.

      2 × depth = sn_fm_mix_to_u12(|net|)  →  depth = sn_fm_mix_to_u12(|net|) / 2
    """
    net = v - 64
    depth = round(sn_fm_mix_to_u12(abs(net)) / 2)
    return depth if net >= 0 else -depth

def bipolar_to_filter_lfo_s12(v):
    """
    Sysex bipolar resonance modulation depth → pt2_synth signed depth (LFO and env).

    Used only for resonance modulations (params[210]/[211] LFO, [208]/[209] ENV).
    Filter-frequency modulations use sn_ff_depth_to_s12() instead.

    Resonance is stored ×3/4 (u7_to_u12(v)*3//4 → 0–3071), so 1 Supernova
    resonance unit ≈ 24.2 pt2_synth units.  Using factor 8 is approximate; resonance
    modulation calibration remains pending.
    """
    return (v - 64) * 8

def bipolar_to_filter_env_s12(v):
    """
    Sysex bipolar resonance envelope modulation depth → pt2_synth signed depth.

    Used only for resonance modulations (params[208]/[209] ENV).
    Filter-frequency modulations use sn_ff_depth_to_s12() instead.
    Same formula as bipolar_to_filter_lfo_s12; kept as a separate name for call-site clarity.
    """
    return (v - 64) * 8

# ── Filter frequency — hardware-calibrated exponential mapping ────────────────

# Anchor points from hardware sweep recordings (filter_freq_low.csv reliable at
# low end, filter_freq.csv reliable at high end; v=127 extrapolated from 90-100
# slope).  Between anchors, log-linear (equal-ratio) interpolation is used.
# Anchor Hz values are doubled relative to raw hardware sweep (filter_freq_low.csv /
# filter_freq.csv at MIDI-60 reference note) to account for the synthesis rendering
# one octave higher than the hardware calibration recordings.  When comparing
# bank_a_synth to bank_a_dry (SEMITONE_SHIFT = -5), the synthesis runs at 2× the
# calibration pitch, so the filter must also sit 2× higher to preserve the same
# harmonic-cutoff relationship.
_SN_FF_ANCHORS = [(0, 236.0), (60, 580.0), (70, 1700.0), (80, 2250.0), (100, 5610.0), (127, 18682.0)]

def sn_ff_to_u12(v):
    """Supernova II filter frequency byte (0-127) → pt2_synth filter_frequency (0-4095).

    The hardware knob is highly non-linear: barely moves from 0-60 (~118-290 Hz),
    then rises steeply to ~9 kHz at 127.  Uses log-linear interpolation between
    hardware-measured anchor points.  No halving — the non-linear distribution
    keeps values well inside the stable Moog range for most programs.
    """
    v = max(0, min(127, v))
    pts = _SN_FF_ANCHORS
    if v <= pts[0][0]:
        hz = pts[0][1]
    elif v >= pts[-1][0]:
        hz = pts[-1][1]
    else:
        for i in range(len(pts) - 1):
            v0, f0 = pts[i]
            v1, f1 = pts[i + 1]
            if v0 <= v <= v1:
                t = (v - v0) / (v1 - v0)
                hz = math.exp(math.log(f0) + t * (math.log(f1) - math.log(f0)))
                break
    return min(4095, max(0, int(round(hz / (_SR / 2) * 4095))))

def sn_ff_depth_to_s12(base_sysex, depth_sysex):
    """Supernova II bipolar filter-freq modulation depth → pt2_synth signed depth (LFO sources).

    The hardware applies LFO/env depths additively in sysex (log-Hz) space, so
    each unit of depth corresponds to a different absolute Hz swing depending on
    the base cutoff.  We evaluate sn_ff_to_u12 at base ± |net| and halve,
    because the LFO waveform peaks at ±4095 and the formula
    (waveform * depth) >> 11 gives ≈ 2×depth at peak.

    For envelope modulation use sn_ff_depth_to_env_s12 instead — the envelope
    formula uses (env_current >> 4) which peaks at 2047, giving 1×depth at peak.

    Asymmetry note: for negative depths the true negative swing would be
    smaller (log-space floor), but we use the positive-side delta for both
    directions as a reasonable approximation.
    """
    net = depth_sysex - 64
    if net == 0:
        return 0
    delta = abs(net)
    target = max(0, min(127, base_sysex + delta))
    ff_base   = sn_ff_to_u12(base_sysex)
    ff_target = sn_ff_to_u12(target)
    depth = round((ff_target - ff_base) * 2048 / 4095)
    return depth if net > 0 else -depth

def sn_ff_depth_to_env_s12(base_sysex, depth_sysex):
    """Supernova II bipolar filter-freq modulation depth → pt2_synth signed depth (ENV sources).

    Same log-Hz swing computation as sn_ff_depth_to_s12, but no halving:
    the envelope formula ((env_current >> 4) * depth) >> 11 peaks at
    (2047 * depth) >> 11 ≈ 1×depth, so the full intended swing is stored directly.
    """
    net = depth_sysex - 64
    if net == 0:
        return 0
    delta = abs(net)
    target = max(0, min(127, base_sysex + delta))
    ff_base   = sn_ff_to_u12(base_sysex)
    ff_target = sn_ff_to_u12(target)
    depth = abs(ff_target - ff_base)
    return depth if net > 0 else -depth

def bipolar_to_pitch_s12(v):
    """
    Sysex bipolar pitch-modulation depth (0-127, 64=center) → pt2_synth signed depth.

    pt2_synth pitch is in Hz; LFO and env peak at ±4095, contributing 2 × depth.
    The Supernova stores pitch depth in semitones; ±12 semitones at full range (net ±63)
    is consistent with bank A survey data (Birdy net=+13 ≈ bird-call sweep ~2.5 st;
    Soft Voices net=+4 ≈ gentle vibrato ~0.75 st at PITCH_NEUTRAL = 350 Hz).

    Calibration (linear approx at PITCH_NEUTRAL = 350 Hz):
      1 semitone ≈ 350 × (2^(1/12) − 1) ≈ 20.8 Hz
      12 semitones at peak (±4095): depth = 12 × 20.8 / 2 ≈ 125  →  factor ≈ 2 per net unit
      →  (v − 64) × 2
    """
    return (v - 64) * 2

def bipolar_to_u12_width(v):
    """
    Sysex bipolar Width byte (0-127, 64=center/50% duty) → unsigned 12-bit (0-4095).
    Center (sysex=64) maps to pt2_synth width=2048.
    """
    return max(0, min(4095, (v - 64) * 32 + 2048))

# ── Calibrated sync / FM depth mappings ──────────────────────────────────────
#
# Both derived from hardware sweep recordings (analysis/osc3_sync.csv and
# analysis/fm13_1_1.csv) compared against pt2_synth sweep results.
#
# Sync: Supernova sync centroid rises from baseline at v=10 by only ~17 Hz
# (barely audible) then accelerates sharply.  pt2_synth with linear mapping
# produces 720 Hz centroid rise at v=10 — far too strong.  A quadratic curve
# (v/127)² matches the hardware profile: v=10→8, v=40→406, v=80→1625, v=127→4095.
#
# FM: With pt2_synth's PM+sine implementation at <<16, modulation index β scales
# linearly with mix, so Supernova v=10 (barely audible, Δcentroid≈21 Hz) requires
# a very small mix.  Numerical fit gives exactly α=2.00: mix = (v/127)² × 4095.

def sn_sync_to_u12(v):
    """
    Supernova oscillator sync (0-127) → pt2_synth u12 (0-4095).
    Quadratic curve calibrated from hardware sweep.
    """
    return round((v / 127) ** 2 * 4095)

def sn_fm_mix_to_u12(v):
    """
    Supernova FM mix depth (0-127) → pt2_synth u12 (0-4095).
    Quadratic curve calibrated for pt2_synth PM+sine at <<16.
    Ring-mod mode uses u7_to_u12() (linear) instead — see convert_program().
    """
    return round((v / 127) ** 2 * 4095)

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
    Hardware sweep measured T ≈ 0.625 × 2^(v/10) ms at sustain=50%, but that
    captures only the time to the halfway point. Factory programs with low sustain
    require the full-range decay time, which matches the attack curve (2 × 2^(v/10)).
    Values ≥ 106 exceed 2.97 s → clamped.
    """
    T_ms = 2.0 * (2.0 ** (v / 10.0))
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

def osc_waveform(syx_byte, hardness):
    """
    Convert type-1F oscillator waveform byte to pt2_synth waveform enum.

    Sysex encoding (type-1F[8]=Osc1, [7]=Osc2, [1]=Osc3):
      0       = SQUARE at 50% duty cycle → WAVEFORM_SQUARE_2
      1–21    = SQUARE, narrower PW      → WAVEFORM_SQUARE_1
      22–42   = SQUARE, medium PW        → WAVEFORM_SQUARE_2
      43–63   = SQUARE, wider PW         → WAVEFORM_SQUARE_3
      64      = SAW                      → WAVEFORM_SAW
      65–127  = Special (Double Saw, Audio inputs) → WAVEFORM_SAW (closest)

    hardness: OSC params[base+8], direct 0–127. Hardness=0 on a SQUARE waveform
    produces a sine on the Supernova II, so map that to WAVEFORM_SINUS.

    TODO: verify which SQUARE_N variant best matches each PW range once the
    pt2_synth waveform table duty cycles are documented.
    """
    if syx_byte >= 64:
        return WAVEFORM_SAW
    if hardness == 0:
        return WAVEFORM_SINUS
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
# Encoding (OS 2.0 manual p.148, Packed NRPN 0 table):
#   The sysex stores Packed NRPN 0 data values directly.  Those values form a flat
#   sequential space across all oscillators, so each oscillator has a different center:
#     octave:    stored = C_oct  + oct   (C_oct  = 32/37/42 for Osc1/2/3; oct ±2)
#     semitone:  stored = C_semi + semi  (C_semi = 57/82/107 for Osc1/2/3; semi ±12)
#     fine tune: stored = 64    + cents  (center=64; ±64 cents; all oscillators)
#
# Keyboard tracking (relative offset 0 of each block = params[11/45/79]) is
# ignored — it cannot be replicated in a render-based synthesizer.

OSC_OCT_POS    = {1:  7, 2: 41, 3: 75}
OSC_SEMI_POS   = {1:  8, 2: 42, 3: 76}
OSC_FINE_POS   = {1:  9, 2: 43, 3: 77}
OSC_OCT_CENTER  = {1: 32, 2: 37, 3: 42}   # Packed NRPN 0: Osc1 oct0=32, Osc2 oct0=37, Osc3 oct0=42
OSC_SEMI_CENTER = {1: 57, 2: 82, 3: 107}  # Packed NRPN 0: Osc1 semi0=57, Osc2 semi0=82, Osc3 semi0=107

PITCH_NEUTRAL = 0x15E  # pt2_synth pitch value for no transposition (oct=0, semi=0, fine=0); one octave up from 0xAF

def osc_pitch_jrm(p, osc):
    """
    Compute pt2_synth oscillator_N_pitch from type-02 params.

    Formula: pitch = round(0x15E * 2^((oct*12 + semi + cents/100) / 12))
    where 0x15E is the neutral pitch for no transposition.
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

# ── Filter type conversion ────────────────────────────────────────────────────

def filter_type_from_sysex(ft):
    """
    Map Supernova II filter type byte (params[192], Packed NRPN 1 data value) to
    pt2_synth filter_type_t.

    Confirmed from hardware (SYSEX_FORMAT.md §Filter):
      0 = 12dB LPF  → FILTER_TYPE_LPF_12DB
      1 = 18dB LPF  → FILTER_TYPE_LPF_18DB  (confirmed: Propellor Fans)
      2 = 24dB LPF  → FILTER_TYPE_LPF_24DB  (confirmed: Ghostwalk, Jan Hammer Lead)

    Direct equivalents from NRPN table (OS 2.0 manual Packed NRPN 1 values):
      4 = BPF        → FILTER_TYPE_BPF_12DB
      5 = HPF        → FILTER_TYPE_HPF_12DB

    Fallbacks — no pt2_synth equivalent; nearest character chosen:
      3 = LPF (unspecified dB slope) → FILTER_TYPE_LPF_24DB
      6–8 = Resonance filter variants → FILTER_TYPE_LPF_24DB
      9 = Notch                       → FILTER_TYPE_BPF_12DB  (adjacent character)
      10–14 = Dual-filter types       → FILTER_TYPE_LPF_24DB
    """
    if ft == 0:
        return FILTER_TYPE_LPF_12DB
    if ft == 1:
        return FILTER_TYPE_LPF_18DB
    if ft == 2:
        return FILTER_TYPE_LPF_24DB
    if ft == 4:
        return FILTER_TYPE_BPF_12DB
    if ft == 5:
        return FILTER_TYPE_HPF_12DB
    if ft == 9:
        return FILTER_TYPE_BPF_12DB   # Notch — BPF is closest available
    return FILTER_TYPE_LPF_24DB       # 3=LPF, 6-8=Res variants, 10-14=dual

# ── Struct packing helpers ────────────────────────────────────────────────────

def pu16(v): return struct.pack(">H", v & 0xFFFF)
def ps16(v): return struct.pack(">h", max(-32768, min(32767, v)))

# ── Program conversion ────────────────────────────────────────────────────────

def convert_program(msg02, msg1f):
    """
    Convert one program from raw sysex bytes to a 224-byte big-endian program_t record.

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

        # Waveform (hardness=0 on a SQUARE waveform → SINUS)
        out += pu16(osc_waveform(f[OSC_WF_BYTE[osc]], p[base + 8]))

        # Mix: level (direct 0-127 → u12), then lfo1/lfo2/env2/env3 (bipolar)
        out += pu16(u7_to_u12(p[mbase + SLOT_LEVEL]))
        out += ps16(bipolar_to_s12(p[mbase + SLOT_LFO1]))
        out += ps16(bipolar_to_s12(p[mbase + SLOT_LFO2]))
        out += ps16(bipolar_to_s12(p[mbase + SLOT_ENV2]))
        out += ps16(bipolar_to_s12(p[mbase + SLOT_ENV3]))

        # Pitch: combined from Octave+Semitone+Cents (see SYSEX_FORMAT.md § Per-oscillator data).
        # Keyboard tracking (params[base+0]) is intentionally ignored.
        # Modulation depths use bipolar_to_pitch_s12 (semitone-scaled), not bipolar_to_s12.
        out += pu16(osc_pitch_jrm(p, osc))
        out += ps16(bipolar_to_pitch_s12(p[base + REL_PITCH + SLOT_LFO1]))
        out += ps16(bipolar_to_pitch_s12(p[base + REL_PITCH + SLOT_LFO2]))
        out += ps16(bipolar_to_pitch_s12(p[base + REL_PITCH + SLOT_ENV2]))
        out += ps16(bipolar_to_pitch_s12(p[base + REL_PITCH + SLOT_ENV3]))

        # Width: level (bipolar, center=64 → pt2_synth center=2048), then mods
        out += pu16(bipolar_to_u12_width(p[base + REL_WIDTH + SLOT_LEVEL]))
        out += ps16(bipolar_to_s12(p[base + REL_WIDTH + SLOT_LFO1]))
        out += ps16(bipolar_to_s12(p[base + REL_WIDTH + SLOT_LFO2]))
        out += ps16(bipolar_to_s12(p[base + REL_WIDTH + SLOT_ENV2]))
        out += ps16(bipolar_to_s12(p[base + REL_WIDTH + SLOT_ENV3]))

        # Sync: level (quadratic — see sn_sync_to_u12), mods use same quadratic curve.
        out += pu16(sn_sync_to_u12(p[base + REL_SYNC + SLOT_LEVEL]))
        out += ps16(bipolar_to_sync_s12(p[base + REL_SYNC + SLOT_LFO1]))
        out += ps16(bipolar_to_sync_s12(p[base + REL_SYNC + SLOT_LFO2]))
        out += ps16(bipolar_to_sync_s12(p[base + REL_SYNC + SLOT_ENV2]))
        out += ps16(bipolar_to_sync_s12(p[base + REL_SYNC + SLOT_ENV3]))

    # ── Noise mix ─────────────────────────────────────────────────────────────
    nb = MIX_BASE['noise']
    out += pu16(u7_to_u12(p[nb + SLOT_LEVEL]))
    out += ps16(bipolar_to_s12(p[nb + SLOT_LFO1]))
    out += ps16(bipolar_to_s12(p[nb + SLOT_LFO2]))
    out += ps16(bipolar_to_s12(p[nb + SLOT_ENV2]))
    out += ps16(bipolar_to_s12(p[nb + SLOT_ENV3]))

    # ── Osc 1×3 ring mod / FM ────────────────────────────────────────────────
    # FM depth uses quadratic mapping (calibrated for PM+sine); ring mod keeps
    # linear because ring-mod depth doesn't share the same response curve.
    b13 = MIX_BASE['13']
    is_fm13 = bool(f[3] & 0x01)
    mix13 = sn_fm_mix_to_u12(p[b13 + SLOT_LEVEL]) if is_fm13 else u7_to_u12(p[b13 + SLOT_LEVEL])
    out += pu16(mix13)
    out += ps16(bipolar_to_fm_mix_s12(p[b13 + SLOT_LFO1]))
    out += ps16(bipolar_to_fm_mix_s12(p[b13 + SLOT_LFO2]))
    out += ps16(bipolar_to_fm_mix_s12(p[b13 + SLOT_ENV2]))
    out += ps16(bipolar_to_fm_mix_s12(p[b13 + SLOT_ENV3]))
    out += pu16(1 if is_fm13 else 0)  # FM flag (type-1F[3] bit 0)

    # ── Osc 2×3 ring mod / FM ────────────────────────────────────────────────
    b23 = MIX_BASE['23']
    is_fm23 = bool(f[3] & 0x02)
    mix23 = sn_fm_mix_to_u12(p[b23 + SLOT_LEVEL]) if is_fm23 else u7_to_u12(p[b23 + SLOT_LEVEL])
    out += pu16(mix23)
    out += ps16(bipolar_to_fm_mix_s12(p[b23 + SLOT_LFO1]))
    out += ps16(bipolar_to_fm_mix_s12(p[b23 + SLOT_LFO2]))
    out += ps16(bipolar_to_fm_mix_s12(p[b23 + SLOT_ENV2]))
    out += ps16(bipolar_to_fm_mix_s12(p[b23 + SLOT_ENV3]))
    out += pu16(1 if is_fm23 else 0)  # FM flag (type-1F[3] bit 1)

    # ── Filter ────────────────────────────────────────────────────────────────
    ff_sysex = p[195]
    out += pu16(sn_ff_to_u12(ff_sysex))                           # frequency
    out += ps16(sn_ff_depth_to_s12(ff_sysex, p[200]))             # freq lfo_1
    out += ps16(sn_ff_depth_to_s12(ff_sysex, p[201]))             # freq lfo_2
    out += ps16(sn_ff_depth_to_env_s12(ff_sysex, p[198]))         # freq env_2
    out += ps16(sn_ff_depth_to_env_s12(ff_sysex, p[199]))         # freq env_3
    out += pu16(u7_to_u12(p[205]) * 7 // 8)   # resonance (×7/8 — SN≈99→2780 self-osc threshold; SN=127→3584)
    # "Resonance/Width" mods: hardware displays as "width mod" for standard filter types
    # (12/18/24dB, HPF, BPF) but the destination is Resonance, not Width.
    # Only the Special dual-filter type uses true Width. See manual pp.85-87.
    # Resonance is now halved (0-2047), so modulation depths use factor 8 like filter freq.
    out += ps16(bipolar_to_filter_lfo_s12(p[210]))   # res lfo_1
    out += ps16(bipolar_to_filter_lfo_s12(p[211]))   # res lfo_2
    out += ps16(bipolar_to_filter_env_s12(p[208]))   # res env_2
    out += ps16(bipolar_to_filter_env_s12(p[209]))   # res env_3

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
    out += pu16(sn_lfo_speed_to_u15(p[157], p[165]))       # LFO2 speed
    out += pu16(lfo_wf_for_jrm(lfo2_waveform(p[155])))   # LFO2 waveform
    out += pu16(filter_type_from_sysex(p[192]))           # filter_type (params[192])

    assert len(out) == 224, f"program_t size error: {len(out)}"
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
        buf += programs.get(idx, b'\x00' * 224)

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
