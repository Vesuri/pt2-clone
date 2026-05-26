#!/usr/bin/env python3
"""
Synthesis equivalence test harness.

Generates a range of program_t parameter sets, renders each with both the 68k
(synth_render under vamos) and the C (synth_test) implementations, and compares
the output byte-for-byte.

Usage:
    python3 test/run_tests.py [--keep-temps] [--verbose]

Requirements:
    - test/68k/synth_render   (built by test/68k/build.py)
    - test/synth_test          (built by test/Makefile)
    - vamos                    (installed via pip: amitools)
    - ~/bin/vasmm68k_mot       (or on PATH)
"""

import argparse
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT    = Path(__file__).parent.parent
TEST_DIR     = REPO_ROOT / "test"
SYNTH_RENDER = TEST_DIR / "68k" / "synth_render"
SYNTH_TEST   = TEST_DIR / "synth_test"
DEFAULT_RENDER_SIZE = 12288

# ---- params.bin serialization ----------------------------------------

WAVEFORM_SAW      = 0
WAVEFORM_SQUARE_1 = 256
WAVEFORM_SQUARE_2 = 512
WAVEFORM_SQUARE_3 = 768
WAVEFORM_NOISE    = 1024
WAVEFORM_SINUS    = 1280

WAVEFORM_LFO_SAW      = 0
WAVEFORM_LFO_SQUARE   = 4096
WAVEFORM_LFO_TRIANGLE = 8192

FILTER_TYPE_LPF_24DB = 0
FILTER_TYPE_LPF_12DB = 1
FILTER_TYPE_LPF_18DB = 2
FILTER_TYPE_HPF_12DB = 3
FILTER_TYPE_BPF_12DB = 4

