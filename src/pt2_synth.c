// for finding memory leaks in debug mode with Visual Studio 
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "pt2_header.h"
#include "pt2_helpers.h"
#include "pt2_tables.h"
#include "pt2_mouse.h"
#include "pt2_synth.h"
#include "pt2_structs.h"
#include "pt2_config.h"
#include "pt2_bmp.h"

synth_t synth; // globalized

// Synthesizer buffers and other data
int8_t waveforms[6 * 256];
int8_t* waveform_saw = waveforms + WAVEFORM_SAW;
int8_t* waveform_square = waveforms + WAVEFORM_SQUARE_1;
int8_t* waveform_noise = waveforms + WAVEFORM_NOISE;
int8_t* waveform_sinus = waveforms + WAVEFORM_SINUS;
int16_t waveforms_lfo[3 * 4096];
int16_t* waveform_lfo_saw = waveforms_lfo + WAVEFORM_LFO_SAW;
int16_t* waveform_lfo_square = waveforms_lfo + WAVEFORM_LFO_SQUARE;
int16_t* waveform_lfo_triangle = waveforms_lfo + WAVEFORM_LFO_TRIANGLE;

// Synthesizer variables
int16_t oscillator_1_width_current = 0;
int16_t oscillator_2_width_current = 0;
int16_t oscillator_3_width_current = 0;
int16_t filter_frequency_current = 0;
int16_t filter_resonance_current = 0;
int16_t filter_q = 0;
int16_t filter_p = 0;
int16_t filter_f = 0;
int16_t filter_in = 0;

