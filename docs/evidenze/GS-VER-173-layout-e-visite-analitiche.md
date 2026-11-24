<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-173 — Layout e visite dei kernel analitici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-173 |
| Tipo | Evidenza di ottimizzazione misurata |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con quattro agenti concorrenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Iterazione esplicita di ottimizzazione |
| Riferimenti | GS-DOR-173; GS-VER-172; GS-STD-001-17; GS-MET-001-15; GS-MET-001-16; GS-MET-001-21; RQ-008; RQ-009; RQ-063 |

## Perimetro

Base pubblicata `f6bba3e`, che include gli incrementi precedenti. Il worktree
isolato conserva i cambiamenti applicativi integrati e limita questo incremento
a layout delle trasposte NMF, centralità armonica non pesata e visita dell'ultimo
blocco moving-block bootstrap. API pubbliche, formule, identità e formati restano invariati.
Brandes non è interessato dal cambiamento e non riceve nuove garanzie numeriche.

## Protocollo

Eseguibile Release e inventario SHA-256 dei sorgenti archiviati prima dei kernel.
Nove workload sintetici deterministici: tre NMF (ordinario, wide, tall), tre
grafi (sparso, catena irregolare, componenti/isolati), tre bootstrap (blocco quasi
intero, coda parziale, blocco unitario). Un warm-up e cinque campioni, configurazioni
esplicite. Setup e checksum completi di input e ultimo risultato fuori timer;
non vengono confrontate singolarmente tutte le chiamate precedenti.

Ogni confronto finale esegue baseline e candidato in sequenza dopo una finestra
quiet, con supervisione dei processi di compilazione/misura. Mediana, min/max e
picco RSS dell'intero processo registrati separatamente. Hardware, toolchain,
stato termico e alimentazione nei report; nessuna preferenza di sistema modificata.
Nessuna soglia di rilascio o promozione scientifica introdotta. Energia, UI,
I/O fisico e hardware di riferimento restano fuori dal confronto locale.

## Contratti e riferimenti funzionali

NMF conserva `W`, `H`, trasposta di `W` e buffer dei prodotti. Soltanto le
trasposte di `X` e `H` sono flat: viste contigue in prestito, accessi in sola
lettura confinati al lifetime del buffer e dimensioni verificate prima della
vista. Quoziente e resto provano le dimensioni senza moltiplicazioni intere
potenzialmente traboccanti. Inizializzazione, restart, aggiornamento di H prima di W,
epsilon, riduzioni, stopping, obiettivo e storia conservano il medesimo ordine.

HarmonicCloseness risolve le identità una volta, riusa coda/distanze e ripristina
soltanto i nodi visitati. I self-loop sono esclusi e i paralleli deduplicati
come prima; anche gli archi di peso zero sono connessioni. La somma finale segue
l'ordine dichiarato dei nodi, non la BFS: una fixture distingue i due ordini di
un ULP. Cinque test includono confronto bitwise legacy, identità in collisione,
Unicode, componenti e Floyd–Warshall indipendente su tutti i 4096 digrafi semplici
di quattro nodi. Brandes e la sua API non sono modificati.

Moving-block visita soltanto `min(L,n-drawn)` osservazioni del blocco estratto.
Con `L=1` delega al bootstrap indipendente dopo le validazioni MBB: stessi indici
casuali, somme, quantili tipo 7, checkpoint e metadati. Il riferimento indipendente
riproduce il precedente ciclo, PRNG e quantili: 612 configurazioni, 180 confronti
con il bootstrap indipendente, 48 casi aggiuntivi con zeri con segno, subnormali
e offset; coda lunga, input invalidi e precedenza degli errori su task cancellati.
NMF estende il riferimento scalare a 84 combinazioni e quattro combinazioni
forma/rango con restart; nessuna tolleranza è stata allargata.

Il lotto mirato finale ha superato **13 test** in 1,197 s, exit 0. I controlli
statici documentali, conformità, profilo Apple e tassonomia/messaggi delle failure
sono passati. La modalità benchmark rifiuta Debug con exit 64 e messaggio su stderr.