PROGRAM_T_FIELDS = [
    # (name, signed)
    ('oscillator_1_waveform',      False),
    ('oscillator_1_mix',           True),
    ('oscillator_1_mix_lfo_1',     True),
    ('oscillator_1_mix_lfo_2',     True),
    ('oscillator_1_mix_env_2',     True),
    ('oscillator_1_mix_env_3',     True),
    ('oscillator_1_pitch',         True),
    ('oscillator_1_pitch_lfo_1',   True),
    ('oscillator_1_pitch_lfo_2',   True),
    ('oscillator_1_pitch_env_2',   True),
    ('oscillator_1_pitch_env_3',   True),
    ('oscillator_1_width',         True),
    ('oscillator_1_width_lfo_1',   True),
    ('oscillator_1_width_lfo_2',   True),
    ('oscillator_1_width_env_2',   True),
    ('oscillator_1_width_env_3',   True),
    ('oscillator_1_sync',          True),
    ('oscillator_1_sync_lfo_1',    True),
    ('oscillator_1_sync_lfo_2',    True),
    ('oscillator_1_sync_env_2',    True),
    ('oscillator_1_sync_env_3',    True),

    ('oscillator_2_waveform',      False),
    ('oscillator_2_mix',           True),
    ('oscillator_2_mix_lfo_1',     True),
    ('oscillator_2_mix_lfo_2',     True),
    ('oscillator_2_mix_env_2',     True),
    ('oscillator_2_mix_env_3',     True),
    ('oscillator_2_pitch',         True),
    ('oscillator_2_pitch_lfo_1',   True),
    ('oscillator_2_pitch_lfo_2',   True),
    ('oscillator_2_pitch_env_2',   True),
    ('oscillator_2_pitch_env_3',   True),
    ('oscillator_2_width',         True),
    ('oscillator_2_width_lfo_1',   True),
    ('oscillator_2_width_lfo_2',   True),
    ('oscillator_2_width_env_2',   True),
    ('oscillator_2_width_env_3',   True),
    ('oscillator_2_sync',          True),
    ('oscillator_2_sync_lfo_1',    True),
    ('oscillator_2_sync_lfo_2',    True),
    ('oscillator_2_sync_env_2',    True),
    ('oscillator_2_sync_env_3',    True),

    ('oscillator_3_waveform',      False),
    ('oscillator_3_mix',           True),
    ('oscillator_3_mix_lfo_1',     True),
    ('oscillator_3_mix_lfo_2',     True),
    ('oscillator_3_mix_env_2',     True),
    ('oscillator_3_mix_env_3',     True),
    ('oscillator_3_pitch',         True),
    ('oscillator_3_pitch_lfo_1',   True),
    ('oscillator_3_pitch_lfo_2',   True),
    ('oscillator_3_pitch_env_2',   True),
    ('oscillator_3_pitch_env_3',   True),
    ('oscillator_3_width',         True),
    ('oscillator_3_width_lfo_1',   True),
    ('oscillator_3_width_lfo_2',   True),
    ('oscillator_3_width_env_2',   True),
    ('oscillator_3_width_env_3',   True),
    ('oscillator_3_sync',          True),
    ('oscillator_3_sync_lfo_1',    True),
    ('oscillator_3_sync_lfo_2',    True),
    ('oscillator_3_sync_env_2',    True),
    ('oscillator_3_sync_env_3',    True),

    ('oscillator_noise_mix',       True),
    ('oscillator_noise_mix_lfo_1', True),
    ('oscillator_noise_mix_lfo_2', True),
    ('oscillator_noise_mix_env_2', True),
    ('oscillator_noise_mix_env_3', True),

    ('oscillator_13_mix',          True),
    ('oscillator_13_mix_lfo_1',    True),
    ('oscillator_13_mix_lfo_2',    True),
    ('oscillator_13_mix_env_2',    True),
    ('oscillator_13_mix_env_3',    True),
    ('oscillator_13_fm',           True),

    ('oscillator_23_mix',          True),
    ('oscillator_23_mix_lfo_1',    True),
    ('oscillator_23_mix_lfo_2',    True),
    ('oscillator_23_mix_env_2',    True),
    ('oscillator_23_mix_env_3',    True),
    ('oscillator_23_fm',           True),

    ('filter_frequency',           True),
    ('filter_frequency_lfo_1',     True),
    ('filter_frequency_lfo_2',     True),
    ('filter_frequency_env_2',     True),
    ('filter_frequency_env_3',     True),
    ('filter_resonance',           True),
    ('filter_resonance_lfo_1',     True),
    ('filter_resonance_lfo_2',     True),
    ('filter_resonance_env_2',     True),
    ('filter_resonance_env_3',     True),

    ('envelope_1_attack',          True),
    ('envelope_1_decay',           True),
    ('envelope_1_sustain',         True),
    ('envelope_2_attack',          True),
    ('envelope_2_decay',           True),
    ('envelope_2_sustain',         True),
    ('envelope_3_attack',          True),
    ('envelope_3_decay',           True),
    ('envelope_3_sustain',         True),

    ('lfo_1_speed',                True),
    ('lfo_1_waveform',             False),
    ('lfo_2_speed',                True),
    ('lfo_2_waveform',             False),
    ('filter_type',                False),
]

assert len(PROGRAM_T_FIELDS) == 104


def make_program(**kwargs):
    """Return a program_t dict with all fields zeroed except those in kwargs."""
    prog = {name: 0 for name, _ in PROGRAM_T_FIELDS}
    prog.update(kwargs)
    return prog


# LFO waveform constant translation.
# C code uses indices into waveforms_lfo[] (0, 4096, 8192).
# 68k code uses byte offsets from waveform_saw (1536, 9728, 17920).
# These represent the same logical waveforms but are numerically different,
# so .jrm files saved by C are not directly loadable by the 68k (issue #3).
# For testing we write different params.bin files for each side.
_C_TO_68K_LFO = {
    WAVEFORM_LFO_SAW:      1536,
    WAVEFORM_LFO_SQUARE:   9728,
    WAVEFORM_LFO_TRIANGLE: 17920,
}
_LFO_FIELDS = {'lfo_1_waveform', 'lfo_2_waveform'}


