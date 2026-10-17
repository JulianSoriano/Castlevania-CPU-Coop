# Castlevania CPU Co-op Mod

> ## Credits: the co-op mod is MateriaShrine's
> **The original NES Castlevania co-op ROM hack was created entirely by [MateriaShrine](https://github.com/MateriaShrine). All credit for the co-op mod goes to them.**
> This project is only an *addition* on top of their work. Without MateriaShrine's co-op patch, none of this would exist. Please support their work.

## What this is

A CPU-controlled Player 2 for MateriaShrine's NES Castlevania co-op ROM hack (CPU partner mod by RAMENPHOLIFE).

- The CPU follows you closely while you are alive.
- When you are dead, the CPU carries on by itself (walks, climbs stairs, jumps, fights, collects items) until you respawn.
- The CPU recovers health from hearts (small heart = 1 bar, big heart = 3 bars).
- Spikes do heavy damage instead of instant death, and respawn takes about 2 seconds.
- The title screen credits both authors: "COOP MOD BY MATERIASHRINE" / "CPU MOD BY RAMENPHOLIFE".

The CPU only does its own thing when you are dead, and levels end when the human player reaches the exit door, so the CPU alone can't finish a level.

## How to use

This repository contains **only the patch and source code, no ROMs**.

1. Get MateriaShrine's Castlevania Co-op ROM (from their release).
2. Apply `patch/Castlevania_CPU_Co-op_Mod_v8.ips` to that ROM with any IPS patcher (for example Floating IPS).
3. Play it in an NES emulator.

The patch is made against MateriaShrine's co-op ROM, not the unmodified Konami game.

## Contents

- `patch/` : the IPS patch (v8)
- `src/` : CPU partner code (`tactics.s`, `nav.inc`, `stairs.inc`, `masks.inc`), build scripts (`build8.py`, `lives.py`, `title.py`) and config files. Assembled with ca65/ld65 (cc65). The build script expects the co-op ROM saved as `orig.nes`; its file paths are from the author's machine and will need adjusting.

## Credits and thanks

- **MateriaShrine**: created the original NES Castlevania co-op mod. All credit for the co-op mod goes to them.
- **RAMENPHOLIFE**: CPU partner mod (this repository).
- Castlevania is a trademark of Konami. This is an unofficial fan project and is not affiliated with Konami.
