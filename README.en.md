# 2.5vibePet 1.0.0

Native 2.5D pipeline for a PET 4032 with stock 1 MHz 6502, 32 KB,
BASIC 4 and graphics keyboard. Monochrome graphics use ROM characters
and reverse characters: white walls, 50% side walls, 6.25% dotted floor,
black background. Contrast improves wall orientation and floor readability.

The procedural world is reconstructed in a resident 40×40-cell window,
with rooms, corridors, openings and lintelled doorways. Continuous navigation,
collision and wall sliding; reproducible seed. The 32-bit global coordinates
make the world practically unbounded, not mathematically infinite.

The viewport is 40×22 characters below three UI rows: 80×44 nominal samples,
but 40 independent rays (each ray covers one horizontal character cell).
60° FOV, 512 directions, fixed-point DDA, perpendicular depth,
precomputed vertical profiles, one camera pose latched per complete view.

Open [demos/infinite-auto.prg](demos/infinite-auto.prg) or
[demos/infinite-interactive.prg](demos/infinite-interactive.prg).
W/S forward-backward, A/D turn; reset to exit. No audio.
The counter counts only newly completed views.

See [QUICKSTART.md](QUICKSTART.md), [PIPELINE.en.md](PIPELINE.en.md),
[ASSEMBLY-GUIDE.en.md](ASSEMBLY-GUIDE.en.md), [WORLD-METRICS.md](WORLD-METRICS.md),
[TESTING.md](TESTING.md) and [RELEASE-RESULTS.md](RELEASE-RESULTS.md).

Limits: one level, uniform walls, no texture mapping, Gouraud, dynamic light,
3D sprites or polygon rasterizer. Double buffering is software: completed
views are copied at retrace, not atomically page-flipped. Absence of transient
CRT tearing is not qualified. Tested in VICE xpet, not on a physical PET.
PET 2001/3000, business-keyboard 4032B and 80-column 8032 are not qualified.

Build requires Python + 64tass and a separately installed PET graphics ROM.
No ROMs or emulator executables are distributed.
Software PolyForm Noncommercial 1.0.0; documentation CC BY-NC 4.0.
Retain attribution in [NOTICE.md](NOTICE.md).
