#!/usr/bin/env python3
"""
render_bank_synth.py — render all bank A factory presets via pt2_synth.

Converts each Supernova II sysex program to a pt2_synth params.bin (using the
same mapping as supernova2_sysex_to_jrm.py) and renders it with test/synth_test,
producing one WAV per program — analogous to record_bank_dry.py but using the
software synthesizer instead of MIDI playback.

Usage:
    python3 render_bank_synth.py [--bank-file supernova2/pbanka.mid]
                                  [--synth-test test/synth_test]
                                  [--out-dir bank_a_synth]
                                  [--render-seconds 6]
                                  [--start-from 0]
"""

import argparse
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

# Import all conversion logic from the sysex converter.
sys.path.insert(0, str(Path(__file__).parent))
from supernova2_sysex_to_jrm import parse_sysex_bank, convert_program

SYNTH_SAMPLERATE = 22050
SEMITONE_SHIFT = -5
PLAYBACK_SAMPLERATE = int(round(SYNTH_SAMPLERATE * 2 ** (SEMITONE_SHIFT / 12)))


def write_wav_header(f, n_samples, sr=SYNTH_SAMPLERATE, bits=16, channels=1):
    data_bytes = n_samples * channels * (bits // 8)
    f.write(b'RIFF')
    f.write(struct.pack('<I', 36 + data_bytes))
    f.write(b'WAVE')
    f.write(b'fmt ')
    f.write(struct.pack('<I', 16))
    f.write(struct.pack('<H', 1))           # PCM
    f.write(struct.pack('<H', channels))
    f.write(struct.pack('<I', sr))
    f.write(struct.pack('<I', sr * channels * bits // 8))
    f.write(struct.pack('<H', channels * bits // 8))
    f.write(struct.pack('<H', bits))
    f.write(b'data')
    f.write(struct.pack('<I', data_bytes))


def render_program(params_bin: bytes, out_wav: Path, synth_test_bin: str, render_size: int):
    """Run synth_test with the given 208-byte params.bin and write a 16-bit WAV."""
    with tempfile.TemporaryDirectory() as tmp:
        params_path = Path(tmp) / 'params.bin'
        raw_path    = Path(tmp) / 'out.raw'

        params_path.write_bytes(params_bin)
        subprocess.run(
            [synth_test_bin, str(params_path), str(raw_path), str(render_size)],
            check=True, capture_output=True
        )
        raw = raw_path.read_bytes()

    pcm8  = np.frombuffer(raw, dtype=np.int8)
    pcm16 = pcm8.astype(np.int16) << 8

    with open(out_wav, 'wb') as f:
        write_wav_header(f, len(pcm16), sr=PLAYBACK_SAMPLERATE)
        f.write(pcm16.tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bank-file',      default='supernova2/pbanka.mid')
    ap.add_argument('--synth-test',     default='test/synth_test')
    ap.add_argument('--out-dir',        default='bank_a_synth')
    ap.add_argument('--render-seconds', type=float, default=6.0)
    ap.add_argument('--start-from',     type=int, default=0,
                    help='Skip programs before this index (for resuming)')
    args = ap.parse_args()

    synth_test = str(Path(args.synth_test).resolve())
    if not Path(synth_test).exists():
        sys.exit(f"synth_test not found at {synth_test} — run: make -C test")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(exist_ok=True)

    render_size = int(args.render_seconds * SYNTH_SAMPLERATE)

    p02, p1f = parse_sysex_bank(args.bank_file)
    print(f"Parsed {len(p02)} programs from {args.bank_file}")
    print(f"Output → {out_dir}/   render={args.render_seconds}s  ({render_size} samples @ {SYNTH_SAMPLERATE} Hz)")
    print()

    errors = []
    for idx in range(128):
        if idx < args.start_from:
            continue
        if idx not in p02 or idx not in p1f:
            continue

        name_bytes = p02[idx][0:16]
        name = name_bytes.rstrip(b'\x00').decode('latin-1').strip()
        safe_name = ''.join(c if c.isalnum() or c in ' _-' else '_' for c in name).strip()
        wav_path = out_dir / f"A{idx:03d}_{safe_name}.wav"

        print(f"[{idx:03d}] {name:<24}", end='  ', flush=True)

        try:
            program_record = convert_program(p02[idx], p1f[idx])
        except Exception as e:
            print(f"SKIP (conversion error: {e})")
            errors.append(f"  [{idx:03d}] {name}: {e}")
            continue

        # convert_program returns 16-byte name + 208-byte params.bin in JRM format.
        # JRM stores LFO waveforms as 68k byte offsets (SAW=1536, SQUARE=9728, TRIANGLE=17920),
        # but synth_test expects C enum values (SAW=0, SQUARE=4096, TRIANGLE=8192).
        # Convert: c_value = (jrm_value - 1536) // 2.
        # LFO1 waveform is at byte offset 200, LFO2 waveform at byte offset 204.
        params_bin = bytearray(program_record[16:])
        assert len(params_bin) == 208
        for lfo_wf_offset in (200, 204):
            jrm_val = struct.unpack_from('>H', params_bin, lfo_wf_offset)[0]
            struct.pack_into('>H', params_bin, lfo_wf_offset, (jrm_val - 1536) // 2)
        params_bin = bytes(params_bin)

        try:
            render_program(params_bin, wav_path, synth_test, render_size)
            print(f"→ {wav_path.name}")
        except subprocess.CalledProcessError as e:
            print(f"SKIP (synth_test error: {e})")
            errors.append(f"  [{idx:03d}] {name}: synth_test failed")

    if errors:
        print("\nErrors:")
        for e in errors:
            print(e)


if __name__ == '__main__':
    main()
