SYSTEM_INCLUDES_NEEDED	equ	0
SAMPLERATE		equ	22050

MODE_OLDFILE		equ	1005
_LVORead		equ	-42
BUFFER_ONLY		equ	1
; The constants below replicate the SYSTEM_INCLUDES_NEEDED block in synth.i.
; They are only referenced in the dead RENDER_REALTIME code path but must be
; defined so the assembler doesn't error.
NT_INTERRUPT		equ	2
LN_TYPE			equ	8
LN_NAME			equ	10
IS_DATA			equ	14
IS_CODE			equ	18
DMAF_SETCLR		equ	$8000
DMAF_AUD0		equ	$0001
DMAF_AUDIO		equ	$000F
INTB_AUD3		equ	10
INTB_AUD2		equ	9
INTB_AUD1		equ	8
INTB_AUD0		equ	7
INTF_SETCLR		equ	(1<<15)
INTF_AUD3		equ	(1<<10)
INTF_AUD2		equ	(1<<9)
INTF_AUD1		equ	(1<<8)
INTF_AUD0		equ	(1<<7)
CIAF_LED		equ	(1<<1)
dmacon			equ	$096
intena			equ	$09a
intreq			equ	$09c
adkcon			equ	$09e
ciapra			equ	$0000
aud0			equ	$0a0
aud1			equ	$0b0
aud2			equ	$0c0
aud3			equ	$0d0
ac_ptr			equ	$00
ac_len			equ	$04
ac_per			equ	$06
ac_vol			equ	$08
io_Device		equ	0
ex_EClockFrequency	equ	$238
ib_FirstScreen		equ	$3c
sc_ViewPort		equ	$2c
_LVOGetVPModeID		equ	-792
_LVOGetDisplayInfoData	equ	-756
mtr_SIZEOF		equ	$60
DTAG_MNTR		equ	$80002000
mtr_TotalRows		equ	$24
mtr_TotalColorClocks	equ	$26
mtr_MinRow		equ	$28
MEMF_CLEAR		equ	(1<<16)
MEMF_CHIP		equ	(1<<1)
IS_SIZE			equ	22
_LVOOpen		equ	-30
_LVOClose		equ	-36
_LVOWrite		equ	-48
MODE_NEWFILE		equ	1006
; Intuition/Gadget structure offsets (from exec_lib.i / Amiga NDK)
gg_Flags		equ	12
gg_Activation		equ	14
gg_GadgetType		equ	16
gg_SpecialInfo		equ	34
gg_GadgetID		equ	38
gg_UserData		equ	40
GTYP_PROPGADGET	equ	1
pi_VertPot		equ	4
pi_HorizPot		equ	2
wd_UserPort		equ	86
im_Class		equ	20
im_Code			equ	24
im_Qualifier		equ	26
im_IAddress		equ	28
IDCMP_GADGETUP		equ	$200
IDCMP_GADGETDOWN	equ	$400
IDCMP_MOUSEMOVE		equ	$10
_LVOAllocMem		equ	-198
_LVOFreeMem		equ	-210
_LVOOpenLibrary		equ	-552
_LVOCloseLibrary	equ	-414
_LVOGetMsg		equ	-372
_LVOReplyMsg		equ	-378
_LVOOpenWindowTagList	equ	-606
_LVOOpenScreenTagList	equ	-612
_LVOOpenDevice		equ	-444
_LVOCloseDevice		equ	-450

	incdir	"include:"
	include	"synth.i"

	section	fastcode,code

	; Initialize the synth
	; --------------------
main:	bsr	load_params
	bsr	startup
	bne	.shut

	move.l	buffer_render,a0
	cmp.b	#RENDER_BUFFER,render_mode
	beq.s	.nort
.holdb:	tst.b	render_hold
	bne.s	.holdb
	move.l	buffer_play,a0
	add.l	buffer_play_current,a0	
.nort:	moveq	#0,d1		; b1
	moveq	#0,d2		; b2
	moveq	#0,d3		; b3
	moveq	#0,d4		; b4
	moveq	#0,d5		; b5
	sub.l	a1,a1		; t1
	sub.l	a2,a2		; t2
	lea	waveform_saw,a3
	sub.l	a6,a6		; position in buffer
.loop:	; Only update envelopes every envelope_stretch samples due to resolution
	; ----------------------------------------------------------------------
	move.l	a6,d6
	and.l	envelope_stretch,d6
	bne	.env3o	

	; Update envelope 1
	; -----------------
	move.l	envelope_1_delta32,d6
	add.l	d6,envelope_1_current32
	bpl.s	.env1do
	clr.l	envelope_1_current32
.env1do:
	sub.w	#1,envelope_1_counter
	bpl.w	.env1o
	add.b	#1,envelope_1_mode
	cmp.b	#ENVELOPE_ATTACK,envelope_1_mode
	bne.s	.env1d
	move.l	#$ffff,d6
	move.w	envelope_1_attack,d7
	addq	#1,d7
	divu	d7,d6
	clr.w	envelope_1_delta32
	move.w	d6,envelope_1_delta
	move.w	envelope_1_attack,envelope_1_counter
	bra.s	.env1o
.env1d:	cmp.b	#ENVELOPE_DECAY,envelope_1_mode
	bne.s	.env1s
	move.l	#$fff,d6
	sub.w	envelope_1_sustain,d6
	lsl.w	#4,d6
	move.w	envelope_1_decay,d7
	addq	#1,d7
	divu	d7,d6
	neg.w	d6
	ext.l	d6
	move.l	d6,envelope_1_delta32
	move.w	envelope_1_decay,envelope_1_counter
	bra.s	.env1o
.env1s:	move.w	envelope_1_sustain,d6
	lsl.w	#4,d6
	move.w	d6,envelope_1_current
	clr.l	envelope_1_delta32
	move.w	#$7fff,envelope_1_counter
.env1o:
	; Update envelope 2
	; -----------------
	move.l	envelope_2_delta32,d6
	add.l	d6,envelope_2_current32
	bpl.s	.env2do
	clr.l	envelope_2_current32
.env2do:
	sub.w	#1,envelope_2_counter
	bpl.w	.env2o
	add.b	#1,envelope_2_mode
	cmp.b	#ENVELOPE_ATTACK,envelope_2_mode
	bne.s	.env2d
	move.l	#$ffff,d6
	move.w	envelope_2_attack,d7
	addq	#1,d7
	divu	d7,d6
	clr.w	envelope_2_delta32
	move.w	d6,envelope_2_delta
	move.w	envelope_2_attack,envelope_2_counter
	bra.s	.env2o
.env2d:	cmp.b	#ENVELOPE_DECAY,envelope_2_mode
	bne.s	.env2s
	move.l	#$fff,d6
	sub.w	envelope_2_sustain,d6
	lsl.w	#4,d6
	move.w	envelope_2_decay,d7
	addq	#1,d7
	divu	d7,d6
	neg.w	d6
	ext.l	d6
	move.l	d6,envelope_2_delta32
	move.w	envelope_2_decay,envelope_2_counter
	bra.s	.env2o
.env2s:	move.w	envelope_2_sustain,d6
	lsl.w	#4,d6
	move.w	d6,envelope_2_current
	clr.l	envelope_2_delta32
	move.w	#$7fff,envelope_2_counter
.env2o:
	; Update envelope 3
	; -----------------
	move.l	envelope_3_delta32,d6
	add.l	d6,envelope_3_current32
	bpl.s	.env3do
	clr.l	envelope_3_current32
.env3do:
	sub.w	#1,envelope_3_counter
	bpl.w	.env3o
	add.b	#1,envelope_3_mode
	cmp.b	#ENVELOPE_ATTACK,envelope_3_mode
	bne.s	.env3d
	move.l	#$ffff,d6
	move.w	envelope_3_attack,d7
	addq	#1,d7
	divu	d7,d6
	clr.w	envelope_3_delta32
	move.w	d6,envelope_3_delta
	move.w	envelope_3_attack,envelope_3_counter
	bra.s	.env3o
.env3d:	cmp.b	#ENVELOPE_DECAY,envelope_3_mode
	bne.s	.env3s
	move.l	#$fff,d6
	sub.w	envelope_3_sustain,d6
	lsl.w	#4,d6
	move.w	envelope_3_decay,d7
	addq	#1,d7
	divu	d7,d6
	neg.w	d6
	ext.l	d6
	move.l	d6,envelope_3_delta32
	move.w	envelope_3_decay,envelope_3_counter
	bra.s	.env3o
.env3s:	move.w	envelope_3_sustain,d6
	lsl.w	#4,d6
	move.w	d6,envelope_3_current
	clr.l 	envelope_3_delta32
	move.w	#$7fff,envelope_3_counter
.env3o:

	; Update LFO 1
	; ------------
	move.w	lfo_1_speed,d6
	ext.l	d6
	swap	d6
	divu	#SAMPLERATE,d6
	ext.l	d6
	lsl.l	#2,d6				; lfo_1_delta
	add.l	d6,lfo_1_position
	cmp.l	#$10000000,lfo_1_position
	bcs.s	.lfo1o
	sub.l	#$10000000,lfo_1_position
.lfo1o:
	; Update LFO 2
	; ------------
	move.w	lfo_2_speed,d6
	ext.l	d6
	swap	d6
	divu	#SAMPLERATE,d6
	ext.l	d6
	lsl.l	#2,d6				; lfo_2_delta
	add.l	d6,lfo_2_position
	cmp.l	#$10000000,lfo_2_position
	bcs.s	.lfo2o
	sub.l	#$10000000,lfo_2_position
.lfo2o:

	; Only update oscillator widths, pitches and square waveforms every
	; 64th sample
	; -----------------------------------------------------------------
	move.l	a6,d6
	and.l	#63,d6
	bne	.updok

	; Update oscillator 1 width
	; -------------------------
	move.w	oscillator_1_width,d6
	tst.w	oscillator_1_width_lfo_1
	beq.s	.o1wl1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_1_width_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1wl1:	tst.w	oscillator_1_width_lfo_2
	beq.s	.o1wl2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_1_width_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1wl2:	tst.w	oscillator_1_width_env_2
	beq.s	.o1we2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_1_width_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1we2:	tst.w	oscillator_1_width_env_3
	beq.s	.o1we3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_1_width_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1we3:	move.w	d6,oscillator_1_width_current

	; Update oscillator 2 width
	; -------------------------
	move.w	oscillator_2_width,d6
	tst.w	oscillator_2_width_lfo_1
	beq.s	.o2wl1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_2_width_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2wl1:	tst.w	oscillator_2_width_lfo_2
	beq.s	.o2wl2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_2_width_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2wl2:	tst.w	oscillator_2_width_env_2
	beq.s	.o2we2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_2_width_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2we2:	tst.w	oscillator_2_width_env_3
	beq.s	.o2we3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_2_width_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2we3:	move.w	d6,oscillator_2_width_current

	; Update oscillator 3 width
	; -------------------------
	move.w	oscillator_3_width,d6
	tst.w	oscillator_3_width_lfo_1
	beq.s	.o3wl1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_3_width_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3wl1:	tst.w	oscillator_3_width_lfo_2
	beq.s	.o3wl2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_3_width_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3wl2:	tst.w	oscillator_3_width_env_2
	beq.s	.o3we2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_3_width_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3we2:	tst.w	oscillator_3_width_env_3
	beq.s	.o3we3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_3_width_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3we3:	move.w	d6,oscillator_3_width_current

	bsr	waveform_square_create

	; Update oscillator 1 pitch
	; -------------------------
	move.w	oscillator_1_pitch,d6
	tst.w	oscillator_1_pitch_lfo_1
	beq.s	.o1pl1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_1_pitch_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1pl1:	tst.w	oscillator_1_pitch_lfo_2
	beq.s	.o1pl2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_1_pitch_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1pl2:	tst.w	oscillator_1_pitch_env_2
	beq.s	.o1pe2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_1_pitch_env_2,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o1pe2:	tst.w	oscillator_1_pitch_env_3
	beq.s	.o1pe3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_1_pitch_env_3,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o1pe3:	ext.l	d6
	bpl.s	.o1cp
	moveq	#0,d6
	bra.s	.o1d
.o1cp:	swap	d6
	divu	#SAMPLERATE,d6
	ext.l	d6
	lsl.l	#8,d6
.o1d:	move.l	d6,oscillator_1_delta

	; Update oscillator 2 pitch
	; -------------------------
	move.w	oscillator_2_pitch,d6
	tst.w	oscillator_2_pitch_lfo_1
	beq.s	.o2pl1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_2_pitch_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2pl1:	tst.w	oscillator_2_pitch_lfo_2
	beq.s	.o2pl2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_2_pitch_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2pl2:	tst.w	oscillator_2_pitch_env_2
	beq.s	.o2pe2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_2_pitch_env_2,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o2pe2:	tst.w	oscillator_2_pitch_env_3
	beq.s	.o2pe3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_2_pitch_env_3,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o2pe3:	ext.l	d6
	bpl.s	.o2cp
	moveq	#0,d6
	bra.s	.o2d
.o2cp:	swap	d6
	divu	#SAMPLERATE,d6
	ext.l	d6
	lsl.l	#8,d6
.o2d:	move.l	d6,oscillator_2_delta

	; Update oscillator 3 pitch
	; -------------------------
	move.w	oscillator_3_pitch,d6
	tst.w	oscillator_3_pitch_lfo_1
	beq.s	.o3pl1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_3_pitch_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3pl1:	tst.w	oscillator_3_pitch_lfo_2
	beq.s	.o3pl2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_3_pitch_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3pl2:	tst.w	oscillator_3_pitch_env_2
	beq.s	.o3pe2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_3_pitch_env_2,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o3pe2:	tst.w	oscillator_3_pitch_env_3
	beq.s	.o3pe3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_3_pitch_env_3,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o3pe3:	ext.l	d6
	bpl.s	.o3cp
	moveq	#0,d6
	bra.s	.o3d
.o3cp:	swap	d6
	divu	#SAMPLERATE,d6
	ext.l	d6
	lsl.l	#8,d6
.o3d:	move.l	d6,oscillator_3_delta

	; Update oscillator 1 sync
	; -------------------------
	move.w	oscillator_1_sync,d6
	tst.w	oscillator_1_sync_lfo_1
	beq.s	.o1sl1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_1_sync_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1sl1:	tst.w	oscillator_1_sync_lfo_2
	beq.s	.o1sl2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_1_sync_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1sl2:	tst.w	oscillator_1_sync_env_2
	beq.s	.o1se2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_1_sync_env_2,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o1se2:	tst.w	oscillator_1_sync_env_3
	beq.s	.o1se3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_1_sync_env_3,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o1se3:	ext.l	d6
	bpl.s	.o1sc
	moveq	#0,d6
	bra.s	.o1sd
.o1sc:	swap	d6
	divu	#SAMPLERATE,d6
	ext.l	d6
	lsl.l	#8,d6
.o1sd:	move.l	d6,oscillator_1_sync_delta

	; Update oscillator 2 sync
	; -------------------------
	move.w	oscillator_2_sync,d6
	tst.w	oscillator_2_sync_lfo_1
	beq.s	.o2sl1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_2_sync_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2sl1:	tst.w	oscillator_2_sync_lfo_2
	beq.s	.o2sl2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_2_sync_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2sl2:	tst.w	oscillator_2_sync_env_2
	beq.s	.o2se2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_2_sync_env_2,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o2se2:	tst.w	oscillator_2_sync_env_3
	beq.s	.o2se3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_2_sync_env_3,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o2se3:	ext.l	d6
	bpl.s	.o2sc
	moveq	#0,d6
	bra.s	.o2sd
.o2sc:	swap	d6
	divu	#SAMPLERATE,d6
	ext.l	d6
	lsl.l	#8,d6
.o2sd:	move.l	d6,oscillator_2_sync_delta

	; Update oscillator 3 sync
	; -------------------------
	move.w	oscillator_3_sync,d6
	tst.w	oscillator_3_sync_lfo_1
	beq.s	.o3sl1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_3_sync_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3sl1:	tst.w	oscillator_3_sync_lfo_2
	beq.s	.o3sl2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_3_sync_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3sl2:	tst.w	oscillator_3_sync_env_2
	beq.s	.o3se2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_3_sync_env_2,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o3se2:	tst.w	oscillator_3_sync_env_3
	beq.s	.o3se3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_3_sync_env_3,d7
	swap	d7
	rol.l	#5,d7
	add.w	d7,d6
