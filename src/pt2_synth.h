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

typedef struct program_t
{
    char name[16];
    enum waveform_t oscillator_1_waveform;
    int16_t oscillator_1_mix;
    int16_t oscillator_1_mix_lfo_1;
    int16_t oscillator_1_mix_lfo_2;
    int16_t oscillator_1_mix_env_2;
    int16_t oscillator_1_mix_env_3;
    int16_t oscillator_1_pitch;
    int16_t oscillator_1_pitch_lfo_1;
    int16_t oscillator_1_pitch_lfo_2;
    int16_t oscillator_1_pitch_env_2;
    int16_t oscillator_1_pitch_env_3;
    int16_t oscillator_1_width;
    int16_t oscillator_1_width_lfo_1;
    int16_t oscillator_1_width_lfo_2;
    int16_t oscillator_1_width_env_2;
    int16_t oscillator_1_width_env_3;
    int16_t oscillator_1_sync;
    int16_t oscillator_1_sync_lfo_1;
    int16_t oscillator_1_sync_lfo_2;
    int16_t oscillator_1_sync_env_2;
    int16_t oscillator_1_sync_env_3;
    enum waveform_t oscillator_2_waveform;
    int16_t oscillator_2_mix;
    int16_t oscillator_2_mix_lfo_1;
    int16_t oscillator_2_mix_lfo_2;
    int16_t oscillator_2_mix_env_2;
    int16_t oscillator_2_mix_env_3;
    int16_t oscillator_2_pitch;
    int16_t oscillator_2_pitch_lfo_1;
    int16_t oscillator_2_pitch_lfo_2;
    int16_t oscillator_2_pitch_env_2;
    int16_t oscillator_2_pitch_env_3;
    int16_t oscillator_2_width;
    int16_t oscillator_2_width_lfo_1;
    int16_t oscillator_2_width_lfo_2;
    int16_t oscillator_2_width_env_2;
    int16_t oscillator_2_width_env_3;
    int16_t oscillator_2_sync;
    int16_t oscillator_2_sync_lfo_1;
    int16_t oscillator_2_sync_lfo_2;
    int16_t oscillator_2_sync_env_2;
    int16_t oscillator_2_sync_env_3;
    enum waveform_t oscillator_3_waveform;
    int16_t oscillator_3_mix;
    int16_t oscillator_3_mix_lfo_1;
    int16_t oscillator_3_mix_lfo_2;
    int16_t oscillator_3_mix_env_2;
    int16_t oscillator_3_mix_env_3;
    int16_t oscillator_3_pitch;
    int16_t oscillator_3_pitch_lfo_1;
    int16_t oscillator_3_pitch_lfo_2;
    int16_t oscillator_3_pitch_env_2;
    int16_t oscillator_3_pitch_env_3;
    int16_t oscillator_3_width;
    int16_t oscillator_3_width_lfo_1;
    int16_t oscillator_3_width_lfo_2;
    int16_t oscillator_3_width_env_2;
    int16_t oscillator_3_width_env_3;
    int16_t oscillator_3_sync;
    int16_t oscillator_3_sync_lfo_1;
    int16_t oscillator_3_sync_lfo_2;
    int16_t oscillator_3_sync_env_2;
    int16_t oscillator_3_sync_env_3;
    int16_t oscillator_noise_mix;
    int16_t oscillator_noise_mix_lfo_1;
    int16_t oscillator_noise_mix_lfo_2;
    int16_t oscillator_noise_mix_env_2;
    int16_t oscillator_noise_mix_env_3;
    int16_t oscillator_13_mix;
    int16_t oscillator_13_mix_lfo_1;
    int16_t oscillator_13_mix_lfo_2;
    int16_t oscillator_13_mix_env_2;
    int16_t oscillator_13_mix_env_3;
    int16_t oscillator_13_fm;
    int16_t oscillator_23_mix;
    int16_t oscillator_23_mix_lfo_1;
    int16_t oscillator_23_mix_lfo_2;
    int16_t oscillator_23_mix_env_2;
    int16_t oscillator_23_mix_env_3;
    int16_t oscillator_23_fm;
    int16_t filter_frequency;
    int16_t filter_frequency_lfo_1;
    int16_t filter_frequency_lfo_2;
    int16_t filter_frequency_env_2;
    int16_t filter_frequency_env_3;
    int16_t filter_resonance;
    int16_t filter_resonance_lfo_1;
    int16_t filter_resonance_lfo_2;
    int16_t filter_resonance_env_2;
    int16_t filter_resonance_env_3;
    int16_t envelope_1_attack;
    int16_t envelope_1_decay;
    int16_t envelope_1_sustain;
    int16_t envelope_2_attack;
    int16_t envelope_2_decay;
    int16_t envelope_2_sustain;
    int16_t envelope_3_attack;
    int16_t envelope_3_decay;
    int16_t envelope_3_sustain;
    int16_t lfo_1_speed;
    enum waveform_lfo_t lfo_1_waveform;
    int16_t lfo_2_speed;
    enum waveform_lfo_t lfo_2_waveform;
} program_t;

typedef struct part_t
{
    uint8_t program;
    uint8_t volume;
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
void synthLoad(UNICHAR *fileName);
void synthSave(UNICHAR *fileName);
