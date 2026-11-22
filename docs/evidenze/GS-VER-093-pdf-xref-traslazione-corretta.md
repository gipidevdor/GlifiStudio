<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-093 — Correzione della traslazione xref nell'export PDF/A-2u

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-093 |
| Tipo | Evidenza di correzione di difetto e regressione |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di RQ-061 (export PDF) |

## Difetto

I test `L'export scientifico inventaria JSON/Markdown/CSV/PDF…` e `Il PDF pagina un rapporto
lungo…` fallivano in modo intermittente (circa una esecuzione su 8–50) con
`PDFDocument.string` vuoto o parziale. Il fallimento non dipendeva dai font né dal
parallelismo dei test.

Causa radice: `promotePDFAToUnicode` sostituisce lo stream XMP con conformità `U` e
ricomprime i metadati (`Z_BEST_SPEED`); la lunghezza risultante differisce da quella
scritta da Core Graphics in metà circa dei casi. La traslazione degli offset della tabella
`xref` (`updateCrossReferenceTable`) usava la condizione `lineRange.count == 20`, che non è
mai vera perché una voce xref priva di terminatore misura 18 o 19 byte: gli offset non
venivano mai traslati. Il PDF era valido solo quando la ricompressione dava per caso la
stessa lunghezza (delta 0); altrimenti tutti gli oggetti successivi ai metadati avevano
offset errati di 1 byte, PDFKit non risolveva i font (`font TT1 not found`) e il testo non
era estraibile. Il file esportato era quindi strutturalmente corrotto per lettori rigorosi.

## Correzione e verifica

- la condizione riconosce voci xref di 18 o 19 byte (`SP LF`, `CR LF`, `SP CR`);
- nuovo test `La traslazione dell'xref sposta solo gli offset a valle e riallinea startxref`:
  fixture sintetica con delta −1; verificato che **fallisce** sul codice precedente e passa
  con la correzione (mutation check);
- 100 esecuzioni consecutive della suite GlifiCore senza alcun fallimento (prima: fallimento
  ogni 8–50 esecuzioni), 118 test.

## Limiti

La correzione ripristina la coerenza degli offset dopo la sostituzione dei metadati; non
aggiunge una validazione strutturale generale del PDF (ad esempio un controllo xref
post-rendering) né un validatore PDF/A esterno.

## Esito

**Superato localmente.** Il gate `make verify` non dipende più da un test intermittente sul
PDF.
