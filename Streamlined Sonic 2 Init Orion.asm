;-------------------------------------------------------------------------
; Streamlined Startup for Sonic the Hedgehog 1
; Targets OrionNavattan's Sonic 2, but can be adapted to
; other disassemblies and other games.
; Includes code from MarkeyJester's init library:
; https://pastebin.com/KXpmQxQp
;-------------------------------------------------------------------------

EntryPoint:
		lea	SetupValues(pc),a0			; load setup array
		move.w	(a0)+,sr				; disable interrupts during setup; they will be reenabled by the Sega Screen
		movem.l (a0)+,a1-a3/a5/a6			; Z80 RAM start, work RAM start, Z80 bus request register, VDP data port, VDP control port
		movem.w (a0)+,d1/d2				; VDP register increment/value for Z80 stop and reset release ($100),  first VDP register value ($8004)
		moveq	#sizeof_SetupVDP-1,d5		; VDP registers loop counter
		moveq	#0,d4					; DMA fill/memory clear/Z80 stop bit test value
		movea.l d4,a4					; clear a4
		move.l	a4,usp					; clear user stack pointer

		tst.w	port_e_control_hi-z80_bus_request(a3)	; was this a soft reset?
		bne.s	.wait_dma				; if so, skip setting region and the TMSS check

		move.b	console_version-z80_bus_request(a3),d6	; load hardware version
		move.b	d6,d3					; copy to d3 for checking revision (d6 will be used later to set region and speed)
		andi.b	#console_revision,d3			; get only hardware version ID
		beq.s	.wait_dma				; if Model 1 VA4 or earlier (ID = 0), branch
		move.l	#'SEGA',tmss_sega-z80_bus_request(a3)	; satisfy the TMSS

   .wait_dma:
		move.w	(a6),ccr				; copy status register to CCR, clearing the VDP write latch and setting the overflow flag if a DMA is in progress
		bvs.s	.wait_dma				; if a DMA was in progress during a soft reset, wait until it is finished

   .loop_vdp:
		move.w	d2,(a6)					; set VDP register
		add.w	d1,d2					; advance register ID
		move.b	(a0)+,d2				; load next register value
		dbf	d5,.loop_vdp				; repeat for all registers; final value loaded will be used later to initialize I/0 ports

		move.l	(a0)+,(a6)				; set DMA fill destination
		move.w	d4,(a5)					; set DMA fill value (0000), clearing the VRAM

		tst.w	port_e_control_hi-z80_bus_request(a3)	; was this a soft reset?
		bne.s	.clear_every_reset			; if so, skip clearing RAM addresses $FE00-$FFFF

		movea.l	(a0),a4					; $FFFFFE00	  (increment will happen later)
		move.w	4(a0),d5				; repeat times
   .loop_ram1:
		move.l	d4,(a4)+
		dbf	d5,.loop_ram1				; clear RAM ($FE00-$FFFF)

   .clear_every_reset:
		addq	#6,a0					; advance to next position in setup array
		move.w	(a0)+,d5				; repeat times
   .loop_ram2:
		move.l	d4,(a2)+				; a2 = start of 68K RAM
		dbf	d5,.loop_ram2				; clear RAM ($0000-$FDFF)

		move.w	d1,(a3)					; stop the Z80 (we will clear the VSRAM and CRAM while waiting for it to stop)
		move.w	d1,z80_reset-z80_bus_request(a3)	; deassert Z80 reset (ZRES is held high on console reset until we clear it)

		move.w	(a0)+,(a6)				; set VDP increment to 2

		move.l	(a0)+,(a6)				; set VDP to VSRAM write
		moveq	#(sizeof_vsram/4)-1,d5			; set repeat times
   .loop_vsram:
		move.l	d4,(a5)					; clear 4 bytes of VSRAM
		dbf	d5,.loop_vsram				; repeat until entire VSRAM has been cleared

		move.l	(a0)+,(a6)				; set VDP to CRAM write
		moveq	#(sizeof_pal_all/4)-1,d5		; set repeat times
   .loop_cram:
		move.l	d4,(a5)					; clear two palette entries
		dbf	d5,.loop_cram				; repeat until entire CRAM has been cleared

   .waitz80:
		btst	d4,(a3)					; has the Z80 stopped?
		bne.s	.waitz80				; if not, branch

		move.w #sizeof_z80_ram-1,d5			; size of Z80 ram
   .clear_Z80_ram:
		move.b 	d4,(a1)+				; clear the Z80 RAM
		dbf	d5,.clear_Z80_ram

		moveq	#4-1,d5					; set number of PSG channels to mute
   .psg_loop:
		move.b	(a0)+,psg_input-vdp_data_port(a5)	; set the PSG channel volume to null (no sound)
		dbf	d5,.psg_loop				; repeat for all channels

		tst.w	port_e_control_hi-z80_bus_request(a3)	; was this a soft reset?
		bne.w	.set_vdp_buffer				; if so, skip the checksum check and setting the region variable

		; Checksum check; delete everything from here to .set_region to remove
		; All absolute longs here have been optimized to PC relative, since this code will
		; invariably be located near the header.
   		move.l	d4,d7					; clear d7
		lea	EndOfHeader(pc),a1			; start checking bytes after the header	($200)
		move.l	ROMEndLoc(pc),d0			; stop at end of ROM

   .checksum_loop:
		add.w	(a1)+,d7				; add each word of the rom to d7
		cmp.l	a1,d0					; have we reached the end?
		bcc.s	.checksum_loop				; if not, branch

		cmp.w	Checksum(pc),d7				; compare checksum in header to ROM

		beq.s	.set_region				; if they match, branch
		move.w	#cRed,(a5)				; if they don't match, set BG color to red
		bra.s	*					; stay here forever

	.set_region:
		andi.b	 #console_region+console_speed,d6	; get region and speed settings
		move.b	 d6,(v_console_region).w		; set in RAM

	.set_vdp_buffer:
		move.w	d4,d5					; clear d5
		move.b	SetupVDP(pc),d5				; get first entry of SetupVDP
		ori.w	#vdp_mode_register2,d5			; make it a valid command word ($8134)
		move.w	d5,(v_vdp_mode_buffer).w		; save to buffer for later use
		move.w	#vdp_hint_counter+(screen_height-1),(v_vdp_hint_counter).w ; horizontal interrupt every 224th scanline

	;.load_sound_driver:
		; WARNING: if using Flamewing's Saxman decompressor, change d7, a5, and a6 in this
		; block to d6, a0, and a1 respectively, and delete 'movea.l a5,a4'.
		pushr.w	d1/d2/d4				; back up these registers for compatibility with other decompressors
