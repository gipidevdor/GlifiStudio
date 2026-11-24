<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Codebook e codifiche persistite (ADR-0027)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-007 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | ADR-0027 accettato dall'iniziatore (opzione 2) |
| Riferimenti | GS-STD-001-07; ADR-0027; ADR-0021; GS-MET-001-20; RF-043; RF-044 |

## Unità di lavoro

| # | Task | Esito atteso |
| --- | --- | --- |
| C1 | Modello di dominio e proiezioni | Eventi `codebookRevised`, `categoryMapped`, `segmentCoded`, `codingRetracted`, `memoAttached` content-addressed; proiezione deterministica dello stato; derivazione della tabella di accordo |
| C2 | Persistenza | Radice `QualitativeHistory` nel manifest e nello store, commit generazionale, validazione all'apertura, recovery; package esistenti apribili (radice vuota) |
| C3 | GlifiKit e CLI | Operazioni per revisionare il codebook, mappare categorie, codificare, ritrattare, annotare, leggere lo stato e calcolare l'accordo dalle codifiche persistite |
| C4 | Documentazione | Evidenze, GS-MET-001-20, GS-DAT-001, API, requisiti, matrice, CHANGELOG |

## Decisioni di progetto

- **Storia lineare**: ogni evento dichiara il predecessore, che deve essere la testa corrente;
  un evento concorrente è rifiutato come `staleArtifact` e va ripetuto sulla nuova testa.
- **Revisioni complete**: `codebookRevised` contiene l'intero codebook della revisione `n+1`;
  categorie con identità stabili (`[a-z0-9._-]{1,64}`), genitore opzionale, etichetta,
  definizione e istruzioni. Un'identità di categoria non cambia significato fra revisioni: fusioni,
  split e rinomine passano da `categoryMapped`.
- **Codifica**: fonte, intervallo UTF-8 nello spazio estratto verificato sul testo e sui confini di
  carattere, codebook e revisione, categoria presente in quella revisione, codificatore
  pseudonimo, origine `manual` o `automatic`. Una codifica non viene mai modificata: si ritratta e
  se ne registra una nuova.
- **Accordo**: unità = coppia (revisione di fonte, intervallo) codificata da almeno un
  codificatore; etichetta mancante per chi non l'ha codificata. Più codifiche attive dello stesso
  codificatore sulla stessa unità rendono l'unità ambigua: è esclusa e conteggiata nel risultato.
- **Privacy**: il codificatore è un'etichetta scelta dall'utente, non un'identità personale; i
  memo sono contenuto del progetto e non entrano mai in failure o log.

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | RF-043 senza UI di codifica (incremento successivo) | — |
| requisiti | RF-043, RF-044, GS-MET-001-20 | — |
| contratto di dominio/API | Nuovi tipi Core e mirror GlifiKit; CLI `codebook`, `code`, `qualitative` | — |
| failure semantics | Categoria assente, revisione non consecutiva, intervallo fuori testo, predecessore non corrente → failure tipizzate nella tassonomia | — |
| esperienza prevista | Nessuna UI in questo incremento | — |
| verifica | Test di proiezione, persistenza, riapertura, recovery SIGKILL, parità Kit/CLI, accordo confrontato con `coding-agreement-v2` | — |
| dati e migrazione | Radice additiva: manifest precedenti decodificati con radice vuota | — |
| sicurezza/privacy | Codificatori pseudonimi; limiti di dimensione per evento e numero di eventi | — |
| prestazioni/sistema | Proiezione lineare negli eventi; limite di 100.000 eventi | — |
| tracciabilità | Evidenza e aggiornamenti per ogni task | — |
| decisioni | ADR-0027 accettato; scelte sopra | — |

## Stato DoR

**Ready** per C1–C4.

## Avanzamento

| # | Stato | Evidenza o motivo |
| --- | --- | --- |
| C1 | Completato | GS-VER-126 |
| C2 | Completato | GS-VER-126 |
| C3 | Completato | GS-VER-127 |
| C4 | Completato | GS-VER-126, GS-VER-127, GS-MET-001-20 1.1.0, GS-API-001 1.22.0 |