.o3se3:	ext.l	d6
	bpl.s	.o3sc
	moveq	#0,d6
	bra.s	.o3sd
.o3sc:	swap	d6
	divu	#SAMPLERATE,d6
	ext.l	d6
	lsl.l	#8,d6
.o3sd:	move.l	d6,oscillator_3_sync_delta

.updok:	; Sum oscillators
	; ---------------
	moveq	#0,d0

	; Sum oscillator 1
	; ----------------
	move.l	oscillator_1_position,d7
	swap	d7
	add.w	oscillator_1_waveform,d7
	move.b	(a3,d7.w),d6
	move.l	oscillator_1_sync_position,d7
	swap	d7
	add.w	oscillator_1_waveform,d7
	move.b	(a3,d7.w),d7
	ext.w	d6
	ext.w	d7
	add.w	d7,d6
	asr.w	d6
	move.w	d6,oscillator_1_current
	move.w	oscillator_1_mix,d6
	tst.w	oscillator_1_mix_lfo_1
	beq.s	.o1ml1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_1_mix_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1ml1:	tst.w	oscillator_1_mix_lfo_2
	beq.s	.o1ml2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_1_mix_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1ml2:	tst.w	oscillator_1_mix_env_2
	beq.s	.o1me2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_1_mix_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1me2:	tst.w	oscillator_1_mix_env_3
	beq.s	.o1me3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_1_mix_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o1me3:	move.w	envelope_1_current,d7
	lsr.w	#4,d7
	muls	d6,d7
	swap	d7
	rol.l	#4,d7
	move.w	oscillator_1_current,d6
	muls	d7,d6
	rol.l	#4,d6
	swap	d6
	add.w	d6,d0

	; Sum oscillator 2
	; ----------------
	move.l	oscillator_2_position,d7
	swap	d7
	add.w	oscillator_2_waveform,d7
	move.b	(a3,d7.w),d6
	move.l	oscillator_2_sync_position,d7
	swap	d7
	add.w	oscillator_2_waveform,d7
	move.b	(a3,d7.w),d7
	ext.w	d6
	ext.w	d7
	add.w	d7,d6
	asr.w	d6
	move.w	d6,oscillator_2_current
	move.w	oscillator_2_mix,d6
	tst.w	oscillator_2_mix_lfo_1
	beq.s	.o2ml1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_2_mix_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2ml1:	tst.w	oscillator_2_mix_lfo_2
	beq.s	.o2ml2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_2_mix_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2ml2:	tst.w	oscillator_2_mix_env_2
	beq.s	.o2me2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_2_mix_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2me2:	tst.w	oscillator_2_mix_env_3
	beq.s	.o2me3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_2_mix_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o2me3:	move.w	envelope_1_current,d7
	lsr.w	#4,d7
	muls	d6,d7
	swap	d7
	rol.l	#4,d7
	move.w	oscillator_2_current,d6
	muls	d7,d6
	rol.l	#4,d6
	swap	d6
	add.w	d6,d0

	; Sum oscillator 3
	; ----------------
	move.l	oscillator_3_position,d7
	swap	d7
	add.w	oscillator_3_waveform,d7
	move.b	(a3,d7.w),d6
	move.l	oscillator_3_sync_position,d7
	swap	d7
	add.w	oscillator_3_waveform,d7
	move.b	(a3,d7.w),d7
	ext.w	d6
	ext.w	d7
	add.w	d7,d6
	asr.w	d6
	move.w	d6,oscillator_3_current
	move.w	oscillator_3_mix,d6
	tst.w	oscillator_3_mix_lfo_1
	beq.s	.o3ml1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_3_mix_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3ml1:	tst.w	oscillator_3_mix_lfo_2
	beq.s	.o3ml2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_3_mix_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3ml2:	tst.w	oscillator_3_mix_env_2
	beq.s	.o3me2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_3_mix_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3me2:	tst.w	oscillator_3_mix_env_3
	beq.s	.o3me3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_3_mix_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o3me3:	move.w	envelope_1_current,d7
	lsr.w	#4,d7
	muls	d6,d7
	swap	d7
	rol.l	#4,d7
	move.w	oscillator_3_current,d6
	muls	d7,d6
	rol.l	#4,d6
	swap	d6
	add.w	d6,d0

	; Sum oscillator 1*3
	; ------------------
	tst.w	oscillator_13_fm
	bne.w	.o4ok
	move.w	oscillator_1_current,d7
	move.w	oscillator_3_current,d6
	muls	d7,d6
	asr.w	#7,d6
	move.w	d6,a5
	move.w	oscillator_13_mix,d6
	tst.w	oscillator_13_mix_lfo_1
	beq.s	.o4ml1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_13_mix_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o4ml1:	tst.w	oscillator_13_mix_lfo_2
	beq.s	.o4ml2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_13_mix_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o4ml2:	tst.w	oscillator_13_mix_env_2
	beq.s	.o4me2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_13_mix_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o4me2:	tst.w	oscillator_13_mix_env_3
	beq.s	.o4me3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_13_mix_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o4me3:	move.w	envelope_1_current,d7
	lsr.w	#4,d7
	muls	d6,d7
	swap	d7
	rol.l	#4,d7
	move.w	a5,d6
	muls	d7,d6
	rol.l	#4,d6
	swap	d6
	add.w	d6,d0
.o4ok:
	; Sum oscillator 2*3
	; ------------------
	tst.w	oscillator_23_fm
	bne.w	.o5ok
	move.w	oscillator_2_current,d7
	move.w	oscillator_3_current,d6
	muls	d7,d6
	asr.w	#7,d6
	move.w	d6,a5
	move.w	oscillator_23_mix,d6
	tst.w	oscillator_23_mix_lfo_1
	beq.s	.o5ml1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_23_mix_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o5ml1:	tst.w	oscillator_23_mix_lfo_2
	beq.s	.o5ml2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_23_mix_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o5ml2:	tst.w	oscillator_23_mix_env_2
	beq.s	.o5me2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_23_mix_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o5me2:	tst.w	oscillator_23_mix_env_3
	beq.s	.o5me3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_23_mix_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o5me3:	move.w	envelope_1_current,d7
	lsr.w	#4,d7
	muls	d6,d7
	swap	d7
	rol.l	#4,d7
	move.w	a5,d6
	muls	d7,d6
	rol.l	#4,d6
	swap	d6
	add.w	d6,d0
.o5ok:
	; Sum noise oscillator
	; --------------------
	move.l	oscillator_noise_position,d7
	swap	d7
	add.w	#WAVEFORM_NOISE,d7
	move.b	(a3,d7.w),d6
	ext.w	d6
	move.w	d6,a5
	move.w	oscillator_noise_mix,d6
	tst.w	oscillator_noise_mix_lfo_1
	beq.s	.onml1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_noise_mix_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.onml1:	tst.w	oscillator_noise_mix_lfo_2
	beq.s	.onml2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_noise_mix_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.onml2:	tst.w	oscillator_noise_mix_env_2
	beq.s	.onme2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_noise_mix_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.onme2:	tst.w	oscillator_noise_mix_env_3
	beq.s	.onme3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_noise_mix_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.onme3:	move.w	envelope_1_current,d7
	lsr.w	#4,d7
	muls	d6,d7
	swap	d7
	rol.l	#4,d7
	move.w	a5,d6
	muls	d7,d6
	rol.l	#4,d6
	swap	d6
	add.w	d6,d0

	asr.w	d0
	
	; Update oscillator 1 sync
	; ------------------------
	move.l	oscillator_1_sync_delta,d6
	add.l	oscillator_1_delta,d6
	add.l	d6,oscillator_1_sync_position
	and.l	#$00ffffff,oscillator_1_sync_position

	; Update oscillator 2 sync
	; ------------------------
	move.l	oscillator_2_sync_delta,d6
	add.l	oscillator_2_delta,d6
	add.l	d6,oscillator_2_sync_position
	and.l	#$00ffffff,oscillator_2_sync_position

	; Update oscillator 3 sync
	; ------------------------
	move.l	oscillator_3_sync_delta,d6
	add.l	oscillator_3_delta,d6
	add.l	d6,oscillator_3_sync_position
	and.l	#$00ffffff,oscillator_3_sync_position

	; Update oscillator 1
	; -------------------
	move.l	oscillator_1_delta,d6
	add.l	d6,oscillator_1_position
	cmp.l	#$01000000,oscillator_1_position
	bcs.s	.osc1o
	and.l	#$00ffffff,oscillator_1_position
	tst.l	oscillator_1_sync_delta
	beq.s	.osc1o
	move.l	oscillator_1_position,oscillator_1_sync_position
.osc1o:
	; Update oscillator 2
	; -------------------
	move.l	oscillator_2_delta,d6
	add.l	d6,oscillator_2_position
	cmp.l	#$01000000,oscillator_2_position
	bcs.s	.osc2o
	and.l	#$00ffffff,oscillator_2_position
	tst.l	oscillator_2_sync_delta
	beq.s	.osc2o
	move.l	oscillator_2_position,oscillator_2_sync_position
.osc2o:
	; Update oscillator 3
	; -------------------
	move.l	oscillator_3_delta,d6
	add.l	d6,oscillator_3_position

	; Oscillator 1 -> oscillator 3 frequency modulation
	; -------------------------------------------------
	tst.w	oscillator_13_fm
	beq.w	.o13fo
	move.w	oscillator_13_mix,d6
	tst.w	oscillator_13_mix_lfo_1
	beq.s	.o13l1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_13_mix_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o13l1:	tst.w	oscillator_13_mix_lfo_2
	beq.s	.o13l2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_13_mix_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o13l2:	tst.w	oscillator_13_mix_env_2
	beq.s	.o13e2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_13_mix_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o13e2:	tst.w	oscillator_13_mix_env_3
	beq.s	.o13e3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_13_mix_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o13e3:	move.w	oscillator_1_current,d7
	muls	d6,d7
	asl.l	#4,d7
	divs	#SAMPLERATE,d7
	ext.l	d7
	asl.l	#8,d7
	asl.l	#5,d7
	add.l	d7,oscillator_3_position
	add.l	d7,oscillator_3_sync_position
	and.l	#$00ffffff,oscillator_3_sync_position

.o13fo:	; Oscillator 2 -> oscillator 3 frequency modulation
	; -------------------------------------------------
	tst.w	oscillator_23_fm
	beq.w	.o23fo
	move.w	oscillator_23_mix,d6
	tst.w	oscillator_23_mix_lfo_1
	beq.s	.o23l1
	move.l	lfo_1_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_1_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_23_mix_lfo_1,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o23l1:	tst.w	oscillator_23_mix_lfo_2
	beq.s	.o23l2
	move.l	lfo_2_position,d7
	swap	d7
	add.w	d7,d7
	add.w	lfo_2_waveform,d7
	move.w	(a3,d7.w),d7
	muls	oscillator_23_mix_lfo_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o23l2:	tst.w	oscillator_23_mix_env_2
	beq.s	.o23e2
	move.w	envelope_2_current,d7
	lsr.w	#4,d7
	muls	oscillator_23_mix_env_2,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o23e2:	tst.w	oscillator_23_mix_env_3
	beq.s	.o23e3
	move.w	envelope_3_current,d7
	lsr.w	#4,d7
	muls	oscillator_23_mix_env_3,d7
	swap	d7
	rol.l	#4,d7
	add.w	d7,d6
.o23e3:	move.w	oscillator_2_current,d7
	muls	d6,d7
	asl.l	#4,d7
	divs	#SAMPLERATE,d7
	ext.l	d7
	asl.l	#8,d7
	asl.l	#5,d7
	add.l	d7,oscillator_3_position
	add.l	d7,oscillator_3_sync_position
	and.l	#$00ffffff,oscillator_3_sync_position

.o23fo:	cmp.l	#$01000000,oscillator_3_position
	bcs.s	.osc3o
	and.l	#$00ffffff,oscillator_3_position
	tst.l	oscillator_3_sync_delta
	beq.s	.osc3o
	move.l	oscillator_3_position,oscillator_3_sync_position
.osc3o:
	; Update noise oscillator
	; -----------------------
	add.l	#$00010000,oscillator_noise_position
	cmp.l	#$01000000,oscillator_noise_position
	bcs.s	.osc4o
	and.l	#$00ffffff,oscillator_noise_position
	bsr	waveform_noise_create
.osc4o:

	; Make sure the sound does not clip
	; ---------------------------------
	cmp.w	#-128,d0
	bge.s	.osclo
	moveq	#-128,d0
	bra.s	.oscok
.osclo:	cmp.w	#127,d0
	ble.s	.oscok
	moveq	#127,d0
.oscok:	asl.w	#5,d0
	move.w	d0,filter_in
	
	; Update filter frequency and resonance every 64th sample
	; -------------------------------------------------------
	move.l	a6,d6
	and.l	#63,d6
	bne.w	.ncoef

	; Update filter frequency
	; -----------------------
	move.w	filter_frequency,d6
	move.w	filter_frequency_lfo_1,d7
	beq.s	.ffl1o
	move.l	lfo_1_position,d0
	swap	d0
	add.w	d0,d0
	add.w	lfo_1_waveform,d0
	move.w	(a3,d0.w),d0
	muls	d7,d0
	swap	d0
	rol.l	#4,d0
	add.w	d0,d6
.ffl1o:	move.w	filter_frequency_lfo_2,d7
	beq.s	.ffl2o
	move.l	lfo_2_position,d0
	swap	d0
	add.w	d0,d0
	add.w	lfo_2_waveform,d0
	move.w	(a3,d0.w),d0
	muls	d7,d0
	swap	d0
	rol.l	#4,d0
	add.w	d0,d6
.ffl2o:	move.w	filter_frequency_env_2,d7
	beq.s	.ffe2o
	move.w	envelope_2_current,d0
	lsr.w	#4,d0
	muls	d7,d0
	swap	d0
	rol.l	#4,d0
	add.w	d0,d6
.ffe2o:	move.w	filter_frequency_env_3,d7
	beq.s	.ffe3o
	move.w	envelope_3_current,d0
	lsr.w	#4,d0
	muls	d7,d0
	swap	d0
	rol.l	#4,d0
	add.w	d0,d6
.ffe3o:	tst.w	d6
	bge.s	.fflok
	moveq	#0,d6
	bra.s	.ffok
.fflok:	cmp.w	#$fff,d6
	ble.s	.ffok
	move.w	#$fff,d6
.ffok:	move.w	d6,filter_frequency_current

	; Update filter resonance
	; -----------------------
	move.w	filter_resonance,d6
	move.w	filter_resonance_lfo_1,d7
	beq.s	.frl1o
	move.l	lfo_1_position,d0
	swap	d0
	add.w	d0,d0
	add.w	lfo_1_waveform,d0
	move.w	(a3,d0.w),d0
	muls	d7,d0
	swap	d0
	rol.l	#4,d0
	add.w	d0,d6
.frl1o:	move.w	filter_resonance_lfo_2,d7
	beq.s	.frl2o
	move.l	lfo_2_position,d0
	swap	d0
	add.w	d0,d0
	add.w	lfo_2_waveform,d0
	move.w	(a3,d0.w),d0
	muls	d7,d0
	swap	d0
	rol.l	#4,d0
	add.w	d0,d6
.frl2o:	move.w	filter_resonance_env_2,d7
	beq.s	.fre2o
	move.w	envelope_2_current,d0
	lsr.w	#4,d0
	muls	d7,d0
	swap	d0
	rol.l	#4,d0
	add.w	d0,d6
.fre2o:	move.w	filter_resonance_env_3,d7
	beq.s	.fre3o
	move.w	envelope_3_current,d0
	lsr.w	#4,d0
	muls	d7,d0
	swap	d0
	rol.l	#4,d0
	add.w	d0,d6
.fre3o:	tst.w	d6
	bpl.s	.frlok
	moveq	#0,d6
	bra.s	.frok
.frlok:	cmp.w	#$fff,d6
	ble.s	.frok
	move.w	#$fff,d6
.frok:	move.w	d6,filter_resonance_current

	; Update filter coefficients
	; --------------------------
	bsr	filter_coefficients
	
