<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Ingresso naturale e interpretazione canonica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-11 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Architettura concettuale approvata; funzione futura |
| Documento padre | [GS-UX-001](README.md) |

## Scopo

Una domanda naturale è un ingresso possibile, non un sostituto del piano
scientifico. Il testo originale viene conservato e, quando interpretabile, tradotto
in una struttura canonica che la persona può ispezionare e correggere.

```text
domanda naturale → interpretazione → AnalyticalIntent + slot tipizzati
                 → AnalysisPlan → AnalysisDAG → Evidence → Finding
```

La domanda «Come cambia il discorso sull'immigrazione dopo il 2015?» può risolvere,
senza eseguire ancora analisi: concetto, dimensione temporale, punto o periodi di
confronto, corpus, unità e intenzioni `trace.change`/`compare.objects`.

## QuestionInterpretation

La struttura canonica comprende almeno:

- domanda originale, lingua e autore;
- versione dell'interprete;
- intenzioni con livello di ambiguità;
- oggetti risolti e candidati alternativi;
- corpus o selezione;
- dimensioni, gruppi, periodi e relazioni richieste;
- vincoli, esclusioni e termini non interpretati;
- stato `resolved`, `needsClarification`, `unsupported` o `rejected`;
- conferme o correzioni effettuate dalla persona.

La UI **DEVE** mostrare in forma comprensibile come ha interpretato la domanda
prima di usare assunzioni che cambiano sostanzialmente il piano. Una correzione
produce una nuova revisione e non altera il testo originale.

## Percorso deterministico e assistenza generativa

Vocabolari, parser e regole tipizzate costituiscono il percorso riproducibile
iniziale. Un LLM può proporre una struttura, ma l'output deve superare validazione di
schema, risoluzione delle entità, applicabilità e conferma quando ambiguo. Il modello
**NON DEVE** accedere direttamente alle fonti o produrre la conclusione al posto
del motore analitico.

Prompt, modello, versione logica, disponibilità, contesto e proposta sono
provenienza generativa. La struttura approvata diventa un input distinto e
versionato; la stessa analisi resta riproducibile senza rigenerare il testo.

## Errori e prudenza

- Una domanda causale non autorizza un'inferenza causale priva di disegno adeguato.
- Concetti ambigui, date incerte e gruppi non risolti richiedono chiarimento.
- Una funzione non supportata viene dichiarata, senza sostituirla silenziosamente.
- Il sistema può proporre una domanda più verificabile spiegando la modifica.
- Nessuna risposta libera è presentata come finding prima della pipeline epistemica.

## Verifica

Fixture italiane e, quando abilitate, inglesi coprono ambiguità, negazione,
riferimenti temporali, confronti, concetti omonimi e richieste causali. I test
verificano struttura, conferma, indipendenza dal testo localizzato e parità tra piano
creato manualmente e piano derivato dalla stessa interpretazione canonica.
