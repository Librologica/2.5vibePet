# Quick start / Avvio rapido

## Italiano

VICE xpet 3.10, modello 4032 (non 4032B), 32 KB, tastiera grafica.
Avviare uno dei PRG inclusi tramite autostart. Caricamento BASIC a $0401;
avvio automatico SYS 4096. W/S movimento, A/D rotazione; reset per uscire.
Non serve un'espansione RAM esterna. Nessun audio.

Per compilare: Python 3.10+, 64tass 1.60.3243 qualificato e la ROM
`characters-2.901447-10.bin` (2048 byte), ottenuta separatamente con VICE.
Mettere 64tass e xpet nel PATH oppure impostare `TASS64_EXE`, `XPET_EXE`.
Se il percorso ROM non è rilevato, impostare `PET_CHARGEN` al file ROM.
`--out` deve indicare una directory nuova; non compilare sopra il pacchetto congelato.

```text
python -B build.py --run auto --seed 0x251c2026 --out ../pet-build-auto
python -B build.py --run interactive --out ../pet-build-interactive
python -B tests/run.py
python -B tests/run.py --emulator
```

Il runner lavora in una copia temporanea e stampa il percorso degli artefatti.
Per 50/60 Hz usare anche l'editor ROM corretto: `edit-4-40-n-50Hz.901498-01.bin`
oppure `edit-4-40-n-60Hz.901499-01.bin`. Il solo flag PAL/NTSC non basta
a identificare la temporizzazione CRTC. Vedere TESTING.

## English

VICE xpet 3.10, model 4032 (not 4032B), 32 KB, graphics keyboard.
Autostart either included PRG. BASIC load address $0401; automatic SYS 4096.
W/S move, A/D turn; reset to exit. No external RAM expansion required. No audio.

Build: Python 3.10+, qualified 64tass 1.60.3243 and the separately installed
2048-byte `characters-2.901447-10.bin` graphics ROM. Put 64tass/xpet on PATH
or set `TASS64_EXE`, `XPET_EXE`. Set `PET_CHARGEN` if ROM discovery fails.
Use the commands above. `--out` must be new; never build over a frozen package.
The runner uses a temporary SDK copy and prints the artifact directory.

For 50/60 Hz also select the corresponding editor ROM listed above.
The PAL/NTSC flag alone does not identify CRTC timing. See TESTING.