.ncoef:	; Apply 24dB resonant filter
	; --------------------------
	move.w	filter_q,d0	; in -= q * b4;
	ext.l	d0
	muls	d4,d0
	swap	d0
	rol.l	#4,d0
	sub.w	d0,filter_in

	move.l	d1,a1		; t1 = b1;

	move.w	filter_in,d0	; b1 = (in + b0) * p - b1 * f;
	add.w	d5,d0
	ext.l	d0
	muls	filter_p,d0
	swap	d0
	rol.l	#4,d0
	ext.l	d1
	muls	filter_f,d1
	swap	d1
	rol.l	#4,d1
	neg.w	d1
	add.w	d0,d1

	move.w	d2,a2		; t2 = b2;

	move.w	a1,d0		; b2 = (b1 + t1) * p - b2 * f;
	add.w	d1,d0
	ext.l	d0
	muls	filter_p,d0
	swap	d0
	rol.l	#4,d0
	ext.l	d2
	muls	filter_f,d2
	swap	d2
	rol.l	#4,d2
	neg.w	d2
	add.w	d0,d2

	move.l	d3,a1		; t1 = b3;

	move.w	a2,d0		; b3 = (b2 + t2) * p - b3 * f;
	add.w	d2,d0
	ext.l	d0
	muls	filter_p,d0
	swap	d0
	rol.l	#4,d0
	ext.l	d3
	muls	filter_f,d3
	swap	d3
	rol.l	#4,d3
	neg.w	d3
	add.w	d0,d3

	move.w	a1,d0		; b4 = (b3 + t1) * p - b4 * f;
	add.w	d3,d0
	ext.l	d0
	muls	filter_p,d0
	swap	d0
	rol.l	#4,d0
	ext.l	d4
	muls	filter_f,d4
	swap	d4
	rol.l	#4,d4
	neg.w	d4
	add.w	d0,d4

	move.w	d4,d0		; b4 = b4 - b4 * b4 * b4 * 0.166667f;
	ext.l	d0
	muls	d4,d0
	swap	d0
	rol.l	#4,d0
	ext.l	d0
	muls	d4,d0
	swap	d0
	rol.l	#4,d0
	ext.l	d0
	divs	#6,d0
	sub.w	d0,d4
	move.w	filter_in,d5	; b0 = in;

	move.w	d4,d0
	asr.w	#5,d0
	move.b	d0,(a0)+
	addq	#1,a6
	cmp.b	#RENDER_BUFFER,render_mode
	beq	.buf
	; Handle messages if any
	; ----------------------
	movem.l	d0-d3/a0-a6,-(sp)
	move.l	window,a5
.msg:	move.l	4.w,a6
	move.l	wd_UserPort(a5),a0
	jsr	_LVOGetMsg(a6)
	tst.l	d0
	beq	.nomsg
	move.l	d0,a1
	move.l	im_Class(a1),d2
	move.w	im_Code(a1),d3
	move.l	im_IAddress(a1),a2
	jsr	_LVOReplyMsg(a6)

	cmp.l	#IDCMP_GADGETUP,d2
	beq	.gup
	cmp.l	#IDCMP_GADGETDOWN,d2
	beq	.gdown
	cmp.l	#IDCMP_MOUSEMOVE,d2
	bne.s	.msg
	move.l	gadget_current,a2
.gup:	move.l	gg_UserData(a2),d0
	beq.s	.msg
	move.l	d0,a0
	cmp.w	#GTYP_PROPGADGET,gg_GadgetType(a2)
	beq.s	.prop
	jsr	(a0)
	bra	.msg
.prop:	move.w	gg_GadgetID(a2),d1
	move.l	gg_SpecialInfo(a2),a2
	move.w	pi_VertPot(a2),d0
	lsr.w	d1,d0
	move.w	d0,(a0)
	bra	.msg
.gdown:	move.l	a2,gadget_current
	bra	.msg
	; Check whether play buffer has been filled
	; -----------------------------------------
.nomsg:	movem.l	(sp)+,d0-d3/a0-a6
	move.l	a6,d6
	move.l	buffer_play_size,d7
	subq	#1,d7
	and.l	d7,d6
	bne.s	.buf

	; Hold rendering until buffer has been played
	; -------------------------------------------
	move.b	#1,render_hold
.hold:	tst.b	render_hold
	bne.s	.hold
	move.l	buffer_play,a0
	add.l	buffer_play_current,a0

.buf:	tst.b	quit
	bne.s	.shut
	cmp.l	buffer_render_size,a6
	bcs	.loop

	; Wait until the last buffer has been played
	; ------------------------------------------
	cmp.b	#RENDER_BUFFER,render_mode
	beq.s	.shut
	bsr	initialize
	move.l	buffer_play,a0
	add.l	buffer_play_current,a0	
	bra	.nort
;	move.b	#1,render_hold
;.final:	tst.b	render_hold
;	bne.s	.final

.shut:	; Shut the synth down
	; -------------------
	bsr	shutdown
	rts

; Calculate filter coefficients
; -----------------------------

; Load synthesis parameters from WORK:params.bin into the parameter globals.
; The file is a flat big-endian binary matching the parameter block layout
; from oscillator_1_waveform through render_size_param (210 bytes / 103 words
; + one longword for the render size).  If render_size_param is non-zero it
; is copied into buffer_render_size so the caller can pass a per-test size.
load_params:
	movem.l	d0-d3/a0-a2/a6,-(sp)
	move.l	4.w,a6
	lea	name_dos,a1
	moveq	#0,d0
	jsr	_LVOOpenLibrary(a6)
	tst.l	d0
	beq.s	.lp_done
	move.l	d0,a2			; save dos base for CloseLibrary
	move.l	d0,a6			; use dos base
	move.l	#params_filename,d1
	move.l	#MODE_OLDFILE,d2
	jsr	_LVOOpen(a6)
	tst.l	d0
	beq.s	.lp_closedos
	move.l	d0,a0			; save file handle
	move.l	d0,d1
	move.l	#oscillator_1_waveform,d2
	move.l	#params_end-oscillator_1_waveform,d3
	jsr	_LVORead(a6)
	move.l	render_size_param,d0		; apply per-test render size if set
	beq.s	.lp_close
	move.l	d0,buffer_render_size
.lp_close:
	move.l	a0,d1			; file handle
	jsr	_LVOClose(a6)
.lp_closedos:
	move.l	a2,a1
	move.l	4.w,a6
	jsr	_LVOCloseLibrary(a6)
.lp_done:
	movem.l	(sp)+,d0-d3/a0-a2/a6
	rts

filter_coefficients:
	movem.l	d0-d1,-(sp)
	move.w	#$0fff,d0	; q = 1.0f - frequency;
	sub.w	filter_frequency_current,d0
	move.w	d0,filter_q
				; frequency + 0.8f * frequency * q;
	move.w	filter_frequency_current,d0
	move.w	d0,d1
	ext.l	d1
	add.l	d1,d1
	add.l	d1,d1
	divs	#5,d1		; d1=0.8*filter_frequency
	muls	filter_q,d1
	swap	d1
	rol.l	#4,d1
	add.w	d0,d1
	move.w	d1,filter_p

	add.w	d1,d1		; f = p + p - 1.0f;
	sub.w	#$0fff,d1
	move.w	d1,filter_f

	move.w	filter_q,d0	; q = resonance * (1.0f + 0.5f * 
	move.w	d0,d1		; q * (1.0f - q + 5.6f * q * q));
	muls	d1,d0
	swap	d0
	rol.l	#4,d0
	muls	#56,d0
	divs	#10,d0
	sub.w	d1,d0
	add.w	#$0fff,d0
	asr.w	d0
	ext.l	d0
	muls	filter_q,d0
	swap	d0
	rol.l	#4,d0
	ext.l	d0
	add.l	#$0fff,d0
	muls	filter_resonance_current,d0
	swap	d0
	rol.l	#4,d0
	move.w	d0,filter_q
	movem.l	(sp)+,d0-d1
	rts

; Create saw waveform
; -------------------
waveform_saw_create:
	lea	waveform_saw,a0
	moveq	#127,d0
	move.l	#256-1,d7
.loop:	move.b	d0,(a0)+
	subq	#1,d0
	dbra	d7,.loop
	rts

; Create square waveforms
; -----------------------
waveform_square_create:
	movem.l	d6-d7/a0,-(sp)
	lea	waveform_square,a0
	move.w	oscillator_1_width_current,d6
	lsr.w	#4,d6
	move.w	d6,d7
	beq.s	.o1hok
	subq	#1,d7
.l1:	move.b	#127,(a0)+
	dbra	d7,.l1

.o1hok:	neg.w	d6
	add.w	#256,d6
	move.w	d6,d7
	beq.s	.o1lok
	subq	#1,d7
.l2:	move.b	#-128,(a0)+
	dbra	d7,.l2

.o1lok:	move.w	oscillator_2_width_current,d6
	lsr.w	#4,d6
	move.w	d6,d7
	beq.s	.o2hok
	subq	#1,d7
.l3:	move.b	#127,(a0)+
	dbra	d7,.l3

.o2hok:	neg.w	d6
	add.w	#256,d6
	move.w	d6,d7
	beq.s	.o2lok
	subq	#1,d7
.l4:	move.b	#-128,(a0)+
	dbra	d7,.l4

.o2lok:	move.w	oscillator_3_width_current,d6
	lsr.w	#4,d6
	move.w	d6,d7
	beq.s	.o3hok
	subq	#1,d7
.l5:	move.b	#127,(a0)+
	dbra	d7,.l5

.o3hok:	neg.w	d6
	add.w	#256,d6
	move.w	d6,d7
	beq.s	.o3lok
	subq	#1,d7
.l6:	move.b	#-128,(a0)+
	dbra	d7,.l6

.o3lok:	movem.l	(sp)+,d6-d7/a0
	rts

; Create noise waveform
; ---------------------
waveform_noise_create:
	movem.l	d0-d2/d7/a0,-(sp)
	lea	waveform_noise,a0
	move.l	#256-1,d7
.loop:	bsr	random
	move.b	d0,(a0)+
	dbra	d7,.loop
	movem.l	(sp)+,d0-d2/d7/a0
	rts

; Create sinus waveform
; ---------------------
waveform_sinus_create:
	lea	sinus,a0
	lea	waveform_sinus,a1
	move.l	#64-1,d7
.loop:	move.b	(a0),(a1)+
	addq	#8,a0
	move.b	(a0),(a1)+
	addq	#8,a0
	move.b	(a0),(a1)+
	addq	#8,a0
	move.b	(a0),(a1)+
	addq	#8,a0
	dbra	d7,.loop
	rts

; Create LFO waveforms
; --------------------
waveform_lfo_create:
	; Create saw
	; ----------
	lea	waveform_lfo_saw,a0
	move.l	#4096-1,d7
.l1:	move.w	d7,d0
	add.w	d7,d0
	sub.w	#4095,d0
	move.w	d0,(a0)+
	dbra	d7,.l1

	; Create square
	; -------------
	move.l	#2048-1,d7
.l2:	move.w	#-$fff,(a0)+
	dbra	d7,.l2
	move.l	#2048-1,d7
.l3:	move.w	#$fff,(a0)+
	dbra	d7,.l3
	
	; Create triangle
	; ---------------
	moveq	#0,d0
	move.l	#1024-1,d7
.l4:	move.w	d0,(a0)+
	addq	#4,d0
	dbra	d7,.l4
	move.l	#2048-1,d7
.l5:	move.w	d0,(a0)+
	subq	#4,d0
	dbra	d7,.l5
	move.l	#1024-1,d7
.l6:	move.w	d0,(a0)+
	addq	#4,d0
	dbra	d7,.l6
	rts

; 32 bit random number generator
; ------------------------------
random:	moveq	#4,d2			; do this 5 times
	move.l	random_number,d0	; get current 
.ninc0:	moveq	#0,d1			; clear bit count
	ror.l	#2,d0			; bit 31 -> carry
	bcc.s	.ninc1			; skip increment if =0
	addq.b	#1,d1			; else increment bit count
.ninc1:	ror.l	#3,d0			; bit 28 -> carry
	bcc.s	.ninc2			; skip increment if =0
	addq.b	#1,d1			; else increment bit count
.ninc2:	rol.l	#5,d0			; restore PRNG longword
	roxr.b	#1,d1			; EOR bit into Xb
	roxr.l	#1,d0			; shift bit to most significant
	dbra	d2,.ninc0		; loop 5 times
	move.l	d0,random_number	; save back to seed word
	rts

; Convert a number to little endian format
; ----------------------------------------
little_endian:
	swap	d0
	move.l	d0,d1
	lsr.l	#8,d0
	lsl.l	#8,d1
	and.l	#$00ff00ff,d0
	and.l	#$ff00ff00,d1
	or.l	d1,d0
	rts

; Initialize parameters to default values
; ---------------------------------------
initialize:
	move.l	#$bc5d71e3,random_number

	; Initialize WAV header
	; ---------------------
	lea	header_wav,a0
	move.l	buffer_render_size,d0
	add.l	#36,d0
	bsr	little_endian
	move.l	d0,4(a0)

	moveq	#16,d0
	bsr	little_endian
	move.l	d0,16(a0)

	moveq	#1,d0
	bsr	little_endian
	swap	d0
	move.w	d0,20(a0)
	move.w	d0,22(a0)
	move.w	d0,32(a0)

	move.l	#SAMPLERATE,d0
	bsr	little_endian
	move.l	d0,24(a0)
	move.l	d0,28(a0)
	
	moveq	#8,d0
	bsr	little_endian
	swap	d0
	move.w	d0,34(a0)

	move.l	buffer_render_size,d0
	bsr	little_endian
	move.l	d0,40(a0)
	
	; Initialize runtime variables
	; ----------------------------
	lea	oscillator_1_position,a0
.loop:	clr.b	(a0)+
	cmp.l	#render_hold,a0
	bcs.s	.loop
	
	; Calculate envelope stretch
	; --------------------------
;	move.l	buffer_render_size,d0
;	swap	d0
;	rol.l	#4,d0
;	subq	#1,d0	
;	move.l	d0,envelope_stretch
	move.l	#7,envelope_stretch

	; Create waveforms
	; ----------------
	bsr	waveform_saw_create
	bsr	waveform_square_create
	bsr	waveform_noise_create
	bsr	waveform_sinus_create
	bsr	waveform_lfo_create
	rts

; Startup code
; ------------
startup:
	bsr	initialize

	move.l	4.w,a6
	cmp.b	#RENDER_REALTIME,render_mode
	beq.s	su_rt

	; Open dos.library
	; ----------------
	moveq	#0,d0
	lea	name_dos,a1
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,base_dos
	beq	.fail

	; Allocate memory for render buffer
	; ---------------------------------
	move.l	buffer_render_size,d0
	moveq	#0,d1
	jsr	_LVOAllocMem(a6)
	move.l	d0,buffer_render
	beq	.fail

	moveq	#0,d0
	rts
.fail:	moveq	#1,d0
	rts

