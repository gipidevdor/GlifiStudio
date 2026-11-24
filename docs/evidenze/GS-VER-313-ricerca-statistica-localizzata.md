<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-313 — Ricerca dei risultati statistici localizzati

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-313 |
| Tipo | Verifica correttiva macOS |
| Versione | 1.1.0 |
| Stato | Superato localmente su macOS |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di correzioni e ottimizzazioni trasversali |
| Riferimenti | GS-DOR-313; CMP-313; RQ-060; RQ-062 |

## Perimetro e correzione

La regressione originaria è stata riprodotta sulla base `741da2e`: con
Bonferroni e input `0,01 0,04`, la ricerca `0,02` non trovava la riga che
mostrava quel valore in italiano. Il lotto modifica soltanto
`StudioStatisticsModel.swift`, `StudioStatisticsView.swift` e
`Tests/StudioStatisticsTests.swift` nell'app macOS.

Il formatter interno è condiviso fra celle e filtro. La ricerca include la
rappresentazione visualizzata nel locale esplicito e conserva gli alias
canonici numerici, `+Infinity`, `-Infinity` e `?`. Il filtro resta
`@concurrent`, controlla la cancellazione per riga e pubblica soltanto se il
token è ancora corrente. Risultato, richiesta, digest ed esportazione restano
invariati nelle regressioni.

La vista sincronizza il locale dell'Environment con `.task(id: locale)`.
L'aggiornamento rifiuta all'ingresso un task già cancellato, prima di modificare
il locale o avviare lavoro; reset, nuovo filtro e cambio locale mantengono
l'invalidazione delle pubblicazioni precedenti. La risoluzione della risorsa
`statistics.undefined` usa lingua e bundle espliciti: il modello accetta un
bundle interno con default `.main`, mentre le prove hostless usano il bundle
test che contiene il catalogo. Nessun catalogo o contratto pubblico è cambiato.

## Sequenza delle prove native

Le corse mirate della tabella seguente hanno usato `GlifiStudio.xcworkspace`, schema
`GlifiStudio-macOS`, configurazione Debug, destinazione macOS e selezione
`GlifiStudioMacTests/StudioStatisticsTests`, senza firma. I conteggi distinguono
definizioni ed esecuzioni, incluse le istanze parametrizzate.

| Fase | Esito osservato | Evidenza locale |
| --- | --- | --- |
| RED originario, produzione invariata | Exit 65; 6 definizioni, 49 esecuzioni; fallisce soltanto `findsTheItalianValueShownByTheResultTable`: conteggio 0 anziché 1 | `313-red-results.json`; `313-red-native-summary.json` |
| Primo candidato, risorse del test | Exit 65; 11 definizioni, 56 esecuzioni; 2 definizioni falliscono perché il bundle implicito del runner restituisce `statistics.undefined` invece della traduzione | `313-green-results.json`; `313-green-attempt-summary.json` |
| Candidato con bundle esplicito | Exit 0; 11 definizioni, 56 esecuzioni; precede la regressione sul task Locale già cancellato | `313-validation-2-results.json`; `313-validation-2-native-summary.json` |
| RED del task Locale già cancellato, prima del guard | Exit 65; 12 definizioni, 57 esecuzioni; fallisce soltanto `cancelledLocaleChangeDoesNotOverrideTheActivePresentation`: conteggio 1 anziché 0 | `313-cancelled-locale-red-results.json`; `313-cancelled-locale-red-summary.json` |
| GREEN finale con guard | Exit 0 in 11,637 s; 12 definizioni, 57 esecuzioni; 0 fallimenti e 0 skip; `runtimeWarnings: []` | `313-final-green-results.json`; `313-green-native-summary.json` |

Il primo candidato fallito riguarda il bundle hostless delle prove e resta
separato dai due RED comportamentali. Non è attribuito al difetto prodotto
originario. I log e i bundle xcresult di ogni fase sono conservati con gli
stessi prefissi nella cache locale
`~/Library/Caches/GlifiStudio/evidence/macOS-2026-11-24-audit-312/`.

