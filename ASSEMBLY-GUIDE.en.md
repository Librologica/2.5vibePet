# PET assembly guide

Documented 6502 instructions, assembled with 64tass `--m6502`. No REU,
acceleration, SID or C64 hardware dependency. The builder adapts small sections
of reused source; reference files are not the C64 runtime actually executed.
Generated PET source is `pet.asm` in the build output directory.

Entry $1000, decimal mode cleared, IRQ disabled during initialization.
PIA/VIA configured for graphics PET; W/S/A/D scanned through PIA1 $E810/$E812.
VIA T1 latch 19998 (+2 cycles), 20000-cycle period at 1 MHz; ACR $40,
shift register disabled. IRQ vector $0090/$0091; BASIC4 editor ROM prologue
saves A/X/Y. Handler restores them with PLA/RTI. Unqualified editor/ROMs
are excluded by this dependency.

Zero-page scratch $20–$6D, pointers $70–$77, world/navigation $D5–$F0.
Stack $0100–$01FF. World self-modifying code is main-thread only;
IRQ never calls renderer/generator and does not use their pointers.
Main/IRQ share counters/ticks with SEI/CLI-protected dequeue.

Map $3000–$363F (1600 bytes); descriptors $3700–$3AFF (1024 reserved,
960 allocated), back screen $3B00–$3EE7 (1000), tables $4000–$6D3F (11584),
upper margin $6D40–$7FFF (4800). Hardware screen $8000–$83E7; initialization
clears 1 KB, each view copies only 1000 bytes. Auto code/state 5828 bytes,
interactive 5887. BASIC at $0401. Full layout in WORLD-METRICS.

Build produces numeric labels, listing and 64tass memory map. `.cerror`
assertions protect code/map/descriptors/screen/table boundaries.
Capture xpet dumps at `presentation_done`, using that frame's latched pose.
Do not use modified ROMs/emulators to claim stock performance.
