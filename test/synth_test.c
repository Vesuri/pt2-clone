/*
 * synth_test — C-side test driver for the synthesis engine.
 *
 * Usage: synth_test <params.bin> <output.raw> [render_size]
 *
 * Reads a 206-byte big-endian params.bin (a serialised program_t), renders
 * render_size samples (default 12288, matching synth.s buffer_render_size),
 * and writes raw signed 8-bit PCM to output.raw.
 *
 * This binary exercises the same renderPart() code that runs inside pt2-clone,
 * so its output can be compared byte-for-byte with the 68k synth_render binary
 * run under vamos.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* Pull in just the headers renderPart() needs. */
#include "../src/pt2_header.h"
#include "../src/pt2_structs.h"
#include "../src/pt2_synth.h"

/* Globals referenced by pt2_synth.c that we stub out here. */
module_t  *song   = NULL;
editor_t   editor;
ui_t       ui;

/* ---- params.bin deserialization ---- */

/* Read a big-endian uint16 from buf at byte offset *pos, advance *pos. */
static int16_t read_be16(const uint8_t *buf, int *pos)
{
	int16_t v = (int16_t)((buf[*pos] << 8) | buf[*pos + 1]);
	*pos += 2;
	return v;
}

static uint16_t read_be16u(const uint8_t *buf, int *pos)
{
	uint16_t v = (uint16_t)((buf[*pos] << 8) | buf[*pos + 1]);
	*pos += 2;
	return v;
}

static void deserialize_program(program_t *p, const uint8_t *buf)
{
	/* The program_t fields are stored as big-endian 16-bit words in the
	 * same order as the struct definition in pt2_synth.h / the globals in
	 * synth.s.  Waveform fields are UWORD (unsigned); everything else is WORD. */
	int pos = 0;

#define RU() read_be16u(buf, &pos)
#define RS() read_be16(buf, &pos)

	p->oscillator_1_waveform      = (enum waveform_t)RU();
	p->oscillator_1_mix           = RS();
	p->oscillator_1_mix_lfo_1     = RS();
	p->oscillator_1_mix_lfo_2     = RS();
	p->oscillator_1_mix_env_2     = RS();
	p->oscillator_1_mix_env_3     = RS();
	p->oscillator_1_pitch         = RS();
	p->oscillator_1_pitch_lfo_1   = RS();
	p->oscillator_1_pitch_lfo_2   = RS();
	p->oscillator_1_pitch_env_2   = RS();
	p->oscillator_1_pitch_env_3   = RS();
	p->oscillator_1_width         = RS();
	p->oscillator_1_width_lfo_1   = RS();
	p->oscillator_1_width_lfo_2   = RS();
	p->oscillator_1_width_env_2   = RS();
	p->oscillator_1_width_env_3   = RS();
	p->oscillator_1_sync          = RS();
	p->oscillator_1_sync_lfo_1    = RS();
	p->oscillator_1_sync_lfo_2    = RS();
	p->oscillator_1_sync_env_2    = RS();
	p->oscillator_1_sync_env_3    = RS();

	p->oscillator_2_waveform      = (enum waveform_t)RU();
	p->oscillator_2_mix           = RS();
	p->oscillator_2_mix_lfo_1     = RS();
	p->oscillator_2_mix_lfo_2     = RS();
	p->oscillator_2_mix_env_2     = RS();
	p->oscillator_2_mix_env_3     = RS();
	p->oscillator_2_pitch         = RS();
	p->oscillator_2_pitch_lfo_1   = RS();
	p->oscillator_2_pitch_lfo_2   = RS();
	p->oscillator_2_pitch_env_2   = RS();
	p->oscillator_2_pitch_env_3   = RS();
	p->oscillator_2_width         = RS();
	p->oscillator_2_width_lfo_1   = RS();
	p->oscillator_2_width_lfo_2   = RS();
	p->oscillator_2_width_env_2   = RS();
	p->oscillator_2_width_env_3   = RS();
	p->oscillator_2_sync          = RS();
	p->oscillator_2_sync_lfo_1    = RS();
	p->oscillator_2_sync_lfo_2    = RS();
	p->oscillator_2_sync_env_2    = RS();
	p->oscillator_2_sync_env_3    = RS();

	p->oscillator_3_waveform      = (enum waveform_t)RU();
	p->oscillator_3_mix           = RS();
	p->oscillator_3_mix_lfo_1     = RS();
	p->oscillator_3_mix_lfo_2     = RS();
	p->oscillator_3_mix_env_2     = RS();
	p->oscillator_3_mix_env_3     = RS();
	p->oscillator_3_pitch         = RS();
	p->oscillator_3_pitch_lfo_1   = RS();
	p->oscillator_3_pitch_lfo_2   = RS();
	p->oscillator_3_pitch_env_2   = RS();
	p->oscillator_3_pitch_env_3   = RS();
	p->oscillator_3_width         = RS();
	p->oscillator_3_width_lfo_1   = RS();
	p->oscillator_3_width_lfo_2   = RS();
	p->oscillator_3_width_env_2   = RS();
	p->oscillator_3_width_env_3   = RS();
	p->oscillator_3_sync          = RS();
	p->oscillator_3_sync_lfo_1    = RS();
	p->oscillator_3_sync_lfo_2    = RS();
	p->oscillator_3_sync_env_2    = RS();
	p->oscillator_3_sync_env_3    = RS();

	p->oscillator_noise_mix       = RS();
	p->oscillator_noise_mix_lfo_1 = RS();
	p->oscillator_noise_mix_lfo_2 = RS();
	p->oscillator_noise_mix_env_2 = RS();
	p->oscillator_noise_mix_env_3 = RS();

	p->oscillator_13_mix          = RS();
	p->oscillator_13_mix_lfo_1    = RS();
	p->oscillator_13_mix_lfo_2    = RS();
	p->oscillator_13_mix_env_2    = RS();
	p->oscillator_13_mix_env_3    = RS();
	p->oscillator_13_fm           = RS();

	p->oscillator_23_mix          = RS();
	p->oscillator_23_mix_lfo_1    = RS();
	p->oscillator_23_mix_lfo_2    = RS();
	p->oscillator_23_mix_env_2    = RS();
	p->oscillator_23_mix_env_3    = RS();
	p->oscillator_23_fm           = RS();

	p->filter_frequency           = RS();
	p->filter_frequency_lfo_1     = RS();
	p->filter_frequency_lfo_2     = RS();
	p->filter_frequency_env_2     = RS();
	p->filter_frequency_env_3     = RS();
	p->filter_resonance           = RS();
	p->filter_resonance_lfo_1     = RS();
	p->filter_resonance_lfo_2     = RS();
	p->filter_resonance_env_2     = RS();
	p->filter_resonance_env_3     = RS();

	p->envelope_1_attack          = RS();
	p->envelope_1_decay           = RS();
	p->envelope_1_sustain         = RS();
	p->envelope_2_attack          = RS();
	p->envelope_2_decay           = RS();
	p->envelope_2_sustain         = RS();
	p->envelope_3_attack          = RS();
	p->envelope_3_decay           = RS();
	p->envelope_3_sustain         = RS();

	p->lfo_1_speed                = RS();
	p->lfo_1_waveform             = (enum waveform_lfo_t)RU();
	p->lfo_2_speed                = RS();
	p->lfo_2_waveform             = (enum waveform_lfo_t)RU();
	p->filter_type                = RU();

#undef RU
#undef RS
}