;		pushr.l	a3			; back a3 up too if using a different compression format
		lea (SoundDriver).l,a6				; sound driver start address

		; WARNING: you must edit MergeCode if you rename this label
	movewZ80CompSize:
		move.w	#$F64,d7				; size of compressed data; patched if necessary by SndDriverCompress.exe
		move.l	d4,d3						; d3 & d4 = buffers for unprocessed data
		move.l	d4,d5						; d5 = offset of end of decompressed data
		move.l	d4,d6						; make the decompressor fetch the first descriptor byte
		lea	(z80_ram).l,a5				; start of compressed data
		movea.l a5,a4					; start of compressed data (used for dictionary matches)

		jsr	(SaxDec).l				; decompress the sound driver (uses d0,d3-d7,a4-a6; d1,d2,a0-a3 are not touched)

;		popr.l	a3		; restore a3 if using a different compression format
		popr.w d1/d2/d4					; restore registers

		btst	#console_speed_bit,(v_console_region).w	; are we on a PAL console?
		sne	f_pal(a4)			; if so, set the driver's PAL flag

		move.w	d4,z80_reset-z80_bus_request(a3)	; reset Z80

		move.b	d2,port_1_control-z80_bus_request(a3)	; initialise port 1
		move.b	d2,port_2_control-z80_bus_request(a3)	; initialise port 2
		move.b	d2,port_e_control-z80_bus_request(a3)	; initialise port e

		move.w	d1,z80_reset-z80_bus_request(a3)	; release Z80 reset
		move.w	d4,(a3)					; start the Z80

		move.b	#id_Sega,(v_gamemode).w			; set initial game mode (Sega screen)
		bra.s	MainGameLoop				; continue to main program


