# Testing / Test

## Italiano

`python -B tests/run.py` verifica manifest, contratti numerici e ricompilazione
byte-identica di entrambi i PRG, in una copia temporanea. Artefatti conservati
fuori dall'SDK originale. `--emulator` aggiunge 120 viste 50 Hz e 120 viste 60 Hz,
20 pose angolari/near-axis e quattro override movimento/rotazione.
Una verifica senza xpet NON è qualificazione del runtime; il runner segnala
NOT RUN senza `--emulator`, oppure fallisce per dipendenza assente se richiesta.
L'editor stock 60 Hz non viene riconosciuto per autostart da VICE 3.10:
il test attende il primo IRQ ROM a $E442 dopo init video e usa il monitor
per caricare il PRG a $0401 e avviare $1000, con stack reinizializzato.
Non modifica ROM o renderer. L'autostart 60 Hz non è quindi qualificato.

Dipendenze: Python, 64tass, VICE xpet e ROM installate separatamente.
Variabili opzionali: `TASS64_EXE`, `XPET_EXE`, `PET_CHARGEN`, `PET_EDITOR_PAL`,
`PET_EDITOR_NTSC`, `PET_TEST_OUT`. Il runner seleziona esplicitamente editor
50/60 Hz e modello 4032; su installazioni non Windows impostare i percorsi ROM.
I test principali non richiedono Pillow. Nessun test su hardware reale incluso.

Host: 16 combinazioni geometriche dei glifi, 512 direzioni, 40 offset del piano
camera, 8144 profondità, contorni misti esatti. La quantizzazione proiezione è
limitata a due righe logiche dal contratto (massimo osservato riportato nei risultati).
Runtime: dump RAM, mondo rigenerato host, DDA/depth/materiale/lato/passi,
intervalli e shade architravi, back screen e Screen RAM. Modello host strutturato
diversamente dal loop assembly; non prova tutta la geometria continua possibile.

Profilazione: trace `render_frame_begin`, `geometry_done`, `render_frame_end`,
`presentation_done`; due secondi emulati di warm-up, finestra 20 secondi.
CPU nominale 1 MHz, UI e contatore inclusi. Warp accelera solo l'host;
non si usa il tempo host per FPS. Il profilo distingue geometria, composizione e
presentazione, non tutti i singoli costi IRQ/simulazione. La latenza input e il
tearing CRT non sono qualificati. Override testano il contratto simulazione,
non la pressione fisica dei tasti del PET.

## English

`python -B tests/run.py` verifies manifest, numeric contracts and byte-exact
rebuild of both PRGs in a temporary copy, retaining artifacts outside the SDK.
`--emulator` adds 120 views at 50 Hz and 120 at 60 Hz, 20 angle/near-axis poses
and four movement/rotation overrides. Without xpet this is NOT runtime
qualification: NOT RUN without the flag, missing-dependency failure if requested.
VICE 3.10 does not recognize the stock 60 Hz editor for autostart. That test
waits for the first ROM IRQ at $E442 after video initialization, then uses the
monitor to load the PRG at $0401 and enter $1000 with the stack reinitialized.
Neither ROM nor renderer is patched. 60 Hz autostart is therefore not qualified.

Dependencies: Python, 64tass, VICE xpet and separately installed ROMs.
Optional environment variables are listed above. The runner explicitly chooses
50/60 Hz editor ROMs and model 4032; set ROM paths on non-Windows installations.
Main tests do not need Pillow. No physical hardware test is included.

Host checks cover 16 geometric glyph combinations, 512 directions, 40
camera-plane offsets, 8144 depths and exact mixed boundaries. Projection
quantization contract allows at most two logical rows (observed maximum in results).
Runtime checks compare RAM dumps, regenerated host world, DDA/depth/material/
side/steps, lintel intervals/shade, back screen and actual Screen RAM. The host
model is structured differently from assembly; this does not prove all continuous
geometry. Main numeric and frame references are never silently updated.

Profiling uses the four trace points above, two emulated seconds of warm-up
and a 20-second window. Nominal 1 MHz CPU, UI/FPS included. Warp affects only
host execution, never the FPS calculation. Geometry/composition/presentation
are separated, not every IRQ/simulation cost. Input latency and CRT tearing
are unqualified. Overrides test simulation, not real physical keyboard input.