## Misure finali

Host Mac16,3, 16 GiB, 10 CPU logiche, macOS 27.2.1 (26B131), Xcode 27.2
(27B52), Swift 6.4.2. Alimentazione AC e Low Power Mode attivo, senza modificarne
la configurazione. Tutte le sezioni dichiarano termica nominale. Due passate
paired valide, `attempt-3` e `attempt-4`; valori separati delle mediane e inviluppo
min–max delle due passate, senza mediana aggregata. Tempi in millisecondi.

| Caso | Mediane prima | Min–max prima | Mediane dopo | Min–max dopo | Prima/dopo |
| --- | ---: | ---: | ---: | ---: | ---: |
| `storage-nmf-120x240-rank3` | 14.839 / 14.795 | 14.785–14.905 | 14.626 / 14.619 | 14.588–14.680 | 1.012–1.015× |
| `storage-nmf-16x20000-rank4` | 163.587 / 163.242 | 163.113–164.653 | 156.580 / 156.595 | 156.493–156.674 | 1.042–1.045× |
| `storage-nmf-20000x16-rank4` | 174.496 / 174.472 | 174.038–175.046 | 175.736 / 175.726 | 175.391–178.360 | 0.993–0.993× |
| `harmonic-sparse-600x3600` | 357.488 / 360.125 | 356.699–360.598 | 12.673 / 12.660 | 12.570–12.946 | 28.209–28.445× |
| `harmonic-irregular-chain-1000` | 656.794 / 665.571 | 647.402–667.490 | 9.603 / 9.581 | 9.553–9.636 | 68.397–69.470× |
| `harmonic-components-1200-isolates300` | 232.494 / 234.504 | 231.144–235.630 | 5.913 / 5.904 | 5.889–5.941 | 39.317–39.720× |
| `moving-block-bootstrap-n4096-b4000-l4095` | 27.581 / 27.718 | 27.380–27.829 | 16.506 / 16.651 | 16.022–16.782 | 1.665–1.671× |
| `moving-block-bootstrap-n4096-b4000-l257` | 19.315 / 19.337 | 19.289–19.361 | 16.556 / 16.497 | 16.470–16.580 | 1.167–1.172× |
| `moving-block-bootstrap-n4096-b4000-l1` | 27.297 / 27.291 | 27.250–27.456 | 21.332 / 21.341 | 21.288–21.370 | 1.279–1.280× |

**Diciotto confronti su diciotto coincidono** per configurazione e checksum
SHA-256 completo di input e ultimo output: ogni cella W/H e storia NMF, ogni
punteggio armonico nell'ordine dei nodi, tutti i campi dell'intervallo bootstrap.
I file del benchmark sono identici alla baseline; sorgenti e binario candidato
sono identici fra le due passate. Warm-up e chiamate precedenti non sono
confrontati singolarmente.

Il tempo NMF diminuisce circa 1,2–1,4% sul caso ordinario e 4,1–4,3% sul caso largo.
**Il caso alto rallenta circa lo 0,7% in entrambe le passate**: il layout viene
mantenuto per il risparmio di memoria e i benefici misurati sulle altre forme;
non viene attribuito un guadagno di tempo alla forma alta. Harmonic migliora
28–69× nei casi dichiarati; il tempo bootstrap diminuisce circa 14–40%, incluso
L=1 (~22%). Nessuna estrapolazione ad altre distribuzioni o hardware.

| Sezione | RSS prima, passate 3 / 4 (MiB) | RSS dopo, passate 3 / 4 (MiB) |
| --- | ---: | ---: |
| factorization | 30.812 / 30.781 | 29.000 / 29.000 |
| graph | 10.641 / 10.656 | 10.641 / 10.656 |
| resampling | 8.906 / 8.906 | 9.000 / 9.000 |

Il picco dell'intero processo comprende setup e checksum, non soltanto il kernel.
NMF risparmia 1,81/1,78 MiB; grafi invariati; bootstrap aggiunge 96 KiB.