int16_t sinus[] = {
	0x0000, 0x00c9, 0x0192, 0x025b, 0x0324, 0x03ed, 0x04b6, 0x057f,
	0x0648, 0x0711, 0x07d9, 0x08a2, 0x096a, 0x0a33, 0x0afb, 0x0bc4,
	0x0c8c, 0x0d54, 0x0e1c, 0x0ee3, 0x0fab, 0x1072, 0x113a, 0x1201,
	0x12c8, 0x138f, 0x1455, 0x151c, 0x15e2, 0x16a8, 0x176e, 0x1833,
	0x18f9, 0x19be, 0x1a82, 0x1b47, 0x1c0b, 0x1ccf, 0x1d93, 0x1e57,
	0x1f1a, 0x1fdd, 0x209f, 0x2161, 0x2223, 0x22e5, 0x23a6, 0x2467,
	0x2528, 0x25e8, 0x26a8, 0x2767, 0x2826, 0x28e5, 0x29a3, 0x2a61,
	0x2b1f, 0x2bdc, 0x2c99, 0x2d55, 0x2e11, 0x2ecc, 0x2f87, 0x3041,
	0x30fb, 0x31b5, 0x326e, 0x3326, 0x33df, 0x3496, 0x354d, 0x3604,
	0x36ba, 0x376f, 0x3824, 0x38d9, 0x398c, 0x3a40, 0x3af2, 0x3ba5,
	0x3c56, 0x3d07, 0x3db8, 0x3e68, 0x3f17, 0x3fc5, 0x4073, 0x4121,
	0x41ce, 0x427a, 0x4325, 0x43d0, 0x447a, 0x4524, 0x45cd, 0x4675,
	0x471c, 0x47c3, 0x4869, 0x490f, 0x49b4, 0x4a58, 0x4afb, 0x4b9d,
	0x4c3f, 0x4ce0, 0x4d81, 0x4e20, 0x4ebf, 0x4f5d, 0x4ffb, 0x5097,
	0x5133, 0x51ce, 0x5268, 0x5302, 0x539b, 0x5432, 0x54c9, 0x5560,
	0x55f5, 0x568a, 0x571d, 0x57b0, 0x5842, 0x58d3, 0x5964, 0x59f3,
	0x5a82, 0x5b0f, 0x5b9c, 0x5c28, 0x5cb3, 0x5d3e, 0x5dc7, 0x5e4f,
	0x5ed7, 0x5f5d, 0x5fe3, 0x6068, 0x60eb, 0x616e, 0x61f0, 0x6271,
	0x62f1, 0x6370, 0x63ee, 0x646c, 0x64e8, 0x6563, 0x65dd, 0x6656,
	0x66cf, 0x6746, 0x67bc, 0x6832, 0x68a6, 0x6919, 0x698b, 0x69fd,
	0x6a6d, 0x6adc, 0x6b4a, 0x6bb7, 0x6c23, 0x6c8e, 0x6cf8, 0x6d61,
	0x6dc9, 0x6e30, 0x6e96, 0x6efb, 0x6f5e, 0x6fc1, 0x7022, 0x7083,
	0x70e2, 0x7140, 0x719d, 0x71f9, 0x7254, 0x72ae, 0x7307, 0x735e,
	0x73b5, 0x740a, 0x745f, 0x74b2, 0x7504, 0x7555, 0x75a5, 0x75f3,
	0x7641, 0x768d, 0x76d8, 0x7722, 0x776b, 0x77b3, 0x77fa, 0x783f,
	0x7884, 0x78c7, 0x7909, 0x794a, 0x7989, 0x79c8, 0x7a05, 0x7a41,
	0x7a7c, 0x7ab6, 0x7aee, 0x7b26, 0x7b5c, 0x7b91, 0x7bc5, 0x7bf8,
	0x7c29, 0x7c59, 0x7c88, 0x7cb6, 0x7ce3, 0x7d0e, 0x7d39, 0x7d62,
	0x7d89, 0x7db0, 0x7dd5, 0x7dfa, 0x7e1d, 0x7e3e, 0x7e5f, 0x7e7e,
	0x7e9c, 0x7eb9, 0x7ed5, 0x7eef, 0x7f09, 0x7f21, 0x7f37, 0x7f4d,
	0x7f61, 0x7f74, 0x7f86, 0x7f97, 0x7fa6, 0x7fb4, 0x7fc1, 0x7fcd,
	0x7fd8, 0x7fe1, 0x7fe9, 0x7ff0, 0x7ff5, 0x7ff9, 0x7ffd, 0x7ffe,
	0x7fff, 0x7ffe, 0x7ffd, 0x7ff9, 0x7ff5, 0x7ff0, 0x7fe9, 0x7fe1,
	0x7fd8, 0x7fcd, 0x7fc1, 0x7fb4, 0x7fa6, 0x7f97, 0x7f86, 0x7f74,
	0x7f61, 0x7f4d, 0x7f37, 0x7f21, 0x7f09, 0x7eef, 0x7ed5, 0x7eb9,
	0x7e9c, 0x7e7e, 0x7e5f, 0x7e3e, 0x7e1d, 0x7dfa, 0x7dd5, 0x7db0,
	0x7d89, 0x7d62, 0x7d39, 0x7d0e, 0x7ce3, 0x7cb6, 0x7c88, 0x7c59,
	0x7c29, 0x7bf8, 0x7bc5, 0x7b91, 0x7b5c, 0x7b26, 0x7aee, 0x7ab6,
	0x7a7c, 0x7a41, 0x7a05, 0x79c8, 0x7989, 0x794a, 0x7909, 0x78c7,
	0x7884, 0x783f, 0x77fa, 0x77b3, 0x776b, 0x7722, 0x76d8, 0x768d,
	0x7641, 0x75f3, 0x75a5, 0x7555, 0x7504, 0x74b2, 0x745f, 0x740a,
	0x73b5, 0x735e, 0x7307, 0x72ae, 0x7254, 0x71f9, 0x719d, 0x7140,
	0x70e2, 0x7083, 0x7022, 0x6fc1, 0x6f5e, 0x6efb, 0x6e96, 0x6e30,
	0x6dc9, 0x6d61, 0x6cf8, 0x6c8e, 0x6c23, 0x6bb7, 0x6b4a, 0x6adc,
	0x6a6d, 0x69fd, 0x698b, 0x6919, 0x68a6, 0x6832, 0x67bc, 0x6746,
	0x66cf, 0x6656, 0x65dd, 0x6563, 0x64e8, 0x646c, 0x63ee, 0x6370,
	0x62f1, 0x6271, 0x61f0, 0x616e, 0x60eb, 0x6068, 0x5fe3, 0x5f5d,
	0x5ed7, 0x5e4f, 0x5dc7, 0x5d3e, 0x5cb3, 0x5c28, 0x5b9c, 0x5b0f,
	0x5a82, 0x59f3, 0x5964, 0x58d3, 0x5842, 0x57b0, 0x571d, 0x568a,
	0x55f5, 0x5560, 0x54c9, 0x5432, 0x539b, 0x5302, 0x5268, 0x51ce,
	0x5133, 0x5097, 0x4ffb, 0x4f5d, 0x4ebf, 0x4e20, 0x4d81, 0x4ce0,
	0x4c3f, 0x4b9d, 0x4afb, 0x4a58, 0x49b4, 0x490f, 0x4869, 0x47c3,
	0x471c, 0x4675, 0x45cd, 0x4524, 0x447a, 0x43d0, 0x4325, 0x427a,
	0x41ce, 0x4121, 0x4073, 0x3fc5, 0x3f17, 0x3e68, 0x3db8, 0x3d07,
	0x3c56, 0x3ba5, 0x3af2, 0x3a40, 0x398c, 0x38d9, 0x3824, 0x376f,
	0x36ba, 0x3604, 0x354d, 0x3496, 0x33df, 0x3326, 0x326e, 0x31b5,
	0x30fb, 0x3041, 0x2f87, 0x2ecc, 0x2e11, 0x2d55, 0x2c99, 0x2bdc,
	0x2b1f, 0x2a61, 0x29a3, 0x28e5, 0x2826, 0x2767, 0x26a8, 0x25e8,
	0x2528, 0x2467, 0x23a6, 0x22e5, 0x2223, 0x2161, 0x209f, 0x1fdd,
	0x1f1a, 0x1e57, 0x1d93, 0x1ccf, 0x1c0b, 0x1b47, 0x1a82, 0x19be,
	0x18f9, 0x1833, 0x176e, 0x16a8, 0x15e2, 0x151c, 0x1455, 0x138f,
	0x12c8, 0x1201, 0x113a, 0x1072, 0x0fab, 0x0ee3, 0x0e1c, 0x0d54,
	0x0c8c, 0x0bc4, 0x0afb, 0x0a33, 0x096a, 0x08a2, 0x07d9, 0x0711,
	0x0648, 0x057f, 0x04b6, 0x03ed, 0x0324, 0x025b, 0x0192, 0x00c9,
	0x0000, 0xff38, 0xfe6f, 0xfda6, 0xfcdd, 0xfc14, 0xfb4b, 0xfa82,
	0xf9b9, 0xf8f0, 0xf828, 0xf75f, 0xf697, 0xf5ce, 0xf506, 0xf43d,
	0xf375, 0xf2ad, 0xf1e5, 0xf11e, 0xf056, 0xef8f, 0xeec7, 0xee00,
	0xed39, 0xec72, 0xebac, 0xeae5, 0xea1f, 0xe959, 0xe893, 0xe7ce,
	0xe708, 0xe643, 0xe57f, 0xe4ba, 0xe3f6, 0xe332, 0xe26e, 0xe1aa,
	0xe0e7, 0xe024, 0xdf62, 0xdea0, 0xddde, 0xdd1c, 0xdc5b, 0xdb9a,
	0xdad9, 0xda19, 0xd959, 0xd89a, 0xd7db, 0xd71c, 0xd65e, 0xd5a0,
	0xd4e2, 0xd425, 0xd368, 0xd2ac, 0xd1f0, 0xd135, 0xd07a, 0xcfc0,
	0xcf06, 0xce4c, 0xcd93, 0xccdb, 0xcc22, 0xcb6b, 0xcab4, 0xc9fd,
	0xc947, 0xc892, 0xc7dd, 0xc728, 0xc675, 0xc5c1, 0xc50f, 0xc45c,
	0xc3ab, 0xc2fa, 0xc249, 0xc199, 0xc0ea, 0xc03c, 0xbf8e, 0xbee0,
	0xbe33, 0xbd87, 0xbcdc, 0xbc31, 0xbb87, 0xbadd, 0xba34, 0xb98c,
	0xb8e5, 0xb83e, 0xb798, 0xb6f2, 0xb64d, 0xb5a9, 0xb506, 0xb464,
	0xb3c2, 0xb321, 0xb280, 0xb1e1, 0xb142, 0xb0a4, 0xb006, 0xaf6a,
	0xaece, 0xae33, 0xad99, 0xacff, 0xac66, 0xabcf, 0xab38, 0xaaa1,
	0xaa0c, 0xa977, 0xa8e4, 0xa851, 0xa7bf, 0xa72e, 0xa69d, 0xa60e,
	0xa57f, 0xa4f2, 0xa465, 0xa3d9, 0xa34e, 0xa2c3, 0xa23a, 0xa1b2,
	0xa12a, 0xa0a4, 0xa01e, 0x9f99, 0x9f16, 0x9e93, 0x9e11, 0x9d90,
	0x9d10, 0x9c91, 0x9c13, 0x9b95, 0x9b19, 0x9a9e, 0x9a24, 0x99ab,
	0x9932, 0x98bb, 0x9845, 0x97cf, 0x975b, 0x96e8, 0x9676, 0x9604,
	0x9594, 0x9525, 0x94b7, 0x944a, 0x93de, 0x9373, 0x9309, 0x92a0,
	0x9238, 0x91d1, 0x916b, 0x9106, 0x90a3, 0x9040, 0x8fdf, 0x8f7e,
	0x8f1f, 0x8ec1, 0x8e64, 0x8e08, 0x8dad, 0x8d53, 0x8cfa, 0x8ca3,
	0x8c4c, 0x8bf7, 0x8ba2, 0x8b4f, 0x8afd, 0x8aac, 0x8a5c, 0x8a0e,
	0x89c0, 0x8974, 0x8929, 0x88df, 0x8896, 0x884e, 0x8807, 0x87c2,
	0x877d, 0x873a, 0x86f8, 0x86b7, 0x8678, 0x8639, 0x85fc, 0x85c0,
	0x8585, 0x854b, 0x8513, 0x84db, 0x84a5, 0x8470, 0x843c, 0x8409,
	0x83d8, 0x83a8, 0x8379, 0x834b, 0x831e, 0x82f3, 0x82c8, 0x829f,
	0x8278, 0x8251, 0x822c, 0x8207, 0x81e4, 0x81c3, 0x81a2, 0x8183,
	0x8165, 0x8148, 0x812c, 0x8112, 0x80f8, 0x80e0, 0x80ca, 0x80b4,
	0x80a0, 0x808d, 0x807b, 0x806a, 0x805b, 0x804d, 0x8040, 0x8034,
	0x8029, 0x8020, 0x8018, 0x8011, 0x800c, 0x8008, 0x8004, 0x8003,
	0x8002, 0x8003, 0x8004, 0x8008, 0x800c, 0x8011, 0x8018, 0x8020,
	0x8029, 0x8034, 0x8040, 0x804d, 0x805b, 0x806a, 0x807b, 0x808d,
	0x80a0, 0x80b4, 0x80ca, 0x80e0, 0x80f8, 0x8112, 0x812c, 0x8148,
	0x8165, 0x8183, 0x81a2, 0x81c3, 0x81e4, 0x8207, 0x822c, 0x8251,
	0x8278, 0x829f, 0x82c8, 0x82f3, 0x831e, 0x834b, 0x8379, 0x83a8,
	0x83d8, 0x8409, 0x843c, 0x8470, 0x84a5, 0x84db, 0x8513, 0x854b,
	0x8585, 0x85c0, 0x85fc, 0x8639, 0x8678, 0x86b7, 0x86f8, 0x873a,
	0x877d, 0x87c2, 0x8807, 0x884e, 0x8896, 0x88df, 0x8929, 0x8974,
	0x89c0, 0x8a0e, 0x8a5c, 0x8aac, 0x8afd, 0x8b4f, 0x8ba2, 0x8bf7,
	0x8c4c, 0x8ca3, 0x8cfa, 0x8d53, 0x8dad, 0x8e08, 0x8e64, 0x8ec1,
	0x8f1f, 0x8f7e, 0x8fdf, 0x9040, 0x90a3, 0x9106, 0x916b, 0x91d1,
	0x9238, 0x92a0, 0x9309, 0x9373, 0x93de, 0x944a, 0x94b7, 0x9525,
	0x9594, 0x9604, 0x9676, 0x96e8, 0x975b, 0x97cf, 0x9845, 0x98bb,
	0x9932, 0x99ab, 0x9a24, 0x9a9e, 0x9b19, 0x9b95, 0x9c13, 0x9c91,
	0x9d10, 0x9d90, 0x9e11, 0x9e93, 0x9f16, 0x9f99, 0xa01e, 0xa0a4,
	0xa12a, 0xa1b2, 0xa23a, 0xa2c3, 0xa34e, 0xa3d9, 0xa465, 0xa4f2,
	0xa57f, 0xa60e, 0xa69d, 0xa72e, 0xa7bf, 0xa851, 0xa8e4, 0xa977,
	0xaa0c, 0xaaa1, 0xab38, 0xabcf, 0xac66, 0xacff, 0xad99, 0xae33,
	0xaece, 0xaf6a, 0xb006, 0xb0a4, 0xb142, 0xb1e1, 0xb280, 0xb321,
	0xb3c2, 0xb464, 0xb506, 0xb5a9, 0xb64d, 0xb6f2, 0xb798, 0xb83e,
	0xb8e5, 0xb98c, 0xba34, 0xbadd, 0xbb87, 0xbc31, 0xbcdc, 0xbd87,
	0xbe33, 0xbee0, 0xbf8e, 0xc03c, 0xc0ea, 0xc199, 0xc249, 0xc2fa,
	0xc3ab, 0xc45c, 0xc50f, 0xc5c1, 0xc675, 0xc728, 0xc7dd, 0xc892,
	0xc947, 0xc9fd, 0xcab4, 0xcb6b, 0xcc22, 0xccdb, 0xcd93, 0xce4c,
	0xcf06, 0xcfc0, 0xd07a, 0xd135, 0xd1f0, 0xd2ac, 0xd368, 0xd425,
	0xd4e2, 0xd5a0, 0xd65e, 0xd71c, 0xd7db, 0xd89a, 0xd959, 0xda19,
	0xdad9, 0xdb9a, 0xdc5b, 0xdd1c, 0xddde, 0xdea0, 0xdf62, 0xe024,
	0xe0e7, 0xe1aa, 0xe26e, 0xe332, 0xe3f6, 0xe4ba, 0xe57f, 0xe643,
	0xe708, 0xe7ce, 0xe893, 0xe959, 0xea1f, 0xeae5, 0xebac, 0xec72,
	0xed39, 0xee00, 0xeec7, 0xef8f, 0xf056, 0xf11e, 0xf1e5, 0xf2ad,
	0xf375, 0xf43d, 0xf506, 0xf5ce, 0xf697, 0xf75f, 0xf828, 0xf8f0,
	0xf9b9, 0xfa82, 0xfb4b, 0xfc14, 0xfcdd, 0xfda6, 0xfe6f, 0xff38
};