def serialize_program(prog, for_68k=False, render_size=DEFAULT_RENDER_SIZE):
    """Serialize program_t to params.bin blob.

    C side: big-endian 208-byte blob (104 fields × 2 bytes).
    68k side: same 208 bytes followed by a big-endian uint32 render_size_param
    (4 bytes), total 212 bytes.  The 68k load_params routine reads the full
    block and copies render_size_param into buffer_render_size if non-zero.

    When for_68k=True, LFO waveform constants are translated from C values
    (0/4096/8192) to 68k values (1536/9728/17920).
    """
    buf = bytearray()
    for name, signed in PROGRAM_T_FIELDS:
        v = prog[name]
        if for_68k and name in _LFO_FIELDS:
            v = _C_TO_68K_LFO.get(v, v)
        if signed:
            buf += struct.pack('>h', v)
        else:
            buf += struct.pack('>H', v)
    if for_68k:
        buf += struct.pack('>I', render_size)
    assert len(buf) == (212 if for_68k else 208)
    return bytes(buf)


# ---- test case definitions -------------------------------------------

def _osc3(wf=WAVEFORM_SAW, pitch=175, mix=0xfff, width=0x800, **kw):
    """Shorthand for a basic OSC3-only program."""
    return make_program(
        oscillator_3_waveform=wf,
        oscillator_3_mix=mix,
        oscillator_3_pitch=pitch,
        oscillator_3_width=width,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
        **kw,
    )


