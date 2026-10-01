# Pipeline PET

`build.py` genera assembly specializzato e tabelle. Nessuna pipeline mesh di
3Dvibe64 viene inclusa: niente trasformazione vertici, clipping poligonale,
ordinamento facce o fill triangoli. `src/reference` conserva codice condiviso
per DDA, prodotto esatto, simulazione, mondo e navigazione. L'adattamento PET
e il compositore risiedono in `src/pet-runtime.asm`.

40 raggi centrati nelle celle orizzontali, offset atan del piano camera a FOV
60°, yaw modulo 512. Coordinate locali Q8.8; reciproci delle componenti direzione
Q8.8 unsigned, $FFFF sentinella per asse parallelo. Il DDA avanza per somme,
comparazioni e letture mappa, con massimo 64 passi. Parità d'angolo: X prima
di Y. Accumulatori distanza saturano a $FFFF; nessun wrap numerico.
Prodotto esatto quarter-square per setup e profondità perpendicolare.

Profondità Q8.8 a 16 bit per 40 raggi; non promette 80 profondità indipendenti.
Indice proiezione Q5.4 a 512 voci, saturazione a 511 oltre 31,9375 celle.
44 campioni verticali; tabella conserva clipping della parete vicina, non
riscalatura della sola parte visibile. 42 profili deduplicati bianchi/retinati.

Le porte sono volumi superiori attraversabili (materiale 9). Si registrano
top d'ingresso e limite inferiore d'uscita, fino a otto architravi per raggio.
Il nono diventa una parete opaca sicura. La tonalità dipende dal lato effettivo
del portale, non dalla parete dietro. Materiale 1 parete, 0 spazio libero.

Il compositore sovrappone architravi al profilo della parete e traduce coppie
verticali in codici ROM. Il contorno misto usa esatti mezzi blocchi bianchi:
nessun glifo alfabetico oltre la superficie. Pareti piene, lati al 50%, pavimento
al 6,25%; non sono colori o illuminazione dinamica. La cella conserva gli stessi
campioni su entrambe le metà orizzontali: dettaglio orizzontale limitato a 40 raggi.

IRQ VIA T1 a 50 Hz; accoda tick, non renderizza e non modifica scratch DDA.
Il main consuma i tick, aggiorna mondo e collisioni, acquisisce una sola posa,
renderizza 880 celle nel back screen, attende il retrace e copia 1000 byte.
Il PET non ha il page flip VIC-II: completamento software sì, atomicità no.
FPS aggiornati su 50 tick, solo viste nuove; nessun frame duplicato contato.
