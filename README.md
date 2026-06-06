# Streamlined Sonic Init
Streamlined init code for Sonic the Hedgehog 1, 2, and 3 & Knuckles made by OrionNavattan (under [BSD Zero Clause](LICENSE)).

The code targets SonicRetro's disassemblies, S1 Hivebrain 2022, and Sonic 2 OrnNv.

These are intended as drop-in replacements for the standard ICDBLK_4 library, and the game-specific init code that immediately follows.
Compared to the original, these are streamlined, eliminating all redundancy (particularly on cold boot) and in-lining the VDP and joypad init, Z80 code load, and the checksum check (which is easy to remove!)

# Installation Instructions

## Sonic 1

### AS (release v26.05, should work in later releases with adjustments)

- Replace everything from `EntryPoint` to `MainGameLoop` with the contents of `Streamlined Sonic 1 Init AS.asm`.
- Find GM_Title and delete the `bsr.w	DACDriverLoad` instruction.
- Delete `CheckSumError`, `VDPSetupGame`, `JoypadInit`, and `DACDriverLoad`, as all of their
functionality is incorporated into the new init code.
(`DACDriverLoad` was called `SoundDriverLoad` before commit `ea75d0f`)

### HB 2022

- Replace the `Mega Drive Setup.asm` include and all code from `GameProgram` to `MainGameLoop` with the contents of `Streamlined Sonic 1 Init HB 2022.asm`.
- Delete the same instruction and subroutines.

## Sonic 2

### AS
- Replace everything from `EntryPoint` to `MainGameLoop` with the contents of `Streamlined Sonic 2 Init AS.asm`.
- Delete `CheckSumError`, `VDPSetupGame`, `JoypadInit`, `SoundDriverLoad`, and `DecompressSoundDriver` up to the `SaxDec_Loop` label, as all of their
functionality is incorporated into the new init code. (If you fail to do this, you will get a duplicate label/multiply defined error for movewZ80CompSize!)

### OrnNv

- Essentially the same as Sonic 2 AS, except the file you need is `Streamlined Sonic 2 Init Orion.asm`.

## Sonic 3K AS

### Sonic 3 Alone

- Replace everything from `EntryPoint` up to `Test_CountryCode` (if you want to keep it) with the contents of `Streamlined Sonic 3K Init AS.asm`, uncommenting the Sonic 3 specific portions and removing the Sonic and Knuckles specific portions
- Delete the entirety of `Test_Checksum`, and
```
		lea	($FF0000).l,a6
		moveq	#0,d7
		move.w	#$3F7F,d6

loc_716:
		move.l	d7,(a6)+
		dbf	d6,loc_716
```
1 line after `Test_Checksum_Done`, then remove `move.b	#0,(Game_mode).w` before `GameLoop`
- Delete `Init_VDP`, `SndDrvInit`, `Init_Controllers` and remove their branches.

### Sonic & Knuckles/3 Complete

- Replace everything from `EntryPoint` up to `Test_LockOn` with the contents of `Streamlined Sonic 3K Init AS.asm`
- Delete `Test_Checksum`, the branches to it, and remove the following from `Test_LockOn`
```
		tst.w	(VDP_control_port).l
		move.w	#$4EF9,(V_int_jump).w	; machine code for jmp
		move.l	#VInt,(V_int_addr).w
		move.w	#$4EF9,(H_int_jump).w
		move.l	#HInt,(H_int_addr).w

-
		move.w	(VDP_control_port).l,d1
		btst	#1,d1
		bne.s	-	; wait till a DMA is completed
		lea	(RAM_start&$FFFFFF).l,a6
		moveq	#0,d7
		move.w	#bytesToLcnt(CrossResetRAM-RAM_start),d6

-
		move.l	d7,(a6)+
		dbf	d6,-
```
- Delete `Init_VDP`, `SndDrvInit`, `Init_Controllers` and their branches in `BlueSpheresStartup`, `SonicAndKnucklesStartup`, and `ChecksumError2`.
- `bra.s	SonicAndKnucklesStartup` will cause an error, change `bra.s` to a `bra.w`