def gen_test_cases():
    """Yield (description, program_dict, render_size) triples covering the
    parameter space.  render_size is the number of samples both sides render;
    the default matches the 68k's built-in buffer_render_size."""

    S = DEFAULT_RENDER_SIZE  # shorthand

    # ------------------------------------------------------------------ #
    # Baseline                                                             #
    # ------------------------------------------------------------------ #

    # Minimal: silence (all zeros — OSC3 mix=0 means no output)
    yield "all_zero", make_program(), S

    # ------------------------------------------------------------------ #
    # OSC3 alone — all waveforms × pitches                                #
    # ------------------------------------------------------------------ #

    for wf_name, wf in [
        ('saw',    WAVEFORM_SAW),
        ('sq1',    WAVEFORM_SQUARE_1),
        ('sq2',    WAVEFORM_SQUARE_2),
        ('sq3',    WAVEFORM_SQUARE_3),
        ('noise',  WAVEFORM_NOISE),
        ('sinus',  WAVEFORM_SINUS),
    ]:
        for pitch in [44, 88, 175, 350, 700, 0x7ff]:
            yield f"osc3_{wf_name}_p{pitch}", make_program(
                oscillator_3_waveform=wf,
                oscillator_3_mix=0xfff,
                oscillator_3_pitch=pitch,
                oscillator_3_width=0x800,
                filter_frequency=0xfff,
                envelope_1_sustain=0xfff,
            ), S

    # ------------------------------------------------------------------ #
    # Ring mod / FM: OSC1×OSC3 (oscillator_13)                            #
    # ------------------------------------------------------------------ #

    for osc1_wf in [WAVEFORM_SAW, WAVEFORM_SINUS]:
        yield f"ringmod_osc1_wf{osc1_wf}", make_program(
            oscillator_1_waveform=osc1_wf,
            oscillator_1_mix=0x800,
            oscillator_1_pitch=88,
            oscillator_3_waveform=WAVEFORM_SAW,
            oscillator_3_mix=0xfff,
            oscillator_3_pitch=175,
            oscillator_13_mix=0x800,
            filter_frequency=0xfff,
            envelope_1_sustain=0xfff,
        ), S

    yield "fm_osc13", make_program(
        oscillator_1_waveform=WAVEFORM_SINUS,
        oscillator_1_pitch=88,
        oscillator_3_waveform=WAVEFORM_SINUS,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_13_mix=0x600,
        oscillator_13_fm=1,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
    ), S

    # ------------------------------------------------------------------ #
    # Ring mod / FM: OSC2×OSC3 (oscillator_23) — previously untested      #
    # ------------------------------------------------------------------ #

    for osc2_wf in [WAVEFORM_SAW, WAVEFORM_SINUS, WAVEFORM_SQUARE_1]:
        yield f"ringmod_osc2_wf{osc2_wf}", make_program(
            oscillator_2_waveform=osc2_wf,
            oscillator_2_mix=0x800,
            oscillator_2_pitch=88,
            oscillator_3_waveform=WAVEFORM_SAW,
            oscillator_3_mix=0xfff,
            oscillator_3_pitch=175,
            oscillator_23_mix=0x800,
            filter_frequency=0xfff,
            envelope_1_sustain=0xfff,
        ), S

    yield "fm_osc23", make_program(
        oscillator_2_waveform=WAVEFORM_SINUS,
        oscillator_2_pitch=88,
        oscillator_3_waveform=WAVEFORM_SINUS,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_23_mix=0x600,
        oscillator_23_fm=1,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
    ), S

    # Both ring-mod pairs active simultaneously
    yield "ringmod_both_13_23", make_program(
        oscillator_1_waveform=WAVEFORM_SAW,
        oscillator_1_mix=0x600,
        oscillator_1_pitch=88,
        oscillator_2_waveform=WAVEFORM_SINUS,
        oscillator_2_mix=0x400,
        oscillator_2_pitch=133,
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_13_mix=0x500,
        oscillator_23_mix=0x400,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
    ), S

    # Both FM pairs
    yield "fm_both_13_23", make_program(
        oscillator_1_waveform=WAVEFORM_SINUS,
        oscillator_1_pitch=66,
        oscillator_2_waveform=WAVEFORM_SINUS,
        oscillator_2_pitch=132,
        oscillator_3_waveform=WAVEFORM_SINUS,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_13_mix=0x500,
        oscillator_13_fm=1,
        oscillator_23_mix=0x300,
        oscillator_23_fm=1,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
    ), S

    # ------------------------------------------------------------------ #
    # Filter sweep                                                         #
    # ------------------------------------------------------------------ #

    for ffreq in [0x100, 0x400, 0x800, 0xfff]:
        for res in [0, 0x400, 0x800, 0xc00]:
            yield f"filter_f{ffreq:03x}_r{res:03x}", make_program(
                oscillator_3_waveform=WAVEFORM_SAW,
                oscillator_3_mix=0xfff,
                oscillator_3_pitch=175,
                oscillator_3_width=0x800,
                filter_frequency=ffreq,
                filter_resonance=res,
                envelope_1_sustain=0xfff,
            ), S

    # ------------------------------------------------------------------ #
    # 12dB and 18dB LPF modes                                            #
    # ------------------------------------------------------------------ #

    for ft, label in [(FILTER_TYPE_LPF_12DB, 'lpf12'), (FILTER_TYPE_LPF_18DB, 'lpf18')]:
        for ffreq in [0x100, 0x400, 0x800, 0xfff]:
            for res in [0, 0x400, 0x800]:
                yield f"{label}_f{ffreq:03x}_r{res:03x}", make_program(
                    oscillator_3_waveform=WAVEFORM_SAW,
                    oscillator_3_mix=0xfff,
                    oscillator_3_pitch=175,
                    oscillator_3_width=0x800,
                    filter_frequency=ffreq,
                    filter_resonance=res,
                    filter_type=ft,
                    envelope_1_sustain=0xfff,
                ), S
        # With LFO modulation
        yield f"{label}_lfo_filter", make_program(
            oscillator_3_waveform=WAVEFORM_SAW,
            oscillator_3_mix=0xfff,
            oscillator_3_pitch=175,
            filter_frequency=0x400,
            filter_frequency_lfo_2=0x300,
            filter_resonance=0x600,
            filter_type=ft,
            envelope_1_sustain=0xfff,
            lfo_2_speed=800,
            lfo_2_waveform=WAVEFORM_LFO_TRIANGLE,
        ), S

    # ------------------------------------------------------------------ #
    # ENV1 (amplitude) shapes                                             #
    # ------------------------------------------------------------------ #

    for atk in [0, 0x100, 0x400]:
        for dec in [0, 0x200, 0x800]:
            for sus in [0, 0x400, 0xfff]:
                yield f"env1_a{atk:03x}_d{dec:03x}_s{sus:03x}", make_program(
                    oscillator_3_waveform=WAVEFORM_SAW,
                    oscillator_3_mix=0xfff,
                    oscillator_3_pitch=175,
                    filter_frequency=0xfff,
                    envelope_1_attack=atk,
                    envelope_1_decay=dec,
                    envelope_1_sustain=sus,
                ), S

    # ------------------------------------------------------------------ #
    # LFO1 modulating OSC3 pitch                                          #
    # ------------------------------------------------------------------ #

    for lfo_wf in [WAVEFORM_LFO_SAW, WAVEFORM_LFO_SQUARE, WAVEFORM_LFO_TRIANGLE]:
        for speed in [100, 500, 2000]:
            yield f"lfo1_pitch_wf{lfo_wf}_s{speed}", make_program(
                oscillator_3_waveform=WAVEFORM_SAW,
                oscillator_3_mix=0xfff,
                oscillator_3_pitch=175,
                oscillator_3_pitch_lfo_1=0x200,
                filter_frequency=0xfff,
                envelope_1_sustain=0xfff,
                lfo_1_speed=speed,
                lfo_1_waveform=lfo_wf,
            ), S

    # ------------------------------------------------------------------ #
    # LFO1 modulating width — previously untested                         #
    # ------------------------------------------------------------------ #

    for lfo_wf in [WAVEFORM_LFO_SAW, WAVEFORM_LFO_TRIANGLE]:
        for speed in [300, 1200]:
            yield f"lfo1_width_wf{lfo_wf}_s{speed}", make_program(
                oscillator_3_waveform=WAVEFORM_SQUARE_1,
                oscillator_3_mix=0xfff,
                oscillator_3_pitch=175,
                oscillator_3_width=0x800,
                oscillator_3_width_lfo_1=0x400,
                filter_frequency=0xfff,
                envelope_1_sustain=0xfff,
                lfo_1_speed=speed,
                lfo_1_waveform=lfo_wf,
            ), S

    # ------------------------------------------------------------------ #
    # LFO1 modulating sync — previously untested                          #
    # ------------------------------------------------------------------ #

    for speed in [500, 1500]:
        yield f"lfo1_sync_s{speed}", make_program(
            oscillator_3_waveform=WAVEFORM_SAW,
            oscillator_3_mix=0xfff,
            oscillator_3_pitch=175,
            oscillator_3_sync_lfo_1=0x500,
            filter_frequency=0xfff,
            envelope_1_sustain=0xfff,
            lfo_1_speed=speed,
            lfo_1_waveform=WAVEFORM_LFO_TRIANGLE,
        ), S

    # ------------------------------------------------------------------ #
    # LFO2 modulating filter frequency                                    #
    # ------------------------------------------------------------------ #

    yield "lfo2_filter", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        filter_frequency=0x400,
        filter_frequency_lfo_2=0x300,
        filter_resonance=0x600,
        envelope_1_sustain=0xfff,
        lfo_2_speed=800,
        lfo_2_waveform=WAVEFORM_LFO_TRIANGLE,
    ), S

    # ------------------------------------------------------------------ #
    # LFO2 modulating pitch, mix, width — previously untested             #
    # ------------------------------------------------------------------ #

    for lfo_wf in [WAVEFORM_LFO_SAW, WAVEFORM_LFO_TRIANGLE]:
        for speed in [200, 1500]:
            yield f"lfo2_pitch_wf{lfo_wf}_s{speed}", make_program(
                oscillator_3_waveform=WAVEFORM_SAW,
                oscillator_3_mix=0xfff,
                oscillator_3_pitch=175,
                oscillator_3_pitch_lfo_2=0x300,
                filter_frequency=0xfff,
                envelope_1_sustain=0xfff,
                lfo_2_speed=speed,
                lfo_2_waveform=lfo_wf,
            ), S

    yield "lfo2_osc3mix", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0x800,
        oscillator_3_mix_lfo_2=0x600,
        oscillator_3_pitch=175,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
        lfo_2_speed=600,
        lfo_2_waveform=WAVEFORM_LFO_SAW,
    ), S

    yield "lfo2_width", make_program(
        oscillator_3_waveform=WAVEFORM_SQUARE_2,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_3_width=0x600,
        oscillator_3_width_lfo_2=0x500,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
        lfo_2_speed=400,
        lfo_2_waveform=WAVEFORM_LFO_TRIANGLE,
    ), S

    yield "lfo2_filter_res", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        filter_frequency=0x800,
        filter_resonance=0x200,
        filter_resonance_lfo_2=0x600,
        envelope_1_sustain=0xfff,
        lfo_2_speed=700,
        lfo_2_waveform=WAVEFORM_LFO_SAW,
    ), S

    # ------------------------------------------------------------------ #
    # Both LFOs simultaneously — previously untested                      #
    # ------------------------------------------------------------------ #

    yield "both_lfos_pitch_filter", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_3_pitch_lfo_1=0x200,
        filter_frequency=0x600,
        filter_frequency_lfo_2=0x400,
        filter_resonance=0x500,
        envelope_1_sustain=0xfff,
        lfo_1_speed=300,
        lfo_1_waveform=WAVEFORM_LFO_TRIANGLE,
        lfo_2_speed=800,
        lfo_2_waveform=WAVEFORM_LFO_SAW,
    ), S

    yield "both_lfos_width_sync", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_3_width=0x800,
        oscillator_3_width_lfo_1=0x400,
        oscillator_3_sync_lfo_2=0x600,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
        lfo_1_speed=600,
        lfo_1_waveform=WAVEFORM_LFO_SAW,
        lfo_2_speed=250,
        lfo_2_waveform=WAVEFORM_LFO_TRIANGLE,
    ), S

    # ------------------------------------------------------------------ #
    # Sync effect                                                          #
    # ------------------------------------------------------------------ #

    for sync_val in [0x200, 0x600, 0xfff]:
        yield f"sync_osc3_s{sync_val:03x}", make_program(
            oscillator_3_waveform=WAVEFORM_SAW,
            oscillator_3_mix=0xfff,
            oscillator_3_pitch=175,
            oscillator_3_sync=sync_val,
            filter_frequency=0xfff,
            envelope_1_sustain=0xfff,
        ), S

    # ------------------------------------------------------------------ #
    # ENV2 as modulation source — shape variations — previously untested  #
    # ------------------------------------------------------------------ #

    for atk in [0, 0x200, 0x600]:
        for dec in [0, 0x400]:
            for sus in [0, 0x800]:
                yield f"env2_a{atk:03x}_d{dec:03x}_s{sus:03x}", make_program(
                    oscillator_3_waveform=WAVEFORM_SAW,
                    oscillator_3_mix=0xfff,
                    oscillator_3_mix_env_2=0x600,
                    oscillator_3_pitch=175,
                    filter_frequency=0xfff,
                    envelope_1_sustain=0xfff,
                    envelope_2_attack=atk,
                    envelope_2_decay=dec,
                    envelope_2_sustain=sus,
                ), S

    # ENV2 modulating pitch
    yield "env2_osc3pitch", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_3_pitch_env_2=0x400,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
        envelope_2_attack=0x100,
        envelope_2_decay=0x400,
        envelope_2_sustain=0x300,
    ), S

    # ENV2 modulating filter frequency
    yield "env2_filter_freq", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        filter_frequency=0x200,
        filter_frequency_env_2=0x7ff,
        filter_resonance=0x600,
        envelope_1_sustain=0xfff,
        envelope_2_attack=0x80,
        envelope_2_decay=0x500,
        envelope_2_sustain=0x300,
    ), S

    # ENV2 modulating filter resonance
    yield "env2_filter_res", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        filter_frequency=0x800,
        filter_resonance=0x200,
        filter_resonance_env_2=0x800,
        envelope_1_sustain=0xfff,
        envelope_2_decay=0x400,
        envelope_2_sustain=0x600,
    ), S

    # ENV2 modulating OSC1 mix (existing cross-check, kept)
    yield "env2_osc1mix", make_program(
        oscillator_1_waveform=WAVEFORM_SINUS,
        oscillator_1_mix_env_2=0xfff,
        oscillator_1_pitch=88,
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
        envelope_2_decay=0x400,
        envelope_2_sustain=0,
    ), S

    # ------------------------------------------------------------------ #
    # ENV3 as modulation source — previously untested                     #
    # ------------------------------------------------------------------ #

    for atk in [0, 0x300]:
        for dec in [0, 0x500]:
            for sus in [0, 0xfff]:
                yield f"env3_a{atk:03x}_d{dec:03x}_s{sus:03x}", make_program(
                    oscillator_3_waveform=WAVEFORM_SAW,
                    oscillator_3_mix=0xfff,
                    oscillator_3_pitch=175,
                    filter_frequency=0x400,
                    filter_frequency_env_3=0x7ff,
                    filter_resonance=0x600,
                    envelope_1_sustain=0xfff,
                    envelope_3_attack=atk,
                    envelope_3_decay=dec,
                    envelope_3_sustain=sus,
                ), S

    # ENV3 modulating pitch
    yield "env3_osc3pitch", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_3_pitch_env_3=0x600,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
        envelope_3_decay=0x600,
        envelope_3_sustain=0x200,
    ), S

    # ENV3 modulating filter resonance
    yield "env3_filter_res", make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        filter_frequency=0x600,
        filter_resonance=0x100,
        filter_resonance_env_3=0x900,
        envelope_1_sustain=0xfff,
        envelope_3_attack=0x200,
        envelope_3_decay=0x800,
        envelope_3_sustain=0x100,
    ), S

    # ------------------------------------------------------------------ #
    # Noise generator                                                      #
    # ------------------------------------------------------------------ #

    yield "noise_gen", make_program(
        oscillator_noise_mix=0xfff,
        filter_frequency=0x800,
        filter_resonance=0x400,
        envelope_1_sustain=0xfff,
    ), S

    # Noise with LFO modulation — previously untested
    yield "noise_lfo1_mix", make_program(
        oscillator_noise_mix=0x800,
        oscillator_noise_mix_lfo_1=0x600,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
        lfo_1_speed=400,
        lfo_1_waveform=WAVEFORM_LFO_TRIANGLE,
    ), S

    yield "noise_lfo2_filter", make_program(
        oscillator_noise_mix=0xfff,
        filter_frequency=0x600,
        filter_frequency_lfo_2=0x500,
        filter_resonance=0x500,
        envelope_1_sustain=0xfff,
        lfo_2_speed=900,
        lfo_2_waveform=WAVEFORM_LFO_SAW,
    ), S

    # Noise with ENV2 modulation — previously untested
    yield "noise_env2_mix", make_program(
        oscillator_noise_mix=0x800,
        oscillator_noise_mix_env_2=0x600,
        filter_frequency=0xfff,
        envelope_1_sustain=0xfff,
        envelope_2_attack=0x100,
        envelope_2_decay=0x300,
    ), S

    # ------------------------------------------------------------------ #
    # Complex preset (cross-check against synth.s preset_bass)           #
    # ------------------------------------------------------------------ #

    yield "preset_bass", make_program(
        oscillator_1_waveform=WAVEFORM_SQUARE_1,
        oscillator_2_waveform=WAVEFORM_SQUARE_2,
        oscillator_2_mix=0x8c0,
        oscillator_2_pitch=88,
        oscillator_3_waveform=WAVEFORM_SQUARE_3,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=44,
        oscillator_3_width=0x800,
        oscillator_3_width_lfo_1=0x7ff,
        oscillator_noise_mix_env_2=0xfff,
        filter_frequency=0x100,
        filter_frequency_env_3=0xfff,
        envelope_1_sustain=0xfff,
        envelope_2_decay=0x80,
        envelope_2_sustain=0x500,
        envelope_3_decay=0x180,
        lfo_1_speed=1000,
        lfo_1_waveform=WAVEFORM_LFO_SAW,
        lfo_2_speed=1000,
        lfo_2_waveform=WAVEFORM_LFO_TRIANGLE,
    ), S

    # ------------------------------------------------------------------ #
    # Variable render sizes — boundary tests                              #
    # ------------------------------------------------------------------ #
    # A single representative program rendered at sizes that stress the
    # per-sample update boundaries (envelope every 8th sample, osc/LFO
    # every 64th sample) and a range of practical module lengths.

    _size_prog = make_program(
        oscillator_3_waveform=WAVEFORM_SAW,
        oscillator_3_mix=0xfff,
        oscillator_3_pitch=175,
        oscillator_3_width=0x800,
        filter_frequency=0x800,
        filter_resonance=0x600,
        envelope_1_attack=0x100,
        envelope_1_decay=0x400,
        envelope_1_sustain=0x800,
        lfo_1_speed=500,
        lfo_1_waveform=WAVEFORM_LFO_TRIANGLE,
        lfo_2_speed=1200,
        lfo_2_waveform=WAVEFORM_LFO_SAW,
        filter_frequency_lfo_2=0x300,
    )

    for size in [
        8,       # exactly one envelope update period
        9,       # one period + 1 sample
        64,      # exactly one oscillator/LFO update period
        65,      # one period + 1 sample
        512,
        4096,
        16384,
        32768,
    ]:
        yield f"size_{size}", _size_prog, size


