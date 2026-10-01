# Guida assembly PET

6502 documentato, compilato con 64tass `--m6502`. Nessuna REU, accelerazione,
SID o dipendenza hardware C64. Il builder adatta piccole parti dei sorgenti
riutilizzati; i file reference non vanno interpretati come runtime C64 eseguito.
Il risultato PET è `pet.asm` nella directory di build.

Entrata $1000, decimal mode disabilitato, IRQ disabilitati durante init.
PIA/VIA configurati per PET grafico; keyboard scan W/S/A/D su PIA1 $E810/$E812.
VIA T1 latch 19998 (+2 cicli), periodo 20000 cicli a 1 MHz; ACR $40,
shift register disabilitato. Vettore IRQ $0090/$0091; il prologo dell'editor
ROM BASIC4 salva A/X/Y. L'handler ripristina quei registri con PLA/RTI.
Questa dipendenza esclude editor/ROM non qualificati.

Scratch $20–$6D, puntatori $70–$77, navigazione/mondo $D5–$F0 in zero page.
Stack $0100–$01FF. Lo SMC del mondo è limitato al thread principale;
IRQ non chiama renderer/generatore e non usa quei puntatori.
Main e IRQ condividono contatori/tick, prelievo protetto con SEI/CLI.

Mappa $3000–$363F (1600 byte); descriptor $3700–$3AFF (1024 riservati,
960 allocati), back screen $3B00–$3EE7 (1000), tabelle $4000–$6D3F (11584),
margine alto $6D40–$7FFF (4800). Screen hardware $8000–$83E7; init pulisce
1 KB, la copia per vista usa soltanto 1000 byte. Codice/stato auto 5828 byte,
interattivo 5887. BASIC a $0401. Vedere WORLD-METRICS per il layout completo.

Build genera label numeriche, listing e mappa 64tass. Asserzioni `.cerror`
proteggono confini codice/mappa/descriptor/screen/tabelle. Dump xpet devono
essere acquisiti a `presentation_done`, con la posa di quel frame.
Non usare ROM/emulatori modificati per dichiarare prestazioni stock.