// 32 bit random number generator
uint32_t random_number = 0xbc5d71e3;
uint32_t generate_random()
{
	for (int i = 0; i < 5; i++) {
		int bit_count = 0;
		if (random_number & 2) {
			bit_count++;
		}
		if (random_number & 16) {
			bit_count++;
		}
		random_number >>= 1;
		if (bit_count & 1) {
			random_number |= 0x80000000;
		}
		bit_count >>= 1;
	}
	return random_number;
}

// Calculate filter coefficients
void filter_coefficients()
{
	filter_q = 0xfff - filter_frequency_current; // q = 1.0f - frequency;
	filter_p = (((filter_frequency_current << 2) / 5 * filter_q) >> 12) + filter_frequency_current; // frequency + 0.8f * frequency * q;
	filter_f = filter_p + filter_p - 0xfff; // f = p + p - 1.0f;
	filter_q = ((((((((filter_q * filter_q) >> 12) * 56 / 10 - filter_q + 0xfff) >> 1) * filter_q) >> 12) + 0xfff) * filter_resonance_current) >> 12; // q = resonance * (1.0f + 0.5f * q * (1.0f - q + 5.6f * q * q));
}

// Create saw waveform
void waveform_saw_create()
{
	int8_t sample = 127;
	for (int offset = 0; offset < 256; offset++) {
		waveform_saw[offset] = sample--;
	}
}