# ---- runner ----------------------------------------------------------

def run_68k(workdir, params_path, render_size=DEFAULT_RENDER_SIZE):
    """Run synth_render under vamos, return path to output.raw or None."""
    out_path = workdir / "out1.raw"
    out_path.unlink(missing_ok=True)
    cmd = ["vamos", "-V", f"WORK:{workdir}", str(SYNTH_RENDER)]
    result = subprocess.run(cmd, capture_output=True, timeout=30)
    if result.returncode != 0 or not out_path.exists():
        return None, result.stderr.decode()
    return out_path, None


def run_c(params_path, output_path, render_size=DEFAULT_RENDER_SIZE):
    """Run synth_test, return error string or None."""
    result = subprocess.run(
        [str(SYNTH_TEST), str(params_path), str(output_path), str(render_size)],
        capture_output=True, timeout=10,
    )
    if result.returncode != 0:
        return result.stderr.decode() or result.stdout.decode()
    return None


def run_tests(keep_temps=False, verbose=False):
    if not SYNTH_RENDER.exists():
        print(f"ERROR: {SYNTH_RENDER} not found. Run python3 test/68k/build.py first.",
              file=sys.stderr)
        return False
    if not SYNTH_TEST.exists():
        print(f"ERROR: {SYNTH_TEST} not found. Run make -C test first.", file=sys.stderr)
        return False

    passed = 0
    failed = 0
    errors = 0

    with tempfile.TemporaryDirectory(prefix="synth_test_") as tmpdir:
        workdir = Path(tmpdir)

        for name, prog, render_size in gen_test_cases():
            params_path    = workdir / "params.bin"
            params_path_c  = workdir / "params_c.bin"
            c_output       = workdir / "output_c.raw"

            # Write separate params.bin files for each side (issue #3).
            # 68k params include a trailing render_size_param longword.
            params_path.write_bytes(serialize_program(prog, for_68k=True,
                                                       render_size=render_size))
            params_path_c.write_bytes(serialize_program(prog, for_68k=False))

            err_68k = None
            out_68k, err_68k = run_68k(workdir, params_path, render_size)
            if out_68k is None:
                if verbose:
                    print(f"  68k error: {err_68k}")
                print(f"FAIL (68k error) {name}")
                errors += 1
                continue

            err_c = run_c(params_path_c, c_output, render_size)
            if err_c:
                if verbose:
                    print(f"  C error: {err_c}")
                print(f"FAIL (C error)  {name}")
                errors += 1
                continue

            data_68k = out_68k.read_bytes()
            data_c   = c_output.read_bytes()

            if len(data_68k) != render_size:
                print(f"FAIL (size)     {name}  "
                      f"68k output {len(data_68k)} bytes, expected {render_size}")
                errors += 1
                continue
            if len(data_c) != render_size:
                print(f"FAIL (size)     {name}  "
                      f"C output {len(data_c)} bytes, expected {render_size}")
                errors += 1
                continue

            if data_68k == data_c:
                if verbose:
                    print(f"pass            {name}")
                passed += 1
            else:
                # Show first difference
                first_diff = next(
                    (i for i, (a, b) in enumerate(zip(data_68k, data_c)) if a != b),
                    None,
                )
                print(f"FAIL (mismatch) {name}  "
                      f"first diff at byte {first_diff}: "
                      f"68k={data_68k[first_diff]:02x} C={data_c[first_diff]:02x}")
                failed += 1

    total = passed + failed + errors
    print(f"\n{passed}/{total} passed, {failed} mismatches, {errors} errors")
    return failed == 0 and errors == 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", "-v", action="store_true")
    args = ap.parse_args()
    ok = run_tests(verbose=args.verbose)
    sys.exit(0 if ok else 1)
