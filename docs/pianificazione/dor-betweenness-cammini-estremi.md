<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Betweenness con molti cammini minimi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-174 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di implementazione complementare alle altre chat |
| Riferimenti | GS-MET-001-16; GS-STD-001-12; GS-STD-001-16; GS-STD-001-29; GS-VER-173; RF-039; RQ-008; RQ-009; RQ-063 |

| Voce | Accettazione |
| --- | --- |
| tracciabilità | GS-VER-174; CMP-178; norma 16, test e benchmark nello stesso incremento. |
| outcome e confini | Restituire la centralità diretta non pesata finita anche quando il numero di cammini minimi supera Double.max; sola betweenness e helper privati |
| difetto riproducibile | Sorgente e 1026 livelli da due nodi completamente collegati fra livelli: contatori infiniti e rapporti Inf/Inf, pur con score esatti finiti |
| contratto scientifico | Brandes, distanza hop, connessioni a peso zero, deduplicazione paralleli, esclusione self-loop e ordine delle riduzioni invariati |
| failure semantics | API pubblica non throwing e identità Betweenness-v1 invariate; nessuna nuova dipendenza, backend o formato; niente clamp o punteggi fittizi |
| percorso ordinario | Stesse somme e divisioni binary64 quando i contatori sono rappresentabili; recupero degli estremi soltanto quando necessario |
| numerica degli estremi | Contatori con rappresentazione scalata interna; prodotto quota-dipendenza senza perdere contributi rappresentabili per underflow prematuro |
| verifica | RED sul codice precedente; formula chiusa indipendente sui DAG stratificati, piccoli grafi esaustivi, riferimenti legacy bitwise e prove non simmetriche |
| prestazioni | Harness e baseline Release prima della patch produttiva; tre topologie ordinarie con input/output completi e condizioni di misura dichiarate |
| ownership | Core: sola betweenness in GlifiNetworkAnalysis; verifica: nuovo file test; misure: benchmark dedicato; coordinatore: registri, integrazione e gate |
| esclusioni | GUI, nuovi operatori analitici, MDS/SOM/LDA, annotazione linguistica, Accelerate, Metal, file reader, runtime macOS, sort e lavoro delle altre chat |
| dati e migrazioni | Soli grafi sintetici; nessun dato reale o migrazione |
| uscita | Revisione indipendente, test mirati, make verify completo, evidenze e pulizia; nessuna promozione scientifica o chiusura G4 |

**Ready** registrata sulla base pubblicata `b59292f`, prima dei cambiamenti
implementativi. Il worktree isolato preserva le modifiche non committate
delle altre chat; i registri comuni hanno un solo integratore.

## Esito del lotto

Implementazione e verifiche funzionali concluse nel gate congiunto di
[GS-VER-174](../evidenze/GS-VER-174-betweenness-cammini-estremi.md), con 637 test
e tutte le build previste. Le misure sotto contesa non attestano prestazioni
isolate; i limiti specifici restano nelle rispettive evidenze. Nessuna promozione
scientifica, audit grafico o gate su dispositivo viene chiuso da questo lotto.
