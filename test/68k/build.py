#!/usr/bin/env python3
"""
Generates synth_render.s from the 68k source repo's synth.s and assembles it.

Changes made to synth.s:
  - RENDER_BUFFER mode instead of RENDER_REALTIME
  - Output file changed to WORK:output.raw (accessible via vamos volume mapping)
  - render_size_param: dc.l 12288 field added after lfo_2_waveform so tests can
    pass a per-test render size; load_params copies it into buffer_render_size
  - params_end label added after render_size_param (marks end of parameter block)
  - params_filename data label added
  - MODE_OLDFILE and _LVORead constants added
  - load_params subroutine added (reads WORK:params.bin into parameter globals)
  - main: calls load_params before startup
  - moveq #0,d0 inserted before .dosok: rts so the binary always exits 0 on
    success (otherwise buffer_render_size leaks into d0 via _LVOFreeMem)
"""

import os
import re
import subprocess
import sys

SYNTH_S = os.path.expanduser("~/Documents/dA JoRMaS/Effects/synth/synth.s")
INCLUDE_DIR = os.path.expanduser("~/Documents/dA JoRMaS/Include")
SYNTH_DIR = os.path.expanduser("~/Documents/dA JoRMaS/Effects/synth")
OUT_S = os.path.join(os.path.dirname(__file__), "synth_render.s")
OUT_BIN = os.path.join(os.path.dirname(__file__), "synth_render")

LOAD_PARAMS_ROUTINE = """
; Load synthesis parameters from WORK:params.bin into the parameter globals.
; The file is a flat big-endian binary matching the parameter block layout
; from oscillator_1_waveform through render_size_param (210 bytes / 103 words
; + one longword for the render size).  If render_size_param is non-zero it
; is copied into buffer_render_size so the caller can pass a per-test size.
load_params:
\tmovem.l\td0-d3/a0-a2/a6,-(sp)
\tmove.l\t4.w,a6
\tlea\tname_dos,a1
\tmoveq\t#0,d0
\tjsr\t_LVOOpenLibrary(a6)
\ttst.l\td0
\tbeq.s\t.lp_done
\tmove.l\td0,a2\t\t\t; save dos base for CloseLibrary
\tmove.l\td0,a6\t\t\t; use dos base
\tmove.l\t#params_filename,d1
\tmove.l\t#MODE_OLDFILE,d2
\tjsr\t_LVOOpen(a6)
\ttst.l\td0
\tbeq.s\t.lp_closedos
\tmove.l\td0,a0\t\t\t; save file handle
\tmove.l\td0,d1
\tmove.l\t#oscillator_1_waveform,d2
\tmove.l\t#params_end-oscillator_1_waveform,d3
\tjsr\t_LVORead(a6)
\tmove.l\trender_size_param,d0\t\t; apply per-test render size if set
\tbeq.s\t.lp_close
\tmove.l\td0,buffer_render_size
.lp_close:
\tmove.l\ta0,d1\t\t\t; file handle
\tjsr\t_LVOClose(a6)
.lp_closedos:
\tmove.l\ta2,a1
\tmove.l\t4.w,a6
\tjsr\t_LVOCloseLibrary(a6)
.lp_done:
\tmovem.l\t(sp)+,d0-d3/a0-a2/a6
\trts
"""

