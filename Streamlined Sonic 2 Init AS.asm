;-------------------------------------------------------------------------
; Streamlined Startup for Sonic the Hedgehog 1
; Targets Sonic 2 SonicRetro AS, but can be adapted to
; other disassemblies and other games.
; Includes code from MarkeyJester's init library:
; https://pastebin.com/KXpmQxQp
;-------------------------------------------------------------------------

EntryPoint:
	lea SetupValues(pc),a0					; load setup array
	move.w	(a0)+,sr					; disable interrupts during setup; they will be reenabled by the Sega Screen
	movem.l (a0)+,a1-a3/a5/a6				; Z80 RAM start, work RAM start, Z80 bus request register, VDP data port, VDP control port
	movem.w (a0)+,d1/d2					; first VDP register value ($8004), VDP register increment/value for Z80 stop and reset release ($100)
	moveq	#SetupVDP_end-SetupVDP-1,d5			; VDP registers loop counter
	moveq	#0,d4						; DMA fill/memory clear/Z80 stop bit test value
	movea.l d4,a4						; clear a4
	move.l	a4,usp						; clear user stack pointer
	
	tst.w	HW_Expansion_Control-1-Z80_Bus_Request(a3)	; was this a soft reset?
	bne.s	.wait_dma					; if so, skip setting region and the TMSS check

	move.b	HW_Version-Z80_Bus_Request(a3),d6		; load hardware version
	move.b	d6,d3						; copy to d3 for checking revision (d6 will be used later to set region and speed)
	andi.b	#$F,d3						; get only hardware version ID
	beq.s	.wait_dma					; if Model 1 VA4 or earlier (ID = 0), branch
	move.l	#'SEGA',Security_Addr-Z80_Bus_Request(a3)	; satisfy the TMSS
	
.wait_dma:
	move.w	(a6),ccr					; copy status register to CCR, clearing the VDP write latch and setting the overflow flag if a DMA is in progress
	bvs.s	.wait_dma					; if a DMA was in progress during a soft reset, wait until it is finished
   
.loop_vdp:
	move.w	d2,(a6)						; set VDP register
	add.w	d1,d2						; advance register ID
	move.b	(a0)+,d2					; load next register value
	dbf	d5,.loop_vdp					; repeat for all registers ; final value loaded will be used later to initialize I/0 ports
   
	move.l	(a0)+,(a6)					; set DMA fill destination
	move.w	d4,(a5)						; set DMA fill value (0000), clearing the VRAM
		
	tst.w	HW_Expansion_Control-1-Z80_Bus_Request(a3)	; was this a soft reset?
	bne.s	.clear_every_reset				; if so, skip clearing RAM addresses $FE00-$FFFF
   
	movea.l	(a0),a4						; $FFFFFE00	  (increment will happen later)
	move.w	4(a0),d5					; repeat times
.loop_ram1:
	move.l	d4,(a4)+
	dbf	d5,.loop_ram1					; clear RAM ($FE00-$FFFF)

.clear_every_reset:
	addq	#6,a0						; advance to next position in setup array
	move.w	(a0)+,d5					; repeat times
.loop_ram2:
	move.l	d4,(a2)+					; a2 = start of 68K RAM
	dbf	d5,.loop_ram2					; clear RAM ($0000-$FDFF)

	move.w	d1,(a3)						; stop the Z80 (we will clear the VSRAM and CRAM while waiting for it to stop)
	move.w	d1,Z80_Reset-Z80_Bus_Request(a3)		; deassert Z80 reset (ZRES is held high on console reset until we clear it)

	move.w	(a0)+,(a6)					; set VDP increment to 2

	move.l	(a0)+,(a6)					; set VDP to VSRAM write
	moveq	#$14-1,d5					; set repeat times