SetupValues:
		dc.w	$2700					; disable interrupts
		dc.l	z80_ram
		dc.l	ram_start				; ram_start
		dc.l	z80_bus_request
		dc.l	vdp_data_port
		dc.l	vdp_control_port

		dc.w	vdp_mode_register2-vdp_mode_register1	; VDP Reg increment value & opposite initialisation flag for Z80
		dc.w	vdp_md_color				; $8004; normal color mode, horizontal interrupts disabled
	SetupVDP:
		dc.b	(vdp_enable_vint|vdp_enable_dma|vdp_ntsc_display|vdp_md_display)&$FF ;  $8134; mode 5, NTSC, vertical interrupts and DMA enabled
		dc.b	(vdp_fg_nametable+(vram_fg>>10))&$FF	; $8230; foreground nametable starts at $C000
		dc.b	(vdp_window_nametable+(vram_window>>10))&$FF ; $8328; window nametable starts at $A000
		dc.b	(vdp_bg_nametable+(vram_bg>>13))&$FF	; $8407; background nametable starts at $E000
		dc.b	(vdp_sprite_table+(vram_sprites>>9))&$FF ; $857C; sprite attribute table starts at $F800
		dc.b	vdp_sprite_table2&$FF			; $8600; unused (high bit of sprite attribute table address for 128KB VRAM)
		dc.b	(vdp_bg_color+0)&$FF			; $8700; background color (palette line 0 color 0)
		dc.b	vdp_sms_hscroll&$FF			; $8800; unused (mode 4 hscroll register)
		dc.b	vdp_sms_vscroll&$FF			; $8900; unused (mode 4 vscroll register)
		dc.b	(vdp_hint_counter+0)&$FF		; $8A00; horizontal interrupt register (set to 0 for now)
		dc.b	(vdp_full_vscroll|vdp_full_hscroll)&$FF	; $8B00; full-screen vertical/horizontal scrolling
		dc.b	vdp_320px_screen_width&$FF		; $8C81; H40 display mode
		dc.b	(vdp_hscroll_table+(vram_hscroll>>10))&$FF ; $8D3F; hscroll table starts at $FC00
		dc.b	vdp_nametable_hi&$FF			; $8E00: unused (high bits of fg and bg nametable addresses for 128KB VRAM)
		dc.b	(vdp_auto_inc+1)&$FF			; $8F01; VDP increment size (will be changed to 2 later)
		dc.b	(vdp_plane_width_64|vdp_plane_height_32)&$FF ; $9001; 64x32 plane size
		dc.b	vdp_window_x_pos&$FF			; $9100; unused (window horizontal position)
		dc.b	vdp_window_y_pos&$FF			; $9200; unused (window vertical position)

		dc.b	(vdp_dma_length_low+((sizeof_vram-1)&$FF))&$FF	; $93FF/$94FF - DMA length
		dc.b	(vdp_dma_length_hi+((sizeof_vram-1)>>8))&$FF
		dc.b	(vdp_dma_source_low+0)&$FF		; $9500/9600 - DMA source
		dc.b	(vdp_dma_source_mid+0)&$FF
		dc.b	vdp_dma_vram_fill&$FF			; VDP $9780 - DMA fill VRAM

		dc.b	$40					; I/O port initialization value

		arraysize SetupVDP

		vdp_comm.l	dc,vram_start,vram,dma	; DMA fill VRAM
		dc.l	v_keep_after_reset
		dc.w	(($FFFFFFFF-v_keep_after_reset+1)/4)-1
		dc.w	((v_keep_after_reset&$FFFF)/4)-1
		dc.w	vdp_auto_inc+2				; VDP increment
		vdp_comm.l	dc,$0000,vsram,write		; VSRAM write mode
		vdp_comm.l	dc,$0000,cram,write		; CRAM write mode

		dc.b	$9F,$BF,$DF,$FF				; PSG mute values (PSG 1 to 4)
