# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

pt2-clone is a C port of Amiga **ProTracker 2.3D** with an added software synthesizer. The stated goal is a 1:1 behavioral clone of the original tracker, not a clean or flexible codebase — the author calls the source "hackish and hardcoded" and prioritizes accuracy over abstraction. Treat existing oddities (magic constants, hardcoded coordinates, global state) as deliberate. SDL2 is the only third-party dependency.

The **`synth` branch** adds a custom software synthesizer that generates sample data into the ProTracker sample slots. Its UI appears in a second panel rendered below the standard tracker screen (y ≥ 255).

A small companion tool, the palette editor, lives under `pt_pal_editor/` with its own `src/` and build scripts; it is unrelated to the main tracker build.

## Build

There is no test suite. The build produces a single executable.

- **Linux:** `./make-linux.sh` → `release/other/pt2-clone`. Requires `libsdl2-dev` + ALSA dev headers.
- **macOS:** `./make-macos.sh` builds x86_64 + arm64 and lipo's them into a universal binary inside `release/macos/pt2-clone-macos.app`. Requires the SDL2 framework installed in `/Library/Frameworks/` (see `HOW-TO-COMPILE.txt`).
- **Windows:** open `vs2019_project/pt2-clone.sln` in Visual Studio 2019+, build in Release mode (x86 or x64).
- **CMake (alternate):** `cmake . && make` — globs `src/*.c` and `src/gfx/*.c`, outputs to `release/other/`.

All build paths glob the entire `src/` tree, so new `.c` files are picked up automatically — no Makefile edits needed, but Visual Studio project files must be updated manually.

The version string lives in `src/pt2_header.h` as `PROG_VER_STR`; `make-macos.sh` greps it to name the build.

## Architecture

Entry point is `src/pt2_main.c`. The program is built around a handful of large global structs (`keyb`, `mouse`, `video`, `editor`, `diskop`, `cursor`, `ui`, `config`, plus the `song` pointer) that are zeroed in `clearStructs()` and then mutated throughout. Treat these as the canonical shared state — most modules read and write them directly rather than passing parameters.

Module layout (in `src/`):

