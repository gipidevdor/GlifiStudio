<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0016 — Specifiche implementative e baseline prodotto 0.1

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0016 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Richiesta esplicita di completare il repository e impostare la costruzione con le migliori pratiche Apple |
| Fonte | Revisione progettuale fornita dall'iniziatore il 2026-09-15 |
| Sostituisce | Nessuno |

## Contesto

GS-MET-001 definisce ormai il significato delle analisi e GS-UX-001 il modello
mentale, ma dominio, persistenza, query, orchestration, runtime e interazione
restavano abbastanza aperti da trasferire decisioni fondamentali nel codice.
Creare un documento per ognuna delle venticinque lacune osservate avrebbe però
duplicato lo standard esistente e indebolito l'autorità delle fonti.

Senza un perimetro 0.1 esplicito, il catalogo scientifico completo rischierebbe
inoltre di diventare scope implicito del primo rilascio.

## Decisione

1. Si istituisce la famiglia `GS-DSG-IDX-001` di esattamente dieci specifiche:
   GS-DOM, GS-DAT, GS-LNG, GS-QRY, GS-ANA, GS-RUN, GS-UI, GS-VIZ, GS-VAL e GS-PROD.
2. Ogni specifica governa un solo concern implementativo. GS-MET conserva autorità
   su formule e metodi; GS-UX su modello mentale; lo Standard su processo,
   sicurezza, qualità, compatibilità e rilascio.
3. Il progetto persistente è un package `.glifi` v1 conforme a `UTType.package`,
   con fonti incorporate per default e riferimenti esterni soltanto espliciti.
4. SQLite di sistema è lo store relazionale canonico; oggetti grandi sono file
   immutabili content-addressed SHA-256. SwiftData non definisce il formato 0.1.
5. Lineage usa intervalli UTF-8 half-open legati a una rappresentazione e SpanMap
   versionati. Indici Swift/UTF-16 sono proiezioni, non autorità persistente.
6. Query, nodi analitici, piani e regole interpretative hanno rappresentazioni
   canoniche versionate condivise da GUI, GlifiKit e GlifiCLI.
7. Il runtime usa structured concurrency, code bounded, budget quantitativi
   conservativi, cancellation e spill controllato; i coefficienti si promuovono
   soltanto con benchmark su dispositivi.
8. La baseline 0.1 è locale, singolo utente, senza account, rete, sync o telemetria;
   supporta TXT/Markdown UTF-8 e un nucleo analitico piccolo. PDF/OCR, metodi
   avanzati e AI generativa sono post-MVP.
9. Per 0.1 il possesso del link unlisted è sufficiente a scaricare l'app: non è
   introdotta autenticazione. Il link è inoltrabile e non protegge dati; il
   prodotto locale non promette un pubblico autorizzato ristretto.
10. Security/privacy, recovery, errori, compatibility ed export restano nei capitoli
   specialistici dello Standard e sono concretizzati per rinvio dalle specifiche.
11. Una verifica automatica protegge presenza, identità, copertura minima e
    integrazione della famiglia.

## Alternative considerate

- lasciare le decisioni ai primi tipi Swift: respinto perché renderebbe il codice
  una specifica accidentale e costosa da migrare;
- venticinque documenti indipendenti: respinto per duplicazione e perdita di
  autorità;
- SwiftData come formato canonico: respinto per la baseline perché schema,
  interoperabilità e migrazioni del package devono restare sotto controllo;
- solo riferimenti esterni: respinto perché indebolisce portabilità e recovery;
- incorporazione obbligatoria senza eccezioni: respinta perché corpus enormi
  richiedono una modalità esterna esplicita;
- includere l'intero catalogo GS-MET nel primo rilascio: respinto perché impedisce
  di raggiungere completezza eccellente in tempi controllabili.

## Conseguenze positive

- implementazione e review hanno confini, invarianti e criteri di prova espliciti;
- il formato non dipende dall'ABI Swift o dal layout della UI;
- GUI e CLI condividono piano, query, risultati ed errori;
- correttezza scientifica, performance, accessibilità e App Store hanno evidenze
  distinte ma tracciate;
- il prodotto 0.1 può raggiungere completezza senza simulare capacità future.

## Conseguenze negative e rischi

- SQLite, package transaction e SpanMap richiedono prototipi e test ostili;
- i budget runtime iniziali possono risultare troppo conservativi e vanno misurati;
- il supporto PDF/OCR e molte analisi di alto valore è rinviato;
- serve disciplina per non replicare formule GS-MET o regole GS-UX;
- le decisioni sono accettate come direzione, ma le specifiche restano baseline da
  approvare ai gate e non provano l'implementazione.

## Verifica della decisione

- `Scripts/check-docs.py` richiede le dieci specifiche e i collegamenti principali;
- requisiti RF-075–RF-086 e RQ-041–RQ-048 sono tracciati a TV-050–TV-061;
- un vertical slice deve provare package, SpanMap, QueryAST, Analysis DAG e runtime;
- GS-VER-015 registra la coerenza documentale, senza dichiarare complete il codice;
- `make verify` e `make verify-app-store` devono restare verdi localmente.
