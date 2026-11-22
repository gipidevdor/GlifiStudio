<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-310 — Importazione nativa PDF ed EPUB

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-310 |
| Tipo | Implementazione e verifica documentale |
| Versione | 1.1.1 |
| Stato | Superato localmente nel perimetro dichiarato |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di includere PDF ed EPUB con componenti Apple |
| Riferimenti | RF-004; RF-005; RF-006; RF-088; ADR-0044; GS-DOR-310; GS-APL-009; CMP-310 |

## Risultato e identità

PDF ed EPUB attraversano importazione, progetto, ricerca, pianificazione,
analisi, interpretazione e riapertura. App, GlifiKit e CLI condividono
l'importatore; il selettore nativo ammette i quattro formati e la CLI offre
riconoscimento per estensione e selezione esplicita. L'originale è immutabile;
testo, locatori e backend sono pubblicati atomicamente nella stessa generazione.
La riapertura usa lo snapshot verificato senza rieseguire parser o OCR.
TXT/Markdown conservano byte, BOM, rappresentazione e trasporti precedenti.

Il lotto parte da a31775c e incorpora main 76e5871. L'allegato
[di verifica](allegati/GS-VER-310-verifica.json) identifica i file effettivamente
provati, i digest, gli orari UTC, i log e le eventuali integrazioni successive.
Il congelamento iniziale comprende 547 file, digest
`sha256:ae4961284060903900df51367db2378ea4977c1d1db9eae8401b4c100461875d`.
443 file upstream non condivisi sono byte-identici. Dei 169 record di conformità
upstream, 168 restano identici; cambia soltanto la motivazione di blocco CMP-020,
che distingue i limiti sintetici implementati dal corpus reale ancora aperto.
Nessuno stato upstream viene promosso.

## Tecnologie e contratti

PDFKit estrae il testo incorporato; Core Graphics rasterizza una pagina per
volta e Vision riconosce soltanto le pagine prive di testo. Il profilo OCR
accurate registra revisione, lingue, sistema/build, geometria e confidenza.
Le pagine vuote consumano un tentativo e il relativo budget OCR; non generano
testo o locatori inventati. Un PDF interamente vuoto produce la failure
`pdf.no-extractable-text`, categoria insufficientData. Le coordinate UTF-8
descrivono il testo acquisito; pagina e regione normalizzata lo collegano
all'originale. Non sono offset del PDF binario.

Per EPUB, Foundation XMLParser e zlib dello SDK leggono ZIP, container, OPF e
XHTML statico nell'ordine spine, anche quando differisce dall'ordine ZIP.
Nessuna dipendenza aggiuntiva, esecuzione di script, WebKit o accesso alla rete.
Sono acquisiti title, creator, language e identifier; valori multipli conservano
l'ordine, separati da LF. I font offuscati IDPF/Adobe ammessi non vengono letti
né deoffuscati; conteggio e policy restano nello snapshot.

| Risorsa | Limite standard e frontiera |
| --- | --- |
| Originale | 64 MiB, letto in modo bounded |
| Testo canonico | 16 MiB UTF-8; limite anche su riapertura e budget analitici |
| Pagine o risorse spine | 2.048, incluse unità senza testo |
| Locatori | 100.000; range validi, ordinati, non sovrapposti e su confini UTF-8 |
| OCR | 128 tentativi di pagina; 4.194.304 pixel per pagina, un bitmap per volta |
| ZIP | 10.000 membri; 16 MiB per membro; 128 MiB per somma dichiarata e per lavoro di lettura/decompressione, comprese letture ripetute |
| XML | Profondità 128 e 1.000.000 nodi per documento |
| Metadati EPUB | 4.096 byte per campo, senza troncatura |

I controlli precedono decompressione/rasterizzazione; cancellazione e limiti
interrompono il lavoro con failure tipizzate. Il laboratorio conserva
l'admission runtime prima della lettura. Query, corpus e planner contabilizzano
il maggiore fra originale e testo acquisito; i riferimenti d'interpretazione
usano la lunghezza canonica effettiva.

## Persistenza e compatibilità

Originale e Artifact riservato di estrazione appartengono alla stessa
transazione. Descriptor e payload sono legati a revisione, corpus e digest;
snapshot assenti, duplicati, alterati o incoerenti vengono rifiutati, anche
nei percorsi storici e di recupero. Gli Artifact generici non possono
sostituire l'estrazione riservata. Il lettore controlla l'ammissione prima di
caricare il payload.

