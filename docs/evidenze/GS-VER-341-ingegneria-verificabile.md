<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-341 — Affidabilità verificabile dei test BDD e dell'inferenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-341 |
| Tipo | Revisione ingegneristica con regressioni di lifecycle, gate e inferenza |
| Versione | 1.0.0 |
| Stato | Parziale; regressioni mirate superate, integrazione finale bloccata dal checkout concorrente |
| Responsabile | Codex, con verifica serializzata dall'integratore |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di ricontrollare il codice e migliorarne la qualità ingegneristica |
| Riferimenti | GS-DOR-341; GS-STD-001-12; GS-STD-001-16; GS-STD-001-29 § 29.6; ADR-0031; ADR-0046; GS-BDD-001; GS-MET-001-21; CMP-341; RQ-011; RQ-027; RQ-058; RQ-060; RQ-062; RQ-063 |

## Problemi confermati dalla revisione

La revisione coordinata ha individuato cinque contratti da rendere effettivi:

- l'attesa distaccata del binario CLI non propagava la cancellazione al figlio
  e poteva prolungare lo scenario oltre il timeout del runner;
- il controllo del report accettava alterazioni dei passi a parità di
  cardinalità, e la lettura JSON permissiva non rifiutava alcune ambiguità;
- il default dei trait upstream poteva attivare le macro in presenza di
  `SPI_BUILD`, nonostante l'intenzione di escluderle;
- alcuni intermedi numerici traboccavano pur con t, d, errore standard o
  limiti ancora finiti; inoltre `(1+CL)/2` poteva arrotondare a 1 per un
  livello valido immediatamente inferiore a 1;
- il modello macOS del classificatore propagava `DecodingError` per JSON di
  stato malformato o incompleto, presentandolo come errore interno invece che
  come input correggibile.

GS-VER-332 e GS-VER-333 restano le evidenze storiche dei rispettivi lotti.
Questo documento registra nuove correzioni e non attribuisce loro verifiche
eseguite successivamente.

## Implementazione e regressioni ispezionate

`BDDSubprocess` possiede figlio diretto, file e task di supervisione attraverso
un actor. Cancellazione e scadenza inviano SIGTERM e successivamente SIGKILL
se necessario; l'esito attende raccolta del figlio e chiusura dei file. Il
limite di 1 MiB è controllato separatamente su stdout e stderr prima della
lettura, dopo la terminazione. Non è una quota disco né una gestione di
discendenti arbitrari. `BDDSubprocessTests` contiene sei test distinti di
risultato, cancellazione preventiva, cancellazione con SIGTERM ignorato,
scadenza con SIGTERM ignorato, avvio fallito e output eccessivo. Le prove
usano un handshake del figlio per stabilire l'ordine degli eventi.
I timer di 20 secondi e del successivo secondo di grazia partono dopo l'avvio;
non costituiscono un limite assoluto comprensivo di avvio, I/O e scheduling.

L'inventario BDD V2 conserva `sourceSHA256` e, per ogni scenario espanso,
`line`, `stepCount` e `stepsSHA256`. Quest'ultimo vincola la sequenza canonica
ordinata di posizione, keyword e nome di ogni passo del report upstream,
compreso il contesto comune. Lo stesso controllo richiede feature e scenari
attesi, esiti positivi e JSON privo di chiavi duplicate, costanti non JSON
e numeri floating non finiti. Non viene aggiunto un parser Gherkin interno.
Il manifest dichiara ora `traits: []` per la dipendenza CucumberSwift.
Anche gli inventari e lockfile usati dai controlli legali e dalla baseline
Apple adottano letture JSON rigorose. La versione dell'inventario legale
richiede un intero: `true` e `1.0` non sono versioni ammesse.

La correzione inferenziale conserva il percorso ordinario e limita il
fallback ai casi problematici: contrasto normalizzato traboccato con
differenza originaria finita, quadrato di d non rappresentabile e
probabilità superiore arrotondata a 1. Gli output realmente non
rappresentabili restano failure tipizzate. La revisione producer `4`
riguarda soltanto `group-metric-comparison`; posthoc e paired restano `3`,
correlazione e associazione `2`. Reader e schemi mantengono accessibili gli
storici producer 1–3 senza riutilizzarli come nuovi risultati della famiglia
modificata.

Le regressioni in `GlifiInferenceStabilityTests` includono contrasti con
segni opposti e cambi di unità, deviazioni subnormali con riferimenti Decimal,
errore standard senza quadrato traboccato, risultati realmente non
rappresentabili e livello `1.nextDown` per effetto standardizzato e Fisher.
Le attese usano formule manuali o riferimenti indipendenti; il confronto
fra facciate che condividono il Core non è l'unico oracolo.

Il test storico che richiedeva un errore per il livello valido `1.nextDown`
è allineato al contratto corretto: conserva il rifiuto di 0, 1, valori
negativi, NaN e infiniti. BCa resta nel proprio perimetro precedente; questa
correzione riguarda soltanto gli intervalli documentati.

`StudioKHLanguageModel` traduce gli errori di decodifica dello stato in
`ui.kh-language.invalid-input`, categoria `invalidInput`, retry
`afterCorrection`. La regressione importa prima uno stato sintetico valido,
poi oggetto incompleto, array, campo di tipo errato e JSON malformato:
verifica failure tipizzata, stato precedente e sua codifica invariati. Le failure
già tipizzate dal decoder, come un campo non ammesso, restano specifiche.
L'intervento è nel modello; non costituisce un audit delle schermate.

