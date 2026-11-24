<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0045 — Profilo OCR nativo adattivo e tracciato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0045 |
| Tipo | Disponibilità e provenienza dell'estrazione |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Completamento dell'importazione PDF/OCR richiesta dall'utente |
| Riferimenti | RF-004; RF-005; RF-006; GS-DOR-311; GS-VER-311; ADR-0044; GS-APL-009 |

## Evidenza che motiva la decisione

Sul runner xcode-27, macOS 27.0.1, i profili accurate provati in processi
freschi falliscono su testo sintetico e pagina vuota. La selezione CPU, le
lingue singole, la correzione linguistica disattivata e la revisione precedente
non risolvono il problema. Il percorso fast riesce. Non si deduce una causa
hardware, RAM o modello specifico dal dominio opaco dell'errore.

La [sequenza nello stesso processo](https://github.com/gipidevdor/GlifiStudio/actions/runs/45056456760/job/137312671757)
dimostra accurate fallito, nuova request fast riuscita sulla stessa immagine:
testo `NATIVE OCR 314159` riconosciuto e pagina vuota senza osservazioni. Sono
due perform per pagina, senza forzare un errore né alterare i gate di prodotto.
Sul Mac locale accurate riesce al primo tentativo.

## Decisione

Il nuovo profilo nominale è
`pdf-import-readable-text-accurate-preferred-fast-resource-v2`, con contratto
`pdfkit-pages-vision-ocr-v2`. Preferisce Vision accurate. Soltanto un errore
nativo di perform classificato insufficientResources ammette un unico secondo
tentativo fast, con request e handler nuovi, stessa immagine e stessa revisione,
lingue e impostazioni dichiarate. Non si impone CPU, GPU o Neural Engine.

Cancellazione, input invalido, capacità non supportata, preflight, limiti e
validazione delle osservazioni non vengono intercettati per ritentare.
Un successo accurate senza osservazioni resta un successo vuoto; non avvia
fast. Se anche fast fallisce, l'importazione fallisce senza pubblicare fonte o
snapshot parziali. Ogni tentativo ha il proprio scope autorelease e bridge di
cancellazione; il task è controllato prima di ogni perform e fra i tentativi.

I limiti storici restano invariati: 128 pagine OCR e 4.194.304 pixel RGBA per
pagina (16 MiB di bitmap). Il nuovo tetto derivato è al massimo 256 perform,
due per pagina; la stessa bitmap viene riusata. Il testo viene validato e
aggiunto al builder solo dopo aver scelto l'unico risultato riuscito.

Il backend e i metadati della nuova acquisizione registrano profilo, livello
preferito ed effettivo, numero di perform e pagine concluse con fast. I locatori
restano pagina/regione/confidenza con metodo pdf-ocr; l'elenco bounded delle
pagine fast ne rende ispezionabile la provenienza senza nuove strutture
persistenti. La fonte mostra una breve etichetta OCR rapido quando effettivo.
Nessuna descrizione, userInfo o path di un errore nativo entra nel trasporto o
nello snapshot.

## Compatibilità e verifica

Il formato payload e il reader restano invariati. Gli snapshot V1 vengono letti
con i propri metadati e backend, senza aggiungere default V2 o riestrarre testo.
Una nuova acquisizione crea una nuova SourceRevision; non sostituisce la
rappresentazione precedente anche quando originale e testo coincidono.

I percorsi [fast e accurate di Apple](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
sono algoritmi differenti: questa decisione privilegia la disponibilità quando
accurate non può funzionare, senza affermare equivalenza qualitativa o maggiore
accuratezza. Il risultato acquisito è immutabile e verificabile alla riapertura.
Qualità su corpus reali, energia, iPadOS e G4/G5 restano aperti.

Prima della consegna sono necessari test della policy (successo vuoto, errori
selezionati, cancellazione, limite di due tentativi e assenza di doppio append),
provenienza/riapertura V1 e V2, prove OCR originali invariate nell'esito, parità
dei client e make verify macOS sul codice finale, con verifica remota.