Al primo import ricco, la migrazione SQL4→SQL5 ricostruisce source_entries e
project_metadata nella transazione esistente, preservando tutte le generazioni
e i relativi record. I progetti mai sottoposti a import ricco restano SQL4;
formato package 1 e schemi manifest 3/4 non cambiano. Il reader corrente è 2;
minimumReaderVersion diventa 2 quando sono pubblicate fonti ricche e resta 2
nelle generazioni successive.

Un errore prima del commit della transazione ripristina anche la migrazione.
Un'interruzione dopo databasePrepared può lasciare SQL5 con il vecchio manifest
minimumReaderVersion 1: il nuovo reader recupera la generazione precedente
immutata; il vecchio reader rifiuta SQL5. Non si promette leggibilità con il
vecchio binario dopo un tentativo ricco interrotto. Le prove del fence usano il
reader corrente, senza eseguire un binario storico. Il test di cancellazione
si arresta immediatamente prima della migrazione: non misura un'interruzione
durante la copia SQL.

## Prove discriminanti

- PDF: digitali, scansionati, misti, ruotati, vuoti, invalidi e protetti;
  budget prima della rasterizzazione, provenienza OCR e prestito del contesto
  di cancellazione sicuro fra code e callback tardive. Nove definizioni mirate.
- EPUB: stored/DEFLATE, CRC delle risorse lette, ordine spine, path/link/encryption e strutture XML
  ostili, 248 entità XHTML confrontate con un oracolo indipendente. Quindici
  definizioni; regressioni Unicode NFD e limite esatto senza LF finale spurio.
- Persistenza: quattordici definizioni, 28 esecuzioni, comprese due formati per
  ciascuno dei sei checkpoint con fault injection, alterazione/recupero,
  migrazione lazy, righe storiche, rollback e fence. Queste prove non sono
  SIGKILL; i 22 checkpoint process-kill del gate generale restano distinti.
- CLI indipendente: 64 processi, 50 successi, 12 invalidInput e due
  unsupportedFormat; envelope, digest, locatori, UTF-8, ordine spine,
  riconoscimento automatico ed esplicito, riapertura e mancata mutazione sugli
  errori. TXT/Markdown verificano anche BOM e CRLF originali.
- Kit: 2.840 dichiarazioni pubbliche controllate; 24 sole aggiunte di dati,
  nessuna rimozione o variazione delle operazioni precedenti. Quattro formati
  confrontati integralmente fra API e CLI, anche con estensione automatica.

Il percorso RED→GREEN conserva le prove dei difetti corretti: CHECK SQL4
(otto test/27 issue), lexer per Character e LF strutturale EPUB (due test/tre
issue), cancellazione classificata I/O e admission laboratorio persa (un
test/sei issue). Nessun controllo è stato indebolito.

## Gate completi

| Controllo sul congelamento iniziale | Esito osservato |
| --- | --- |
| make verify, profilo macOS | Exit 0; 704 Core + 147 Kit, 244 righe di oracoli, due PDF/A-2u conformi, 118 test nativi/351 esecuzioni, build Debug/Release |
| Release Core/Kit | 851 test; nessun warning di compilazione |
| Parità Release | 63 fixture/196 controlli analitici; 132 operazioni/264 confronti Kit, quattro formati espliciti e automatici |
| Address Sanitizer | 851 test; nessuna diagnostica del sanitizzatore |
| Thread Sanitizer | 851 test; nessuna diagnostica del sanitizzatore |

Gli esiti effettivi di make verify macOS, Release, Address Sanitizer e Thread
Sanitizer sono registrati nell'allegato con identità delle fonti prima e dopo,
conteggi e digest dei log. Il gate macOS comprende oracoli numerici, due export
PDF/A-2u validati con veraPDF, parità CLI, recupero, test nativi e build
Debug/Release. L'esecuzione nativa iniziale conta 118 definizioni e 351
esecuzioni, senza failure o skip. Il simulatore iOS non aggiornato emette il
warning già presente; il profilo macOS termina indipendentemente da esso.

