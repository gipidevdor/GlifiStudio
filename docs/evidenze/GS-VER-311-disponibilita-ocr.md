<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-311 — Disponibilità e failure OCR native

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-311 |
| Tipo | Diagnosi e verifica correttiva |
| Versione | 0.2.0 |
| Stato | In verifica |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Completamento dell'importazione PDF/OCR richiesta dall'utente |
| Riferimenti | GS-DOR-311; GS-VER-310; ADR-0044; CMP-311 |

## Baseline e rilievo

La baseline pubblicata b401c08 supera le prove locali GS-VER-310. La verifica
remota fallisce invece in VNImageRequestHandler.perform per le prove mixed e
blank; il wrapper espone pdf.ocr-failed/invalidInput e nasconde il tipo nativo.
L'errore di tassonomia è indipendente dalla causa del backend: risorse, modello
e runtime non dimostrano che un PDF sia invalido.

## Prima diagnosi remota

Il ramo diagnostico 0d170a9 aggiunge un job manuale senza rimuovere o modificare
i gate di prodotto. Il [job sintetico](https://github.com/gipidevdor/GlifiStudio/actions/runs/45054499095)
confronta testo e blank, immagini dirette e PDF rasterizzati, callback assente,
callback di conteggio e bridge del task, selezione automatica e CPU per ogni
stage pubblicizzato. Nessun profilo alternativo viene provato come retry del
prodotto e nessun fallimento viene accettato come risultato OCR vuoto.

Sul Mac locale 26 perform riescono; sul runner macOS 27.0.1/Xcode 27.1 tutti
falliscono con dominio opaco TextRecognition.CRImageReaderError, codice 9,
senza underlying. Il runner espone Metal GPU e Core ML CPU/GPU: la sola
virtualizzazione non dimostra assenza di GPU e il confronto non giustifica
un fallback CPU. Non si interpreta il codice 9 come un valore di VNErrorCode,
perché il dominio è differente.

Questa prima matrice usa un processo unico dopo due richieste concorrenti.
Inoltre la query stage di un cold task può precedere la fine dell'altro.
Un'inizializzazione fallita potrebbe contaminare i casi successivi; la
diagnosi prosegue con un processo fresco per ogni profilo e fixture.
Le immagini dirette e rasterizzate hanno dimensioni dichiarate differenti:
non si attribuisce un esito al solo contenitore PDF.

## Processi freschi e sequenza bounded

Nel run 45055797007 ogni profilo/fixture usa un nuovo processo: 18 prove
accurate falliscono, quattro fast riescono. Lingue, autodetect, correzione e
revisione precedente non rendono disponibile accurate su quell'immagine.
Non si attribuisce il difetto a GPU, RAM o a uno specifico modello.

Nel run 45056456760 i due controlli accurate falliscono; entrambe le sequenze
accurate→fast nello stesso processo riescono con due perform sulla stessa
immagine, testo riconosciuto e blank senza osservazioni. ADR-0045 adotta quindi
un profilo nominale esplicito, non un cambio silenzioso di accuratezza.

## Implementazione e mirati

La policy separa le failure native restituite da perform dagli errori lanciati
per preflight, limiti o cancellazione. Le osservazioni sono validate e aggiunte
solo dopo la selezione unica. Budget documentale di 256 perform al massimo,
stessa bitmap da massimo 4.194.304 pixel; livelli reali e pagine fast nello
snapshot e nel badge localizzato. Vecchi snapshot V1 riaperti immutati.

Il primo mirato della sola tassonomia supera 17 definizioni/40 esecuzioni.
Il mirato completo supera 27 definizioni, inclusi policy, producer reale e
provenienza V1/V2, senza warning. Due errori iniziali del test (try nelle macro
e factory sintetica fuori tassonomia) sono corretti senza indebolire i guard;
log e stati RED restano separati dalle prove GREEN.

## Stato

Mirati superati; make verify macOS e controllo remoto della composizione
comprendente CMP-286/287/288 sono ancora necessari. I checkpoint storici di
GS-VER-286 e GS-VER-310 non vengono riscritti. Risultati e prove sono raccolti
nell'[allegato](allegati/GS-VER-311-verifica.json). Nessuna qualifica di corpus
reali, energia, iPadOS, UX/accessibilità manuale o G4/G5.