su_rt:	; Allocate memory for play buffer
					ifeq	BUFFER_ONLY
	; -------------------------------
	move.l	buffer_play_size,d0
	add.w	d0,d0
	move.l	#MEMF_CLEAR|MEMF_CHIP,d1
	jsr	_LVOAllocMem(a6)
	move.l	d0,buffer_play
	beq	.fail

	; Open graphics.library and intuition.library
	; -------------------------------------------
	moveq	#0,d0
	lea	name_graphics,a1
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,base_graphics
	beq	.fail

	moveq	#0,d0
	lea	name_intuition,a1
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,base_intuition
	beq	.fail

	; Open screen and window
	; ----------------------
	move.l	d0,a6
	sub.l	a0,a0
	lea	screen_tags,a1
	jsr	_LVOOpenScreenTagList(a6)
	move.l	d0,screen
	beq	.fail

	move.l	d0,window_screen+4
	move.l	d0,a0
	lea	sc_ViewPort(a0),a0
	move.l	base_graphics,a6
	lea	color_table,a1
	jsr	_LVOLoadRGB32(a6)

	move.w	filter_frequency,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_frequency+pi_VertPot
	move.w	filter_frequency_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_frequency_lfo_1+pi_VertPot
	move.w	filter_frequency_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_frequency_lfo_2+pi_VertPot
	move.w	filter_frequency_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_frequency_env_2+pi_VertPot
	move.w	filter_frequency_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_frequency_env_3+pi_VertPot
	move.w	filter_resonance,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_resonance+pi_VertPot
	move.w	filter_resonance_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_resonance_lfo_1+pi_VertPot
	move.w	filter_resonance_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_resonance_lfo_2+pi_VertPot
	move.w	filter_resonance_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_resonance_env_2+pi_VertPot
	move.w	filter_resonance_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_filter_resonance_env_3+pi_VertPot
	move.w	envelope_1_attack,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_envelope_1_attack+pi_VertPot
	move.w	envelope_1_decay,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_envelope_1_decay+pi_VertPot
	move.w	envelope_1_sustain,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_envelope_1_sustain+pi_VertPot
	move.w	envelope_2_attack,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_envelope_2_attack+pi_VertPot
	move.w	envelope_2_decay,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_envelope_2_decay+pi_VertPot
	move.w	envelope_2_sustain,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_envelope_2_sustain+pi_VertPot
	move.w	envelope_3_attack,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_envelope_3_attack+pi_VertPot
	move.w	envelope_3_decay,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_envelope_3_decay+pi_VertPot
	move.w	envelope_3_sustain,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_envelope_3_sustain+pi_VertPot
	move.w	lfo_1_speed,d0
	lsl.w	#3,d0
	move.w	d0,propinfo_lfo_1_speed+pi_VertPot
	move.w	lfo_2_speed,d0
	lsl.w	#3,d0
	move.w	d0,propinfo_lfo_2_speed+pi_VertPot

	move.l	base_intuition,a6
	sub.l	a0,a0
	lea	window_tags,a1
	jsr	_LVOOpenWindowTagList(a6)
	move.l	d0,window
	beq	.fail

	move.l	d0,a0
	move.l	wd_RPort(a0),a0
	lea	intuitext_jormation,a1
	moveq	#0,d0
	moveq	#4,d1
	jsr	_LVOPrintIText(a6)

	move.w	#1,oscillator_gadgets_active
	bsr	callback_oscillator_1

	lea	gadget_lfo_1_waveform_square,a3
	move.l	#gadget_lfo_1_waveform_triangle,d2
	bsr	refresh_lfo_gadgets

	lea	gadget_lfo_2_waveform_square,a3
	move.l	#gadget_lfo_2_waveform_triangle,d2
	bsr	refresh_lfo_gadgets

	; Create message and IO request for opening audio.device
	; ------------------------------------------------------
	move.l	4.w,a6
	jsr	_LVOCreateMsgPort(a6)
	move.l	d0,message_port
	beq	.fail

	move.l	d0,a0
	move.l	#ioa_SIZEOF,d0
	jsr	_LVOCreateIORequest(a6)
	move.l	d0,io_request
	beq	.fail

	lea	name_audio,a0
	move.l	io_request,a1
	moveq	#0,d0
	moveq	#0,d1
	jsr	_LVOOpenDevice(a6)
	tst.w	d0
	bne	.fail

	; Initialize interrupt structure
	; ------------------------------
	lea	vector_audio_0,a0
	move	#NT_INTERRUPT,LN_TYPE(a0)
	move.l	#name_interrupt,LN_NAME(a0)
	move.l	buffer_render,IS_DATA(a0)
	move.l	#interrupt_audio_0,IS_CODE(a0)

	; Stop audio DMA
	; --------------
	move.w	#DMAF_AUDIO,custom+dmacon

	; Set interrupt vector for audio channel 0
	; ----------------------------------------
	move.l	#INTB_AUD0,d0
	lea	vector_audio_0,a1
	jsr	_LVOSetIntVector(a6)
	move.l	d0,interrupt_vector_audio_0

	; Enable audio interrupt
	; ----------------------
	move.w	#AUDIO_INTERRUPTS,custom+intreq
	move.w	#AUDIO_INTERRUPTS,custom+intena
	move.w	#INTF_SETCLR|INTERRUPT_USED,custom+intena
	or.b	#CIAF_LED,ciaa+ciapra		; switch off audio filter

	; Set up audio parameters
	; -----------------------
	move.l	base_intuition,a0
	move.l	ib_FirstScreen(a0),d0
	move.l	base_graphics,a6
	move.l	d0,a0
	move.l	sc_ViewPort(a0),a0
	jsr	_LVOGetVPModeID(a6)
	swap	d0
	cmp.w	#1,d0
	beq	.ntsc
	move.l	#3546895/SAMPLERATE,d0	; PAL
	bra.s	.perok
.ntsc:	move.l	#3579545/SAMPLERATE,d0	; NTSC
.perok:	move.w	d0,custom+aud0+ac_per
	move.l	buffer_play_size,d0
	lsr.w	d0
	move.w	d0,custom+aud0+ac_len
	move.w	#64,custom+aud0+ac_vol
	move.l	buffer_play,d0
	move.l	d0,custom+aud0+ac_ptr

	; Start audio DMA
	; ---------------
	move.b	#1,render_hold
	move.w	#DMAF_SETCLR|DMAF_AUDIO,custom+dmacon

	moveq	#0,d0
	rts
.fail:	moveq	#1,d0
	rts

; Shutdown code
; -------------
					endc
shutdown:
	cmp.b	#RENDER_REALTIME,render_mode
	beq	sd_rt

	tst.l	buffer_render
	beq	.rbok

	; Whether to write RAW or WAV
	; ---------------------------
	move.b	#'r',name_outputfile+10
	move.b	#'w',name_outputfile+12
	cmp.b	#BUFFER_WAV,buffer_mode
	bne.s	.raw
	; Convert buffer to unsigned
	; --------------------------
	move.l	buffer_render,a0
	move.l	buffer_render_size,d7
	subq	#1,d7
.conv:	add.b	#$80,(a0)+
	dbra	d7,.conv
	move.b	#'w',name_outputfile+10
	move.b	#'v',name_outputfile+12
.raw:
	; Write buffer to disk
	; --------------------
	move.l	base_dos,a6
	move.l	#name_outputfile,d1
	move.l	#MODE_NEWFILE,d2
	jsr	_LVOOpen(a6)
	move.l	d0,a2

	cmp.b	#BUFFER_WAV,buffer_mode
	bne.s	.hdrok
	move.l	d0,d1
	move.l	#header_wav,d2
	move.l	#header_wav_end-header_wav,d3
	jsr	_LVOWrite(a6)
	
.hdrok:	move.l	a2,d1
	move.l	buffer_render,d2
	move.l	buffer_render_size,d3
	jsr	_LVOWrite(a6)

	move.l	a2,d1
	jsr	_LVOClose(a6)

	; Free render buffer
	; ------------------
	move.l	4.w,a6
	move.l	buffer_render,a1
	move.l	buffer_render_size,d0
	jsr	_LVOFreeMem(a6)

.rbok:	; Close dos.library
	; -----------------
	tst.l	base_dos
	beq.s	.dosok
	move.l	base_dos,a1
	jsr	_LVOCloseLibrary(a6)
					moveq	#0,d0
.dosok:	rts

sd_rt:	move.l	4.w,a6
					ifeq	BUFFER_ONLY
	move.l	io_request,d0
	beq	.iorok
	move.l	d0,a0
	tst.l	io_Device(a0)
	beq	.devok

	; Disable audio interrupts
	; ------------------------
	move.w	#AUDIO_INTERRUPTS,custom+intreq
	move.w	#AUDIO_INTERRUPTS,custom+intena

	; Stop audio DMA
	; --------------
	move.w	#DMAF_AUDIO,custom+dmacon
	clr.w	custom+aud0+ac_vol

	; Use previous audio interrupt
	; ----------------------------
	move.l	interrupt_vector_audio_0,d0
	beq.s	.av0ok
	move.l	d0,a1
	move.l	#INTB_AUD0,d0
	jsr	_LVOSetIntVector(a6)

.av0ok:	; Close audio.device
	; ------------------
	move.l	io_request,a2
	move.l	a2,a1
	jsr	_LVOCloseDevice(a6)
	clr.l	io_Device(a2)

.devok:	; Delete IO request
	; -----------------
	move.l	io_request,d0
	beq.s	.iorok
	move.l	d0,a0
	jsr	_LVODeleteIORequest(a6)

.iorok:	; Delete message port
	; -------------------
	move.l	message_port,d0
	beq.s	.msgok
	move.l	d0,a0
	jsr	_LVODeleteMsgPort(a6)

.msgok:	; Free play buffer
	; ----------------
	tst.l	buffer_play
	beq.s	.pbok
	move.l	buffer_play,a1
	move.l	buffer_play_size,d0
	add.w	d0,d0
	jsr	_LVOFreeMem(a6)
.pbok:	; Close window and screen
	; -----------------------
	move.l	base_intuition,a6
	tst.l	window
	beq	.winok
	move.l	window,a0
	jsr	_LVOCloseWindow(a6)
.winok:	tst.l	screen
	beq	.scrok
	move.l	screen,a0
	jsr	_LVOCloseScreen(a6)
.scrok:	; Close intuition.library
	; -----------------
	move.l	4.w,a6
	tst.l	base_intuition
	beq.s	.intok
	move.l	base_intuition,a1
	jsr	_LVOCloseLibrary(a6)
.intok:	; Close graphics.library
	; -----------------
	tst.l	base_graphics
	beq.s	.gfxok
	move.l	base_graphics,a1
	jsr	_LVOCloseLibrary(a6)
.gfxok:	rts

; Audio interrupt
; ---------------
interrupt_audio_0:
	movem.l	d1-d2,-(sp)

	; Clear interrupt request bits
	; ----------------------------
	and.w	#INTERRUPT_USED,d1
	move.w	d1,custom+intreq

	; Swap current buffer
	; -------------------
	move.l	buffer_play_size,d0
	eor.l	d0,buffer_play_current

	; Play current buffer
	; -------------------
	move.l	buffer_play_size,d0
	lsr.w	d0
	move.w	d0,custom+aud0+ac_len
	move.l	buffer_play,d0
	add.l	buffer_play_current,d0
	move.l	d0,custom+aud0+ac_ptr
	move.w	#64,custom+aud0+ac_vol

	; Allow rendering of more data
	; ----------------------------
	clr.b	render_hold
	
	movem.l	(sp)+,d1-d2
	rts

callback_quit:
	move.b	#1,quit
	rts

refresh_oscillator_gadgets:
	move.l	base_intuition,a6
	lea	gadget_oscillator_1,a0
	move.l	window,a1
	sub.l	a2,a2
	moveq	#8,d0
	jsr	_LVORefreshGList(a6)

	lea	gadget_oscillator_1,a3
.loop:	move.l	window,a0
	move.l	a3,a1
	jsr	_LVORemoveGadget(a6)
	
	cmp.l	d2,a3
	beq.s	.set
	cmp.l	d3,a3
	beq.s	.set
	clr.w	gg_Flags(a3)
	bra.s	.add
.set:	move.w	#GFLG_SELECTED,gg_Flags(a3)
.add:	
	move.l	window,a0
	move.l	a3,a1
	jsr	_LVOAddGadget(a6)
	
	move.l	gg_NextGadget(a3),a3
	cmp.l	#gadget_oscillator_13_fm,a3
	bne.s	.loop
	
	lea	gadget_oscillator_1,a0
	move.l	window,a1
	moveq	#8,d0
	jsr	_LVORefreshGList(a6)

	lea	gadget_oscillator_mix,a0
	move.l	window,a1
	moveq	#20,d0
	jsr	_LVORefreshGList(a6)
	rts

activate_oscillator_gadgets:
	move.l	base_intuition,a6
	sub.l	a2,a2
	lea	gadget_oscillator_pitch,a3
.loop:	move.l	a3,a0
	move.l	window,a1
	jsr	_LVOOnGadget(a6)
	move.l	gg_NextGadget(a3),a3
	cmp.l	#0,a3
	bne.s	.loop

	lea	gadget_square,a0
	move.l	window,a1
	jsr	_LVOOnGadget(a6)

	lea	gadget_saw,a0
	move.l	window,a1
	jsr	_LVOOnGadget(a6)

	move.w	#1,oscillator_gadgets_active
	rts

deactivate_oscillator_gadgets:
	move.l	base_intuition,a6
	sub.l	a2,a2
	lea	gadget_oscillator_pitch,a3
.loop:	move.l	a3,a0
	move.l	window,a1
	jsr	_LVOOffGadget(a6)
	move.l	gg_NextGadget(a3),a3
	cmp.l	#0,a3
	bne.s	.loop

	lea	gadget_square,a0
	move.l	window,a1
	jsr	_LVOOffGadget(a6)

	lea	gadget_saw,a0
	move.l	window,a1
	jsr	_LVOOffGadget(a6)

	clr.w	oscillator_gadgets_active
	rts

callback_oscillator_1:
	move.l	#oscillator_1_mix,gadget_oscillator_mix+gg_UserData
	move.l	#oscillator_1_mix_lfo_1,gadget_oscillator_mix_lfo_1+gg_UserData
	move.l	#oscillator_1_mix_lfo_2,gadget_oscillator_mix_lfo_2+gg_UserData
	move.l	#oscillator_1_mix_env_2,gadget_oscillator_mix_env_2+gg_UserData
	move.l	#oscillator_1_mix_env_3,gadget_oscillator_mix_env_3+gg_UserData
	move.l	#oscillator_1_pitch,gadget_oscillator_pitch+gg_UserData
	move.l	#oscillator_1_pitch_lfo_1,gadget_oscillator_pitch_lfo_1+gg_UserData
	move.l	#oscillator_1_pitch_lfo_2,gadget_oscillator_pitch_lfo_2+gg_UserData
	move.l	#oscillator_1_pitch_env_2,gadget_oscillator_pitch_env_2+gg_UserData
	move.l	#oscillator_1_pitch_env_3,gadget_oscillator_pitch_env_3+gg_UserData
	move.l	#oscillator_1_width,gadget_oscillator_width+gg_UserData
	move.l	#oscillator_1_width_lfo_1,gadget_oscillator_width_lfo_1+gg_UserData
	move.l	#oscillator_1_width_lfo_2,gadget_oscillator_width_lfo_2+gg_UserData
	move.l	#oscillator_1_width_env_2,gadget_oscillator_width_env_2+gg_UserData
	move.l	#oscillator_1_width_env_3,gadget_oscillator_width_env_3+gg_UserData
	move.l	#oscillator_1_sync,gadget_oscillator_sync+gg_UserData
	move.l	#oscillator_1_sync_lfo_1,gadget_oscillator_sync_lfo_1+gg_UserData
	move.l	#oscillator_1_sync_lfo_2,gadget_oscillator_sync_lfo_2+gg_UserData
	move.l	#oscillator_1_sync_env_2,gadget_oscillator_sync_env_2+gg_UserData
	move.l	#oscillator_1_sync_env_3,gadget_oscillator_sync_env_3+gg_UserData
	move.l	#oscillator_1_waveform,oscillator_waveform
	move.w	#WAVEFORM_SQUARE_1,oscillator_square

	move.w	oscillator_1_mix,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix+pi_VertPot
	move.w	oscillator_1_mix_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_1+pi_VertPot
	move.w	oscillator_1_mix_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_2+pi_VertPot
	move.w	oscillator_1_mix_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_2+pi_VertPot
	move.w	oscillator_1_mix_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_3+pi_VertPot
	move.w	oscillator_1_pitch,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch+pi_VertPot
	move.w	oscillator_1_pitch_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_lfo_1+pi_VertPot
	move.w	oscillator_1_pitch_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_lfo_2+pi_VertPot
	move.w	oscillator_1_pitch_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_env_2+pi_VertPot
	move.w	oscillator_1_pitch_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_env_3+pi_VertPot
	move.w	oscillator_1_width,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_width+pi_VertPot
	move.w	oscillator_1_width_lfo_1,d0
	lsl.w	#5,d0
	move.w	d0,propinfo_oscillator_width_lfo_1+pi_VertPot
	move.w	oscillator_1_width_lfo_2,d0
	lsl.w	#5,d0
	move.w	d0,propinfo_oscillator_width_lfo_2+pi_VertPot
	move.w	oscillator_1_width_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_width_env_2+pi_VertPot
	move.w	oscillator_1_width_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_width_env_3+pi_VertPot
	move.w	oscillator_1_sync,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync+pi_VertPot
	move.w	oscillator_1_sync_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_lfo_1+pi_VertPot
	move.w	oscillator_1_sync_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_lfo_2+pi_VertPot
	move.w	oscillator_1_sync_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_env_2+pi_VertPot
	move.w	oscillator_1_sync_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_env_3+pi_VertPot

	cmp.w	#WAVEFORM_SAW,oscillator_1_waveform
	beq.s	.saw
	move.l	#gadget_square,d2
	bra.s	.wavok