Un primo tentativo del checker Release usa per errore Python 3.9, privo di
zip(strict=True). Il tentativo fallito è conservato separatamente; i due
checker sono ripetuti con Python 3.14 sullo stesso binario e sulle stesse fonti,
entrambi con esito 0. Non è classificato come successo del prodotto né nascosto.

Per un PDF troncato dopo una firma valida, Core Graphics può emettere il
messaggio generico «CoreGraphics PDF has logged an error». È registrato e
verificato privo di contenuto e path; segue la failure tipizzata. Nessuna
redirezione globale di stderr o modifica dell'ambiente del processo.

## Integrazione successiva di main

Prima della pubblicazione è incorporato d6b4828, con scenari GS-303 e
configurazione Xcode GS-306. L'allegato mantiene separati i gate iniziali e la
fase composedVerification: 557 file, digest
`sha256:658a5a2841828fa9fc5454ea9d3822dfd60fa4f43a5db6c8d3dce83fe29b6cc1`.
35 file documentali della feature restano identici al checkpoint 8fa5159;
519 file eseguibili upstream non condivisi restano identici a d6b4828.
I tre file condivisi conservano ammissione del testo acquisito, parità e nuova
matrice di scenario. La sola differenza Swift rispetto ai primi sanitizzatori
è un commento rimosso e la medesima detrazione locale del budget spostata oltre
costruttori puri, senza letture intermedie del budget o effetti pubblicati.

Il nuovo controllo degli scenari ha prodotto RED perché profile elencava due
formati mentre l'enum ne ammette quattro. La matrice ora include PDF/EPUB e
collega i test già esistenti: 172 varianti e cinque workflow, con 14 self-test
del checker verdi. Il tentativo Release avviato sul primo congelamento composto
è stato interrotto prima dei test; log e metadata restano separati e non sono
attribuiti a un successo del prodotto.

Sul composto, make verify macOS e Release Core/Kit sono ripetuti integralmente:
706 Core + 155 Kit, 861 test; l'app Debug conta 126 definizioni e 411 esecuzioni.
La nuova regressione planner supera TSan con due definizioni e 11 casi. La
review di equivalenza e la conservazione byte-identica degli importatori
motivano il riuso dei due sanitizzatori completi sul primo congelamento: non
sono dichiarati full ASan/TSan sul composto di 557 file. La configurazione
nativa Release supera anch'essa 126 definizioni e 411 esecuzioni, senza failure
o skip, con una prova distinta nell'allegato.
make quality finale supera controlli documentali, conformità, progetto Xcode,
concorrenza e formattazione. Anche il suo primo avvio con Python 3.9 è conservato
come errore del runner; il controllo valido usa Python 3.12 sullo stesso codice.

## Misure e limiti della prova

Il confronto informativo Vision usa un'immagine sintetica, un warmup e cinque
campioni alternati per livello: fast mediana 9,302 ms, accurate 49,122 ms, stesso
testo riconosciuto in tutti i campioni. Low Power Mode attivo e compilazioni
concorrenti impediscono generalizzazioni di throughput o energia. Il prodotto
mantiene il profilo accurate dichiarato; non si afferma un miglioramento
prestazionale o una qualità OCR misurata su corpus reali.

Non sono supportati DRM, testo cifrato, ZIP64, archivi multidisco o spine non
XHTML. Il PDF richiede firma al byte zero. L'OCR non fonde immagini e testo
incorporato sulla stessa pagina; layout complessi non hanno ordine di lettura
garantito. L'estrazione iniziale dei framework può variare fra sistemi, mentre
lo snapshot persistito conserva la rappresentazione acquisita.

Non sono provati un reader impaginato EPUB/PDF, CSS, corpus avversari reali,
qualità OCR, energia, isolamento fuori processo, iPadOS, UX/accessibilità
manuale o distribuzione firmata. G4/G5 e CMP-020 restano aperti; CMP-310 resta
implemented per evitare di confondere verifica funzionale sintetica e qualifica
completa. Log, fixture e risultati utili sono conservati localmente; le sole
cache rigenerabili del lotto sono rimosse a verifiche concluse.

## Riverifica remota

Il successivo controllo remoto ha rilevato indisponibilità del percorso OCR
accurate sull’immagine assegnata. GS-VER-311 registra diagnosi e correzione
ADR-0045; i conteggi e gli esiti locali precedenti restano riferiti ai propri
congelamenti e non vengono presentati come successi remoti.