.loop_vsram:
	move.l	d4,(a5)						; clear 4 bytes of VSRAM
	dbf	d5,.loop_vsram					; repeat until entire VSRAM has been cleared

	move.l	(a0)+,(a6)					; set VDP to CRAM write
	moveq	#$20-1,d5					; set repeat times
.loop_cram:
	move.l	d4,(a5)						; clear two palette entries
	dbf	d5,.loop_cram					; repeat until entire CRAM has been cleared

   .waitz80:
	btst	d4,(a3)						; has the Z80 stopped?
	bne.s	.waitz80					; if not, branch

	move.w	#$2000-1,d5					; size of Z80 ram - 1
.clear_Z80_RAM:
	move.b 	d4,(a1)+					; clear the Z80 RAM
	dbf	d5,.clear_Z80_RAM
	
	moveq	#4-1,d5						; set number of PSG channels to mute
.psg_loop:
	move.b	(a0)+,PSG_input-VDP_data_port(a6)		; set the PSG channel volume to null (no sound)
	dbf	d5,.psg_loop					; repeat for all channels

	tst.w	HW_Expansion_Control-1-Z80_Bus_Request(a3)	; was this a soft reset?
	bne.w	.set_vdp_buffer					; if so, skip the checksum check and setting the region variable

	; Checksum check; delete everything from here to .set_region to remove
	; All absolute longs here have been optimized to PC relative, since this code will
	; invariably be located near the header.
   	move.l	d4,d7						; clear d7
	lea	EndOfHeader(pc),a1				; start checking bytes after the header	($200)
	move.l	ROMEndLoc(pc),d0				; stop at end of ROM

.checksum_loop:
	add.w	(a1)+,d7					; add each word of the rom to d7
	cmp.l	a1,d0						; have we reached the end?
	bcc.s	.checksum_loop					; if not, branch

	cmp.w	Checksum(pc),d7					; compare checksum in header to ROM
	
	beq.s	.set_region					; if they match, branch
	move.w	#$E,(a5)					; if they don't match, set BG color to red
	bra.s	*						; stay here forever

.set_region:
	andi.b	 #$C0,d6					; get region and speed settings
	move.b	 d6,(Graphics_Flags).w				; set in RAM
	
.set_vdp_buffer:
	move.w	d4,d5						; clear d5
	move.b	SetupVDP(pc),d5					; get first entry of SetupVDP
	ori.w	#$8100,d5					; make it a valid command word ($8134)
	move.w	d5,(VDP_Reg1_val).w				; save to buffer for later use
	move.w	#$8A00+(224-1),(Hint_counter_reserve).w		; horizontal interrupt every 224th scanline
	
;.load_sound_driver:
	; WARNING: if using Flamewing's Saxman decompressor, change d7, a5, and a6 in this
	; block to d6, a0, and a1 respectively, and delete 'movea.l a5,a4'.
	movem.w	d1/d2/d4,-(sp)					; back up these registers for compatibility with other decompressors
;	move.l	a3,-(sp)		; back a3 up too if using a different compression format
	lea (Snd_Driver).l,a6					; sound driver start address

	; WARNING: you must edit the source of FixPointer if you rename this label	
movewZ80CompSize:	
	move.w	#$F64,d7					; size of compressed driver				
	move.l	d4,d3						; clear d3/d5/d6
	move.l	d4,d5			
	move.l	d4,d6	
	lea	(Z80_RAM).l,a5
	movea.l a5,a4
	
	jsr	(SaxDec_Loop).l					; decompress the sound driver (d1, d2, and a3 are not touched by the Saxman decompressor)
	
