# Streamlined Sonic Init
Streamlined init code for Sonic the Hedgehog 1, 2, and 3 & Knuckles made by OrionNavattan (under [BSD Zero Clause](LICENSE)).

The code targets SonicRetro's disassemblies, S1 Hivebrain 2022, and Sonic 2 OrnNv.
 
These are intended as drop-in replacements for the standard ICDBLK_4 library, and the game-specific init code that immediately follows.
Compared to the original, these are streamlined, eliminating all redundancy (particularly on cold boot) and in-lining the VDP and joypad init, Z80 code load, and the checksum check (which is easy to remove!)

# Installation Instructions

## Sonic 1

### AS

- Replace everything from `EntryPoint` to `MainGameLoop` with the contents of `Streamlined Sonic 1 Init AS.asm`. 
- Find GM_Title and delete the `bsr.w	SoundDriverLoad` six lines into that routine.
- Delete `CheckSumError`, `VDPSetupGame`, `JoypadInit`, and `SoundDriverLoad`, as all of their
functionality is incorporated into the new init code.

### HB 2022

- Replace the `Mega Drive Setup.asm` include and all code from `GameProgram` to `MainGameLoop` with the contents of `Streamlined Sonic 1 Init HB 2022.asm`.
- Delete the same instruction and subroutines, except that `SoundDriverLoad` is named `DacDriverLoad` instead.

## Sonic 2 

### AS 
- Replace everything from `EntryPoint` to `MainGameLoop` with the contents of `Streamlined Sonic 2 Init AS.asm`.
- Delete `CheckSumError`, `VDPSetupGame`, `JoypadInit`, `SoundDriverLoad`, and `DecompressSoundDriver` up to the `SaxDec_Loop` label, as all of their
functionality is incorporated into the new init code. (If you fail to do this, you will get a duplicate label/multiply defined error for movewZ80CompSize.

### OrnNv

- Essentially the same as Sonic 2 AS, except the file you need is `Streamlined Sonic 2 Init Orion.asm`. 

## Sonic 3K AS

### Sonic 3 Alone

- Replace everything from `EntryPoint` up to `Test_CountryCode` (if you want to keep it) with the contents of `Streamlined Sonic 3K Init AS.asm`, uncommenting the Sonic 3 specific portion
- (if you're keeping region locking) Replace the branch from `Test_Checksum` after line 1 of `loc_330` to `GameLoop`
- Delete the entirety of `Test_Checksum`, and
```
		lea	($FF0000).l,a6
		moveq	#0,d7
		move.w	#$3F7F,d6

loc_716:
		move.l	d7,(a6)+
		dbf	d6,loc_716
```
1 line after `Test_Checksum_Done`
- Delete `Init_VDP`, `SndDrvInit`, `Init_Controllers` and remove their branches.

### Sonic & Knuckles/3 Complete

- Replace everything from `EntryPoint` up to `Test_LockOn` with the contents of `Streamlined Sonic 3K Init AS.asm`
- Delete `Test_Checksum`, the branches to it, and remove the first 15 lines of `Test_LockOn`
- Delete `Init_VDP`, `SndDrvInit`, `Init_Controllers` and their branches in `BlueSpheresStartup` and `SonicAndKnucklesStartup`.