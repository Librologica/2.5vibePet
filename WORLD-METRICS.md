# World and memory / Mondo e memoria

## Italiano

Non è previsto un parser scena JSON. I parametri pubblici di build sono
`--run auto|interactive`, `--seed` intero unsigned a 32 bit e `--out` directory
nuova. Seed di riferimento `0x251c2026`. `src/reference/world.py` contiene il
modello host deterministico; modifiche al mondo richiedono coerenza con
`world-runtime.asm` e nuova qualificazione, non modifica degli hash di riferimento.

Coordinate interne in celle: X verso destra, Y verso il basso nella mappa;
yaw 0 verso +Y, 128 verso +X. Posa iniziale (20,5;20,5), yaw 0. Camera a metà
dell'altezza della parete. Movimento massimo 6/256 cella/tick; raggio collisione
48/256 cella, test separato sugli assi per scorrimento. La mappa 40×40 trasla
quando la camera passa dalla regione centrale; origine globale modulo 2^32.
Nessuna cronologia illimitata in RAM: stesso seed/coordinate ricostruisce le celle.

## English

There is no JSON scene parser. Public build options are `--run auto|interactive`,
unsigned 32-bit `--seed`, and new output directory `--out`. Reference seed
`0x251c2026`. `src/reference/world.py` is the deterministic host world model;
world changes require agreement with `world-runtime.asm` and fresh qualification,
not changes to reference hashes to hide divergence.

Internal coordinates are cells: X right, Y down the map; yaw 0 faces +Y,
128 faces +X. Initial pose (20.5,20.5), yaw 0, camera at half wall height.
Movement at most 6/256 cell per tick; square collision radius 48/256 cell,
axis-separated sliding. The 40×40 map shifts around the camera; global origin
wraps modulo 2^32. No unbounded history in RAM: seed/coordinates regenerate cells.

## Memory map / Mappa memoria

| Range | Purpose / Funzione | Bytes |
|---|---|---:|
| $0401… | BASIC SYS 4096 stub | 12 |
| $1000…code_end | Code + state auto / interactive | 5828 / 5887 |
| $3000–$363F | Resident map / Mappa residente | 1600 |
| $3700–$3AFF | Descriptor reservation (960 used) / Riserva descriptor | 1024 |
| $3B00–$3EE7 | Back screen / Schermo software | 1000 |
| $4000–$6D3F | Tables + profiles + door shade / Tabelle e profili | 11584 |
| $6D40–$7FFF | Upper free margin / Margine superiore | 4800 |
| $8000–$83E7 | Hardware screen / Schermo hardware | 1000 |
| $0100–$01FF | Stack | 256 |

PRG: 26945 bytes including load header and layout padding / inclusi header e padding.
Table bytes include alignment; unused holes below $6D40 are not counted as upper
margin / i buchi inferiori non sono conteggiati nel margine superiore.
Character ROM is external, not loaded into RAM or distributed / ROM esterna.
