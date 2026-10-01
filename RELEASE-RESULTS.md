# 1.0.0 qualification / Qualificazione

2026-10-01. Python 3.13, 64tass 1.60.3243, VICE 3.10 xpet, PET4032/32 KB,
stock 1 MHz. UI and FPS active / UI e FPS attivi. No audio / nessun audio.

| Check / Verifica | Result / Risultato |
|---|---|
| Auto + interactive clean rebuild / Ricompilazione pulita | Byte-identical to frozen readability PRGs / identica ai PRG congelati |
| Host glyph/direction/projection contracts | PASS: 16 glyph combinations, 512 directions, 40 offsets, 8144 depths |
| Projection error / Errore proiezione | Observed max 1 logical row; contract ≤2 / massimo osservato 1 riga |
| Actual 50 Hz views / Viste effettive 50 Hz | PASS: 120 |
| Actual 60 Hz views / Viste effettive 60 Hz | PASS: 120 |
| Near-axis angle sweep / Sweep angoli | PASS: 20 poses / pose |
| Input override / Override input | PASS: 4 directions × 4 views / direzioni × viste |
| World, DDA, depth, lintel shade, screen dumps | Zero differences against fixed host model / zero differenze col modello host |
| Physical PET and keyboard / PET e tastiera fisici | NOT TESTED / NON TESTATI |
| Transient copy tearing / Tearing transitorio | NOT QUALIFIED / NON QUALIFICATO |
| 60 Hz VICE autostart | Unavailable with unrecognized editor; monitor load used / editor non riconosciuto, avvio da monitor |

## Measured performance / Prestazioni misurate

Two-second emulated warm-up, 20-second emulated window; one run per standard.
Due secondi emulati di warm-up, finestra emulata 20 s; una prova per standard.
Time from emulated CPU cycles, not host wall time / tempo da cicli CPU emulati.

| Metric / Metrica | 50 Hz | 60 Hz |
|---|---:|---:|
| Complete views / Viste complete | 95 | 96 |
| FPS | 4.75 | 4.80 |
| Mean presentation interval, cycles / Intervallo medio | 209575 | 208915 |
| Median / Mediana | 199996 | 199793 |
| p95 | 280007 | 282954 |
| Worst / Peggiore | 339997 | 333098 |
| Geometry mean / Geometria media | 101985 | 101734 |
| Composition mean / Composizione media | 54903 | 54849 |
| Presentation mean / Presentazione media | 20685 | 20340 |

Intervals include between-view simulation/world updates; phase means do not
sum to the entire interval. No claim of steady 5 FPS or physical hardware speed.
Gli intervalli includono simulazione/streaming fra viste; le fasi non sommano
all'intero intervallo. Non si dichiara 5 FPS stabili né velocità su hardware reale.

50 Hz editor `edit-4-40-n-50Hz.901498-01.bin` produces 20000 cycles/refresh.
60 Hz editor `edit-4-40-n-60Hz.901499-01.bin` produces 16650 cycles/refresh
(60.060 Hz). Simulation remains 50 logical ticks/s via VIA T1 in both cases.
Entrambe le ROM sono esterne; il timer simulazione resta a 50 tick/s.

PRGs: 26945 bytes each / byte ciascuno. Tables / tabelle 11584 bytes;
upper free margin / margine alto 4800 bytes. See / vedere WORLD-METRICS.
Reference SHA-256 values are in PACKAGE-MANIFEST.json and MANIFEST.sha256.
Hash SHA-256 di riferimento in PACKAGE-MANIFEST.json e MANIFEST.sha256.
