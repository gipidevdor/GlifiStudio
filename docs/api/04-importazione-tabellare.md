<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Importazione tabellare con mapping e provenienza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-API-004 |
| Tipo | Contratto di importazione |
| Versione | 1.0.0 |
| Stato | Implementato; verifica integrata separata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di importazione CSV/Excel con anteprima e mapping |
| Riferimenti | GS-STD-001-11; GS-STD-001-14; GS-API-003 |

## Contratto

`GlifiStudioTabularImporter.preview(data:options:)` decodifica e valida l'intera
tabella entro limiti dichiarati. Il risultato non è un campione troncato: la
presentazione può mostrarne una pagina mantenendo totale e righe originali.
`map(table:mapping:)` produce documenti testuali, variabili tipizzate, coordinate
delle celle e l'elenco di ogni riga esplicitamente scartata. Le due operazioni
sono asincrone fuori dal Main Actor, cancellabili e usano `GlifiStudioFailure`.
Il parser non modifica la fonte e non calcola formule.

Le colonne sono numerate da **1**. I numeri di riga includono l'intestazione;
in CSV sono le righe fisiche di inizio record, anche quando un campo quotato
contiene newline. In XLSX sono i riferimenti di riga originali del foglio.
`sheetNames` elenca i fogli disponibili; `sheetName` seleziona esplicitamente
quello da importare, altrimenti si usa il primo nell'ordine del workbook.

L'intestazione è facoltativa. I nomi di colonna vuoti ricevono un'etichetta
«Colonna N»; il mapping usa gli indici e non dipende da nomi univoci. L'ordine
delle colonne testuali selezionate determina il testo risultante, con due LF
come separatore. Gli intervalli `textSegments` sono half-open in byte UTF-8
del testo risultante. `origins` mantiene digest dell'originale, foglio, riga
e colonna per testo, identificativo e ogni variabile, anche se mancante.

## CSV

Sono supportati UTF-8, UTF-16 little-endian e big-endian e Windows-1252,
selezionati esplicitamente. Un BOM iniziale è rimosso dalla rappresentazione
testuale ma resta nei byte originali e nel loro digest. La decodifica richiede
round-trip esatto, senza sostituzione di byte o surrogate malformati.
I delimitatori sono virgola, punto e virgola e tab. Il parser riconosce
LF/CRLF/CR, campi quotati, doppie virgolette escaped e newline nei campi.
Virgolette non chiuse o caratteri dopo la chiusura di un campo quotato
producono una failure, senza euristiche di riparazione.

## XLSX

È implementato un profilo SpreadsheetML XLSX tramite Foundation XMLParser e
il lettore ZIP bounded già utilizzato per EPUB; non sono introdotte dipendenze.
Il workbook risolve fogli, relazioni interne, stringhe condivise e inline,
rich text statico, celle sparse, numeri finiti, booleani e date ISO memorizzate
come stringhe/date. Le celle assenti restano mancanti. Gli stili data-only
built-in 14–17 e i formati espliciti con anno/giorno, senza ora o secondi,
convertono i seriali interi in date ISO Gregoriane, rispettando `date1904`.
Il seriale 60 della base 1900 è rifiutato perché rappresenterebbe una data
inesistente; sono rifiutate anche frazioni di giorno su una data-only.
Gli altri numeri conservano il valore XML; non si deducono separatori locali,
date da numeri privi di stile, o istanti da formati orari ambigui.

XLS binario legacy, macro, formule anche con cache, celle unite, celle di errore,
relazioni esterne, traversal, XML con entità e profili ZIP non ammessi sono
rifiutati esplicitamente. Nessun codice, macro, formula, link o contenuto esterno
viene eseguito. Le relazioni non vengono risolte sul filesystem. Le dimensioni
espanse e il CRC sono verificati prima di usare i payload XML.

Il riferimento strutturale è la documentazione primaria Microsoft:
[SpreadsheetML](https://learn.microsoft.com/en-us/office/open-xml/spreadsheet/structure-of-a-spreadsheetml-document),
[shared strings](https://learn.microsoft.com/en-us/office/open-xml/spreadsheet/working-with-the-shared-string-table),
[celle](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.cell).

## Mapping e failure

Il mapping sceglie una o più colonne testuali, un identificativo facoltativo
e variabili `text`, `integer`, `decimal`, `boolean` o `date`. Senza identificativo
si usa `rN` con il numero di riga originale. Il confronto degli identificativi
usa NFC, senza case folding. Una collisione può essere rifiutata, scartata
con issue oppure risolta mediante suffisso `#rN` dichiarato. Una seconda
collisione sul suffisso fallisce.

Valore mancante e stringa vuota sono distinti: il chiamante dichiara i token
di missing (default solo `""`); le variabili mancanti sono assenti dalla mappa.
I booleani ammettono esattamente `true`, `false`, `1`, `0`; gli interi sono
Int64 in forma decimale canonica; i decimali usano punto ed esponente e devono
essere finiti. Le date sono Gregoriane esatte `YYYY-MM-DD`, con verifica
dei giorni e degli anni bisestili. Non si indovinano locale, fuso o calendario.

Righe con numero di celle incoerente, testo assente o valori di variabile
non validi possono fallire oppure essere scartate con numero e codice,
secondo `invalidRowPolicy`. Budget, cancellazione e sintassi del contenitore
non sono mai convertiti in semplici righe saltate. Nessuna riga valida
produce `tabular.no-valid-rows` e nessun dataset vuoto è presentato come successo.
Le failure contengono solo codici e numeri di riga, senza testo o path originali.

## Limiti e persistenza

I default sono 16 MiB originali, 10.000 righe incluso header, 256 colonne,
200.000 celle e 1 MiB per cella. I limiti espliciti possono essere ridotti
o aumentati entro il massimo ammesso dal parser. La matrice XLSX viene
rettangolarizzata solo dopo la verifica di righe × colonne. La lettura ZIP
ammette 2.048 componenti, 64 MiB espansi complessivi e 16 MiB per componente.

La preview e il mapping sono DTO di trasporto; la loro presenza non modifica
il formato `.glifi`. L'incorporazione nel progetto deve conservare i byte
originali, mapping, issue e provenienza attraverso il percorso transazionale
di progetto, separato dal parser. I test dei parser non attestano da soli
il completamento della GUI, del commit di progetto o della parità CLI.

## Trasporto delle anteprime grandi

Il trasporto `research-call` mantiene l’envelope entro 1 MiB. Preview e import
leggono l’originale tramite `sourcePath`; il mapping ammette `tablePath` in
alternativa al DTO inline `table`. Il file contiene il risultato tabellare
completo e ha un budget di 64 MiB, verificato prima della decodifica rigorosa.
La mappatura usa la stessa API nativa, gli stessi limiti delle celle, opzioni
e provenienza. Un parametro inline insieme al path è ambiguo e viene rifiutato.
Il lettore condiviso verifica tipo, dimensione e stabilità del file senza
seguire symlink o attendere una FIFO; le failure sono quelle di GS-API-006.
