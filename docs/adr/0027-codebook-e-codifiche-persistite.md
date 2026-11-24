<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0027 — Codebook e codifiche persistite (RF-043)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0027 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-19 |
| Data decisione | 2026-09-19 |
| Approvazione | L'iniziatore ha scelto l'opzione 2 (storia qualitativa append-only) |
| Integra | ADR-0021, ADR-0025, GS-MET-001-20, RF-043, RF-044 |
| Sostituisce | Nessuno |

## Contesto

RF-043 richiede codebook, categorie, codifiche di segmenti, annotazioni e memo con identità,
versione, autore e lineage. GS-MET-001-20 vieta di riscrivere codifiche storiche quando una
categoria cambia e richiede che versioni, fusioni, split e mapping siano artefatti tracciati, e che
annotazioni manuali e automatiche restino distinguibili. Oggi l'accordo fra codificatori
(`coding-agreement-v2`, GS-VER-103) lavora su una tabella JSON fornita dalla richiesta: non esiste
un modello di dominio persistito.

## Opzioni

1. **Codifiche come Artifact analitici.** Semplice, ma gli Artifact sono derivati riproducibili dai
   dati: una codifica umana non è ricalcolabile e violerebbe la semantica del DAG.
2. **Storia qualitativa append-only nel package, sul modello di ADR-0021.** Una radice generazionale
   `QualitativeHistory` distinta da fonti, Artifact e indagini, con eventi content-addressed:
   `codebookRevised` (categorie gerarchiche con identità stabili, definizioni, istruzioni),
   `categoryMapped` (fusione, split, rinomina come mapping esplicito), `segmentCoded` (fonte,
   intervallo UTF-8 verificato con la SpanMap, categoria e revisione del codebook, codificatore,
   istante, origine manuale o automatica), `codingRetracted`, `memoAttached`. Le viste correnti
   (codebook attivo, codifiche per codificatore) sono proiezioni deterministiche della storia.
3. **Database relazionale dedicato.** Flessibile per le query, ma introduce un secondo modello di
   persistenza e di migrazione fuori dal package generazionale.

## Raccomandazione

Opzione 2. Riusa le garanzie già verificate per l'indagine (append-only, commit generazionale,
recovery), impedisce per costruzione la riscrittura silenziosa delle codifiche storiche e permette
di derivare la tabella di `coding-agreement-v2` direttamente dalle codifiche indipendenti,
eliminando l'input JSON manuale. L'accordo e le policy di ADR-0026 restano invariati.

## Conseguenze se accettata

- nuova radice nel manifest (migrazione additiva dello schema del package, come per ADR-0021);
- operazioni GlifiKit/CLI per revisionare il codebook, codificare, ritrattare e calcolare l'accordo
  dalle codifiche persistite;
- UI di codifica secondo le specifiche UX in un incremento successivo;
- nessuna modifica al DAG analitico né agli Artifact esistenti.

## Stato

Accettato il 2026-09-19 con l'opzione 2. L'implementazione segue GS-DOR-007.