## Checklist GS-STD-001-29 § 29.6

| Area | Ambito e stato dell'evidenza |
| --- | --- |
| API | Adattatore BDD interno con failure tipizzate; catalogo DocC complessivo Da introdurre, nessuna attestazione globale |
| Correttezza | Regressioni numeriche e BDD mirate superate; guard negativi JSON e inventario superati. Suite finale del checkout non attestata |
| Concorrenza | Ownership del figlio e dei task di supervisione, cancellazione e raccolta; sei test passati sia isolati sia nella suite BDD integrata |
| Dati | Producer selettivo 4 e storia 3 verificati con riapertura, riuso e byte storici invariati; nessuna nuova migrazione dichiarata |
| Sicurezza e privacy | Input sintetici, JSON rigoroso, limite alla lettura degli output e confine del processo posseduto; nessuna qualifica di quota disco o isolamento dei discendenti |
| Accessibilità e localizzazione | Documenti e feature italiani; UI, VoiceOver, Voice Control, tastiera, testo grande, contrasto, pseudo-lingua e RTL non verificati da questo lotto e non promossi |
| Piattaforma | Percorsi headless e test macOS; audit HIG/UI e verifica iPadOS fuori dall'evidenza corrente |
| Prestazioni ed energia | Nessuna nuova ottimizzazione o soglia approvata; metriche e audit G4 Da introdurre o nello stato già dichiarato |
| Test ed evidenza | GREEN mirato acquisito; integrazione finale bloccata da nuove modifiche concorrenti. Sanitizer e verifiche di copertura non eseguiti restano Da introdurre |
| Documentazione | DoR, contratti, tracciabilità ed evidenza aggiornati; ADR-0031 e ADR-0046 già applicabili, nessuna nuova decisione architetturale; nessuna promozione implicita del capitolo 28 |

La checklist circoscrive le prove necessarie e i limiti. Non attribuisce un
voto complessivo al codice e non dichiara conforme un criterio privo della
specifica evidenza.

## Stato della verifica

L'[allegato di verifica](allegati/GS-VER-341-verifica.json) conserva comandi,
conteggi, hash dei log, sorgenti revisionati e limiti. Le prove osservate sono:

- RED degli intervalli dell'effetto: quattro definizioni, otto casi espansi,
  sedici issue prima della correzione;
- GREEN mirato: 24 definizioni Core, due Kit e 67 BDD in nove suite, inclusi
  i sei test subprocess e le prove di riapertura della cache;
- 23 test del controllo licenze e inventario di 27 materiali superati;
  inventario BDD V2 e controlli negativi superati, con 8 feature, 116 scenari
  espansi e 655 passi; il report storico GS-VER-332 è riletto senza riscriverlo;
- grafo risolto con `SPI_BUILD=1`: trait CucumberSwift vuoti e soltanto le due
  dipendenze approvate; nessuna macro o dipendenza SwiftSyntax;
- prima suite completa del package: 173 definizioni Kit e 67 BDD superate;
  792 Core con una sola issue per l'aspettativa storica su `1.nextDown`, poi
  corretta mantenendo sei livelli realmente invalidi;
- prima prova macOS: 150 definizioni, 149 superate e una issue della nuova
  fixture, che richiedeva un codice generico per un campo sconosciuto già
  tipizzato. La fixture ora prova separatamente tipo errato e campo non
  ammesso, preservando il codice specifico. Questa revisione finale della
  fixture resta da rieseguire nel checkout integrato.

L'ultimo `make verify` macOS termina con exit status 2: la nuova
implementazione tabellare concorrente emette `failure.tabular.cancelled` e
`failure.tabular.invalid-input` senza i messaggi localizzati richiesti. Il
precedente tentativo di compilazione della suite incontra inoltre riferimenti
non ancora disponibili a `researchState()` in `GlifiStudioSavedAnalysis.swift`,
nel nuovo flusso persistente ADR-0047. Sono blocchi osservati del checkout in
lavorazione, non controlli disabilitati o risultati dichiarati positivi.

Durante l'integrazione sono stati allineati i `try` dei test al builder
throwing dei dendrogrammi, normalizzata la formattazione dei file Swift già
modificati e completati i metadati richiesti di ADR-0047 senza cambiarne la
decisione. Le modifiche concorrenti restano conservate. I risultati storici
GS-VER-332 e GS-VER-333 non vengono aggiornati retroattivamente.

CMP-341 resta `implemented`: questa evidenza non promuove il gate completo,
la revisione finale del test del classificatore o i criteri generali di
qualità. Non è attribuito un voto 10/10 al repository. Per chiudere il lotto
servono compilazione del nuovo flusso, messaggi tabellari e riesecuzione di
`make verify` macOS sul checkout stabilizzato.

La verifica statica successiva alla documentazione si ferma sulle medesime due
chiavi tabellari; controlli documentali, matrice di compliance e `git diff
--check` sono superati separatamente. La cache di build posseduta è stata
rimossa (1.923.940 KiB), insieme alla cache isolata del subprocesso già misurata
(66.488 KiB): totale circa 1,90 GiB. Strumenti, dipendenze globali, altre cache
attive, file utente ed evidenze versionate sono conservati.

## Identità nel registro condiviso

L’identificativo iniziale GS-VER-334 è stato riallineato a GS-VER-341
per distinguere evidenze create in parallelo e già presenti su main.
I comandi e gli esiti storici restano riferiti ai rispettivi snapshot;
la verifica della composizione finale è registrata in GS-VER-343.
