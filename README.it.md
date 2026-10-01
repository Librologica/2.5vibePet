# 2.5vibePet 1.0.0

Pipeline 2.5D nativa per PET 4032 con CPU 6502 stock a 1 MHz, 32 KB,
BASIC 4 e tastiera grafica. Grafica monocromatica ottenuta dai caratteri ROM
e dai loro inversi: pareti bianche, lati al 50%, pavimento puntinato al 6,25%,
sfondo nero. Il contrasto distingue meglio orientamento delle pareti e pavimento.

Il mondo procedurale viene ricostruito in una finestra residente 40×40 celle,
con stanze, corridoi, aperture e porte con architrave. Navigazione continua,
collisioni e scorrimento sulle pareti; seed riproducibile. Le coordinate globali
a 32 bit rendono il mondo praticamente illimitato, non matematicamente infinito.

La viewport occupa 40×22 caratteri, sotto tre righe di interfaccia: 80×44 campioni
nominali, ma 40 raggi indipendenti (ogni raggio copre una cella orizzontale).
FOV 60°, 512 direzioni, DDA fixed-point, profondità perpendicolare,
profili verticali precalcolati, posa della camera acquisita una volta per vista.

Aprire [demos/infinite-auto.prg](demos/infinite-auto.prg) oppure
[demos/infinite-interactive.prg](demos/infinite-interactive.prg).
W/S avanti-indietro, A/D rotazione; reset per uscire. Nessun audio.
Il contatore conta soltanto nuove viste complete.

Vedere [QUICKSTART.md](QUICKSTART.md), [PIPELINE.it.md](PIPELINE.it.md),
[ASSEMBLY-GUIDE.it.md](ASSEMBLY-GUIDE.it.md), [WORLD-METRICS.md](WORLD-METRICS.md),
[TESTING.md](TESTING.md) e [RELEASE-RESULTS.md](RELEASE-RESULTS.md).

Limiti: un livello, pareti uniformi, nessun texture mapping, Gouraud, luce
dinamica, sprite 3D o rasterizzatore poligonale. Il doppio buffer è software:
la copia della vista completa è sincronizzata al retrace, ma non è un page flip
atomico. Non è stata qualificata l'assenza di tearing transitorio su CRT.
Test in VICE xpet, non su PET fisico. Non qualificati PET 2001/3000,
4032B con tastiera business e 8032 a 80 colonne.

Build Python + 64tass; ROM grafica PET installata separatamente.
Il pacchetto non distribuisce ROM né emulatori.
Software PolyForm Noncommercial 1.0.0; documentazione CC BY-NC 4.0.
Conservare l'attribuzione in [NOTICE.md](NOTICE.md).