NEW_CONSTANTS = """
MODE_OLDFILE\t\tequ\t1005
_LVORead\t\tequ\t-42
BUFFER_ONLY\t\tequ\t1
; The constants below replicate the SYSTEM_INCLUDES_NEEDED block in synth.i.
; They are only referenced in the dead RENDER_REALTIME code path but must be
; defined so the assembler doesn't error.
NT_INTERRUPT\t\tequ\t2
LN_TYPE\t\t\tequ\t8
LN_NAME\t\t\tequ\t10
IS_DATA\t\t\tequ\t14
IS_CODE\t\t\tequ\t18
DMAF_SETCLR\t\tequ\t$8000
DMAF_AUD0\t\tequ\t$0001
DMAF_AUDIO\t\tequ\t$000F
INTB_AUD3\t\tequ\t10
INTB_AUD2\t\tequ\t9
INTB_AUD1\t\tequ\t8
INTB_AUD0\t\tequ\t7
INTF_SETCLR\t\tequ\t(1<<15)
INTF_AUD3\t\tequ\t(1<<10)
INTF_AUD2\t\tequ\t(1<<9)
INTF_AUD1\t\tequ\t(1<<8)
INTF_AUD0\t\tequ\t(1<<7)
CIAF_LED\t\tequ\t(1<<1)
dmacon\t\t\tequ\t$096
intena\t\t\tequ\t$09a
intreq\t\t\tequ\t$09c
adkcon\t\t\tequ\t$09e
ciapra\t\t\tequ\t$0000
aud0\t\t\tequ\t$0a0
aud1\t\t\tequ\t$0b0
aud2\t\t\tequ\t$0c0
aud3\t\t\tequ\t$0d0
ac_ptr\t\t\tequ\t$00
ac_len\t\t\tequ\t$04
ac_per\t\t\tequ\t$06
ac_vol\t\t\tequ\t$08
io_Device\t\tequ\t0
ex_EClockFrequency\tequ\t$238
ib_FirstScreen\t\tequ\t$3c
sc_ViewPort\t\tequ\t$2c
_LVOGetVPModeID\t\tequ\t-792
_LVOGetDisplayInfoData\tequ\t-756
mtr_SIZEOF\t\tequ\t$60
DTAG_MNTR\t\tequ\t$80002000
mtr_TotalRows\t\tequ\t$24
mtr_TotalColorClocks\tequ\t$26
mtr_MinRow\t\tequ\t$28
MEMF_CLEAR\t\tequ\t(1<<16)
MEMF_CHIP\t\tequ\t(1<<1)
IS_SIZE\t\t\tequ\t22
_LVOOpen\t\tequ\t-30
_LVOClose\t\tequ\t-36
_LVOWrite\t\tequ\t-48
MODE_NEWFILE\t\tequ\t1006
; Intuition/Gadget structure offsets (from exec_lib.i / Amiga NDK)
gg_Flags\t\tequ\t12
gg_Activation\t\tequ\t14
gg_GadgetType\t\tequ\t16
gg_SpecialInfo\t\tequ\t34
gg_GadgetID\t\tequ\t38
gg_UserData\t\tequ\t40
GTYP_PROPGADGET\tequ\t1
pi_VertPot\t\tequ\t4
pi_HorizPot\t\tequ\t2
wd_UserPort\t\tequ\t86
im_Class\t\tequ\t20
im_Code\t\t\tequ\t24
im_Qualifier\t\tequ\t26
im_IAddress\t\tequ\t28
IDCMP_GADGETUP\t\tequ\t$200
IDCMP_GADGETDOWN\tequ\t$400
IDCMP_MOUSEMOVE\t\tequ\t$10
_LVOAllocMem\t\tequ\t-198
_LVOFreeMem\t\tequ\t-210
_LVOOpenLibrary\t\tequ\t-552
_LVOCloseLibrary\tequ\t-414
_LVOGetMsg\t\tequ\t-372
_LVOReplyMsg\t\tequ\t-378
_LVOOpenWindowTagList\tequ\t-606
_LVOOpenScreenTagList\tequ\t-612
_LVOOpenDevice\t\tequ\t-444
_LVOCloseDevice\t\tequ\t-450
"""