- **Replayer / audio core:** `pt2_replayer.c` is a hand-port of the original 68k ProTracker 2.3D playroutine — preserve its quirks. `pt2_audio.c` drives the SDL audio callback and the Paula-style mixer. `pt2_blep.c` (band-limited steps), `pt2_rcfilter.c` (A500 RC low-pass), `pt2_ledfilter.c` (the Amiga "LED" filter), and `pt2_downsample2x.c` together emulate the Amiga audio path. `pt2_scopes.c` runs the on-screen oscilloscopes off the same mixer state.
- **Module I/O:** `pt2_module_loader.c` / `pt2_module_saver.c` for .MOD files, `pt2_sample_loader.c` / `pt2_sample_saver.c` for instruments (WAV/IFF/etc.), `pt2_xpk.c` for XPK-compressed Amiga files, `pt2_mod2wav.c` for offline rendering.
- **UI / editing:** `pt2_visuals.c` is the screen renderer (320×511 framebuffer scaled via SDL — 320×255 for ProTracker, 320×256 for the synth panel below). `pt2_textout.c`, `pt2_bmp.c`, `pt2_palette.c` handle drawing primitives. Per-screen graphics data is split across `src/gfx/pt2_gfx_*.c` (compiled-in bitmap arrays, not runtime assets). `pt2_edit.c`, `pt2_pattern_viewer.c`, `pt2_sampler.c`, `pt2_diskop.c`, `pt2_chordmaker.c`, `pt2_pat2smp.c`, `pt2_sampling.c` implement the various editor screens.
- **Synthesizer:** `pt2_synth.c` / `pt2_synth.h`. See the [Synthesizer](#synthesizer) section below.
- **Input:** `pt2_mouse.c`, `pt2_keyboard.c`.
- **Timing / sync:** `pt2_hpc.c` (high-precision clock), `pt2_sync.c` (audio↔video sync queue so visuals match the audio that's actually playing).
- **Misc:** `pt2_tables.c` (precomputed period/sine/etc. tables — these are the original Amiga tables, not regenerated), `pt2_math.c`, `pt2_helpers.c`, `pt2_unicode.c`, `pt2_structs.c`, `pt2_config.c` (parses `protracker.ini`).

Many Amiga-specific constants live in `pt2_header.h` (PAL crystal, Paula clock, CIA clock, period limits). The replayer math assumes these — don't substitute "round" numbers.

## Synthesizer

`pt2_synth.c` implements a software synthesizer modelled on the feature set of the **Novation Supernova II** hardware synthesizer. It renders audio into ProTracker sample slots before playback. The global `synth_t synth` struct (declared in `pt2_synth.h`, defined in `pt2_synth.c`) holds all synthesizer state and lives alongside the other global structs.

### Supernova II concepts and how they map to the code

The Supernova II organises sounds into three levels: **Program → Performance → Part**. The code mirrors this directly:

| Supernova II term | Code type | Description |
|---|---|---|
| Program | `program_t` | A single voice definition: oscillators, filter, envelopes, LFOs |
| Performance | `performance_t` | Up to 8 layered Parts played together |
| Part | `part_t` | One Program within a Performance, with volume, sample rate, and start offset |

**Oscillators.** Each `program_t` has three oscillators (OSC1, OSC2, OSC3) and a noise generator, matching the Supernova II voice architecture. Waveforms: SAW, SQUARE (three pulse width variants — `WAVEFORM_SQUARE_1/2/3`), NOISE, SINUS. OSC3 is the main audio output to the mixer (as in the Supernova II FM operator topology where OSC3 is the carrier).

**Ring modulators / FM pairs.** The Supernova II front panel labels two outputs as `1*3` and `2*3` (ring modulators between OSC1×OSC3 and OSC2×OSC3). In the code these are `oscillator_13` and `oscillator_23`. Each has a mix level and an `_fm` parameter that switches the pair from ring modulation (multiply) to frequency modulation. This is how the Supernova II's FM synthesis mode works: OSC1 or OSC2 acts as a modulator FM-ing into OSC3.

**Modulation matrix.** The Supernova II uses a hardware modulation matrix where any source (LFO1, LFO2, ENV2, ENV3, Mod Wheel, Aftertouch) can be routed to any destination (mix, pitch, width, sync, filter frequency, filter resonance) at variable depth. In the code this matrix is flattened into individual fields on `program_t`: each modulatable parameter has five suffixed variants — `_lfo_1`, `_lfo_2`, `_env_2`, `_env_3` for oscillators, and the same for filter frequency and resonance. MIDI performance sources (mod wheel, aftertouch, velocity) are not implemented.

**Envelopes.** The Supernova II has 3 envelopes: ENV1 is the *amplifier* envelope (controls overall volume); ENV2 and ENV3 are free modulation sources. The full Supernova II envelope is ADSR with optional Sustain Rate, Sustain Time, and A-D Repeat. The code simplifies to **ADS only** (no Release, no Sustain Rate/Time) — appropriate since samples are rendered to a buffer at a fixed length rather than played in response to key events. The `envelope_mode` states are INIT → ATTACK → DECAY → SUSTAIN.

**Sync.** Each oscillator has a `_sync` parameter (and its LFO/ENV modulators) implementing the Supernova II "Sync Effect" — a simulated oscillator hard-sync that creates the characteristic piercing sync sound without requiring a separate master oscillator.

**Filter.** A single resonant low-pass filter with frequency and resonance, both modulatable by LFO1, LFO2, ENV2, ENV3. The Supernova II offers multiple filter modes (12/18/24 dB LPF, HPF, BPF, Special dual-filter) — the code implements one mode only.

**LFOs.** Two LFOs with waveforms SAW, SQUARE, TRIANGLE (the Supernova II also offers S/H; it is not implemented). LFO speed is a 16-bit value. LFO tables are 4096 samples; oscillator tables are 256 samples.

**Not implemented from the Supernova II:** Hardness effect (harmonic softening), Formant Width, Sync Skew, filter overdrive, all effects (distortion, EQ, comb filter, reverb, chorus/flanger/phaser, delay, pan/tremolo), arpeggiator, vocoder, unison/detune, portamento, and all MIDI-sourced modulation (velocity, mod wheel, aftertouch).

### 68k reference implementation

A Motorola 68000 assembler implementation lives in a **separate repository** at `~/Documents/dA JoRMaS/Effects/synth`. The two implementations must produce identical output. This equivalence is enforced only by discipline — the repos share no history and there is no automated cross-check. When changing synthesis behaviour in either codebase, the corresponding change must be made in the other, and commit messages should note this explicitly. When doing comparison work across both repos, read files from the 68k path directly; Claude Code sessions started in `pt2-clone` will not see that directory automatically.

The 68k repo contains three files relevant to the synth:

- **`synthplayer.s`** — The direct counterpart to `pt2_synth.c`. Defines the same `program_t`/`part_t`/`performance_t` struct layout (via `STRUCTURE` macros), parses the `.jrm` file, and renders performances into module sample data. Field names are identical to the C structs. This is the file to compare against when verifying correctness.
- **`synth.s`** — A standalone prototype that runs on real Amiga hardware. Uses flat global variables instead of structs, and has a real-time mode (Amiga audio DMA + Intuition gadget UI) as well as a file-render mode. The render loop algorithm is the same as `synthplayer.s` but reads from globals rather than a struct base register.
- **`PT2.3F_replay_cia.s`** — The PT2.3F CIA playroutine for Amiga, unmodified.

**Three files relevant to the synth:**

- **`synthplayer.s`** — The direct counterpart to `pt2_synth.c`. Defines the same `program_t`/`part_t`/`performance_t` struct layout (via `STRUCTURE` macros), parses the `.jrm` file, and renders performances into module sample data. Field names are identical to the C structs. This is the file to compare against when verifying correctness.
- **`synth.s`** — A standalone prototype that runs on real Amiga hardware. Uses flat global variables instead of structs, and has a real-time mode (Amiga audio DMA + Intuition gadget UI) as well as a file-render mode. The render loop algorithm is the same as `synthplayer.s` but reads from globals rather than a struct base register.
- **`PT2.3F_replay_cia.s`** — The PT2.3F CIA playroutine for Amiga, unmodified.

**Algorithmic constants that must stay identical in both codebases:**
- `envelope_stretch = 7` — envelopes update every 8th sample (`position & 7 == 0`)
- Oscillator widths, pitches, and filter coefficients update every 64th sample (`position & 63 == 0`)
- Moog 4-pole ladder filter with cubic saturation: `b4 = b4 - b4³/6`
- PRNG seed `0xbc5d71e3`, 5-iteration LFSR (used for noise waveform generation)

**Waveform addressing difference (not a bug).** The 68k lays out all waveform data in a single flat array starting at `waveform_saw`, so the `WAVEFORM_LFO_*` constants in `synth.i` are byte offsets from that base (`1536`, `9728`, `17920`). The C code uses separate `waveforms[]` and `waveforms_lfo[]` arrays, so the enum values are offsets into the LFO array only (`0`, `4096`, `8192`). The actual waveform content is identical.

### Synthesis equivalence test suite

`test/` contains a cross-implementation test harness that verifies `pt2_synth.c` and the 68k `synth.s` produce byte-identical output:

- **`test/68k/build.py`** — Patches `synth.s` from the Bitbucket repo (changes to `RENDER_BUFFER` mode, adds `BUFFER_ONLY` conditional to exclude realtime UI code, adds `load_params` subroutine) and assembles it with `vasmm68k_mot` into `test/68k/synth_render`.
- **`test/synth_test.c`** / **`test/Makefile`** — C test driver; reads a `params.bin` file, calls `renderPart()`, writes raw 8-bit PCM.
- **`test/run_tests.py`** — Generates parameter sets, writes `params.bin` (with per-side LFO constant translation — see issue #3), runs both implementations under vamos / natively, and diffs output byte-for-byte.

**Building:**
```sh
python3 test/68k/build.py          # assembles the 68k binary
make -C test                       # builds synth_test
PATH="$HOME/bin:$PATH" python3 test/run_tests.py -v
```

Requires `vasmm68k_mot` at `~/bin/vasmm68k_mot` (built from `http://sun.hasenbraten.de/vasm/release/vasm.tar.gz`) and `vamos` / `machine68k` / `greenlet` via pip.

### Rendering pipeline

`synthRender()` is called from `pt2_module_loader.c` after a `.mod` is loaded. It iterates the 8 parts of the current sample slot's performance, calling `renderPart()` for each active part. `renderPart()` synthesizes a full sample buffer — running envelopes, LFOs, oscillator mixing, ring mod / FM between the 1×3 and 2×3 pairs, and the resonant filter — then writes 8-bit signed PCM directly into `song->sampleData`.

### Persistence

When a `.mod` is saved, `synthSave()` writes a sidecar `.jrm` file in the same directory. On load, `synthLoad()` reads it back. The `.jrm` format stores enabled-performance and enabled-program bitmasks, then only the active `performance_t` and `program_t` records. All multi-byte values are stored big-endian (explicitly byte-swapped, since the rest of the codebase is little-endian). A separate global `protracker.jrm` in the working directory stores the full 128-program library; it is read at startup.

### UI

The synth panel occupies the lower half of the doubled framebuffer (y coordinates written as `255 + N`). The tracker's `SCREEN_H` constant is 511 on this branch (was 255 on master). Dirty-flag fields for every editable synth parameter live in `ui_t` (in `pt2_structs.h`); set `ui.updateSynth = true` to trigger a full panel redraw. The panel's background bitmap is `src/gfx/pt2_gfx_synth.c`, compiled in from `src/gfx/bmp/synth.bmp`.

## Platform constraints

- **Little-endian only.** The code reads multi-byte module data byte-by-byte in places but does memory-mapped reads in others; do not introduce big-endian-unsafe code, but also do not bother adding portability scaffolding the author has explicitly declined.
- **Arithmetic shift right on signed integers is assumed.** Most compilers emit ASR/SAR, but be aware when porting expressions.
- Windows-specific code (single-instance handling, low-level keyboard hook, file-association IPC via shared memory) is gated on `_WIN32`; macOS-specific code (app translocation check, cwd fix from argv) is gated on `__APPLE__`. Keep new platform code behind the same guards.

## Config

The shipped `protracker.ini` lives under `release/other/` (Linux/Windows) and `release/macos/` (macOS); on Linux/macOS the user copy belongs in `~/.protracker/`. Code that reads config is in `pt2_config.c`.