.saw:	move.l	#gadget_saw,d2
.wavok:	move.l	#gadget_oscillator_1,d3

	bsr	refresh_oscillator_gadgets
	
	tst.w	oscillator_gadgets_active
	bne.s	.done
	bsr	activate_oscillator_gadgets
.done:	rts

callback_oscillator_2:
	move.l	#oscillator_2_mix,gadget_oscillator_mix+gg_UserData
	move.l	#oscillator_2_mix_lfo_1,gadget_oscillator_mix_lfo_1+gg_UserData
	move.l	#oscillator_2_mix_lfo_2,gadget_oscillator_mix_lfo_2+gg_UserData
	move.l	#oscillator_2_mix_env_2,gadget_oscillator_mix_env_2+gg_UserData
	move.l	#oscillator_2_mix_env_3,gadget_oscillator_mix_env_3+gg_UserData
	move.l	#oscillator_2_pitch,gadget_oscillator_pitch+gg_UserData
	move.l	#oscillator_2_pitch_lfo_1,gadget_oscillator_pitch_lfo_1+gg_UserData
	move.l	#oscillator_2_pitch_lfo_2,gadget_oscillator_pitch_lfo_2+gg_UserData
	move.l	#oscillator_2_pitch_env_2,gadget_oscillator_pitch_env_2+gg_UserData
	move.l	#oscillator_2_pitch_env_3,gadget_oscillator_pitch_env_3+gg_UserData
	move.l	#oscillator_2_width,gadget_oscillator_width+gg_UserData
	move.l	#oscillator_2_width_lfo_1,gadget_oscillator_width_lfo_1+gg_UserData
	move.l	#oscillator_2_width_lfo_2,gadget_oscillator_width_lfo_2+gg_UserData
	move.l	#oscillator_2_width_env_2,gadget_oscillator_width_env_2+gg_UserData
	move.l	#oscillator_2_width_env_3,gadget_oscillator_width_env_3+gg_UserData
	move.l	#oscillator_2_sync,gadget_oscillator_sync+gg_UserData
	move.l	#oscillator_2_sync_lfo_1,gadget_oscillator_sync_lfo_1+gg_UserData
	move.l	#oscillator_2_sync_lfo_2,gadget_oscillator_sync_lfo_2+gg_UserData
	move.l	#oscillator_2_sync_env_2,gadget_oscillator_sync_env_2+gg_UserData
	move.l	#oscillator_2_sync_env_3,gadget_oscillator_sync_env_3+gg_UserData
	move.l	#oscillator_2_waveform,oscillator_waveform
	move.w	#WAVEFORM_SQUARE_2,oscillator_square

	move.w	oscillator_2_mix,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix+pi_VertPot
	move.w	oscillator_2_mix_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_1+pi_VertPot
	move.w	oscillator_2_mix_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_2+pi_VertPot
	move.w	oscillator_2_mix_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_2+pi_VertPot
	move.w	oscillator_2_mix_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_3+pi_VertPot
	move.w	oscillator_2_pitch,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch+pi_VertPot
	move.w	oscillator_2_pitch_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_lfo_1+pi_VertPot
	move.w	oscillator_2_pitch_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_lfo_2+pi_VertPot
	move.w	oscillator_2_pitch_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_env_2+pi_VertPot
	move.w	oscillator_2_pitch_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_env_3+pi_VertPot
	move.w	oscillator_2_width,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_width+pi_VertPot
	move.w	oscillator_2_width_lfo_1,d0
	lsl.w	#5,d0
	move.w	d0,propinfo_oscillator_width_lfo_1+pi_VertPot
	move.w	oscillator_2_width_lfo_2,d0
	lsl.w	#5,d0
	move.w	d0,propinfo_oscillator_width_lfo_2+pi_VertPot
	move.w	oscillator_2_width_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_width_env_2+pi_VertPot
	move.w	oscillator_2_width_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_width_env_3+pi_VertPot
	move.w	oscillator_2_sync,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync+pi_VertPot
	move.w	oscillator_2_sync_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_lfo_1+pi_VertPot
	move.w	oscillator_2_sync_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_lfo_2+pi_VertPot
	move.w	oscillator_2_sync_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_env_2+pi_VertPot
	move.w	oscillator_2_sync_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_env_3+pi_VertPot

	cmp.w	#WAVEFORM_SAW,oscillator_2_waveform
	beq.s	.saw
	move.l	#gadget_square,d2
	bra.s	.wavok
.saw:	move.l	#gadget_saw,d2
.wavok:	move.l	#gadget_oscillator_2,d3

	bsr	refresh_oscillator_gadgets
	
	tst.w	oscillator_gadgets_active
	bne.s	.done
	bsr	activate_oscillator_gadgets
.done:	rts

callback_oscillator_3:
	move.l	#oscillator_3_mix,gadget_oscillator_mix+gg_UserData
	move.l	#oscillator_3_mix_lfo_1,gadget_oscillator_mix_lfo_1+gg_UserData
	move.l	#oscillator_3_mix_lfo_2,gadget_oscillator_mix_lfo_2+gg_UserData
	move.l	#oscillator_3_mix_env_2,gadget_oscillator_mix_env_2+gg_UserData
	move.l	#oscillator_3_mix_env_3,gadget_oscillator_mix_env_3+gg_UserData
	move.l	#oscillator_3_pitch,gadget_oscillator_pitch+gg_UserData
	move.l	#oscillator_3_pitch_lfo_1,gadget_oscillator_pitch_lfo_1+gg_UserData
	move.l	#oscillator_3_pitch_lfo_2,gadget_oscillator_pitch_lfo_2+gg_UserData
	move.l	#oscillator_3_pitch_env_2,gadget_oscillator_pitch_env_2+gg_UserData
	move.l	#oscillator_3_pitch_env_3,gadget_oscillator_pitch_env_3+gg_UserData
	move.l	#oscillator_3_width,gadget_oscillator_width+gg_UserData
	move.l	#oscillator_3_width_lfo_1,gadget_oscillator_width_lfo_1+gg_UserData
	move.l	#oscillator_3_width_lfo_2,gadget_oscillator_width_lfo_2+gg_UserData
	move.l	#oscillator_3_width_env_2,gadget_oscillator_width_env_2+gg_UserData
	move.l	#oscillator_3_width_env_3,gadget_oscillator_width_env_3+gg_UserData
	move.l	#oscillator_3_sync,gadget_oscillator_sync+gg_UserData
	move.l	#oscillator_3_sync_lfo_1,gadget_oscillator_sync_lfo_1+gg_UserData
	move.l	#oscillator_3_sync_lfo_2,gadget_oscillator_sync_lfo_2+gg_UserData
	move.l	#oscillator_3_sync_env_2,gadget_oscillator_sync_env_2+gg_UserData
	move.l	#oscillator_3_sync_env_3,gadget_oscillator_sync_env_3+gg_UserData
	move.l	#oscillator_3_waveform,oscillator_waveform
	move.w	#WAVEFORM_SQUARE_3,oscillator_square

	move.w	oscillator_3_mix,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix+pi_VertPot
	move.w	oscillator_3_mix_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_1+pi_VertPot
	move.w	oscillator_3_mix_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_2+pi_VertPot
	move.w	oscillator_3_mix_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_2+pi_VertPot
	move.w	oscillator_3_mix_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_3+pi_VertPot
	move.w	oscillator_3_pitch,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch+pi_VertPot
	move.w	oscillator_3_pitch_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_lfo_1+pi_VertPot
	move.w	oscillator_3_pitch_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_lfo_2+pi_VertPot
	move.w	oscillator_3_pitch_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_env_2+pi_VertPot
	move.w	oscillator_3_pitch_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_pitch_env_3+pi_VertPot
	move.w	oscillator_3_width,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_width+pi_VertPot
	move.w	oscillator_3_width_lfo_1,d0
	lsl.w	#5,d0
	move.w	d0,propinfo_oscillator_width_lfo_1+pi_VertPot
	move.w	oscillator_3_width_lfo_2,d0
	lsl.w	#5,d0
	move.w	d0,propinfo_oscillator_width_lfo_2+pi_VertPot
	move.w	oscillator_3_width_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_width_env_2+pi_VertPot
	move.w	oscillator_3_width_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_width_env_3+pi_VertPot
	move.w	oscillator_3_sync,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync+pi_VertPot
	move.w	oscillator_3_sync_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_lfo_1+pi_VertPot
	move.w	oscillator_3_sync_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_lfo_2+pi_VertPot
	move.w	oscillator_3_sync_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_env_2+pi_VertPot
	move.w	oscillator_3_sync_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_sync_env_3+pi_VertPot

	cmp.w	#WAVEFORM_SAW,oscillator_3_waveform
	beq.s	.saw
	move.l	#gadget_square,d2
	bra.s	.wavok
.saw:	move.l	#gadget_saw,d2
.wavok:	move.l	#gadget_oscillator_3,d3

	bsr	refresh_oscillator_gadgets
	
	tst.w	oscillator_gadgets_active
	bne.s	.done
	bsr	activate_oscillator_gadgets
.done:	rts

callback_oscillator_13:
	move.l	#oscillator_13_mix,gadget_oscillator_mix+gg_UserData
	move.l	#oscillator_13_mix_lfo_1,gadget_oscillator_mix_lfo_1+gg_UserData
	move.l	#oscillator_13_mix_lfo_2,gadget_oscillator_mix_lfo_2+gg_UserData
	move.l	#oscillator_13_mix_env_2,gadget_oscillator_mix_env_2+gg_UserData
	move.l	#oscillator_13_mix_env_3,gadget_oscillator_mix_env_3+gg_UserData

	move.w	oscillator_13_mix,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix+pi_VertPot
	move.w	oscillator_13_mix_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_1+pi_VertPot
	move.w	oscillator_13_mix_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_2+pi_VertPot
	move.w	oscillator_13_mix_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_2+pi_VertPot
	move.w	oscillator_13_mix_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_3+pi_VertPot

	moveq	#0,d2
	move.l	#gadget_oscillator_13,d3
	bsr	refresh_oscillator_gadgets
	
	tst.w	oscillator_gadgets_active
	beq.s	.done
	bsr	deactivate_oscillator_gadgets
.done:	rts

callback_oscillator_23:
	move.l	#oscillator_23_mix,gadget_oscillator_mix+gg_UserData
	move.l	#oscillator_23_mix_lfo_1,gadget_oscillator_mix_lfo_1+gg_UserData
	move.l	#oscillator_23_mix_lfo_2,gadget_oscillator_mix_lfo_2+gg_UserData
	move.l	#oscillator_23_mix_env_2,gadget_oscillator_mix_env_2+gg_UserData
	move.l	#oscillator_23_mix_env_3,gadget_oscillator_mix_env_3+gg_UserData

	move.w	oscillator_23_mix,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix+pi_VertPot
	move.w	oscillator_23_mix_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_1+pi_VertPot
	move.w	oscillator_23_mix_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_2+pi_VertPot
	move.w	oscillator_23_mix_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_2+pi_VertPot
	move.w	oscillator_23_mix_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_3+pi_VertPot

	moveq	#0,d2
	move.l	#gadget_oscillator_23,d3
	bsr	refresh_oscillator_gadgets
	
	tst.w	oscillator_gadgets_active
	beq.s	.done
	bsr	deactivate_oscillator_gadgets
.done:	rts

callback_oscillator_noise:
	move.l	#oscillator_noise_mix,gadget_oscillator_mix+gg_UserData
	move.l	#oscillator_noise_mix_lfo_1,gadget_oscillator_mix_lfo_1+gg_UserData
	move.l	#oscillator_noise_mix_lfo_2,gadget_oscillator_mix_lfo_2+gg_UserData
	move.l	#oscillator_noise_mix_env_2,gadget_oscillator_mix_env_2+gg_UserData
	move.l	#oscillator_noise_mix_env_3,gadget_oscillator_mix_env_3+gg_UserData

	move.w	oscillator_noise_mix,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix+pi_VertPot
	move.w	oscillator_noise_mix_lfo_1,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_1+pi_VertPot
	move.w	oscillator_noise_mix_lfo_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_lfo_2+pi_VertPot
	move.w	oscillator_noise_mix_env_2,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_2+pi_VertPot
	move.w	oscillator_noise_mix_env_3,d0
	lsl.w	#4,d0
	move.w	d0,propinfo_oscillator_mix_env_3+pi_VertPot

	moveq	#0,d2
	move.l	#gadget_oscillator_noise,d3
	bsr	refresh_oscillator_gadgets
	
	tst.w	oscillator_gadgets_active
	beq.s	.done
	bsr	deactivate_oscillator_gadgets
.done:	rts

callback_square:
	move.l	oscillator_waveform,a0
	move.w	oscillator_square,(a0)

	move.l	base_intuition,a6
	lea	gadget_square,a0
	move.l	window,a1
	sub.l	a2,a2
	moveq	#2,d0
	jsr	_LVORefreshGList(a6)

	move.l	window,a0
	lea	gadget_square,a1
	jsr	_LVORemoveGadget(a6)

	move.w	#GFLG_SELECTED,gadget_square+gg_Flags

	move.l	window,a0
	lea	gadget_square,a1
	jsr	_LVOAddGadget(a6)

	move.l	window,a0
	lea	gadget_saw,a1
	jsr	_LVORemoveGadget(a6)

	clr.w	gadget_saw+gg_Flags

	move.l	window,a0
	lea	gadget_saw,a1
	jsr	_LVOAddGadget(a6)
	
	lea	gadget_square,a0
	move.l	window,a1
	moveq	#2,d0
	jsr	_LVORefreshGList(a6)
	rts

callback_saw:
	move.l	oscillator_waveform,a0
	move.w	#WAVEFORM_SAW,(a0)

	move.l	base_intuition,a6
	lea	gadget_square,a0
	move.l	window,a1
	sub.l	a2,a2
	moveq	#2,d0
	jsr	_LVORefreshGList(a6)

	move.l	window,a0
	lea	gadget_square,a1
	jsr	_LVORemoveGadget(a6)

	clr.w	gadget_square+gg_Flags

	move.l	window,a0
	lea	gadget_square,a1
	jsr	_LVOAddGadget(a6)

	move.l	window,a0
	lea	gadget_saw,a1
	jsr	_LVORemoveGadget(a6)

	move.w	#GFLG_SELECTED,gadget_saw+gg_Flags

	move.l	window,a0
	lea	gadget_saw,a1
	jsr	_LVOAddGadget(a6)
	
	lea	gadget_square,a0
	move.l	window,a1
	moveq	#2,d0
	jsr	_LVORefreshGList(a6)
	rts

callback_oscillator_13_fm:
	move.l	base_intuition,a6
	lea	gadget_oscillator_13_fm,a0
	move.l	window,a1
	sub.l	a2,a2
	moveq	#1,d0
	jsr	_LVORefreshGList(a6)

	move.l	window,a0
	lea	gadget_oscillator_13_fm,a1
	jsr	_LVORemoveGadget(a6)

	move.l	window,a0
	lea	gadget_oscillator_13_fm,a1
	eor.w	#1,oscillator_13_fm
	bne.s	.set
	clr.w	gg_Flags(a1)
	bra.s	.do
.set:	move.w	#GFLG_SELECTED,gg_Flags(a1)
.do:	jsr	_LVOAddGadget(a6)

	lea	gadget_oscillator_13_fm,a0
	move.l	window,a1
	moveq	#1,d0
	jsr	_LVORefreshGList(a6)
	rts