def patch(src):
    lines = src.splitlines(keepends=True)
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]

        # 1. Change render_mode from REALTIME to BUFFER
        if re.match(r'^render_mode:\s+dc\.b\s+RENDER_REALTIME', line):
            line = line.replace('RENDER_REALTIME', 'RENDER_BUFFER')

        # 2. Change output filename to a vamos-accessible path.
        #    shutdown: patches positions +10 and +12 of this string to 'r'/'w' for
        #    RAW mode or 'w'/'v' for WAV mode — so the base must be X.wav where X
        #    is 9 chars (5 for "WORK:" + 4 for name) so position 10 = 'w', 12 = 'v'.
        #    "WORK:out1.wav" → "WORK:out1.raw" in BUFFER_RAW mode.
        if re.match(r'^name_outputfile:', line) and 'ram:synth' in line:
            line = re.sub(r'"[^"]*"', '"WORK:out1.wav"', line)

        # 3a. Wrap realtime-only sections with ifeq BUFFER_ONLY / endc.
        #
        # su_rt: and sd_rt: labels are always emitted (so 'beq su_rt'/'beq sd_rt'
        # in startup:/shutdown: can still assemble), but their CONTENTS are wrapped.
        # When BUFFER_ONLY=1 those labels exist but their bodies are empty, so the
        # branches from startup:/shutdown: point into dead code that is never reached
        # at runtime (render_mode is hardcoded to RENDER_BUFFER).
        if re.match(r'^su_rt:', line):
            out.append(line)           # emit su_rt: label unconditionally
            out.append('\t\t\t\t\tifeq\tBUFFER_ONLY\n')
            i += 1
            continue
        if re.match(r'^shutdown:', line):
            out.append('\t\t\t\t\tendc\n')   # close su_rt: body wrap
        if re.match(r'^sd_rt:', line):
            out.append(line)           # emit sd_rt: label unconditionally
            out.append('\t\t\t\t\tifeq\tBUFFER_ONLY\n')
            i += 1
            continue
        # screen_tags: closes the sd_rt: body wrap and opens the data wrap
        if re.match(r'^screen_tags:', line):
            out.append('\t\t\t\t\tendc\n')   # close sd_rt: body wrap
            out.append('\t\t\t\t\tifeq\tBUFFER_ONLY\n')  # open data wrap
        if re.match(r'^header_wav:', line):
            out.append('\t\t\t\t\tendc\n')   # close data wrap

        # 3b. Add params_filename label alongside name_outputfile block
        if re.match(r'^name_outputfile:', line):
            out.append(line)
            out.append('params_filename:\t\t\tdc.b\t"WORK:params.bin",0\n')
            out.append('\t\t\t\t\teven\n')
            i += 1
            continue

        # 4. Add render_size_param field and params_end label after lfo_2_waveform.
        #    render_size_param is read by load_params; if non-zero it overrides
        #    buffer_render_size so tests can request a specific render length.
        if re.match(r'^lfo_2_waveform:', line):
            out.append(line)
            i += 1
            out.append('render_size_param:\t\tdc.l\t12288\n')
            out.append('params_end:\n')
            continue

        # 5. Add MODE_OLDFILE and _LVORead after the SYSTEM_INCLUDES_NEEDED block
        if re.match(r'^SAMPLERATE\s+equ', line):
            out.append(line)
            out.append(NEW_CONSTANTS)
            i += 1
            continue

        # 6. Clear d0 before the RENDER_BUFFER shutdown exit so the binary always
        #    exits with code 0 on success.  Without this, buffer_render_size is
        #    left in d0 by _LVOFreeMem and vamos exposes it as the process exit code.
        if re.match(r'^\.dosok:\s+rts', line):
            out.append('\t\t\t\t\tmoveq\t#0,d0\n')
            # fall through to emit .dosok: rts normally

        # 7. main: is the binary entry point — insert load_params call there.
        #    Place the subroutine itself before filter_coefficients: so it isn't
        #    at the very start of the code section (which the OS would execute directly).
        if re.match(r'^main:\s+bsr\s+startup', line):
            out.append('main:\tbsr\tload_params\n')
            out.append(line.replace('main:\t', '\t', 1))  # keep bsr startup
            i += 1
            continue
        if re.match(r'^filter_coefficients:', line):
            out.append(LOAD_PARAMS_ROUTINE)
            out.append('\n')

        out.append(line)
        i += 1
    return ''.join(out)


def build():
    print(f"Reading {SYNTH_S}")
    with open(SYNTH_S, 'r') as f:
        src = f.read()

    patched = patch(src)

    print(f"Writing {OUT_S}")
    with open(OUT_S, 'w') as f:
        f.write(patched)

    print(f"Assembling → {OUT_BIN}")
    cmd = [
        'vasmm68k_mot',
        '-Fhunkexe',
        '-phxass',
        '-o', OUT_BIN,
        '-I', INCLUDE_DIR,
        '-I', SYNTH_DIR,
        OUT_S,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if result.returncode != 0:
        print("Assembly failed", file=sys.stderr)
        sys.exit(1)
    print("Done.")


if __name__ == '__main__':
    build()
