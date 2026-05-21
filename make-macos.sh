#!/bin/bash

# Thanks to odaki on GitHub for this script. I have modified it a bit.

arch=$(arch)
if [ $arch == "ppc" ]; then
    echo Sorry, PowerPC \(PPC\) is not supported...
fi

if [ "$1" = "-v" ]; then
    VERBOSE=-v
fi

#
# Setup variables
#
VERSION=v`grep PROG_VER_STR src/pt2_header.h|cut -d'"' -f 2`

RELEASE_MACOS_DIR=release/macos/
APP_DIR=${RELEASE_MACOS_DIR}pt2-clone-macos.app/

TARGET_X86_64=${APP_DIR}Contents/MacOS/pt2-clone-macos-x86_64
TARGET_ARM64=${APP_DIR}Contents/MacOS/pt2-clone-macos-arm64
TARGET_UNIVERSAL=${APP_DIR}Contents/MacOS/pt2-clone-macos
TARGET_DIR=${APP_DIR}Contents/MacOS/

#
# Prepare
#
if [ ! -d $TARGET_DIR ]; then
    mkdir -p $TARGET_DIR
fi

#
# SDL2 detection: prefer installed framework, fall back to sdl2-config / brew / pkg-config
#
if [ -d /Library/Frameworks/SDL2.framework ]; then
    SDL2_CFLAGS="-F /Library/Frameworks"
    SDL2_LDFLAGS="-L /Library/Frameworks -framework SDL2"
else
    # Locate sdl2-config: check PATH, then Homebrew prefix (arm64 and Intel)
    SDL2_CONFIG=
    if command -v sdl2-config &> /dev/null; then
        SDL2_CONFIG=sdl2-config
    else
        for candidate in \
            "$(brew --prefix sdl2 2>/dev/null)/bin/sdl2-config" \
            /opt/homebrew/bin/sdl2-config \
            /usr/local/bin/sdl2-config; do
            if [ -x "$candidate" ]; then
                SDL2_CONFIG="$candidate"
                break
            fi
        done
    fi

    if [ -n "$SDL2_CONFIG" ]; then
        SDL2_PREFIX=$($SDL2_CONFIG --prefix)
        SDL2_CFLAGS="-I${SDL2_PREFIX}/include $($SDL2_CONFIG --cflags | sed 's/-I[^ ]*//')"
        SDL2_LDFLAGS=$($SDL2_CONFIG --libs)
        # sdl2-config may return -framework SDL2 (official DMG style) even when only the
        # Homebrew dylib is installed. If the framework is missing but the dylib exists,
        # fall back to -lSDL2 so the link succeeds.
        if echo "$SDL2_LDFLAGS" | grep -q "\-framework SDL2"; then
            FRAMEWORK_PATH=$(echo "$SDL2_LDFLAGS" | grep -o '\-F[^ ]*' | sed 's/-F//')
            if [ -z "$FRAMEWORK_PATH" ] || [ ! -d "${FRAMEWORK_PATH}/SDL2.framework" ]; then
                if [ -f "${SDL2_PREFIX}/lib/libSDL2.dylib" ]; then
                    SDL2_LDFLAGS="-L${SDL2_PREFIX}/lib -lSDL2"
                fi
            fi
        fi
    elif command -v pkg-config &> /dev/null && pkg-config --exists sdl2; then
        SDL2_CFLAGS=$(pkg-config --cflags-only-I sdl2 | sed 's|-I\([^ ]*\)/SDL2|-I\1|g')
        SDL2_LDFLAGS=$(pkg-config --libs sdl2)
    else
        echo "Error: SDL2 not found. Install SDL2.framework to /Library/Frameworks or install via Homebrew (brew install sdl2)."
        exit 1
    fi
fi

#
# Compile (parallel per-file, then link)
#
COMMON_CFLAGS="-g0 -DNDEBUG -ffast-math -Wall -Winit-self -Wextra -Wunused -Wredundant-decls"
SRCS=(src/gfx/*.c src/modloaders/*.c src/smploaders/*.c src/*.c)

function compile() {
    local output=$1
    local pids=() objs=() failed=0

    for src in "${SRCS[@]}"; do
        local obj="${src%.c}.o"
        clang $VERBOSE $CFLAGS $SDL2_CFLAGS $COMMON_CFLAGS -c "$src" -o "$obj" &
        pids+=($!) objs+=("$obj")
    done

    for pid in "${pids[@]}"; do wait "$pid" || failed=1; done
    [ $failed -ne 0 ] && return 1

    clang $VERBOSE $CFLAGS "${objs[@]}" $LDFLAGS $SDL2_LDFLAGS -framework Cocoa -lm -o "$output"
}

export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk

if [ -d /Library/Frameworks/SDL2.framework ]; then
    # Framework present: build universal binary
    echo Compiling x86_64 binary, please wait patiently...
    CFLAGS="-target x86_64-apple-macos10.11 -mmacosx-version-min=10.11 -arch x86_64 -mmmx -mfpmath=sse -msse2 -O3"
    LDFLAGS=
    compile $TARGET_X86_64
    if [ $? -ne 0 ]; then echo failed; exit 1; fi

    echo Compiling arm64 binary, please wait patiently...
    CFLAGS="-target arm64-apple-macos11 -mmacosx-version-min=11.0 -arch arm64 -march=armv8.3-a+sha3 -O3"
    LDFLAGS=
    compile $TARGET_ARM64
    if [ $? -ne 0 ]; then echo failed; exit 1; fi

    echo Building universal binary...
    rm $TARGET_UNIVERAL &> /dev/null
    lipo -create -output $TARGET_UNIVERSAL $TARGET_X86_64 $TARGET_ARM64
    rm $TARGET_X86_64
    rm $TARGET_ARM64
    strip $TARGET_UNIVERSAL
    install_name_tool -change @rpath/SDL2.framework/Versions/A/SDL2 @executable_path/../Frameworks/SDL2.framework/Versions/A/SDL2 $TARGET_UNIVERSAL
    codesign -s - --entitlements pt2-clone.entitlements release/macOS/pt2-clone-macos.app
else
    # No framework: build native arch only (e.g. Homebrew SDL2)
    echo Compiling $(arch) binary, please wait patiently...
    if [ $arch == "arm64" ]; then
        CFLAGS="-target arm64-apple-macos11 -mmacosx-version-min=11.0 -arch arm64 -march=armv8.3-a+sha3 -O3"
    else
        CFLAGS="-target x86_64-apple-macos10.11 -mmacosx-version-min=10.11 -arch x86_64 -mmmx -mfpmath=sse -msse2 -O3"
    fi
    LDFLAGS=
    compile $TARGET_UNIVERSAL
    if [ $? -ne 0 ]; then echo failed; exit 1; fi
    strip $TARGET_UNIVERSAL
fi

echo Done. The executable can be found in \'${RELEASE_MACOS_DIR}\' if everything went well.

#
# Cleanup
#
rm src/gfx/*.o src/modloaders/*.o src/smploaders/*.o src/*.o &> /dev/null
