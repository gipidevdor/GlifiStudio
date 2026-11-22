<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-310 — Importazione nativa PDF ed EPUB

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-310 |
| Tipo | Implementazione e verifica documentale |
| Versione | 0.1.0 |
| Stato | In verifica |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di includere PDF ed EPUB con componenti Apple |
| Riferimenti | RF-004; RF-005; RF-006; RF-088; ADR-0044; GS-DOR-310; GS-APL-009 |

## Ambito

Lotto isolato basato su a31775c. PDFKit estrae testo e pagine; Vision esegue OCR
locale sulle pagine prive di testo. Foundation XMLParser e zlib dello SDK
leggono contenitore, OPF e XHTML degli EPUB testuali non cifrati.

L'originale resta incorporato; uno snapshot versionato di testo, coordinate e
backend viene pubblicato atomicamente nella stessa generazione. La riapertura
non ripete estrazione o OCR. Query, analisi corpus e laboratorio leggono tale
rappresentazione, con budget anche sul testo acquisito. Il salto alla fonte
usa coordinate UTF-8 del testo acquisito e locatori pagina/capitolo distinti.

## Piano di verifica

- PDF sintetici digitali, scansionati, misti, ruotati, protetti e invalidi;
  limiti prima della rasterizzazione, metodi, lingue e regioni/confidenza OCR.
- EPUB sintetici stored/DEFLATE con ordine spine diverso dall'ordine ZIP;
  CRC, limiti cumulativi, path, link, entità XML e strutture ostili.
- Transazione fonte/snapshot, tutti i checkpoint di interruzione, riapertura
  senza parser, rifiuto di snapshot mancante/duplicato/alterato e riserva storage.
- Parità profile/import/source-text fra native e CLI per quattro formati;
  query, laboratorio e fonte dopo riapertura. Compatibilità TXT/Markdown.
- make verify macOS sul contenuto finale. Limiti di layout/OCR e prove reali
  restano distinti dai controlli sintetici.

## Rilievo durante la verifica

Le prime prove hanno rilevato il CHECK SQL4 che ammette soltanto plainText e
markdown: il primo tentativo di persistenza produce 27 issue su otto test.
La decisione iniziale senza migrazione SQL è corretta in ADR-0044: aggiornamento
lazy SQL5 al primo import ricco e minimumReaderVersion 2, con prove di rollback,
conservazione delle generazioni e riapertura. Nessun vincolo viene disabilitato.

La revisione incrociata ha riprodotto due difetti EPUB (due test/tre issue):
lexer XML per Character invece di UnicodeScalar e LF strutturale addebitato
anche quando assente dal testo finale. Entrambi sono corretti con regressioni
NFD e limite canonico esatto. Un ulteriore test runtime ha riprodotto sei issue:
il laboratorio aveva perso l'admission prima della lettura; il controllo è
ripristinato e il medesimo test è verde. La cancellazione prima della migrazione
ha inoltre discriminato una classificazione generica I/O, corretta alla failure
cancelled con stato dell'ultima generazione.

## Stato

Implementazione e prove mirate in corso. Nessun esito completo è ancora
attribuito al nuovo lotto; i conteggi saranno registrati dopo le esecuzioni.
