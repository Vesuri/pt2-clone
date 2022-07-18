#pragma once

#include <stdint.h>
#include "pt2_palette.h"
#include "pt2_mouse.h"

// TABLES
extern const char *ftuneStrTab[16];
extern const int8_t vuMeterHeights[65];
extern const char hexTable[16];
extern const uint32_t cursorColors[6][3];
extern const char *noteNames1[2+36];
extern const char *noteNames2[2+36];
extern const char *noteNames3[2+36];
extern const char *noteNames4[2+36];
extern const uint8_t vibratoTable[32];
extern const int16_t periodTable[(37*16)+15];
extern int8_t pNoteTable[32];
extern const uint64_t musicTimeTab64[256-32];

// changable by config file
extern uint16_t analyzerColors[36];
extern uint16_t vuMeterColors[48];

// button tables taken from the ptplay project + modified

// MODIFY THESE EVERY TIME YOU REMOVE/ADD A BUTTON!
#define ASK_BUTTONS 2
#define PAT2SMP_ASK_BUTTONS 3
#define CLEAR_BUTTONS 4
#define TOPSCREEN_BUTTONS 47
#define MIDSCREEN_BUTTONS 3
#define BOTSCREEN_BUTTONS 4
#define DISKOP_BUTTONS 17
#define POSED_BUTTONS 12
#define EDITOP1_BUTTONS 13
#define EDITOP2_BUTTONS 22
#define EDITOP3_BUTTONS 29
#define EDITOP4_BUTTONS 29
#define SAMPLER_BUTTONS 25
#define SYNTH_BUTTONS 15
// -----------------------------------------------

extern const guiButton_t bAsk[];
extern const guiButton_t bPat2SmpAsk[];
extern const guiButton_t bClear[];
extern const guiButton_t bTopScreen[];
extern const guiButton_t bMidScreen[];
extern const guiButton_t bBotScreen[];
extern const guiButton_t bDiskOp[];
extern const guiButton_t bPosEd[];
extern const guiButton_t bEditOp1[];
extern const guiButton_t bEditOp2[];
extern const guiButton_t bEditOp3[];
extern const guiButton_t bEditOp4[];
extern const guiButton_t bSampler[];
extern const guiButton_t bSynth[];