Il GREEN finale comprende 3 definizioni parametrizzate con 48 esecuzioni e
9 definizioni non parametrizzate. Copre valori it_IT/en_US, decimali, notazione
scientifica, interi, testo, infinità e indefinito; matching canonico; cambio
locale, filtro soppiantato, reset, task già cancellato e retry. Le nuove prove
attendono operazioni o notifiche effettive, senza introdurre polling o sleep.
Nel log Xcode compare una diagnostica `DVTAssertions` di `IDELaunchSession`,
distinta dalle segnalazioni runtime dell'applicazione. Gli insights temporali
di Xcode sono conservati nel riepilogo; non costituiscono una misura di
prestazioni del prodotto.

Lint Swift strict, controllo di localizzazione e `git diff --check` mirati ai
tre file sono superati. Nessun test, build o misura è attribuito a questo
documento oltre alle corse esplicitamente elencate.

## Identità dei sorgenti del GREEN finale

| File sotto `Apps/macOS/` | SHA-256 |
| --- | --- |
| `StudioStatisticsModel.swift` | `1b68f46a5f1ca5d216814bf91e6e8a78eecaf93b457fd3aa3da381078430b76b` |
| `StudioStatisticsView.swift` | `cb331b79ba168afdbd543fa7ee2de832b14fc11862fafb4ba6aec45deb4282e1` |
| `Tests/StudioStatisticsTests.swift` | `0fae585b6ac37ba14c6397305ff6952d5f1c7226ef06bedd6acbe1fab159951c` |

Gli hash prima e dopo la corsa sono identici. Nel secondo RED e nel GREEN
finale era presente e congelato anche il candidato di produzione Core 314;
le sue nuove prove Core non erano ancora applicate. Questa è una verifica
mirata dei tre file, non l'identificazione della composizione integrata dell'intero
repository.

## Inquadramento delle prove mirate

Le prove mirate precedenti erano Debug e non identificavano l'intera
composizione. Il gate `make verify`, la fonte finale e la successiva prova
Release della suite sono registrati separatamente nella chiusura seguente.

Sono escluse interazione grafica e verifiche manuali, VoiceOver, Voice Control,
tastiera, contrasto, pseudo-lingua e destra-sinistra. Nessun test o build iPadOS
è stato eseguito o dichiarato per questo lotto. Non si chiudono criteri HIG o
accessibilità che richiedono quelle evidenze.

## Chiusura della composizione macOS

La composizione congelata ha base `741da2e` e **1284 file**, fingerprint
`345c5f70a0ce4133c1325476a92f08ce40815bdad272ca5d75dc432131474b0e`. Il gate
`make verify` macOS termina con **exit 0** in **515,177 s**: 736 test Core,
161 Kit e 133 definizioni native / 420 esecuzioni Debug, senza failure, skip
o runtimeWarnings nel report nativo; build Release riuscita. La sola suite
Statistics ripete 12 definizioni / 57 esecuzioni in Release, senza errori.

Verificati anche 244 righe di oracoli e 64 casi Fraction, 2 PDF/A reali,
196 controlli CLI testuali, 132 operazioni / 264 confronti Kit-CLI, inventario
pubblico di 2840 dichiarazioni, 172 varianti e 22 checkpoint di recovery.
Il bundle Release ha risorse e lookup it/en corretti, 15 voci ispezionate e
zero corrispondenze nell’ambito vietato dichiarato. Non è un nuovo archivio
App Store e non attesta Finder o restoration.

Tutti i 1284 contenuti e modi coincidono con il manifest alla fine del gate;
archivio sorgente verificato, HEAD e indice invariati. Le sole evidenze e i
metadati di tracciabilità vengono chiusi dopo la verifica, conservando il
manifest del gate e il confronto separato dei file non documentali.
Il [rapporto strutturato](allegati/GS-VER-312-314-verifica.json) conserva
misure, conteggi e limiti. Il dossier locale `macOS-2026-11-24-audit-312`
contiene manifest, archivio, log, JSON sanificati e review indipendenti.

La diagnostica IDELaunchSession DVTAssertions appartiene a Xcode; i report
dei test non contengono runtimeWarnings. Restano esclusi CI remota di questo
lotto, iPadOS, audit visuali/assistivi manuali e G4/G5.
