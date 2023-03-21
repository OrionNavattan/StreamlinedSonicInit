# Streamlined Sonic Init
Streamlined init code for Sonic the Hedgehog 1 and 2. Versions targeting SonicRetro's disassemblies, S1 Hivebrain 2022, and my own S2 disasm (Sonic 2 OrnNv).
 
These are intended as drop-in replacements for the standard ICDBLK_4 library, and the game-specific init code that immediately follows.
Compared to the original, these are streamlined, eliminating all redundancy (particularly on cold boot) and in-lining the VDP and joypad init, Z80 code load, and the checksum check (which is easy to remove.)

## Installation Instructions:

### Sonic 1

#### AS
- Replace everything from `EntryPoint` to `MainGameLoop` with the contents of `Streamlined Sonic 1 Init AS.asm`. 
- Find GM_Title and delete the `bsr.w	SoundDriverLoad` six lines into that routine.
- Delete `CheckSumError`, `VDPSetupGame`, `JoypadInit`, and `SoundDriverLoad`, as all of their
functionality is incorporated into the new init code.

#### HB 2022
- Replace the `Mega Drive Setup.asm` include and all code from `GameProgram` to `MainGameLoop` with the contents of Streamlined Sonic 1 Init HB 2022.asm.
- Delete the same instruction and subroutines and  as for Sonic 1 AS, except that `SoundDriverLoad` is named `DacDriverLoad` instead.

### Sonic 2 

#### AS 
- Replace everything from `EntryPoint` to `MainGameLoop` with the contents of `Streamlined Sonic 2 Init AS.asm`.
- Delete `CheckSumError`, `VDPSetupGame`, `JoypadInit`, `SoundDriverLoad`, and `DecompressSoundDriver` up to the `SaxDec_Loop` label, as all of their
functionality is incorporated into the new init code. (If you fail to do this, you will get a duplicate label/multiply defined error for movewZ80CompSize.

#### OrnNv 
- Essentially the same as Sonic 2 AS, except the file you need is `Streamlined Sonic 2 Init Orion.asm`. 