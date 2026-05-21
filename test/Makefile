CC         = gcc
# sdl2-config --cflags gives -I.../SDL2, but pt2_header.h uses <SDL2/SDL.h>
# so we need the parent directory.
SDL_CFLAGS = $(shell sdl2-config --cflags 2>/dev/null | sed 's|/SDL2||g')
CFLAGS     = -O2 -DNDEBUG -I../src $(SDL_CFLAGS) -Wall -Wno-unused-result
SRCS    = synth_test.c ../src/pt2_synth.c
TARGET  = synth_test

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -f $(TARGET)

.PHONY: clean
