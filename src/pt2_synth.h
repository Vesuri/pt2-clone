#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "pt2_structs.h"

enum envelope_mode {
    ENVELOPE_INIT = 0,
    ENVELOPE_ATTACK = 1,
    ENVELOPE_DECAY = 2,
    ENVELOPE_SUSTAIN = 3
};

enum waveform_t {
    WAVEFORM_SAW = 0,
    WAVEFORM_SQUARE_1 = 256,
    WAVEFORM_SQUARE_2 = 512,
    WAVEFORM_SQUARE_3 = 768,
    WAVEFORM_NOISE = 1024,
    WAVEFORM_SINUS = 1280
};

enum waveform_lfo_t {
    WAVEFORM_LFO_SAW = 0,
    WAVEFORM_LFO_SQUARE = 4096,
    WAVEFORM_LFO_TRIANGLE = 8192
};

enum current_oscillator {
    OSCILLATOR_1 = 0,
    OSCILLATOR_2 = 1,
    OSCILLATOR_3 = 2,
    OSCILLATOR_13 = 3,
    OSCILLATOR_23 = 4,
    OSCILLATOR_NOISE = 5
};

// Field ranges for program_t:
//   mix base (oscillator_*_mix, oscillator_noise_mix, oscillator_13/23_mix): uint16_t, 0x000–0xfff
//   mix modulation depths (*_mix_lfo_1/2, *_mix_env_2/3):                   int16_t,  −0x7ff–0x7ff
//   pitch base (oscillator_*_pitch):                                         uint16_t, 0x000–0x7ff
//   pitch modulation depths (*_pitch_lfo_*, *_pitch_env_*):                  int16_t,  −0x800–0x7ff
//   width base (oscillator_*_width):                                         uint16_t, 0x000–0xfff (>> 4 → 0–255 waveform index)
//   width modulation depths (*_width_lfo_*, *_width_env_*):                  int16_t,  −0x7ff–0x7ff
//   sync base (oscillator_*_sync):                                           uint16_t, 0x000–0xfff
//   sync modulation depths (*_sync_lfo_*, *_sync_env_*):                     int16_t,  −0x7ff–0x7ff
//   filter_frequency, filter_resonance (base):                               uint16_t, 0x000–0xfff
//   filter modulation depths (*_lfo_*, *_env_*):                             int16_t,  −0x7ff–0x7ff
//   envelope_*_attack, envelope_*_decay, envelope_*_sustain:                 uint16_t, 0x000–0xfff
//   lfo_*_speed:                                                              uint16_t, 0x0000–0x7fff
//   lfo_*_waveform:                                                           WAVEFORM_LFO_SAW/SQUARE/TRIANGLE (0/4096/8192); clamped to SAW on invalid load
//   oscillator_13_fm, oscillator_23_fm:                                       uint16_t, 0 (ring mod) or 1 (FM); normalised to 0/1 on load
typedef struct program_t
{
    char name[16];
    enum waveform_t oscillator_1_waveform;
    uint16_t oscillator_1_mix;           // 0x000–0xfff
    int16_t oscillator_1_mix_lfo_1;     // signed depth
    int16_t oscillator_1_mix_lfo_2;     // signed depth
    int16_t oscillator_1_mix_env_2;     // signed depth
    int16_t oscillator_1_mix_env_3;     // signed depth
    uint16_t oscillator_1_pitch;         // 0x000–0x7ff
    int16_t oscillator_1_pitch_lfo_1;   // signed depth
    int16_t oscillator_1_pitch_lfo_2;   // signed depth
    int16_t oscillator_1_pitch_env_2;   // signed depth
    int16_t oscillator_1_pitch_env_3;   // signed depth
    uint16_t oscillator_1_width;         // 0x000–0xfff
    int16_t oscillator_1_width_lfo_1;   // signed depth
    int16_t oscillator_1_width_lfo_2;   // signed depth
    int16_t oscillator_1_width_env_2;   // signed depth
    int16_t oscillator_1_width_env_3;   // signed depth
    uint16_t oscillator_1_sync;          // 0x000–0xfff
    int16_t oscillator_1_sync_lfo_1;    // signed depth
    int16_t oscillator_1_sync_lfo_2;    // signed depth
    int16_t oscillator_1_sync_env_2;    // signed depth
    int16_t oscillator_1_sync_env_3;    // signed depth
    enum waveform_t oscillator_2_waveform;
    uint16_t oscillator_2_mix;           // 0x000–0xfff
    int16_t oscillator_2_mix_lfo_1;     // signed depth
    int16_t oscillator_2_mix_lfo_2;     // signed depth
    int16_t oscillator_2_mix_env_2;     // signed depth
    int16_t oscillator_2_mix_env_3;     // signed depth
    uint16_t oscillator_2_pitch;         // 0x000–0x7ff
    int16_t oscillator_2_pitch_lfo_1;   // signed depth
    int16_t oscillator_2_pitch_lfo_2;   // signed depth
    int16_t oscillator_2_pitch_env_2;   // signed depth
    int16_t oscillator_2_pitch_env_3;   // signed depth
    uint16_t oscillator_2_width;         // 0x000–0xfff
    int16_t oscillator_2_width_lfo_1;   // signed depth
    int16_t oscillator_2_width_lfo_2;   // signed depth
    int16_t oscillator_2_width_env_2;   // signed depth
    int16_t oscillator_2_width_env_3;   // signed depth
    uint16_t oscillator_2_sync;          // 0x000–0xfff
    int16_t oscillator_2_sync_lfo_1;    // signed depth
    int16_t oscillator_2_sync_lfo_2;    // signed depth
    int16_t oscillator_2_sync_env_2;    // signed depth
    int16_t oscillator_2_sync_env_3;    // signed depth
    enum waveform_t oscillator_3_waveform;
    uint16_t oscillator_3_mix;           // 0x000–0xfff
    int16_t oscillator_3_mix_lfo_1;     // signed depth
    int16_t oscillator_3_mix_lfo_2;     // signed depth
    int16_t oscillator_3_mix_env_2;     // signed depth
    int16_t oscillator_3_mix_env_3;     // signed depth
    uint16_t oscillator_3_pitch;         // 0x000–0x7ff
    int16_t oscillator_3_pitch_lfo_1;   // signed depth
    int16_t oscillator_3_pitch_lfo_2;   // signed depth
    int16_t oscillator_3_pitch_env_2;   // signed depth
    int16_t oscillator_3_pitch_env_3;   // signed depth
    uint16_t oscillator_3_width;         // 0x000–0xfff
    int16_t oscillator_3_width_lfo_1;   // signed depth
    int16_t oscillator_3_width_lfo_2;   // signed depth
    int16_t oscillator_3_width_env_2;   // signed depth
    int16_t oscillator_3_width_env_3;   // signed depth
    uint16_t oscillator_3_sync;          // 0x000–0xfff
    int16_t oscillator_3_sync_lfo_1;    // signed depth
    int16_t oscillator_3_sync_lfo_2;    // signed depth
    int16_t oscillator_3_sync_env_2;    // signed depth
    int16_t oscillator_3_sync_env_3;    // signed depth
    uint16_t oscillator_noise_mix;       // 0x000–0xfff
    int16_t oscillator_noise_mix_lfo_1; // signed depth
    int16_t oscillator_noise_mix_lfo_2; // signed depth
    int16_t oscillator_noise_mix_env_2; // signed depth
    int16_t oscillator_noise_mix_env_3; // signed depth
    uint16_t oscillator_13_mix;          // 0x000–0xfff
    int16_t oscillator_13_mix_lfo_1;    // signed depth
    int16_t oscillator_13_mix_lfo_2;    // signed depth
    int16_t oscillator_13_mix_env_2;    // signed depth
    int16_t oscillator_13_mix_env_3;    // signed depth
    uint16_t oscillator_13_fm;           // 0 = ring mod, 1 = FM
    uint16_t oscillator_23_mix;          // 0x000–0xfff
    int16_t oscillator_23_mix_lfo_1;    // signed depth
    int16_t oscillator_23_mix_lfo_2;    // signed depth
    int16_t oscillator_23_mix_env_2;    // signed depth
    int16_t oscillator_23_mix_env_3;    // signed depth
    uint16_t oscillator_23_fm;           // 0 = ring mod, 1 = FM
    uint16_t filter_frequency;           // 0x000–0xfff
    int16_t filter_frequency_lfo_1;     // signed depth
    int16_t filter_frequency_lfo_2;     // signed depth
    int16_t filter_frequency_env_2;     // signed depth
    int16_t filter_frequency_env_3;     // signed depth
    uint16_t filter_resonance;           // 0x000–0xfff
    int16_t filter_resonance_lfo_1;     // signed depth
    int16_t filter_resonance_lfo_2;     // signed depth
    int16_t filter_resonance_env_2;     // signed depth
    int16_t filter_resonance_env_3;     // signed depth
    uint16_t envelope_1_attack;          // 0x000–0xfff
    uint16_t envelope_1_decay;           // 0x000–0xfff
    uint16_t envelope_1_sustain;         // 0x000–0xfff
    uint16_t envelope_2_attack;          // 0x000–0xfff
    uint16_t envelope_2_decay;           // 0x000–0xfff
    uint16_t envelope_2_sustain;         // 0x000–0xfff
    uint16_t envelope_3_attack;          // 0x000–0xfff
    uint16_t envelope_3_decay;           // 0x000–0xfff
    uint16_t envelope_3_sustain;         // 0x000–0xfff
    uint16_t lfo_1_speed;                // 0x0000–0x7fff
    enum waveform_lfo_t lfo_1_waveform; // WAVEFORM_LFO_SAW/SQUARE/TRIANGLE
    uint16_t lfo_2_speed;                // 0x0000–0x7fff
    enum waveform_lfo_t lfo_2_waveform; // WAVEFORM_LFO_SAW/SQUARE/TRIANGLE
} program_t;

typedef struct part_t
{
    uint8_t program;
    uint8_t padding;
    uint16_t volume;
    uint16_t sampleRate;
    uint16_t offset;
} part_t;

typedef struct performance_t
{
    char name[16];
    part_t parts[8];
} performance_t;

typedef struct synth_t
{
    performance_t performances[MOD_SAMPLES];
    program_t programs[128];
    bool performanceEnabled[MOD_SAMPLES];

    uint8_t currPart;
    enum current_oscillator currOsc;
} synth_t;

extern synth_t synth; // pt2_synth.c

void initSynth(void);
void synthRender(void);
void renderPart(part_t* part, bool add);
void synthLoad(UNICHAR *fileName, bool allPerformances);
void synthSave(UNICHAR *fileName, bool allPerformances);