Le due passate si svolgono il 2026-11-22 dalle 08:10:36 alle 08:10:49 UTC e
dalle 08:10:54 alle 08:11:07 UTC, exit 0.
Supervisione ogni 250 ms, almeno quattro secondi consecutivi senza processi di
compilazione/test/benchmark rilevanti prima di ogni passata completa; nessuna contesa
osservata durante le due passate valide. Un tentativo precedente sovrapposto a
un benchmark estraneo è conservato in `contended-3-4-1` ed escluso dalle tabelle.
La supervisione non dimostra l'assenza di ogni possibile attività del sistema.

SHA-256 della baseline Release: `cc13020e260168d82514e266828f739345710201608c08cf29676a473063fdc6`.
SHA-256 del candidato Release: `ac2c6eeeb17d06efa34655bcd9128e1691caed3804d4e32122d2f3ad422a1b28`.
SHA-256 degli inventari dei sorgenti prima/dopo:
`e915e4cb1165994e943f21854a9914c86fbfc876c3e626852dca27f7f8e7b8ab` e
`fb2f3f1b34e9d45c26aeeaa722013762c4949d9c7755a36c244a19ae9dbcdabc`.

## Tentativi e raffinamento

I tentativi incontesi 1/2 conservano l'esperimento iniziale: buffer flat indicizzati
in NMF e loop bounded uniforme MBB. Output identici, ma NMF larga rallentava
circa l'8,5% e MBB L=1 circa il 100%. Le viste contigue readonly NMF eliminano
l'indirizzamento ripetuto nel prodotto; la delega L=1 evita il costo per ogni
singola osservazione. Le tabelle finali usano soltanto il candidato affinato.
I report iniziali restano conservati; nessuna regressione iniziale è occultata.

## Gate completo

**`make verify` concluso con exit 0 il 2026-11-22 alle 09:19 CET**, con profilo
macOS e iPadOS. Superati **430 test Core, 59 test Kit e 55 test nativi macOS**,
**544 complessivi**; il riepilogo `xcresulttool` conferma 55 passati, zero falliti
e zero saltati (195 esecuzioni native includendo i parametri dinamici).
Superate 185 righe di oracoli numerici riprodotte e collegate ai test Swift,
due PDF/A-2u con veraPDF, 51 controlli CLI su 15 fixture condivise, QueryAST
e 22 checkpoint di recovery tramite process-kill.

Build Debug/Release macOS e iPadOS concluse tramite `GlifiStudio.xcworkspace`.
Nessun controllo richiesto saltato o indebolito. Documentazione, conformità e
diff-check sono stati ricontrollati con exit 0 dopo il consolidamento finale,
senza ulteriori modifiche ai kernel.

Restano gli avvisi dell'host: CoreSimulator 1171.7.0 inferiore a 1174.21.0
richiesto da Xcode e dichiarazione di apertura in-place iPadOS. Le build generiche
sono passate; non viene attribuita un'esecuzione su dispositivo o simulatore iPad.

## Pulizia e conservazione

Rimosse soltanto cache e temporanei dedicati a questa iterazione e il binario
di baseline, conservandone il digest: **2.974.212 KiB, circa 2,84 GiB**.
Restano circa 956 KiB di evidenze in `/tmp/GlifiAlgorithms173Reports`: report
iniziali/finali, tentativo conteso, mediane/minimi/massimi, RSS, supervisione,
ambiente/alimentazione, inventari SHA-256, copie dei tre kernel finali, protocollo,
log del gate e dei 13 test mirati, riepilogo nativo senza identificatori del dispositivo.
Toolchain, dipendenze, file utente e cache delle altre attività non sono stati rimossi.

## Stato e limiti

CMP-177 resta `implemented`; nessuna promozione scientifica, nuova variante o
soglia prestazionale. RQ-008/RQ-009 restano incompleti nell'ambito generale:
energia, I/O fisico, UI e hardware di riferimento non sono misurati da questi
confronti sintetici locali. Nessuna nuova garanzia numerica per Brandes.
