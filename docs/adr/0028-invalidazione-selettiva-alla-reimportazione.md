<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0028 — Invalidazione selettiva degli Artifact all'importazione di fonti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0028 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-19 |
| Data decisione | 2026-09-20 |
| Approvazione | Opzione 2 accettata esplicitamente dall'iniziatore (DA-033 chiusa) |
| Integra | GS-MET-001-02, GS-DAT-001, ADR-0013 |
| Sostituisce | Nessuno |

## Contesto

GS-MET-001-02 richiede che la modifica di un nodo invalidi transitivamente **soltanto** i
discendenti che dipendono dal significato modificato, e che i nodi validi non coinvolti siano
riusati. Oggi ogni importazione produce una generazione senza Artifact: tutti i descrittori usano
come `corpusVersionDigest` il digest radice dell'intera raccolta e il package verifica,
all'apertura e al commit, che ogni Artifact abbia `corpusVersionDigest` uguale al digest radice
della propria generazione (`project.artifact-corpus-mismatch`). Un'analisi su due documenti viene
quindi ricalcolata anche quando si importa un terzo documento estraneo.

Le SourceRevision sono immutabili e append-only (GS-VER-125): un'analisi che dipende soltanto da
revisioni selezionate resta valida dopo l'importazione di altre revisioni.

## Opzioni

1. **Stato attuale**: invalidazione totale a ogni importazione. Corretta ma contraria al requisito
   di invalidazione selettiva e costosa sui corpus grandi.
2. **Selezione esplicita nel descrittore (raccomandata)**: `GlifiAnalysisDescriptor` acquisisce
   `sourceRevisionIDs` ordinati canonicamente; `corpusVersionDigest` diventa il digest delle sole
   revisioni dichiarate. L'invariante del package diventa: ogni revisione dichiarata esiste nella
   generazione e il digest coincide con quello ricalcolato su quelle revisioni. All'importazione il
   commit conserva gli Artifact validi per questo invariante e i loro dipendenti la cui catena di
   dipendenze resta valida; piani, interpretazioni e profili della raccolta intera dichiarano
   tutte le revisioni e sono quindi invalidati, come richiesto.
3. **Indice separato di dipendenze dalle fonti** fuori dal descrittore: evita di cambiare
   l'identità dei nodi ma sposta l'autorità fuori dal descrittore firmato e richiede un secondo
   invariante di coerenza.

## Decisione

Opzione 2, con:

- nuovo schema del descrittore (`analysis-descriptor.v2`) che entra nell'identità dei nodi: gli
  Artifact esistenti diventano nodi diversi e vengono ricalcolati una volta, senza perdita;
- compatibilità in lettura dei package v1: un descrittore v1 senza `sourceRevisionIDs` è trattato
  come dipendente dall'intera generazione (regola attuale), quindi i package esistenti si aprono
  invariati;
- test: invalidazione transitiva esatta su grafi sintetici ramificati, riuso osservabile dopo
  l'importazione di una fonte estranea, recovery SIGKILL invariata, apertura di fixture v1.

## Conseguenze

Riuso reale dopo le importazioni e conformità a GS-MET-001-02. Costi: cambio di schema persistito,
aggiornamento del protocollo di commit e dei controlli d'integrità, nuove fixture di persistenza.
Nessun cambiamento visibile nell'interfaccia oltre ai tempi.

## Attuazione

Il cambiamento tocca l'invariante su cui poggiano integrità, riuso e recovery, quindi procede in
tre incrementi, ciascuno con il proprio gate verde:

| # | Incremento | Contenuto |
| --- | --- | --- |
| A | Descrittore v2 e identità | `sourceRevisionIDs` nel descrittore, `corpusVersionDigest` sulle sole revisioni dichiarate, lettura invariata dei package v1 |
| B | Invariante e commit | Nuovo invariante del package (esistenza delle revisioni dichiarate e digest ricalcolato), trasporto degli Artifact validi alla nuova generazione, checkpoint di recovery |
| C | Riuso osservabile | Riuso dimostrato dopo l'importazione di una fonte estranea, invalidazione transitiva esatta su grafi ramificati, fixture di persistenza v2 |

## Stato

Accettato il 2026-09-20 dall'iniziatore del progetto. Gli Artifact esistenti diventano nodi
diversi e vengono ricalcolati una volta, senza perdita di dati.