callback_oscillator_23_fm:
	move.l	base_intuition,a6
	lea	gadget_oscillator_23_fm,a0
	move.l	window,a1
	sub.l	a2,a2
	moveq	#1,d0
	jsr	_LVORefreshGList(a6)

	move.l	window,a0
	lea	gadget_oscillator_23_fm,a1
	jsr	_LVORemoveGadget(a6)

	move.l	window,a0
	lea	gadget_oscillator_23_fm,a1
	eor.w	#1,oscillator_23_fm
	bne.s	.set
	clr.w	gg_Flags(a1)
	bra.s	.do
.set:	move.w	#GFLG_SELECTED,gg_Flags(a1)
.do:	jsr	_LVOAddGadget(a6)

	lea	gadget_oscillator_23_fm,a0
	move.l	window,a1
	moveq	#1,d0
	jsr	_LVORefreshGList(a6)
	rts

refresh_lfo_gadgets:
	move.l	base_intuition,a6
	move.l	a3,a0
	move.l	window,a1
	sub.l	a2,a2
	moveq	#3,d0
	jsr	_LVORefreshGList(a6)

	move.l	a3,a4
	moveq	#3-1,d3
.loop:	move.l	window,a0
	move.l	a3,a1
	jsr	_LVORemoveGadget(a6)
	
	cmp.l	d2,a3
	beq.s	.set
	clr.w	gg_Flags(a3)
	bra.s	.add
.set:	move.w	#GFLG_SELECTED,gg_Flags(a3)
.add:	
	move.l	window,a0
	move.l	a3,a1
	jsr	_LVOAddGadget(a6)
	
	move.l	gg_NextGadget(a3),a3
	dbra	d3,.loop
	
	move.l	a4,a0
	move.l	window,a1
	moveq	#3,d0
	jsr	_LVORefreshGList(a6)
	rts

callback_lfo_1_waveform_square:
	move.w	#WAVEFORM_LFO_SQUARE,lfo_1_waveform
	lea	gadget_lfo_1_waveform_square,a3
	move.l	#gadget_lfo_1_waveform_square,d2
	bsr	refresh_lfo_gadgets
	rts

callback_lfo_1_waveform_saw:
	move.w	#WAVEFORM_LFO_SAW,lfo_1_waveform
	lea	gadget_lfo_1_waveform_square,a3
	move.l	#gadget_lfo_1_waveform_saw,d2
	bsr	refresh_lfo_gadgets
	rts

callback_lfo_1_waveform_triangle:
	move.w	#WAVEFORM_LFO_TRIANGLE,lfo_1_waveform
	lea	gadget_lfo_1_waveform_square,a3
	move.l	#gadget_lfo_1_waveform_triangle,d2
	bsr	refresh_lfo_gadgets
	rts

callback_lfo_2_waveform_square:
	move.w	#WAVEFORM_LFO_SQUARE,lfo_2_waveform
	lea	gadget_lfo_2_waveform_square,a3
	move.l	#gadget_lfo_2_waveform_square,d2
	bsr	refresh_lfo_gadgets
	rts

callback_lfo_2_waveform_saw:
	move.w	#WAVEFORM_LFO_SAW,lfo_2_waveform
	lea	gadget_lfo_2_waveform_square,a3
	move.l	#gadget_lfo_2_waveform_saw,d2
	bsr	refresh_lfo_gadgets
	rts

callback_lfo_2_waveform_triangle:
	move.w	#WAVEFORM_LFO_TRIANGLE,lfo_2_waveform
	lea	gadget_lfo_2_waveform_square,a3
	move.l	#gadget_lfo_2_waveform_triangle,d2
	bsr	refresh_lfo_gadgets
	rts

				section	fastdata,data
; System structures
; -----------------
					endc
					ifeq	BUFFER_ONLY
screen_tags:			dc.l	SA_Left,0
screen_top:			dc.l	SA_Top,0
				dc.l	SA_Width,640
				dc.l	SA_Height,480
				dc.l	SA_Depth,2
screen_id:			dc.l	SA_DisplayID,V_HIRES|V_LACE
				dc.l	SA_Overscan,OSCAN_STANDARD
				dc.l	SA_AutoScroll,0
				dc.l	SA_Quiet,1
				dc.l	SA_ShowTitle,0
				dc.l	SA_SysFont,1
				dc.l	TAG_DONE

window_tags:			dc.l	WA_Left,0
				dc.l	WA_Top,0
				dc.l	WA_Width,640
				dc.l	WA_Height,480
				dc.l	WA_DetailPen,1
				dc.l	WA_BlockPen,2
				dc.l	WA_IDCMP,IDCMP_GADGETUP|IDCMP_GADGETDOWN|IDCMP_MOUSEMOVE
				dc.l	WA_Flags,BORDERLESS|RMBTRAP
				dc.l	WA_Gadgets,gadget_oscillator_1
window_screen:			dc.l	WA_CustomScreen,0

gadget_oscillator_1:		dc.l	gadget_oscillator_2
				dc.w	80,0,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_oscillator_1,0,0
				dc.w	0
				dc.l	callback_oscillator_1

gadget_oscillator_2:		dc.l	gadget_oscillator_3
				dc.w	120,0,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_oscillator_2,0,0
				dc.w	0
				dc.l	callback_oscillator_2

gadget_oscillator_3:		dc.l	gadget_oscillator_13
				dc.w	160,0,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_oscillator_3,0,0
				dc.w	0
				dc.l	callback_oscillator_3

gadget_oscillator_13:		dc.l	gadget_oscillator_23
				dc.w	200,0,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_oscillator_13,0,0
				dc.w	0
				dc.l	callback_oscillator_13

gadget_oscillator_23:		dc.l	gadget_oscillator_noise
				dc.w	240,0,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_oscillator_23,0,0
				dc.w	0
				dc.l	callback_oscillator_23

gadget_oscillator_noise:	dc.l	gadget_square
				dc.w	280,0,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
 				dc.l	border_boolean,0,intuitext_oscillator_noise,0,0
				dc.w	0
				dc.l	callback_oscillator_noise

gadget_square:			dc.l	gadget_saw
				dc.w	80,16,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_square,0,0
				dc.w	0
				dc.l	callback_square

gadget_saw:			dc.l	gadget_oscillator_13_fm
				dc.w	120,16,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_saw,0,0
				dc.w	0
				dc.l	callback_saw

gadget_oscillator_13_fm:	dc.l	gadget_oscillator_23_fm
				dc.w	200,16,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_fm,0,0
				dc.w	0
				dc.l	callback_oscillator_13_fm

gadget_oscillator_23_fm:	dc.l	gadget_lfo_1_waveform_square
				dc.w	240,16,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_fm,0,0
				dc.w	0
				dc.l	callback_oscillator_23_fm

gadget_lfo_1_waveform_square:	dc.l	gadget_lfo_1_waveform_saw
				dc.w	560,0,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_square,0,0
				dc.w	0
				dc.l	callback_lfo_1_waveform_square

gadget_lfo_1_waveform_saw:	dc.l	gadget_lfo_1_waveform_triangle
				dc.w	560,16,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_saw,0,0
				dc.w	0
				dc.l	callback_lfo_1_waveform_saw

gadget_lfo_1_waveform_triangle:	dc.l	gadget_lfo_2_waveform_square
				dc.w	560,32,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_triangle,0,0
				dc.w	0
				dc.l	callback_lfo_1_waveform_triangle

gadget_lfo_2_waveform_square:	dc.l	gadget_lfo_2_waveform_saw
				dc.w	600,0,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_square,0,0
				dc.w	0
				dc.l	callback_lfo_2_waveform_square

gadget_lfo_2_waveform_saw:	dc.l	gadget_lfo_2_waveform_triangle
				dc.w	600,16,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_saw,0,0
				dc.w	0
				dc.l	callback_lfo_2_waveform_saw

gadget_lfo_2_waveform_triangle:	dc.l	gadget_power
				dc.w	600,32,38,14
				dc.w	0
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_triangle,0,0
				dc.w	0
				dc.l	callback_lfo_2_waveform_triangle

gadget_power:			dc.l	gadget_filter_frequency
				dc.w	0,16,38,14
				dc.w	GFLG_SELECTED
				dc.w	GACT_RELVERIFY
				dc.w	GTYP_BOOLGADGET
				dc.l	border_boolean,0,intuitext_power,0,0
				dc.w	0
				dc.l	callback_quit

gadget_filter_frequency:	dc.l	gadget_filter_frequency_lfo_1
				dc.w	330,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_filter_frequency,0,propinfo_filter_frequency
				dc.w	4
				dc.l	filter_frequency

gadget_filter_frequency_lfo_1:	dc.l	gadget_filter_frequency_lfo_2
				dc.w	341,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l1,0,propinfo_filter_frequency_lfo_1
				dc.w	4
				dc.l	filter_frequency_lfo_1

gadget_filter_frequency_lfo_2:	dc.l	gadget_filter_frequency_env_2
				dc.w	352,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l2,0,propinfo_filter_frequency_lfo_2
				dc.w	4
				dc.l	filter_frequency_lfo_2

gadget_filter_frequency_env_2:	dc.l	gadget_filter_frequency_env_3
				dc.w	363,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e2,0,propinfo_filter_frequency_env_2
				dc.w	4
				dc.l	filter_frequency_env_2

gadget_filter_frequency_env_3:	dc.l	gadget_filter_resonance
				dc.w	374,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e3,0,propinfo_filter_frequency_env_3
				dc.w	4
				dc.l	filter_frequency_env_3

gadget_filter_resonance:	dc.l	gadget_filter_resonance_lfo_1
				dc.w	390,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_filter_resonance,0,propinfo_filter_resonance
				dc.w	4
				dc.l	filter_resonance

gadget_filter_resonance_lfo_1:	dc.l	gadget_filter_resonance_lfo_2
				dc.w	401,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l1,0,propinfo_filter_resonance_lfo_1
				dc.w	4
				dc.l	filter_resonance_lfo_1

gadget_filter_resonance_lfo_2:	dc.l	gadget_filter_resonance_env_2
				dc.w	412,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l2,0,propinfo_filter_resonance_lfo_2
				dc.w	4
				dc.l	filter_resonance_lfo_2

gadget_filter_resonance_env_2:	dc.l	gadget_filter_resonance_env_3
				dc.w	423,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e2,0,propinfo_filter_resonance_env_2
				dc.w	4
				dc.l	filter_resonance_env_2

gadget_filter_resonance_env_3:	dc.l	gadget_envelope_1_attack
				dc.w	434,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e3,0,propinfo_filter_resonance_env_3
				dc.w	4
				dc.l	filter_resonance_env_3

gadget_envelope_1_attack:	dc.l	gadget_envelope_1_decay
				dc.w	460,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_envelope_1,0,propinfo_envelope_1_attack
				dc.w	4
				dc.l	envelope_1_attack

gadget_envelope_1_decay:	dc.l	gadget_envelope_1_sustain
				dc.w	471,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_envelope_decay,0,propinfo_envelope_1_decay
				dc.w	4
				dc.l	envelope_1_decay

gadget_envelope_1_sustain:	dc.l	gadget_envelope_2_attack
				dc.w	482,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_envelope_sustain,0,propinfo_envelope_1_sustain
				dc.w	4
				dc.l	envelope_1_sustain

gadget_envelope_2_attack:	dc.l	gadget_envelope_2_decay
				dc.w	500,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_envelope_2,0,propinfo_envelope_2_attack
				dc.w	4
				dc.l	envelope_2_attack

gadget_envelope_2_decay:	dc.l	gadget_envelope_2_sustain
				dc.w	511,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_envelope_decay,0,propinfo_envelope_2_decay
				dc.w	4
				dc.l	envelope_2_decay

gadget_envelope_2_sustain:	dc.l	gadget_envelope_3_attack
				dc.w	522,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_envelope_sustain,0,propinfo_envelope_2_sustain
				dc.w	4
				dc.l	envelope_2_sustain

gadget_envelope_3_attack:	dc.l	gadget_envelope_3_decay
				dc.w	540,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_envelope_3,0,propinfo_envelope_3_attack
				dc.w	4
				dc.l	envelope_3_attack

gadget_envelope_3_decay:	dc.l	gadget_envelope_3_sustain
				dc.w	551,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_envelope_decay,0,propinfo_envelope_3_decay
				dc.w	4
				dc.l	envelope_3_decay

gadget_envelope_3_sustain:	dc.l	gadget_lfo_1_speed
				dc.w	562,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_envelope_sustain,0,propinfo_envelope_3_sustain
				dc.w	4
				dc.l	envelope_3_sustain

gadget_lfo_1_speed:		dc.l	gadget_lfo_2_speed
				dc.w	590,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_lfo_1,0,propinfo_lfo_1_speed
				dc.w	3
				dc.l	lfo_1_speed

gadget_lfo_2_speed:		dc.l	gadget_oscillator_mix
				dc.w	620,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_lfo_2,0,propinfo_lfo_2_speed
				dc.w	3
				dc.l	lfo_2_speed

gadget_oscillator_mix:		dc.l	gadget_oscillator_mix_lfo_1
				dc.w	80,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_oscillator_mix,0,propinfo_oscillator_mix
				dc.w	4
				dc.l	oscillator_1_mix

gadget_oscillator_mix_lfo_1:	dc.l	gadget_oscillator_mix_lfo_2
				dc.w	91,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l1,0,propinfo_oscillator_mix_lfo_1
				dc.w	4
				dc.l	oscillator_1_mix_lfo_1

gadget_oscillator_mix_lfo_2:	dc.l	gadget_oscillator_mix_env_2
				dc.w	102,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l2,0,propinfo_oscillator_mix_lfo_2
				dc.w	4
				dc.l	oscillator_1_mix_lfo_2

gadget_oscillator_mix_env_2:	dc.l	gadget_oscillator_mix_env_3
				dc.w	113,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e2,0,propinfo_oscillator_mix_env_2
				dc.w	4
				dc.l	oscillator_1_mix_env_2

gadget_oscillator_mix_env_3:	dc.l	gadget_oscillator_pitch
				dc.w	124,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e3,0,propinfo_oscillator_mix_env_3
				dc.w	4
				dc.l	oscillator_1_mix_env_3

gadget_oscillator_pitch:	dc.l	gadget_oscillator_pitch_lfo_1
				dc.w	140,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_oscillator_pitch,0,propinfo_oscillator_pitch
				dc.w	4
				dc.l	oscillator_1_pitch

gadget_oscillator_pitch_lfo_1:	dc.l	gadget_oscillator_pitch_lfo_2
				dc.w	151,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l1,0,propinfo_oscillator_pitch_lfo_1
				dc.w	4
				dc.l	oscillator_1_pitch_lfo_1

gadget_oscillator_pitch_lfo_2:	dc.l	gadget_oscillator_pitch_env_2
				dc.w	162,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l2,0,propinfo_oscillator_pitch_lfo_2
				dc.w	4
				dc.l	oscillator_1_pitch_lfo_2

gadget_oscillator_pitch_env_2:	dc.l	gadget_oscillator_pitch_env_3
				dc.w	173,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e2,0,propinfo_oscillator_pitch_env_2
				dc.w	4
				dc.l	oscillator_1_pitch_env_2

gadget_oscillator_pitch_env_3:	dc.l	gadget_oscillator_width
				dc.w	184,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e3,0,propinfo_oscillator_pitch_env_3
				dc.w	4
				dc.l	oscillator_1_pitch_env_3

gadget_oscillator_width:	dc.l	gadget_oscillator_width_lfo_1
				dc.w	200,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_oscillator_width,0,propinfo_oscillator_width
				dc.w	4
				dc.l	oscillator_1_width

gadget_oscillator_width_lfo_1:	dc.l	gadget_oscillator_width_lfo_2
				dc.w	211,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l1,0,propinfo_oscillator_width_lfo_1
				dc.w	5
				dc.l	oscillator_1_width_lfo_1

gadget_oscillator_width_lfo_2:	dc.l	gadget_oscillator_width_env_2
				dc.w	222,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l2,0,propinfo_oscillator_width_lfo_2
				dc.w	5
				dc.l	oscillator_1_width_lfo_2

gadget_oscillator_width_env_2:	dc.l	gadget_oscillator_width_env_3
				dc.w	233,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e2,0,propinfo_oscillator_width_env_2
				dc.w	4
				dc.l	oscillator_1_width_env_2

gadget_oscillator_width_env_3:	dc.l	gadget_oscillator_sync
				dc.w	244,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e3,0,propinfo_oscillator_width_env_3
				dc.w	4
				dc.l	oscillator_1_width_env_3