int main(int argc, char **argv)
{
	if (argc < 3) {
		fprintf(stderr, "usage: %s <params.bin> <output.raw> [render_size]\n", argv[0]);
		return 1;
	}

	int render_size = 12288;
	if (argc >= 4)
		render_size = atoi(argv[3]);

	/* Read params.bin */
	FILE *pf = fopen(argv[1], "rb");
	if (!pf) { perror(argv[1]); return 1; }
	uint8_t raw[208];
	if (fread(raw, 1, 208, pf) != 208) {
		fprintf(stderr, "params.bin must be exactly 208 bytes\n");
		return 1;
	}
	fclose(pf);

	/* Deserialize into a program_t. */
	program_t prog;
	memset(&prog, 0, sizeof(prog));
	deserialize_program(&prog, raw);

	/* Initialize waveform tables (normally done at startup by initSynth). */
	initSynth();

	/* Store program in synth slot 0 so renderPart() can find it. */
	synth.programs[0] = prog;

	/* Set up a minimal module_t with a sample buffer big enough. */
	module_t mod;
	memset(&mod, 0, sizeof(mod));
	mod.sampleData = calloc(1, render_size);
	if (!mod.sampleData) { perror("calloc"); return 1; }
	mod.samples[0].length = render_size;
	mod.samples[0].offset = 0;
	song = &mod;

	editor.currSample = 0;

	/* Build the part: program 0, max volume, default sample rate, no offset. */
	part_t part;
	memset(&part, 0, sizeof(part));
	part.program    = 0;
	part.volume     = 64;
	part.sampleRate = 22050;
	part.offset     = 0;

	renderPart(&part, false);

	/* Write output. */
	FILE *of = fopen(argv[2], "wb");
	if (!of) { perror(argv[2]); return 1; }
	fwrite(mod.sampleData, 1, render_size, of);
	fclose(of);

	free(mod.sampleData);
	return 0;
}
