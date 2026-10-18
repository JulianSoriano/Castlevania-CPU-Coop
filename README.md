# Castlevania CPU Co-op Mod

> ## Credits: the co-op mod is MateriaShrine's
> **The original NES Castlevania co-op ROM hack was created entirely by MateriaShrine. All credit for the co-op mod goes to them.**
> This project is built on top of their work, and their co-op changes are included in the patch with permission. Without MateriaShrine's co-op mod, none of this would exist. Please support their work.

## What this is

A CPU-controlled Player 2 for NES Castlevania. Start a game and Player 2 is played by the computer.

- The CPU follows you closely while you are alive.
- When you are dead, the CPU carries on by itself (walks, climbs stairs, jumps, fights, collects items) until you respawn.
- The CPU recovers health from hearts (small heart = 1 bar, big heart = 3 bars).
- Spikes do heavy damage instead of instant death, and respawn takes about 2 seconds.
- Both players start with 9 lives.
- The title screen credits both authors: "COOP MOD BY MATERIASHRINE" / "CPU MOD BY RAMENPHOLIFE".

Levels end when the human player reaches the exit door, so the CPU alone can't finish a level.

## How to install (one patch, nothing else needed)

This is a **standalone patch**. You do **not** need MateriaShrine's co-op patch: their co-op changes are already included in this patch. This repository contains only patches and source code, no ROMs.

You need one thing: a regular, unmodified **Castlevania (USA) Rev 1** ROM.
- File size: 131,088 bytes
- MD5: `52eb3f7e2c5fc765aa71f21c85f0770e`

**Option A: any IPS patcher** (for example Floating IPS or Lunar IPS)
1. Apply `patch/Castlevania_CPU_Coop_v8.ips` to your Castlevania USA Rev 1 ROM.
2. Play the result in an NES emulator.

**Option B: the included script** (needs Python 3)
1. Run `python3 patch/apply_patch.py "Castlevania (USA) (Rev 1).nes"` (use the path to your ROM).
2. It checks that your ROM is the right one and writes `Castlevania_CPU_Coop_v8.nes` next to the script.

If the script says your ROM isn't right, you have a different version (Rev 0, another region, or a ROM with a different header). The patch only works on the exact ROM above.

The finished ROM has MD5 `10fba4c7e1e2fadd85e35c298c052228`.

## Contents

- `patch/`: the standalone IPS patch (v8) and `apply_patch.py`
- `src/`: CPU partner code (`tactics.s`, `nav.inc`, `stairs.inc`, `masks.inc`), build scripts (`build8.py`, `lives.py`, `title.py`) and config files. Assembled with ca65/ld65 (cc65). These are the author's working build scripts, and their file paths will need adjusting.

## Credits and thanks

- **MateriaShrine**: created the original NES Castlevania co-op mod. All credit for the co-op mod goes to them.
- **RAMENPHOLIFE**: CPU partner mod (this repository).
- Castlevania is a trademark of Konami. This is an unofficial fan project and is not affiliated with Konami.