gadget_oscillator_sync:		dc.l	gadget_oscillator_sync_lfo_1
				dc.w	260,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_oscillator_sync,0,propinfo_oscillator_sync
				dc.w	4
				dc.l	oscillator_1_sync

gadget_oscillator_sync_lfo_1:	dc.l	gadget_oscillator_sync_lfo_2
				dc.w	271,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l1,0,propinfo_oscillator_sync_lfo_1
				dc.w	4
				dc.l	oscillator_1_sync_lfo_1

gadget_oscillator_sync_lfo_2:	dc.l	gadget_oscillator_sync_env_2
				dc.w	282,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_l2,0,propinfo_oscillator_sync_lfo_2
				dc.w	4
				dc.l	oscillator_1_sync_lfo_2

gadget_oscillator_sync_env_2:	dc.l	gadget_oscillator_sync_env_3
				dc.w	293,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e2,0,propinfo_oscillator_sync_env_2
				dc.w	4
				dc.l	oscillator_1_sync_env_2

gadget_oscillator_sync_env_3:	dc.l	0
				dc.w	304,80,8,400
				dc.w	0
				dc.w	GACT_RELVERIFY|GACT_IMMEDIATE|GACT_FOLLOWMOUSE
				dc.w	GTYP_PROPGADGET
				dc.l	image_prop,0,intuitext_e3,0,propinfo_oscillator_sync_env_3
				dc.w	4
				dc.l	oscillator_1_sync_env_3

intuitext_oscillator_1:		dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_oscillator_1,0

intuitext_oscillator_2:		dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_oscillator_2,0

intuitext_oscillator_3:		dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_oscillator_3,0

intuitext_oscillator_13:	dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_oscillator_13,0

intuitext_oscillator_23:	dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_oscillator_23,0

intuitext_oscillator_noise:	dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_oscillator_noise,0

intuitext_saw:			dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_saw,0

intuitext_square:		dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_square,0

intuitext_triangle:		dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_triangle,0

intuitext_fm:			dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_fm,0

intuitext_oscillator_mix:	dc.b	2,1,0,0
				dc.w	15,-23
				dc.l	0,text_oscillator_mix,0

intuitext_oscillator_pitch:	dc.b	2,1,0,0
				dc.w	10,-23
				dc.l	0,text_oscillator_pitch,0

intuitext_oscillator_width:	dc.b	2,1,0,0
				dc.w	10,-23
				dc.l	0,text_oscillator_width,0

intuitext_oscillator_sync:	dc.b	2,1,0,0
				dc.w	12,-23
				dc.l	0,text_oscillator_sync,0

intuitext_filter_frequency:	dc.b	2,1,0,0
				dc.w	0,-23
				dc.l	0,text_filter_frequency,0

intuitext_filter_resonance:	dc.b	2,1,0,0
				dc.w	0,-23
				dc.l	0,text_filter_resonance,0

intuitext_envelope_1:		dc.b	2,1,0,0
				dc.w	0,-23
				dc.l	0,text_envelope_1,intuitext_envelope_attack

intuitext_envelope_2:		dc.b	2,1,0,0
				dc.w	0,-23
				dc.l	0,text_envelope_2,intuitext_envelope_attack

intuitext_envelope_3:		dc.b	2,1,0,0
				dc.w	0,-23
				dc.l	0,text_envelope_3,intuitext_envelope_attack

intuitext_envelope_attack:	dc.b	2,1,0,0
				dc.w	0,-12
				dc.l	0,text_envelope_attack,0

intuitext_envelope_decay:	dc.b	2,1,0,0
				dc.w	0,-12
				dc.l	0,text_envelope_decay,0

intuitext_envelope_sustain:	dc.b	2,1,0,0
				dc.w	0,-12
				dc.l	0,text_envelope_sustain,0

intuitext_lfo_1:		dc.b	2,1,0,0
				dc.w	-10,-23
				dc.l	0,text_lfo_1,intuitext_lfo_speed

intuitext_lfo_2:		dc.b	2,1,0,0
				dc.w	-10,-23
				dc.l	0,text_lfo_2,intuitext_lfo_speed

intuitext_lfo_speed:		dc.b	2,1,0,0
				dc.w	-10,-12
				dc.l	0,text_lfo_speed,0

intuitext_l1:			dc.b	2,1,0,0
				dc.w	-2,-12
				dc.l	0,text_l1,0

intuitext_l2:			dc.b	2,1,0,0
				dc.w	-2,-12
				dc.l	0,text_l2,0

intuitext_e2:			dc.b	2,1,0,0
				dc.w	-2,-12
				dc.l	0,text_e2,0

intuitext_e3:			dc.b	2,1,0,0
				dc.w	-2,-12
				dc.l	0,text_e3,0

intuitext_power:		dc.b	2,1,0,0
				dc.w	2,2
				dc.l	0,text_power,0

intuitext_jormation:		dc.b	2,1,0,0
				dc.w	0,0
				dc.l	0,text_jormation,0

border_boolean:			dc.w	0,0
				dc.b	1,2,RP_JAM2,5
				dc.l	border_boolean_coords
				dc.l	0

border_boolean_coords:		dc.w	0,0,37,0,37,13,0,13,0,0

propinfo_oscillator_mix:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_mix_lfo_1:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_mix_lfo_2:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_mix_env_2:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_mix_env_3:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_pitch:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_pitch_lfo_1:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_pitch_lfo_2:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_pitch_env_2:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_pitch_env_3:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_width:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_width_lfo_1:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_width_lfo_2:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_width_env_2:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_width_env_3:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_sync:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_sync_lfo_1:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_sync_lfo_2:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_sync_env_2:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_oscillator_sync_env_3:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_frequency:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_frequency_lfo_1:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_frequency_lfo_2:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_frequency_env_2:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_frequency_env_3:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_resonance:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_resonance_lfo_1:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_resonance_lfo_2:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_resonance_env_2:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_filter_resonance_env_3:dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_envelope_1_attack:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_envelope_1_decay:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_envelope_1_sustain:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_envelope_2_attack:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_envelope_2_decay:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_envelope_2_sustain:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_envelope_3_attack:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_envelope_3_decay:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_envelope_3_sustain:	dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_lfo_1_speed:		dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

propinfo_lfo_2_speed:		dc.w	FREEVERT|PROPNEWLOOK
				dc.w	0,0,MAXBODY,MAXBODY*8/400,0,0,0,0,0,0

image_prop:			dc.w	0,0,6,6,0
				dc.l	0
				dc.b	0,0
				dc.l	0

color_table:			dc.w	4,0
				dc.l	87<<24,101<<24,112<<24
				dc.l	0,0,0
				dc.l	255<<24,255<<24,255<<24
				dc.l	178<<24,30<<24,81<<24
				dc.l	0
				
					endc
header_wav:			dc.b	"RIFF"
				dc.l	0
				dc.b	"WAVE"
				dc.b	"fmt "
				dc.l	0
				dc.w	0,0
				dc.l	0,0
				dc.w	0,0
				dc.b	"data"
				dc.l	0
header_wav_end:

; System strings
; --------------
name_outputfile:		dc.b	"WORK:out1.wav",0
params_filename:			dc.b	"WORK:params.bin",0
					even
name_graphics:			dc.b	"graphics.library",0
name_intuition:			dc.b	"intuition.library",0
name_dos:			dc.b	"dos.library",0
name_audio:			dc.b	"audio.device",0
name_interrupt:			dc.b	"dA JoRMaS interrupt",0
text_oscillator_1:		dc.b	"Osc1",0
text_oscillator_2:		dc.b	"Osc2",0
text_oscillator_3:		dc.b	"Osc3",0
text_oscillator_13:		dc.b	"Osc1*3",0
text_oscillator_23:		dc.b	"Osc2*3",0
text_oscillator_noise:		dc.b	"Noise",0
text_saw:			dc.b	"Saw",0
text_square:			dc.b	"Square",0
text_triangle:			dc.b	"Triangle",0
text_fm:			dc.b	"FM",0
text_oscillator_mix:		dc.b	"Mix",0
text_oscillator_pitch:		dc.b	"Pitch",0
text_oscillator_width:		dc.b	"Width",0
text_oscillator_sync:		dc.b	"Sync",0
text_filter_frequency:		dc.b	"Frequency",0
text_filter_resonance:		dc.b	"Resonance",0
text_envelope_1:		dc.b	"Env 1",0
text_envelope_2:		dc.b	"Env 2",0
text_envelope_3:		dc.b	"Env 3",0
text_envelope_attack:		dc.b	"A",0
text_envelope_decay:		dc.b	"D",0
text_envelope_sustain:		dc.b	"S",0
text_lfo_1:			dc.b	"LFO 1",0
text_lfo_2:			dc.b	"LFO 2",0
text_lfo_speed:			dc.b	"Speed",0
text_l1:			dc.b	"L1",0
text_l2:			dc.b	"L2",0
text_e2:			dc.b	"E2",0
text_e3:			dc.b	"E3",0
text_power:			dc.b	"Power",0
text_jormation:			dc.b	"Jormation",0
				even

sinus:				include	"sinus-1024-7fff.i"

;buffer_render_size:		dc.l	$400
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SQUARE_1
;oscillator_1_mix:		dc.w	0
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	44		; 44, 88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	$fff
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	44
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	100
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$c00
;filter_resonance:		dc.w	0
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$c0		; $c0, $300
;envelope_3_sustain:		dc.w	$60
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$7880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (A046: Dopplereffekt 2)
; ----------------------------------------------
buffer_render_size:		dc.l	12288
buffer_play_size:		dc.l	256
oscillator_1_waveform:		dc.w	WAVEFORM_SQUARE_1
oscillator_1_mix:		dc.w	0
oscillator_1_mix_lfo_1:		dc.w	0
oscillator_1_mix_lfo_2:		dc.w	0
oscillator_1_mix_env_2:		dc.w	0
oscillator_1_mix_env_3:		dc.w	0
oscillator_1_pitch:		dc.w	88
oscillator_1_pitch_lfo_1:	dc.w	0
oscillator_1_pitch_lfo_2:	dc.w	0
oscillator_1_pitch_env_2:	dc.w	0
oscillator_1_pitch_env_3:	dc.w	0
oscillator_1_width:		dc.w	$800
oscillator_1_width_lfo_1:	dc.w	0
oscillator_1_width_lfo_2:	dc.w	0
oscillator_1_width_env_2:	dc.w	0
oscillator_1_width_env_3:	dc.w	0
oscillator_1_sync:		dc.w	0
oscillator_1_sync_lfo_1:	dc.w	0
oscillator_1_sync_lfo_2:	dc.w	0
oscillator_1_sync_env_2:	dc.w	0
oscillator_1_sync_env_3:	dc.w	0
oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
oscillator_2_mix:		dc.w	$8c0
oscillator_2_mix_lfo_1:		dc.w	0
oscillator_2_mix_lfo_2:		dc.w	0
oscillator_2_mix_env_2:		dc.w	0
oscillator_2_mix_env_3:		dc.w	0
oscillator_2_pitch:		dc.w	88
oscillator_2_pitch_lfo_1:	dc.w	0
oscillator_2_pitch_lfo_2:	dc.w	0
oscillator_2_pitch_env_2:	dc.w	0
oscillator_2_pitch_env_3:	dc.w	0
oscillator_2_width:		dc.w	$800
oscillator_2_width_lfo_1:	dc.w	0
oscillator_2_width_lfo_2:	dc.w	0
oscillator_2_width_env_2:	dc.w	0
oscillator_2_width_env_3:	dc.w	0
oscillator_2_sync:		dc.w	0
oscillator_2_sync_lfo_1:	dc.w	0
oscillator_2_sync_lfo_2:	dc.w	0
oscillator_2_sync_env_2:	dc.w	0
oscillator_2_sync_env_3:	dc.w	0
oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
oscillator_3_mix:		dc.w	$fff
oscillator_3_mix_lfo_1:		dc.w	0
oscillator_3_mix_lfo_2:		dc.w	0
oscillator_3_mix_env_2:		dc.w	0
oscillator_3_mix_env_3:		dc.w	0
oscillator_3_pitch:		dc.w	44
oscillator_3_pitch_lfo_1:	dc.w	0
oscillator_3_pitch_lfo_2:	dc.w	0
oscillator_3_pitch_env_2:	dc.w	0
oscillator_3_pitch_env_3:	dc.w	0
oscillator_3_width:		dc.w	$800
oscillator_3_width_lfo_1:	dc.w	$7ff
oscillator_3_width_lfo_2:	dc.w	0
oscillator_3_width_env_2:	dc.w	0
oscillator_3_width_env_3:	dc.w	0
oscillator_3_sync:		dc.w	0
oscillator_3_sync_lfo_1:	dc.w	0
oscillator_3_sync_lfo_2:	dc.w	0
oscillator_3_sync_env_2:	dc.w	0
oscillator_3_sync_env_3:	dc.w	0
oscillator_noise_mix:		dc.w	0
oscillator_noise_mix_lfo_1:	dc.w	0
oscillator_noise_mix_lfo_2:	dc.w	0
oscillator_noise_mix_env_2:	dc.w	$fff
oscillator_noise_mix_env_3:	dc.w	0
oscillator_13_mix:		dc.w	0
oscillator_13_mix_lfo_1:	dc.w	0
oscillator_13_mix_lfo_2:	dc.w	0
oscillator_13_mix_env_2:	dc.w	0
oscillator_13_mix_env_3:	dc.w	0
oscillator_13_fm:		dc.w	0
oscillator_23_mix:		dc.w	0
oscillator_23_mix_lfo_1:	dc.w	0
oscillator_23_mix_lfo_2:	dc.w	0
oscillator_23_mix_env_2:	dc.w	0
oscillator_23_mix_env_3:	dc.w	0
oscillator_23_fm:		dc.w	0
filter_frequency:		dc.w	$100
filter_frequency_lfo_1:		dc.w	0
filter_frequency_lfo_2:		dc.w	0
filter_frequency_env_2:		dc.w	0
filter_frequency_env_3:		dc.w	$fff
filter_resonance:		dc.w	0
filter_resonance_lfo_1:		dc.w	0
filter_resonance_lfo_2:		dc.w	0
filter_resonance_env_2:		dc.w	0
filter_resonance_env_3:		dc.w	0
envelope_1_attack:		dc.w	0
envelope_1_decay:		dc.w	0
envelope_1_sustain:		dc.w	$fff
envelope_2_attack:		dc.w	0
envelope_2_decay:		dc.w	$80
envelope_2_sustain:		dc.w	$500
envelope_3_attack:		dc.w	0
envelope_3_decay:		dc.w	$180
envelope_3_sustain:		dc.w	0
lfo_1_speed:			dc.w	1000
lfo_1_waveform:			dc.w	WAVEFORM_LFO_SAW
lfo_2_speed:			dc.w	1000
lfo_2_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
render_size_param:		dc.l	12288
params_end:

; Synthesizer parameters (e004: 808 Kick Loong)
; ---------------------------------------------
;buffer_render_size:		dc.l	16384
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	55
;oscillator_1_pitch_lfo_1:	dc.w	-40
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	$30
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	$fff
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	55
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	$30
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	44
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	$7ff
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$fff
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	0
;filter_resonance:		dc.w	0
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	$800
;envelope_1_sustain:		dc.w	0
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	$100
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$40
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	200
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	1000
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE

; Synthesizer parameters (e006: 808 Snare 2)
; ------------------------------------------
;buffer_render_size:		dc.l	2560
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_1_mix:		dc.w	0
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	$b00
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	275
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	15
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	55
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	$40
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	44
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	$7ff
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	$fff
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$fff
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	0
;filter_resonance:		dc.w	$600
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	$120
;envelope_1_sustain:		dc.w	0
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	$100
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$140
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	0
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	1000
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE

; Synthesizer parameters (B027: ItsKindaPhasedWh)
; -----------------------------------------------
;buffer_render_size:		dc.l	65536
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	175
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SAW
;oscillator_2_mix:		dc.w	$fff
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	264
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SAW
;oscillator_3_mix:		dc.w	$fff
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	176
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	$7ff
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$180
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$800
;filter_resonance:		dc.w	$700
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	$200
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	$fff
;envelope_3_attack:		dc.w	$800
;envelope_3_decay:		dc.w	$e00
;envelope_3_sustain:		dc.w	$80
;lfo_1_speed:			dc.w	0
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	1000
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE

