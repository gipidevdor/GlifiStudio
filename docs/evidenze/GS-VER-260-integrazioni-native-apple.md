<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-260 — Integrazioni native Apple coordinate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-260 |
| Tipo | Evidenza di integrazione, correttezza e misure |
| Versione | 1.0.0 |
| Stato | In verifica |
| Responsabile | Iniziatore del progetto, con supporto Codex |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di valutare e integrare le tecnologie Apple appropriate rispettando le altre chat |
| Riferimenti | GS-DOR-260; GS-APL-016; ADR-0040; CMP-261/262/264 |

## Perimetro

Lotto isolato dalla baseline `02c1c66`: reader Foundation delle fonti esterne,
attività finita del piano macOS e comandi di sistema. Il candidato sort Accelerate
è stato valutato e scartato.
Nessun nuovo formato, entitlement, rete, modello, backend scientifico o
migrazione. La valutazione completa è in GS-APL-016, con aree assegnate alle
altre chat e tecnologie rinviate per requisiti o prove mancanti.

## Verifica

La verifica mirata del prototipo ha superato 18 test: 12 Core e 6 Kit,
compresi quattro test numerici dell’esperimento. Dopo lo scarto del candidato,
i 14 test nuovi nel prodotto riguardano letture bounded, crescita, file non
regolari, cancellazione, riuso dell’URL coordinato e ownership/reentrancy delle
attività. I quattro test numerici restano soltanto nella patch riproducibile.
`make quality-static` è superato sul lotto isolato; il gate completo sul candidato
integrato resta da concludere e non è dichiarato superato.

## Esperimento Accelerate

Il confronto finale della stessa API pubblica fra due eseguibili Release usa
quattro processi A/B e B/A, 15 casi sintetici e 480 risultati completi (warm-up
inclusi), tutti identici bitwise. Il monitor non ha osservato build, test o altri
benchmark concorrenti durante questa passata. Low Power Mode è rimasto attivo e
lo stato termico nominale; nessuna impostazione è stata cambiata.

| Caso | Swift / vDSP, passata 1 (ms) | Swift / vDSP, passata 2 (ms) |
| --- | ---: | ---: |
| Continuo 500.000 | 83,320 / 82,944 | 85,606 / 82,916 |
| Continuo 1.000.000 | 175,637 / 175,209 | 179,305 / 175,400 |
| Ripetuto 500.000 | 15,101 / 16,166 | 15,390 / 15,805 |
| Zeri in coda | 10,044 / 10,629 | 10,082 / 10,623 |
| Subnormali in coda | 8,613 / 9,227 | 8,750 / 9,215 |

Il piccolo beneficio nei casi grandi non è robusto e i fallback peggiorano.
RSS massimo del processo: 36.306.944 byte Swift e 36.323.328 vDSP (+16 KiB), senza
risparmio dimostrato. Il candidato è scartato; nessun percorso numerico, import,
soglia o flag sperimentale viene aggiunto al prodotto. Il sort Swift resta
invariato. Non sono misure energetiche o rappresentative dell’intera matrice
Mac/iPad.

[Protocollo, patch, inventari, risultati e limiti riproducibili](allegati/GS-VER-260/esperimento-sort/README.md)
conservano anche i tentativi precedenti contesi, separati da quello finale.

La prima prova reale sui file ha esposto un blocco di Foundation nell’apertura di
una FIFO prima dell’accessor; il processo di test è stato interrotto dopo il
campionamento dello stack. La correzione rifiuta tipi non regolari esistenti prima
del coordinatore e mantiene `fstat`/`O_NOFOLLOW`/`O_NONBLOCK` sul descriptor.
Il test mantiene la FIFO e verifica anche l’assenza di chiamata al coordinatore;
non è stato rimosso o indebolito. La guardia preliminare non elimina la race di
una sostituzione non cooperante nell’apertura interna di Foundation.

## Limiti

Build e test non attestano audit manuali di VoiceOver, provider, App Nap, energia
o dispositivi. Il coordinamento riguarda scrittori cooperanti e non interrompe
una chiamata sincrona già bloccata. Le prove scientifiche candidate e lo sviluppo
delle altre chat mantengono i propri stati.
