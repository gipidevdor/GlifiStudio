<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-133 — Riuso selettivo osservabile dopo un'importazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-133 |
| Tipo | Evidenza di integrazione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | GS-DOR-010, incremento C (ADR-0028 accettato) |

## Ambito

Terzo incremento di ADR-0028: le analisi dichiarano le fonti che leggono e il beneficio diventa
osservabile dal motore, da GlifiKit e dalla CLI.

- **Fabbriche collegate**: profilo di corpus, keyness, similarità e le quindici analisi derivate
  di gruppo dichiarano le revisioni che leggono; l'accordo fra codificatori dichiara l'insieme
  vuoto, perché calcola sulla tabella fornita dal chiamante e nessuna importazione lo invalida.
  Piano e interpretazione continuano a non dichiarare nulla: dipendono dall'intera generazione e
  restano invalidati a ogni importazione, come l'ADR richiede.
- **Costruzione a prova di disallineamento**: le fabbriche non ricevono più un digest già
  calcolato, ma lo snapshot; digest dichiarato e revisioni dichiarate nascono dalla stessa
  chiamata, quindi non possono divergere.
- **Guardia rimossa**: `corpusAnalysisArtifact` non confronta più il digest radice corrente con
  quello pianificato. Un profilo dichiarato su revisioni immutate resta valido dopo l'arrivo di
  altre fonti; una revisione scomparsa è comunque rifiutata dal calcolo del digest, e il commit
  rivalida l'invariante.

## Procedura e risultato

1. `serviceReusesAnalysesAcrossUnrelatedImports`: associazione e ponderazione su due fonti;
   l'importazione di una terza fonte estranea incrementa la generazione ma lascia invariato il
   numero di Artifact; ripetere le due analisi restituisce gli stessi `artifactID` e
   `analysisNodeID` senza creare una generazione; allargare l'analisi alla fonte nuova produce un
   nodo diverso;
2. contract test CLI nel gate, sulla nuova fixture `Fixtures/Persistence/v2/selective-invalidation`:
   le attese sono lette dal `case.json` invece di essere duplicate a mano nello script; dopo
   l'importazione estranea gli Artifact restano due e la seconda esecuzione dell'analisi
   restituisce lo stesso `artifactID` nella stessa generazione;
3. la fixture di persistenza entra nel catalogo `Fixtures/manifest.json` ed è validata da
   `check-fixtures.py`: schema, casi, fonti dichiarate e blocco delle attese. Prima
   dell'incremento la cartella `Fixtures/Persistence` non era registrata e nessun controllo la
   leggeva;
4. test aggiornati al nuovo comportamento: l'export di una vista dopo un'importazione estranea ora
   **riesce** (il rifiuto `visual-export.stale-artifact` resta verificato con un Artifact assente
   dalla generazione), e la reimportazione in presenza di un'indagine conserva parte degli
   Artifact invece di azzerarli;
5. `make verify` completo verde: i conteggi del progetto smoke della CLI restano invariati, perché
   le sue importazioni precedono tutte le analisi.

## Limiti

Il piano e l'interpretazione restano invalidati da qualunque importazione: è corretto rispetto al
loro significato, ma rende il riuso invisibile nei flussi che rieseguono un piano intero. Il
beneficio è misurato in numero di Artifact conservati e di ricalcoli evitati, non ancora in tempo
risparmiato su corpus grandi: nessun benchmark accompagna questo incremento.

## Esito

**Superato localmente: dopo l'importazione di una fonte estranea le analisi dichiarate sulle
revisioni immutate sopravvivono e vengono riusate, dal motore fino alla CLI.**