// Create square waveforms
void waveform_square_create()
{
	int offset = 0;
	int width = oscillator_1_width_current >> 4;
	for (int i = 0; i < width; i++) {
		waveform_square[offset++] = 127;
	}
	width = 256 - width;
	for (int i = 0; i < width; i++) {
		waveform_square[offset++] = -128;
	}

	width = oscillator_2_width_current >> 4;
	for (int i = 0; i < width; i++) {
		waveform_square[offset++] = 127;
	}
	width = 256 - width;
	for (int i = 0; i < width; i++) {
		waveform_square[offset++] = -128;
	}

	width = oscillator_3_width_current >> 4;
	for (int i = 0; i < width; i++) {
		waveform_square[offset++] = 127;
	}
	width = 256 - width;
	for (int i = 0; i < width; i++) {
		waveform_square[offset++] = -128;
	}
}

// Create noise waveform
void waveform_noise_create()
{
	for (int offset = 0; offset < 256; offset++) {
		waveform_noise[offset] = generate_random();
	}
}

// Create sinus waveform
void waveform_sinus_create()
{
	for (int offset = 0; offset < 256; offset++) {
		waveform_sinus[offset] = sinus[offset << 3];
	}
}

// Create LFO waveforms
void waveform_lfo_create()
{
	// Create saw
	int16_t sample = 4095;
	for (int offset = 0; offset < 4096; offset++, sample -= 2) {
		waveform_lfo_saw[offset] = sample;
	}

	// Create square
	for (int offset = 0; offset < 2048; offset++) {
		waveform_lfo_square[offset] = -0xfff;
	}
	for (int offset = 2048; offset < 4096; offset++) {
		waveform_lfo_square[offset] = 0xfff;
	}

	// Create triangle
	sample = 0;
	for (int offset = 0; offset < 1024; offset++, sample += 4) {
		waveform_lfo_triangle[offset] = sample;
	}
	for (int offset = 1024; offset < 3072; offset++, sample -= 4) {
		waveform_lfo_triangle[offset] = sample;
	}
	for (int offset = 3072; offset < 4096; offset++, sample += 4) {
		waveform_lfo_triangle[offset] = sample;
	}
}

// Initialize parameters to default values
void initSynth(void)
{
	// Initialize runtime variables
	for (int i = 0; i < MOD_SAMPLES; i++) {
		memset(&synth.performances[i], 0, sizeof(performance_t));

		for (int j = 0; j < 8; j++) {
			synth.performances[i].parts[j].sampleRate = 22050;
		}
	}

	for (int i = 0; i < 256; i++) {
		memset(&synth.programs[i], 0, sizeof(program_t));

		synth.programs[i].oscillator_1_waveform = WAVEFORM_SAW;
		synth.programs[i].oscillator_1_pitch = 44;
		synth.programs[i].oscillator_1_width = 0x800;
		synth.programs[i].oscillator_2_waveform = WAVEFORM_SAW;
		synth.programs[i].oscillator_2_pitch = 44;
		synth.programs[i].oscillator_2_width = 0x800;
		synth.programs[i].oscillator_3_waveform = WAVEFORM_SAW;
		synth.programs[i].oscillator_3_mix = 0xfff;
		synth.programs[i].oscillator_3_pitch = 44;
		synth.programs[i].oscillator_3_width = 0x800;
		synth.programs[i].filter_frequency = 0xfff;
		synth.programs[i].envelope_1_sustain = 0xfff;
		synth.programs[i].lfo_1_speed = 1000;
		synth.programs[i].lfo_1_waveform = WAVEFORM_LFO_SAW;
		synth.programs[i].lfo_2_speed = 1000;
		synth.programs[i].lfo_2_waveform = WAVEFORM_LFO_TRIANGLE;
	}

	synth.performances[0].parts[0].volume = 64;
	synth.programs[0].oscillator_1_waveform = WAVEFORM_SQUARE_1;
	synth.programs[0].oscillator_1_pitch = 88;
	synth.programs[0].oscillator_1_width = 0x800;
	synth.programs[0].oscillator_2_waveform = WAVEFORM_SQUARE_2;
	synth.programs[0].oscillator_2_mix = 0x8c0;
	synth.programs[0].oscillator_2_pitch = 88;
	synth.programs[0].oscillator_2_width = 0x800;
	synth.programs[0].oscillator_3_waveform = WAVEFORM_SQUARE_3;
	synth.programs[0].oscillator_3_mix = 0xfff;
	synth.programs[0].oscillator_3_pitch = 44;
	synth.programs[0].oscillator_3_width = 0x800;
	synth.programs[0].oscillator_3_width_lfo_1 = 0x7ff;
	synth.programs[0].oscillator_noise_mix_env_2 = 0xfff;
	synth.programs[0].filter_frequency = 0x100;
	synth.programs[0].filter_frequency_env_3 = 0xfff;
	synth.programs[0].envelope_1_sustain = 0xfff;
	synth.programs[0].envelope_2_decay = 0x80;
	synth.programs[0].envelope_2_sustain = 0x500;
	synth.programs[0].envelope_3_decay = 0x180;
	synth.programs[0].envelope_3_sustain = 0;
	synth.programs[0].lfo_1_speed = 1000;
	synth.programs[0].lfo_1_waveform = WAVEFORM_LFO_SAW;
	synth.programs[0].lfo_2_speed = 1000;
	synth.programs[0].lfo_2_waveform = WAVEFORM_LFO_TRIANGLE;

	synthLoad("protracker.jrm");
}

void synthRender(void)
{
	performance_t* performance = &synth.performances[editor.currSample];
	for (int part = 0; part < 8; part++) {
		renderPart(&performance->parts[part], part > 0);
	}
}

