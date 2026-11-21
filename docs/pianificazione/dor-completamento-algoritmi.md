<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Completamento degli algoritmi analitici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-168 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di continuare e completare tutti gli algoritmi di analisi |
| Riferimenti | RF-026; RF-028; RF-037; RF-038; RF-040; RF-041; RF-042; RF-045; RQ-008; RQ-063 |

## Contratto dell'incremento

Completare i metodi con formula normativa già definita e le primitive headless
di raggruppamento temporale e valutazione linguistica. Sono comprese distribuzioni
lessicali, crescita del vocabolario, fitting diagnostico Zipf/Heaps, statistiche
descrittive, Welch ANOVA, TextRank/LexRank, taglio HAC a soglia e chiusura dei
contratti numerici di clustering, NMF e correlazione.

Le nuove famiglie in memoria conservano variante, parametri, ordine e identità
degli input; GlifiKit espone facciate concorrenti senza dipendenze di GlifiCore
dalle app. Nessun nuovo formato di progetto, backend NLP, dipendenza o servizio
di rete. Non sono comprese estensioni future prive di formula approvata
(t-SNE/UMAP, embedding neurali, Zipf–Mandelbrot stimato) né la promozione automatica
di nuovi metodi nella UI o nel planner persistente.

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Algoritmi con formula normativa e primitive headless descritte sopra; nessuna promozione automatica della superficie di prodotto |
| failure semantics | Input invalidi, dati insufficienti, overflow e budget superati producono GlifiFailure; nessuna correzione silenziosa |
| dati mancanti | Esclusioni, denominatori nulli e date civili/istanti hanno policy esplicite |
| verifica | Oracoli R indipendenti, casi esatti, proprietà, input ostili, cancellazione e parità Core/Kit; `make verify` prima della consegna |
| prestazioni | Conteggi incrementali, input bounded, cancellazione nei cicli e nessun calcolo sul Main Actor dalla facciata |
| tracciabilità | GS-VER-168, requisiti, matrice, registro evidenze e CHANGELOG aggiornati insieme |
| limiti scientifici | Nessuna review umana simulata; validazione empirica NLP, V6 e audit su dispositivo restano distinti |

**Ready** prima del primo cambiamento implementativo.

## Esito

Implementazioni e verifiche completate in
[GS-VER-168](../evidenze/GS-VER-168-completamento-algoritmi.md): gate completo
superato, 431 test e 152 righe di oracoli. Le nuove famiglie headless restano
candidate; integrazione nel prodotto, validazione empirica e promozione scientifica
seguono i gate propri.