;	move.l	(sp)+,a3		; restore a3 if using a different compression format
	movem.w (sp)+,d1/d2/d4					; restore registers
	
	btst	#6,(Graphics_Flags).w				; are we on a PAL console?
	sne	zPalModeByte(a4)				; if so, set the driver's PAL flag

	move.w	d4,Z80_Reset-Z80_Bus_Request(a3)		; reset Z80 (d7 = 0 after returning from Saxman decompressor)
	
	move.b	d2,HW_Port_1_Control-Z80_Bus_Request(a3)	; initialise port 1
	move.b	d2,HW_Port_2_Control-Z80_Bus_Request(a3)	; initialise port 2
	move.b	d2,HW_Expansion_Control-Z80_Bus_Request(a3)	; initialise port e

	move.w	d1,Z80_Reset-Z80_Bus_Request(a3)		; release Z80 reset
	move.w	d4,(a3)						; start the Z80

	move.b	#GameModeID_SegaScreen,(Game_Mode).w		; set initial game mode (Sega screen)
	bra.s	MainGameLoop					; continue to main program
	
	
SetupValues:
	dc.w	$2700						; disable interrupts
	dc.l	Z80_RAM
	dc.l	$FFFF0000					; ram_start
	dc.l	Z80_Bus_Request
	dc.l	VDP_data_port
	dc.l	VDP_control_port

	dc.w	$100						; VDP Reg increment value & opposite initialisation flag for Z80
	dc.w	$8004						; $8004; normal color mode, horizontal interrupts disabled
SetupVDP:
	dc.b	$8134&$FF					;  $8134; mode 5, NTSC, vertical interrupts and DMA enabled 
	dc.b	($8200+(VRAM_Plane_A_Name_Table>>10))&$FF	; $8230; foreground nametable starts at $C000
	dc.b	($8300+($A000>>10))&$FF				; $8328; window nametable starts at $A000
	dc.b	($8400+(VRAM_Plane_B_Name_Table>>13))&$FF	; $8407; background nametable starts at $E000
	dc.b	($8500+(VRAM_Sprite_Attribute_Table>>9))&$FF	; $857C; sprite attribute table starts at $F800
	dc.b	$8600&$FF					; $8600; unused (high bit of sprite attribute table for 128KB VRAM)
	dc.b	$8700&$FF					; $8700; background colour (palette line 0 color 0)
	dc.b	$8800&$FF					; $8800; unused (mode 4 hscroll register)
	dc.b	$8900&$FF					; $8900; unused (mode 4 vscroll register)
	dc.b	($8A00+0)&$FF					; $8A00; horizontal interrupt register (set to 0 for now)
	dc.b	$8B00&$FF					; $8B00 ; full-screen vertical/horizontal scrolling
	dc.b	$8C81&$FF					; $8C81 ; H40 display mode
	dc.b	($8D00+(VRAM_Horiz_Scroll_Table>>10))&$FF	; $8D3F; hscroll table starts at $FC00
	dc.b	$8E00&$FF					; $8E00: unused (high bits of fg and bg nametable addresses for 128KB VRAM)
	dc.b	($8F00+1)&$FF					; $8F01; VDP increment size (will be changed to 2 later)
	dc.b	$9001&$FF					; $9100; unused (window horizontal position)
	dc.b	$9100&$FF					; $9200; unused (window vertical position)
	dc.b	$9200&$FF					; window vertical position

	dc.w	$FFFF						; $93FF/$94FF - DMA length
	dc.w	0						; VDP $9500/9600 - DMA source
	dc.b	$9780&$FF					; VDP $9780 - DMA fill VRAM

	dc.b	$40						; I/O port initialization value
   
SetupVDP_end:

	dc.l	$40000080					; DMA fill VRAM
	dc.l	$FFFFFE00					; start of RAM only cleared on cold boot
	dc.w	(($FFFFFFFF-$FFFFFE00+1)/4)-1			; loops to clear RAM cleared only on cold boot
	dc.w	(($FFFFFE00&$FFFF)/4)-1				; loops to clear RAM cleared on all boots
	dc.w	$8F00+2						; VDP increment
	dc.l	$40000010					; VSRAM write mode
	dc.l 	$C0000000					; CRAM write mode

	dc.b	$9F,$BF,$DF,$FF					; PSG mute values (PSG 1 to 4) 