void renderPart(part_t* part, bool add)
{
	if (part->volume == 0) {
		return;
	}

	program_t* program = &synth.programs[part->program];
	uint32_t SAMPLERATE = part->sampleRate;

	int32_t oscillator_1_position = 0;
	int32_t oscillator_1_delta = 0;
	int32_t oscillator_2_position = 0;
	int32_t oscillator_2_delta = 0;
	int32_t oscillator_3_position = 0;
	int32_t oscillator_3_delta = 0;
	int32_t oscillator_noise_position = 0;
	int32_t oscillator_1_sync_position = 0;
	int32_t oscillator_1_sync_delta = 0;
	int32_t oscillator_2_sync_position = 0;
	int32_t oscillator_2_sync_delta = 0;
	int32_t oscillator_3_sync_position = 0;
	int32_t oscillator_3_sync_delta = 0;
	int32_t lfo_1_position = 0;
	int32_t lfo_2_position = 0;
	int32_t envelope_1_current = 0;
	int32_t envelope_1_delta = 0;
	int32_t envelope_2_current = 0;
	int32_t envelope_2_delta = 0;
	int32_t envelope_3_current = 0;
	int32_t envelope_3_delta = 0;
	int32_t envelope_stretch = 7;
	int16_t oscillator_1_current = 0;
	int16_t oscillator_2_current = 0;
	int16_t oscillator_3_current = 0;
	int16_t envelope_1_counter = 0;
	int16_t envelope_2_counter = 0;
	int16_t envelope_3_counter = 0;
	enum envelope_mode envelope_1_mode = ENVELOPE_INIT;
	enum envelope_mode envelope_2_mode = ENVELOPE_INIT;
	enum envelope_mode envelope_3_mode = ENVELOPE_INIT;

	// Create waveforms
	random_number = 0xbc5d71e3;
	waveform_saw_create();
	waveform_square_create();
	waveform_noise_create();
	waveform_sinus_create();
	waveform_lfo_create();

	moduleSample_t* sample = &song->samples[editor.currSample];
	int8_t* buffer_render = &song->sampleData[sample->offset];

	if (!add) {
		for (int buffer_position = 0; buffer_position < part->offset; buffer_position++) {
			buffer_render[buffer_position] = 0;
		}
	}

	int16_t b0 = 0;
	int16_t b1 = 0;
	int16_t b2 = 0;
	int16_t b3 = 0;
	int16_t b4 = 0;
	for (int buffer_position = part->offset; buffer_position < song->samples[editor.currSample].length; buffer_position++) {
		// Only update envelopes every envelope_stretch samples due to resolution
		if ((buffer_position & envelope_stretch) == 0) {
			// Update envelope 1
			envelope_1_current += envelope_1_delta;
			envelope_1_counter--;
			if (envelope_1_counter < 0) {
				envelope_1_mode++;
				switch (envelope_1_mode) {
				case ENVELOPE_ATTACK:
					envelope_1_delta = 0xffff / (program->envelope_1_attack + 1);
					envelope_1_counter = program->envelope_1_attack;
					break;
				case ENVELOPE_DECAY:
					envelope_1_delta = -((0xfff - program->envelope_1_sustain) << 4) / (program->envelope_1_decay + 1);
					envelope_1_counter = program->envelope_1_decay;
					break;
				default:
					envelope_1_delta = 0;
					envelope_1_counter = 0x7fff;
					break;
				}
			}

			// Update envelope 2
			envelope_2_current += envelope_2_delta;
			envelope_2_counter--;
			if (envelope_2_counter < 0) {
				envelope_2_mode++;
				switch (envelope_2_mode) {
				case ENVELOPE_ATTACK:
					envelope_2_delta = 0xffff / (program->envelope_2_attack + 1);
					envelope_2_counter = program->envelope_2_attack;
					break;
				case ENVELOPE_DECAY:
					envelope_2_delta = -((0xfff - program->envelope_2_sustain) << 4) / (program->envelope_2_decay + 1);
					envelope_2_counter = program->envelope_2_decay;
					break;
				default:
					envelope_2_delta = 0;
					envelope_2_counter = 0x7fff;
					break;
				}
			}

			// Update envelope 3
			envelope_3_current += envelope_3_delta;
			envelope_3_counter--;
			if (envelope_3_counter < 0) {
				envelope_3_mode++;
				switch (envelope_3_mode) {
				case ENVELOPE_ATTACK:
					envelope_3_delta = 0xffff / (program->envelope_3_attack + 1);
					envelope_3_counter = program->envelope_3_attack;
					break;
				case ENVELOPE_DECAY:
					envelope_3_delta = -((0xfff - program->envelope_3_sustain) << 4) / (program->envelope_3_decay + 1);
					envelope_3_counter = program->envelope_3_decay;
					break;
				default:
					envelope_3_delta = 0;
					envelope_3_counter = 0x7fff;
					break;
				}
			}
		}

		// Update LFO 1
		lfo_1_position += ((program->lfo_1_speed << 16) / SAMPLERATE) << 2; // lfo_1_delta
		if (lfo_1_position >= 0x10000000) {
			lfo_1_position -= 0x10000000;
		}

		// Update LFO 2
		lfo_2_position += ((program->lfo_2_speed << 16) / SAMPLERATE) << 2; // lfo_2_delta
		if (lfo_2_position >= 0x10000000) {
			lfo_2_position -= 0x10000000;
		}

		// Only update oscillator widths, pitches and square waveforms every 64th sample
		if ((buffer_position & 63) == 0) {
			// Update oscillator 1 width
			oscillator_1_width_current = program->oscillator_1_width;
			if (program->oscillator_1_width_lfo_1 != 0) {
				oscillator_1_width_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_1_width_lfo_1) >> 12;
			}
			if (program->oscillator_1_width_lfo_2 != 0) {
				oscillator_1_width_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_1_width_lfo_2) >> 12;
			}
			if (program->oscillator_1_width_env_2 != 0) {
				oscillator_1_width_current += ((envelope_2_current >> 4) * program->oscillator_1_width_env_2) >> 12;
			}
			if (program->oscillator_1_width_env_3 != 0) {
				oscillator_1_width_current += ((envelope_3_current >> 4) * program->oscillator_1_width_env_3) >> 12;
			}

			// Update oscillator 2 width
			oscillator_2_width_current = program->oscillator_2_width;
			if (program->oscillator_2_width_lfo_1 != 0) {
				oscillator_2_width_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_2_width_lfo_1) >> 12;
			}
			if (program->oscillator_2_width_lfo_2 != 0) {
				oscillator_2_width_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_2_width_lfo_2) >> 12;
			}
			if (program->oscillator_2_width_env_2 != 0) {
				oscillator_2_width_current += ((envelope_2_current >> 4) * program->oscillator_2_width_env_2) >> 12;
			}
			if (program->oscillator_2_width_env_3 != 0) {
				oscillator_2_width_current += ((envelope_3_current >> 4) * program->oscillator_2_width_env_3) >> 12;
			}

			// Update oscillator 3 width
			oscillator_3_width_current = program->oscillator_3_width;
			if (program->oscillator_3_width_lfo_1 != 0) {
				oscillator_3_width_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_3_width_lfo_1) >> 12;
			}
			if (program->oscillator_3_width_lfo_2 != 0) {
				oscillator_3_width_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_3_width_lfo_2) >> 12;
			}
			if (program->oscillator_3_width_env_2 != 0) {
				oscillator_3_width_current += ((envelope_2_current >> 4) * program->oscillator_3_width_env_2) >> 12;
			}
			if (program->oscillator_3_width_env_3 != 0) {
				oscillator_3_width_current += ((envelope_3_current >> 4) * program->oscillator_3_width_env_3) >> 12;
			}

			waveform_square_create();

			// Update oscillator 1 pitch
			uint16_t oscillator_1_pitch_current = program->oscillator_1_pitch;
			if (program->oscillator_1_pitch_lfo_1 != 0) {
				oscillator_1_pitch_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_1_pitch_lfo_1) >> 12;
			}
			if (program->oscillator_1_pitch_lfo_2 != 0) {
				oscillator_1_pitch_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_1_pitch_lfo_2) >> 12;
			}
			if (program->oscillator_1_pitch_env_2 != 0) {
				oscillator_1_pitch_current += ((envelope_2_current >> 4) * program->oscillator_1_pitch_env_2) >> 11;
			}
			if (program->oscillator_1_pitch_env_3 != 0) {
				oscillator_1_pitch_current += ((envelope_3_current >> 4) * program->oscillator_1_pitch_env_3) >> 11;
			}
			oscillator_1_delta = ((oscillator_1_pitch_current << 16) / SAMPLERATE) << 8;

			// Update oscillator 2 pitch
			uint16_t oscillator_2_pitch_current = program->oscillator_2_pitch;
			if (program->oscillator_2_pitch_lfo_1 != 0) {
				oscillator_2_pitch_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_2_pitch_lfo_1) >> 12;
			}
			if (program->oscillator_2_pitch_lfo_2 != 0) {
				oscillator_2_pitch_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_2_pitch_lfo_2) >> 12;
			}
			if (program->oscillator_2_pitch_env_2 != 0) {
				oscillator_2_pitch_current += ((envelope_2_current >> 4) * program->oscillator_2_pitch_env_2) >> 11;
			}
			if (program->oscillator_2_pitch_env_3 != 0) {
				oscillator_2_pitch_current += ((envelope_3_current >> 4) * program->oscillator_2_pitch_env_3) >> 11;
			}
			oscillator_2_delta = ((oscillator_2_pitch_current << 16) / SAMPLERATE) << 8;

			// Update oscillator 3 pitch
			uint16_t oscillator_3_pitch_current = program->oscillator_3_pitch;
			if (program->oscillator_3_pitch_lfo_1 != 0) {
				oscillator_3_pitch_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_3_pitch_lfo_1) >> 12;
			}
			if (program->oscillator_3_pitch_lfo_2 != 0) {
				oscillator_3_pitch_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_3_pitch_lfo_2) >> 12;
			}
			if (program->oscillator_3_pitch_env_2 != 0) {
				oscillator_3_pitch_current += ((envelope_2_current >> 4) * program->oscillator_3_pitch_env_2) >> 11;
			}
			if (program->oscillator_3_pitch_env_3 != 0) {
				oscillator_3_pitch_current += ((envelope_3_current >> 4) * program->oscillator_3_pitch_env_3) >> 11;
			}
			oscillator_3_delta = ((oscillator_3_pitch_current << 16) / SAMPLERATE) << 8;

			// Update oscillator 1 sync
			uint16_t oscillator_1_sync_current = program->oscillator_1_sync;
			if (program->oscillator_1_sync_lfo_1 != 0) {
				oscillator_1_sync_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_1_sync_lfo_1) >> 12;
			}
			if (program->oscillator_1_sync_lfo_2 != 0) {
				oscillator_1_sync_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_1_sync_lfo_2) >> 12;
			}
			if (program->oscillator_1_sync_env_2 != 0) {
				oscillator_1_sync_current += ((envelope_2_current >> 4) * program->oscillator_1_sync_env_2) >> 11;
			}
			if (program->oscillator_1_sync_env_3 != 0) {
				oscillator_1_sync_current += ((envelope_3_current >> 4) * program->oscillator_1_sync_env_3) >> 11;
			}
			oscillator_1_sync_delta = ((oscillator_1_sync_current << 16) / SAMPLERATE) << 8;

			// Update oscillator 2 sync
			uint16_t oscillator_2_sync_current = program->oscillator_2_sync;
			if (program->oscillator_2_sync_lfo_1 != 0) {
				oscillator_2_sync_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_2_sync_lfo_1) >> 12;
			}
			if (program->oscillator_2_sync_lfo_2 != 0) {
				oscillator_2_sync_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_2_sync_lfo_2) >> 12;
			}
			if (program->oscillator_2_sync_env_2 != 0) {
				oscillator_2_sync_current += ((envelope_2_current >> 4) * program->oscillator_2_sync_env_2) >> 11;
			}
			if (program->oscillator_2_sync_env_3 != 0) {
				oscillator_2_sync_current += ((envelope_3_current >> 4) * program->oscillator_2_sync_env_3) >> 11;
			}
			oscillator_2_sync_delta = ((oscillator_2_sync_current << 16) / SAMPLERATE) << 8;

			// Update oscillator 3 sync
			uint16_t oscillator_3_sync_current = program->oscillator_3_sync;
			if (program->oscillator_3_sync_lfo_1 != 0) {
				oscillator_3_sync_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_3_sync_lfo_1) >> 12;
			}
			if (program->oscillator_3_sync_lfo_2 != 0) {
				oscillator_3_sync_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_3_sync_lfo_2) >> 12;
			}
			if (program->oscillator_3_sync_env_2 != 0) {
				oscillator_3_sync_current += ((envelope_2_current >> 4) * program->oscillator_3_sync_env_2) >> 11;
			}
			if (program->oscillator_3_sync_env_3 != 0) {
				oscillator_3_sync_current += ((envelope_3_current >> 4) * program->oscillator_3_sync_env_3) >> 11;
			}
			oscillator_3_sync_delta = ((oscillator_3_sync_current << 16) / SAMPLERATE) << 8;
		}

		// Sum oscillators
		int16_t sample = 0;

		// Sum oscillator 1
		oscillator_1_current = (waveform_saw[(oscillator_1_position >> 16) + program->oscillator_1_waveform] + waveform_saw[(oscillator_1_sync_position >> 16) + program->oscillator_1_waveform]) >> 1;
		uint16_t oscillator_1_mix_current = program->oscillator_1_mix;
		if (program->oscillator_1_mix_lfo_1 != 0) {
			oscillator_1_mix_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_1_mix_lfo_1) >> 12;
		}
		if (program->oscillator_1_mix_lfo_2 != 0) {
			oscillator_1_mix_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_1_mix_lfo_2) >> 12;
		}
		if (program->oscillator_1_mix_env_2 != 0) {
			oscillator_1_mix_current += ((envelope_2_current >> 4) * program->oscillator_1_mix_env_2) >> 12;
		}
		if (program->oscillator_1_mix_env_3 != 0) {
			oscillator_1_mix_current += ((envelope_3_current >> 4) * program->oscillator_1_mix_env_3) >> 12;
		}
		sample += (((((envelope_1_current >> 4) * oscillator_1_mix_current) >> 12) * oscillator_1_current) << 4) >> 16;

		// Sum oscillator 2
		oscillator_2_current = (waveform_saw[(oscillator_2_position >> 16) + program->oscillator_2_waveform] + waveform_saw[(oscillator_2_sync_position >> 16) + program->oscillator_2_waveform]) >> 1;
		uint16_t oscillator_2_mix_current = program->oscillator_2_mix;
		if (program->oscillator_2_mix_lfo_1 != 0) {
			oscillator_2_mix_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_2_mix_lfo_1) >> 12;
		}
		if (program->oscillator_2_mix_lfo_2 != 0) {
			oscillator_2_mix_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_2_mix_lfo_2) >> 12;
		}
		if (program->oscillator_2_mix_env_2 != 0) {
			oscillator_2_mix_current += ((envelope_2_current >> 4) * program->oscillator_2_mix_env_2) >> 12;
		}
		if (program->oscillator_2_mix_env_3 != 0) {
			oscillator_2_mix_current += ((envelope_3_current >> 4) * program->oscillator_2_mix_env_3) >> 12;
		}
		sample += (((((envelope_1_current >> 4) * oscillator_2_mix_current) >> 12) * oscillator_2_current) << 4) >> 16;

		// Sum oscillator 3
		oscillator_3_current = (waveform_saw[(oscillator_3_position >> 16) + program->oscillator_3_waveform] + waveform_saw[(oscillator_3_sync_position >> 16) + program->oscillator_3_waveform]) >> 1;
		uint16_t oscillator_3_mix_current = program->oscillator_3_mix;
		if (program->oscillator_3_mix_lfo_1 != 0) {
			oscillator_3_mix_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_3_mix_lfo_1) >> 12;
		}
		if (program->oscillator_3_mix_lfo_2 != 0) {
			oscillator_3_mix_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_3_mix_lfo_2) >> 12;
		}
		if (program->oscillator_3_mix_env_2 != 0) {
			oscillator_3_mix_current += ((envelope_2_current >> 4) * program->oscillator_3_mix_env_2) >> 12;
		}
		if (program->oscillator_3_mix_env_3 != 0) {
			oscillator_3_mix_current += ((envelope_3_current >> 4) * program->oscillator_3_mix_env_3) >> 12;
		}
		sample += (((((envelope_1_current >> 4) * oscillator_3_mix_current) >> 12) * oscillator_3_current) << 4) >> 16;

		// Sum oscillator 1*3
		if (program->oscillator_13_fm == 0) {
			int16_t oscillator_13_current = (oscillator_1_current * oscillator_3_current) >> 7;
			uint16_t oscillator_13_mix_current = program->oscillator_13_mix;
			if (program->oscillator_13_mix_lfo_1 != 0) {
				oscillator_13_mix_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_13_mix_lfo_1) >> 12;
			}
			if (program->oscillator_13_mix_lfo_2 != 0) {
				oscillator_13_mix_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_13_mix_lfo_2) >> 12;
			}
			if (program->oscillator_13_mix_env_2 != 0) {
				oscillator_13_mix_current += ((envelope_2_current >> 4) * program->oscillator_13_mix_env_2) >> 12;
			}
			if (program->oscillator_13_mix_env_3 != 0) {
				oscillator_13_mix_current += ((envelope_3_current >> 4) * program->oscillator_13_mix_env_3) >> 12;
			}
			sample += (((((envelope_1_current >> 4) * oscillator_13_mix_current) >> 12) * oscillator_13_current) << 4) >> 16;
		}

		// Sum oscillator 2*3
		if (program->oscillator_23_fm == 0) {
			int16_t oscillator_23_current = (oscillator_2_current * oscillator_3_current) >> 7;
			uint16_t oscillator_23_mix_current = program->oscillator_23_mix;
			if (program->oscillator_23_mix_lfo_1 != 0) {
				oscillator_23_mix_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_23_mix_lfo_1) >> 12;
			}
			if (program->oscillator_23_mix_lfo_2 != 0) {
				oscillator_23_mix_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_23_mix_lfo_2) >> 12;
			}
			if (program->oscillator_23_mix_env_2 != 0) {
				oscillator_23_mix_current += ((envelope_2_current >> 4) * program->oscillator_23_mix_env_2) >> 12;
			}
			if (program->oscillator_23_mix_env_3 != 0) {
				oscillator_23_mix_current += ((envelope_3_current >> 4) * program->oscillator_23_mix_env_3) >> 12;
			}
			sample += (((((envelope_1_current >> 4) * oscillator_23_mix_current) >> 12) * oscillator_23_current) << 4) >> 16;
		}

		// Sum noise oscillator
		int16_t oscillator_noise_current = waveform_saw[(oscillator_noise_position >> 16) + WAVEFORM_NOISE];
		uint16_t oscillator_noise_mix_current = program->oscillator_noise_mix;
		if (program->oscillator_noise_mix_lfo_1 != 0) {
			oscillator_noise_mix_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_noise_mix_lfo_1) >> 12;
		}
		if (program->oscillator_noise_mix_lfo_2 != 0) {
			oscillator_noise_mix_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_noise_mix_lfo_2) >> 12;
		}
		if (program->oscillator_noise_mix_env_2 != 0) {
			oscillator_noise_mix_current += ((envelope_2_current >> 4) * program->oscillator_noise_mix_env_2) >> 12;
		}
		if (program->oscillator_noise_mix_env_3 != 0) {
			oscillator_noise_mix_current += ((envelope_3_current >> 4) * program->oscillator_noise_mix_env_3) >> 12;
		}
		sample += (((((envelope_1_current >> 4) * oscillator_noise_mix_current) >> 12) * oscillator_noise_current) << 4) >> 16;

		sample >>= 1;

		// Update oscillator 1 sync
		oscillator_1_sync_position += oscillator_1_sync_delta + oscillator_1_delta;
		oscillator_1_sync_position &= 0xffffff;

		// Update oscillator 2 sync
		oscillator_2_sync_position += oscillator_2_sync_delta + oscillator_2_delta;
		oscillator_2_sync_position &= 0xffffff;

		// Update oscillator 3 sync
		oscillator_3_sync_position += oscillator_3_sync_delta + oscillator_3_delta;
		oscillator_3_sync_position &= 0xffffff;

		// Update oscillator 1
		oscillator_1_position += oscillator_1_delta;
		if (oscillator_1_position >= 0x1000000) {
			oscillator_1_position &= 0xffffff;
			if (oscillator_1_sync_delta != 0) {
				oscillator_1_sync_position = oscillator_1_position;
			}
		}

		// Update oscillator 2
		oscillator_2_position += oscillator_2_delta;
		if (oscillator_2_position >= 0x1000000) {
			oscillator_2_position &= 0xffffff;
			if (oscillator_2_sync_delta != 0) {
				oscillator_2_sync_position = oscillator_2_position;
			}
		}

		// Update oscillator 3
		oscillator_3_position += oscillator_3_delta;

		// Oscillator 1 -> oscillator 3 frequency modulation
		if (program->oscillator_13_fm != 0) {
			uint16_t oscillator_13_mix_current = program->oscillator_13_mix;
			if (program->oscillator_13_mix_lfo_1 != 0) {
				oscillator_13_mix_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_13_mix_lfo_1) >> 12;
			}
			if (program->oscillator_13_mix_lfo_2 != 0) {
				oscillator_13_mix_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_13_mix_lfo_2) >> 12;
			}
			if (program->oscillator_13_mix_env_2 != 0) {
				oscillator_13_mix_current += ((envelope_2_current >> 4) * program->oscillator_13_mix_env_2) >> 12;
			}
			if (program->oscillator_13_mix_env_3 != 0) {
				oscillator_13_mix_current += ((envelope_3_current >> 4) * program->oscillator_13_mix_env_3) >> 12;
			}
			int32_t delta = ((((oscillator_1_current * oscillator_13_mix_current) >> 16) << 20) / SAMPLERATE) << 13;
			oscillator_3_position += delta;
			oscillator_3_sync_position += delta;
			oscillator_3_sync_position &= 0xffffff;
		}

		// Oscillator 2 -> oscillator 3 frequency modulation
		if (program->oscillator_23_fm != 0) {
			uint16_t oscillator_23_mix_current = program->oscillator_23_mix;
			if (program->oscillator_23_mix_lfo_1 != 0) {
				oscillator_23_mix_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->oscillator_23_mix_lfo_1) >> 12;
			}
			if (program->oscillator_23_mix_lfo_2 != 0) {
				oscillator_23_mix_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->oscillator_23_mix_lfo_2) >> 12;
			}
			if (program->oscillator_23_mix_env_2 != 0) {
				oscillator_23_mix_current += ((envelope_2_current >> 4) * program->oscillator_23_mix_env_2) >> 12;
			}
			if (program->oscillator_23_mix_env_3 != 0) {
				oscillator_23_mix_current += ((envelope_3_current >> 4) * program->oscillator_23_mix_env_3) >> 12;
			}
			int32_t delta = ((((oscillator_2_current * oscillator_23_mix_current) >> 16) << 20) / SAMPLERATE) << 13;
			oscillator_3_position += delta;
			oscillator_3_sync_position += delta;
			oscillator_3_sync_position &= 0xffffff;
		}

		if (oscillator_3_position >= 0x1000000) {
			oscillator_3_position &= 0xffffff;
			if (oscillator_3_sync_delta != 0) {
				oscillator_3_sync_position = oscillator_3_position;
			}
		}

		// Update noise oscillator
		oscillator_noise_position += 0x10000;
		if (oscillator_noise_position >= 0x1000000) {
			oscillator_noise_position &= 0xffffff;
			waveform_noise_create();
		}

		// Make sure the sound does not clip
		if (sample < -128) {
			sample = -128;
		} else if (sample > 127) {
			sample = 127;
		}
		filter_in = sample << 5;

		// Update filter frequency and resonance every 64th sample
		if ((buffer_position & 63) == 0) {
			// Update filter frequency
			filter_frequency_current = program->filter_frequency;
			if (program->filter_frequency_lfo_1 != 0) {
				filter_frequency_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->filter_frequency_lfo_1) >> 12;
			}
			if (program->filter_frequency_lfo_2 != 0) {
				filter_frequency_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->filter_frequency_lfo_2) >> 12;
			}
			if (program->filter_frequency_env_2 != 0) {
				filter_frequency_current += ((envelope_2_current >> 4) * program->filter_frequency_env_2) >> 12;
			}
			if (program->filter_frequency_env_3 != 0) {
				filter_frequency_current += ((envelope_3_current >> 4) * program->filter_frequency_env_3) >> 12;
			}
			if (filter_frequency_current < 0) {
				filter_frequency_current = 0;
			} else if (filter_frequency_current > 0xfff) {
				filter_frequency_current = 0xfff;
			}

			// Update filter resonance
			filter_resonance_current = program->filter_resonance;
			if (program->filter_resonance_lfo_1 != 0) {
				filter_resonance_current += (waveforms_lfo[(lfo_1_position >> 16) + program->lfo_1_waveform] * program->filter_resonance_lfo_1) >> 12;
			}
			if (program->filter_resonance_lfo_2 != 0) {
				filter_resonance_current += (waveforms_lfo[(lfo_2_position >> 16) + program->lfo_2_waveform] * program->filter_resonance_lfo_2) >> 12;
			}
			if (program->filter_resonance_env_2 != 0) {
				filter_resonance_current += ((envelope_2_current >> 4) * program->filter_resonance_env_2) >> 12;
			}
			if (program->filter_resonance_env_3 != 0) {
				filter_resonance_current += ((envelope_3_current >> 4) * program->filter_resonance_env_3) >> 12;
			}
			if (filter_resonance_current < 0) {
				filter_resonance_current = 0;
			} else if (filter_resonance_current > 0xfff) {
				filter_resonance_current = 0xfff;
			}

			// Update filter coefficients
			filter_coefficients();
		}

		// Apply 24dB resonant filter
		filter_in -= (filter_q * b4) >> 12;
		int16_t t1 = b1;
		b1 = (((filter_in + b0) * filter_p) >> 12) - ((b1 * filter_f) >> 12);
		int16_t t2 = b2;
		b2 = (((b1 + t1) * filter_p) >> 12) - ((b2 * filter_f) >> 12);
		t1 = b3;
		b3 = (((b2 + t2) * filter_p) >> 12) - ((b3 * filter_f) >> 12);
		b4 = (((b3 + t1) * filter_p) >> 12) - ((b4 * filter_f) >> 12);
		b4 -= ((((b4 * b4) >> 12) * b4) >> 12) / 6;
		b0 = filter_in;

		int16_t output = (b4 * part->volume) >> 11;
		if (add) {
			output += buffer_render[buffer_position];
			if (output < -128) {
				output = -128;
			} else if (output > 127) {
				output = 127;
			}
		}
		buffer_render[buffer_position] = output;
	}
}

void synthLoad(UNICHAR *fileName)
{
	FILE* file = UNICHAR_FOPEN(fileName, "rb");
	if (file == NULL)
	{
		return;
	}

	fseek(file, 0, SEEK_END);
	uint32_t size = ftell(file);
	rewind(file);

	if (size == (sizeof(synth_t) - 2)) {
		fread(&synth, 1, size, file);
	}

	fclose(file);
}

void synthSave(UNICHAR *fileName)
{
	FILE* file = UNICHAR_FOPEN(fileName, "wb");
	if (file == NULL)
	{
		return;
	}

	fwrite(&synth, 1, sizeof(synth_t) - 2, file);
	fclose(file);
}