; Synthesizer parameters (C081: Jan Hammer)
; -----------------------------------------
;buffer_render_size:		dc.l	4096
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	0
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	$fff
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	175
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SAW
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	$fff
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	353
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	$fff
;oscillator_3_pitch:		dc.w	704
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	$7ff
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	$400
;oscillator_13_mix_env_3:	dc.w	$600
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$280
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$900
;filter_resonance:		dc.w	$800
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	$200
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	$200
;envelope_1_sustain:		dc.w	0
;envelope_2_attack:		dc.w	$180
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	$fff
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$1c0
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	$c00
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	1000
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE

; Synthesizer parameters (A070: Sollie strings 1)
; -----------------------------------------------
;buffer_render_size:		dc.l	32768
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SQUARE_1
;oscillator_1_mix:		dc.w	$800
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	351
;oscillator_1_pitch_lfo_1:	dc.w	-6
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$a00
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	$280
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	$800
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	704
;oscillator_2_pitch_lfo_1:	dc.w	-7
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	$280
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_3_mix:		dc.w	$400
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	353
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	$300
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$80
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	$e00
;filter_frequency_env_3:		dc.w	0
;filter_resonance:		dc.w	0
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	$800
;envelope_2_sustain:		dc.w	$a00
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	0
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	$1000
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$e00
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE

; Synthesizer parameters (Huhhuh!)
; --------------------------------
;buffer_render_size:		dc.l	65536
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SQUARE_1
;oscillator_1_mix:		dc.w	0
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	66
;oscillator_1_pitch_lfo_1:	dc.w	50
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	500
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	$600
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	352
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	44
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	100
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	$200
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	$fff
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$580
;filter_frequency_lfo_1:		dc.w	$300
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	0
;filter_resonance:		dc.w	$400
;filter_resonance_lfo_1:		dc.w	$300
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	$800
;envelope_2_decay:		dc.w	$300
;envelope_2_sustain:		dc.w	$fff
;envelope_3_attack:		dc.w	$300
;envelope_3_decay:		dc.w	$680
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Hihat Closed)
; -------------------------------------
;buffer_render_size:		dc.l	640
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	0
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	44
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	$fff
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$e00
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	0
;filter_resonance:		dc.w	$a00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	$40
;envelope_1_sustain:		dc.w	0
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	0
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Hihat Open)
; -----------------------------------
;buffer_render_size:		dc.l	4096
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	0
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	44
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	$fff
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$e00
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	0
;filter_resonance:		dc.w	$a00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	$300
;envelope_1_sustain:		dc.w	0
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	0
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Acid 1)
; -------------------------------
;buffer_render_size:		dc.l	4096		; 4096, 8192
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	44		; 44, 88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$c00
;filter_resonance:		dc.w	0		; 0, $500, $a00, $d00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$c0		; $c0, $300
;envelope_3_sustain:		dc.w	$60
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Acid 2)
; -------------------------------
;buffer_render_size:		dc.l	8192		; 4096, 8192
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	88		; 44, 88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$c00
;filter_resonance:		dc.w	0		; 0, $500, $a00, $d00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$300		; $c0, $300
;envelope_3_sustain:		dc.w	$60
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Acid 3)
; -------------------------------
;buffer_render_size:		dc.l	4096		; 4096, 8192
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	44		; 44, 88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$c00
;filter_resonance:		dc.w	$500		; 0, $500, $a00, $d00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$c0		; $c0, $300
;envelope_3_sustain:		dc.w	$60
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Acid 4)
; -------------------------------
;buffer_render_size:		dc.l	8192		; 4096, 8192
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	88		; 44, 88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$c00
;filter_resonance:		dc.w	$500		; 0, $500, $a00, $d00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$300		; $c0, $300
;envelope_3_sustain:		dc.w	$60
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Acid 5)
; -------------------------------
;buffer_render_size:		dc.l	4096		; 4096, 8192
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	44		; 44, 88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$c00
;filter_resonance:		dc.w	$a00		; 0, $500, $a00, $d00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$c0		; $c0, $300
;envelope_3_sustain:		dc.w	$60
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Acid 6)
; -------------------------------
;buffer_render_size:		dc.l	8192		; 4096, 8192
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	88		; 44, 88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$c00
;filter_resonance:		dc.w	$a00		; 0, $500, $a00, $d00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$300		; $c0, $300
;envelope_3_sustain:		dc.w	$60
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Acid 7)
; -------------------------------
;buffer_render_size:		dc.l	4096		; 4096, 8192
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	44		; 44, 88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$c00
;filter_resonance:		dc.w	$d00		; 0, $500, $a00, $d00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$c0		; $c0, $300
;envelope_3_sustain:		dc.w	$60
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Acid 8)
; -------------------------------
;buffer_render_size:		dc.l	8192		; 4096, 8192
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	88		; 44, 88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$c00
;filter_resonance:		dc.w	$d00		; 0, $500, $a00, $d00
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$300		; $c0, $300
;envelope_3_sustain:		dc.w	$60
;lfo_1_speed:			dc.w	$180
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$880
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Clap)
; -----------------------------
;buffer_render_size:		dc.l	8192
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	0
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	176
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	$800
;oscillator_noise_mix_lfo_2:	dc.w	$800
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	0
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$480
;filter_resonance:		dc.w	$200
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	$280
;envelope_1_sustain:		dc.w	0
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	$380
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	$2b00
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_SQUARE
;lfo_2_speed:			dc.w	$1e00
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Arp)
; ----------------------------
;buffer_render_size:		dc.l	1024
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SQUARE_1
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	704
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	$800
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SQUARE_3
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	175
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$400
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	$400
;filter_resonance:		dc.w	$800
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	$40
;envelope_3_decay:		dc.w	$40
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	$2800
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$1e00
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (FM 1)
; -----------------------------
;buffer_render_size:		dc.l	16384
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_1_mix:		dc.w	0
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	352
;oscillator_1_pitch_lfo_1:	dc.w	30
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	420
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	370
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	70
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_3_mix:		dc.w	$fff
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	130
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	$700
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	1
;oscillator_23_mix:		dc.w	$fff
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$fff
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	0
;filter_resonance:		dc.w	0
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	$800
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	$300
;envelope_3_decay:		dc.w	0
;envelope_3_sustain:		dc.w	$fff
;lfo_1_speed:			dc.w	$1e00
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$1e00
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (FM 2)
; -----------------------------
;buffer_render_size:		dc.l	16384
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_1_mix:		dc.w	0
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	352
;oscillator_1_pitch_lfo_1:	dc.w	30
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	420
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	0
;oscillator_1_sync_lfo_1:	dc.w	0
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_2_mix:		dc.w	0
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	200
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	0
;oscillator_2_sync_lfo_1:	dc.w	0
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_3_mix:		dc.w	$fff
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	130
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	$700
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	1
;oscillator_23_mix:		dc.w	$fff
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$fff
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	0
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	0
;filter_resonance:		dc.w	0
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	$800
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	$20;$300
;envelope_3_decay:		dc.w	$100;0
;envelope_3_sustain:		dc.w	0;$fff
;lfo_1_speed:			dc.w	$1e00
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$1e00
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_SQUARE

; Synthesizer parameters (Sync)
; -----------------------------
;buffer_render_size:		dc.l	22532
;buffer_play_size:		dc.l	256
;oscillator_1_waveform:		dc.w	WAVEFORM_SAW
;oscillator_1_mix:		dc.w	$fff
;oscillator_1_mix_lfo_1:		dc.w	0
;oscillator_1_mix_lfo_2:		dc.w	0
;oscillator_1_mix_env_2:		dc.w	0
;oscillator_1_mix_env_3:		dc.w	0
;oscillator_1_pitch:		dc.w	88
;oscillator_1_pitch_lfo_1:	dc.w	0
;oscillator_1_pitch_lfo_2:	dc.w	0
;oscillator_1_pitch_env_2:	dc.w	0
;oscillator_1_pitch_env_3:	dc.w	0
;oscillator_1_width:		dc.w	$800
;oscillator_1_width_lfo_1:	dc.w	0
;oscillator_1_width_lfo_2:	dc.w	0
;oscillator_1_width_env_2:	dc.w	0
;oscillator_1_width_env_3:	dc.w	0
;oscillator_1_sync:		dc.w	$200
;oscillator_1_sync_lfo_1:	dc.w	80
;oscillator_1_sync_lfo_2:	dc.w	0
;oscillator_1_sync_env_2:	dc.w	0
;oscillator_1_sync_env_3:	dc.w	0
;oscillator_2_waveform:		dc.w	WAVEFORM_SQUARE_2
;oscillator_2_mix:		dc.w	$fff
;oscillator_2_mix_lfo_1:		dc.w	0
;oscillator_2_mix_lfo_2:		dc.w	0
;oscillator_2_mix_env_2:		dc.w	0
;oscillator_2_mix_env_3:		dc.w	0
;oscillator_2_pitch:		dc.w	44
;oscillator_2_pitch_lfo_1:	dc.w	0
;oscillator_2_pitch_lfo_2:	dc.w	0
;oscillator_2_pitch_env_2:	dc.w	0
;oscillator_2_pitch_env_3:	dc.w	0
;oscillator_2_width:		dc.w	$800
;oscillator_2_width_lfo_1:	dc.w	0
;oscillator_2_width_lfo_2:	dc.w	0
;oscillator_2_width_env_2:	dc.w	0
;oscillator_2_width_env_3:	dc.w	0
;oscillator_2_sync:		dc.w	$80
;oscillator_2_sync_lfo_1:	dc.w	$30
;oscillator_2_sync_lfo_2:	dc.w	0
;oscillator_2_sync_env_2:	dc.w	0
;oscillator_2_sync_env_3:	dc.w	0
;oscillator_3_waveform:		dc.w	WAVEFORM_SINUS
;oscillator_3_mix:		dc.w	0
;oscillator_3_mix_lfo_1:		dc.w	0
;oscillator_3_mix_lfo_2:		dc.w	0
;oscillator_3_mix_env_2:		dc.w	0
;oscillator_3_mix_env_3:		dc.w	0
;oscillator_3_pitch:		dc.w	130
;oscillator_3_pitch_lfo_1:	dc.w	0
;oscillator_3_pitch_lfo_2:	dc.w	0
;oscillator_3_pitch_env_2:	dc.w	0
;oscillator_3_pitch_env_3:	dc.w	0
;oscillator_3_width:		dc.w	$800
;oscillator_3_width_lfo_1:	dc.w	0
;oscillator_3_width_lfo_2:	dc.w	0
;oscillator_3_width_env_2:	dc.w	0
;oscillator_3_width_env_3:	dc.w	0
;oscillator_3_sync:		dc.w	0
;oscillator_3_sync_lfo_1:	dc.w	0
;oscillator_3_sync_lfo_2:	dc.w	0
;oscillator_3_sync_env_2:	dc.w	0
;oscillator_3_sync_env_3:	dc.w	0
;oscillator_noise_mix:		dc.w	0
;oscillator_noise_mix_lfo_1:	dc.w	0
;oscillator_noise_mix_lfo_2:	dc.w	0
;oscillator_noise_mix_env_2:	dc.w	0
;oscillator_noise_mix_env_3:	dc.w	0
;oscillator_13_mix:		dc.w	0
;oscillator_13_mix_lfo_1:	dc.w	0
;oscillator_13_mix_lfo_2:	dc.w	0
;oscillator_13_mix_env_2:	dc.w	0
;oscillator_13_mix_env_3:	dc.w	0
;oscillator_13_fm:		dc.w	0
;oscillator_23_mix:		dc.w	0
;oscillator_23_mix_lfo_1:	dc.w	0
;oscillator_23_mix_lfo_2:	dc.w	0
;oscillator_23_mix_env_2:	dc.w	0
;oscillator_23_mix_env_3:	dc.w	0
;oscillator_23_fm:		dc.w	0
;filter_frequency:		dc.w	$260
;filter_frequency_lfo_1:		dc.w	0
;filter_frequency_lfo_2:		dc.w	$80
;filter_frequency_env_2:		dc.w	0
;filter_frequency_env_3:		dc.w	0
;filter_resonance:		dc.w	$800
;filter_resonance_lfo_1:		dc.w	0
;filter_resonance_lfo_2:		dc.w	0
;filter_resonance_env_2:		dc.w	0
;filter_resonance_env_3:		dc.w	0
;envelope_1_attack:		dc.w	0
;envelope_1_decay:		dc.w	0
;envelope_1_sustain:		dc.w	$fff
;envelope_2_attack:		dc.w	0
;envelope_2_decay:		dc.w	0
;envelope_2_sustain:		dc.w	0
;envelope_3_attack:		dc.w	0
;envelope_3_decay:		dc.w	0
;envelope_3_sustain:		dc.w	0
;lfo_1_speed:			dc.w	$490
;lfo_1_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE
;lfo_2_speed:			dc.w	$920
;lfo_2_waveform:			dc.w	WAVEFORM_LFO_TRIANGLE

render_mode:			dc.b	RENDER_BUFFER
buffer_mode:			dc.b	BUFFER_RAW

				section	fastbss,bss
; System variables
; ----------------
base_graphics:			ds.l	1
base_intuition:			ds.l	1
base_dos:			ds.l	1
interrupt_vector_audio_0:	ds.l	1
vector_audio_0:			ds.b	IS_SIZE
io_request:			ds.l	1
message_port:			ds.l	1
screen:				ds.l	1
window:				ds.l	1
gadget_current:			ds.l	1

; Synthesizer buffers and other data
; ----------------------------------
buffer_render:			ds.l	1
buffer_play:			ds.l	1
buffer_play_current:		ds.l	1
random_number:			ds.l	1
oscillator_waveform:		ds.l	1
oscillator_square:		ds.w	1
oscillator_gadgets_active:			ds.w	1

; Synthesizer variables
; ---------------------
oscillator_1_position:		ds.l	1
oscillator_1_delta:		ds.l	1
oscillator_2_position:		ds.l	1
oscillator_2_delta:		ds.l	1
oscillator_3_position:		ds.l	1
oscillator_3_delta:		ds.l	1
oscillator_noise_position:	ds.l	1
oscillator_1_sync_position:	ds.l	1
oscillator_1_sync_delta:	ds.l	1
oscillator_2_sync_position:	ds.l	1
oscillator_2_sync_delta:	ds.l	1
oscillator_3_sync_position:	ds.l	1
oscillator_3_sync_delta:	ds.l	1
lfo_1_position:			ds.l	1
lfo_2_position:			ds.l	1
envelope_1_current32:		ds.w	1
envelope_1_current:		ds.w	1
envelope_1_delta32:		ds.w	1
envelope_1_delta:		ds.w	1
envelope_2_current32:		ds.w	1
envelope_2_current:		ds.w	1
envelope_2_delta32:		ds.w	1
envelope_2_delta:		ds.w	1
envelope_3_current32:		ds.w	1
envelope_3_current:		ds.w	1
envelope_3_delta32:		ds.w	1
envelope_3_delta:		ds.w	1
envelope_stretch:		ds.l	1
waveform_saw:			ds.b	256
waveform_square:		ds.b	3*256
waveform_noise:			ds.b	256
waveform_sinus:			ds.b	256
waveform_lfo_saw:		ds.w	4096
waveform_lfo_square:		ds.w	4096
waveform_lfo_triangle:		ds.w	4096
filter_q:			ds.w	1
filter_p:			ds.w	1
filter_f:			ds.w	1
filter_in:			ds.w	1
filter_frequency_current:	ds.w	1
filter_resonance_current:	ds.w	1
oscillator_1_current:		ds.w	1
oscillator_1_width_current:	ds.w	1
oscillator_2_current:		ds.w	1
oscillator_2_width_current:	ds.w	1
oscillator_3_current:		ds.w	1
oscillator_3_width_current:	ds.w	1
envelope_1_counter:		ds.w	1
envelope_2_counter:		ds.w	1
envelope_3_counter:		ds.w	1
envelope_1_mode:		ds.b	1
envelope_2_mode:		ds.b	1
envelope_3_mode:		ds.b	1
render_hold:			ds.b	1
quit:				ds.b	1
