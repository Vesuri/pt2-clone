// for finding memory leaks in debug mode with Visual Studio 
#if defined _DEBUG && defined _MSC_VER
#include <crtdbg.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include "pt2_header.h"
#include "pt2_helpers.h"
#include "pt2_tables.h"
#include "pt2_mouse.h"
#include "pt2_synth.h"
#include "pt2_structs.h"
#include "pt2_config.h"
#include "pt2_bmp.h"

synth_t synth; // globalized

void synthRender(void)
{
	printf("RENDER\n");
}
