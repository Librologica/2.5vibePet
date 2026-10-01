# PET pipeline

`build.py` generates specialized assembly and tables. No 3Dvibe64 mesh pipeline
is included: no vertex transforms, polygon clipping, face sorting or triangle
fill. `src/reference` retains shared DDA, exact product, simulation, world and
navigation code. PET adaptation/composition live in `src/pet-runtime.asm`.

40 rays centred in horizontal character cells, camera-plane atan offsets at
60° FOV, yaw modulo 512. Local coordinates Q8.8; unsigned Q8.8 direction-component
reciprocals, $FFFF sentinel for parallel axes. DDA uses additions, comparisons
and map reads, at most 64 steps. Corner ties step X before Y. Distance
accumulators saturate to $FFFF, never wrap. Exact quarter-square multiplication
is used for setup and perpendicular depth.

16-bit Q8.8 depth for 40 rays, not 80 independent depths. 512-entry Q5.4 projection
index saturates to 511 beyond 31.9375 cells. 44 vertical samples; near-wall tables
clip the original wall instead of rescaling its visible part. 42 deduplicated
white/checker vertical profiles.

Doors are passable upper volumes (material 9). Entry top and exit lower edge are
recorded, at most eight lintels per ray. The ninth becomes a safe opaque wall.
Shade belongs to the actual portal hit side, not the background wall.
Material 1 means wall, 0 means free space.

The compositor overlays lintels on the wall profile and translates vertical
sample pairs to ROM codes. Mixed boundaries use exact white half-blocks, not
alphabetic glyphs outside the surface. Solid walls, 50% sides, 6.25% floor are
coverage patterns, not actual colours or dynamic lighting. Both horizontal
halves share samples: independent horizontal detail is limited to 40 rays.

VIA T1 IRQ at 50 Hz queues ticks; it neither renders nor touches DDA scratch.
Main consumes ticks, updates world/collisions, latches one pose, renders 880
cells into the back screen, waits for retrace and copies 1000 bytes.
PET has no VIC-II page flip: software completion yes, atomicity no.
FPS update every 50 ticks and count only new completed views.
