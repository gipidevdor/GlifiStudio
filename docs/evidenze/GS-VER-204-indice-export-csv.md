<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-204 — Indice locale dei riferimenti Evidence nel CSV

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-204 |
| Tipo | Evidenza di ottimizzazione misurata |
| Versione | 1.0.0 |
| Stato | Superato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-204; RQ-009; RQ-040; RQ-044; RQ-063 |
| Riferimenti | GS-STD-001-17; ADR-0023; CMP-204 |

## Perimetro e contratto

La [GS-DOR-204](../pianificazione/dor-ottimizzazione-indice-export-csv.md) è
Ready prima del coding. `GlifiScientificExportRenderer.csvPayloads` cercava,
per ogni Evidence, tutti i Finding con almeno un riferimento a quell'identità.
L'incremento prepara un indice inverso locale `EvidenceID → [FindingID]`.

L'indice viene costruito scorrendo i Finding nell'ordine originale; un
`Set<EvidenceID>` distinto per ciascun Finding elimina solo le ripetizioni
della stessa identità entro quel Finding. Disposition e reason non cambiano
l'associazione, come nel precedente `contains`. La stessa Evidence può essere
associata a più Finding. La lettura dell'indice avviene nell'ordine originale
delle Evidence; non viene iterato l'ordine della tabella hash per produrre CSV.

Restano invariati i due payload, schema, media type, ordine, JSON canonico,
CRLF, escape e neutralizzazione delle formule. Preparazione dell'indice e
memoria effimera sono inclusi nell'operazione da misurare. L'indice non viene
persistito o condiviso fra export.

## Identità della modifica e della baseline

La copia di lavoro deriva da `a86a53b512bd777f191c89692e0c573a3d37a3ff` con
gli incrementi locali concomitanti. Il coordinatore ha congelato **271 file**
del Package e delle fixture prima di modificare i prodotti GS-202/203/204.
Il renderer è rimasto fermo fino alla conclusione della baseline Release.
Il confronto degli inventari conferma che il candidato cambia esclusivamente
renderer CSV, SpanMap e tokenizer; gli altri **268 file**, comprese fixture e
harness, restano identici. Negli scenari CSV la modifica pertinente è il renderer.

Il [record dell'archivio sorgenti](allegati/GS-VER-202-204-archivio-sorgenti.json)
conserva un archivio di **664.425 byte**, SHA-256 verificato
`3ef945ed177466487e25ddd997e48ca027b175285f677de53919a15fdf628a15`.
La verifica indipendente ha confrontato i 271 file della copia candidata e i
tre sorgenti della baseline con entrambi gli inventari; sono conservati anche
i due inventari identici agli allegati e il test CSV finale aggiuntivo.
I 277 membri sono file regolari, senza duplicati, link, percorsi assoluti,
traversal o cache di build.

| Artefatto | SHA-256 |
| --- | --- |
| Renderer baseline | `dea51e7a80f68a06487b446aa70eba6f4259e3123b11f421719b1b1fd3f550c2` |
| Renderer candidato | `d10d3480856f4a52a11d966968597baed8dc66d0c9fedf10b980cebb715e1476` |
| Test/harness CSV congelato per entrambe le misure | `6814b651e5db4ea17c65dfa82fd5e439594c224e6cff6182ef95e94be872c6e7` |
| Helper di misura congelato | `9b4b65677c7d34ef2778798bdb83f70efc0772094f36c41e3c39ee4fc278b5bd` |
| Inventario baseline | `60efee04fa6f582259e5ebd6e63c59a4781b889d214d6dbce523fc22a22dd820` |
| Inventario candidato | `60c5841e755db2664ff8264f1bea2a36b6379ce794d59058bbfb29d9fd9fb551` |
| Test nel workspace, con regressione aggiuntiva successiva alla baseline | `295d3437915f4f54e643c9dc7dec1092aaef3071a3b54589b417b45e9dfe1096` |

La regressione aggiuntiva usa tre riferimenti allo stesso EvidenceID con
disposition supporting, contrary ed excluded e reason diverse, più un altro
Finding che condivide l'Evidence. È aggiunta soltanto nel workspace: il file
di test e l'harness della copia A/B restano congelati. Non altera i workload
misurati o i risultati attesi della baseline.

## Metodo e dati sintetici

L'entry `pipelineOptimizationCSV` esegue sempre una regressione piccola contro
`referenceCSV`, definita con l'algoritmo lineare originale `filter/contains`.
Il confronto comprende l'intero contenuto e i metadati dei due payload, non
soltanto un checksum o il numero di righe.

Solo impostando `GLIFI_PIPELINE_BENCHMARK_DIRECTORY`, in Release, vengono
misurati due report da **256** e **2.048 Finding/Evidence**, con quattro
riferimenti ciclici per Finding. L'ordine editoriale e quello delle Evidence
sono invertiti rispetto alla generazione. Le identità sono deterministiche;
report, proiezione tramite gli initializer pubblici e riferimento completo
sono preparati fuori dal timer.

Il coordinatore esegue separatamente i filtri esatti dei tre workload, dopo
un'unica compilazione Release. Ogni misura CSV ha **un warm-up e sette
campioni grezzi**. Il timer include l'intero renderer, compresa la costruzione
dell'indice candidato. Uguaglianza completa, checksum SHA-256 e codifica del
rapporto vengono eseguiti dopo lo stop. La baseline ha superato gli **otto
confronti su otto** di ciascuno scenario; il candidato ripete gli stessi otto
controlli con interi payload, digest delle fixture e risultati esattamente uguali.

| Fixture | Digest della fixture | Digest dell'intero risultato |
| --- | --- | --- |
| 256 Finding/Evidence | `sha256:327f43c66feafe09c21c4966bb8ab02707a2e96d66950570108a8d05fe31c256` | `sha256:a57a427571d0b9bc2f487a737b4cc519f661bc35c3634831229c1a959d1c87d1` |
| 2.048 Finding/Evidence | `sha256:fb6661f7843b6a1608cf046cdbd5b3fc11dfdf509c7143f5d850aa994d039a71` | `sha256:f3c8b29220f83a6d360e6c03f545fe12cacf1770f79696cab43e86ff64982ac1` |

I [campioni grezzi della baseline](allegati/GS-VER-202-204-baseline.json) e
quelli del [candidato](allegati/GS-VER-202-204-candidate.json) sono conservati
con il [confronto](allegati/GS-VER-202-204-confronto.json) e gli inventari di
[baseline](allegati/GS-VER-202-204-inventario-baseline.json) e
[candidato](allegati/GS-VER-202-204-inventario-candidate.json).
La rilettura indipendente dei dieci workload conferma sette campioni per fase,
mediane e range corretti, otto confronti esatti e condizioni macchina equivalenti.
Il gate completo del lotto è superato come registrato di seguito.

## Ambiente e risultati disponibili

| Campo | Baseline e candidato osservati |
| --- | --- |
| Hardware | `Mac16,3`, 10 processori logici, 17.179.869.184 byte di memoria fisica |
| Sistema | `Version 27.2.1 (Build 26B131)` |
| Configurazione | Eseguibile di test SwiftPM Release, un workload per misura |
| Stato termico iniziale/finale | `nominal` → `nominal`, in entrambi gli scenari |
| Low Power Mode iniziale/finale | `true` → `true`, in entrambi gli scenari |
| Cache | Processo caldo, nessun flush; non si misura il disco fisico a freddo |
| Esecutore e data | Codex, 2026-11-21 |

Entrambe le corse A/B terminano con exit 0. Valori in millisecondi, mediana e
intervallo minimo–massimo dei sette campioni; percentuali calcolate sui valori
non arrotondati conservati negli allegati:

| Scenario | Baseline mediana [min–max] | Candidato mediana [min–max] | Riduzione della mediana |
| --- | --- | --- | --- |
| 256 Finding/Evidence, quattro riferimenti ciclici | 30,423 [29,732–30,570] | 27,925 [27,763–28,144] | 8,21% |
| 2.048 Finding/Evidence, quattro riferimenti ciclici | 385,538 [381,380–389,489] | 234,297 [225,753–237,189] | 39,23% |

Il beneficio osservato è **1,089 volte** nello scenario da 256 elementi e
**1,646 volte** in quello da 2.048. La misura comprende preparazione dell'indice
e serializzazione completa; non riguarda l'intera scrittura di un export.
L'indice aggiunge memoria locale proporzionale alle associazioni distinte
Finding–Evidence. Il [riepilogo dei processi](allegati/GS-VER-202-204-processi.json)
riporta RSS massimo dell'intera invocazione CSV di `swift test/time -l` da
**131.907.584** a **137.199.616 byte**, ossia **+5.292.032 byte**
(**+5,046875 MiB**). I [dati baseline](allegati/GS-VER-202-204-baseline-processi.txt)
e [candidati](allegati/GS-VER-202-204-candidate-processi.txt) includono avvio,
SwiftPM, fixture, riferimento e controlli. È un'osservazione interoprocesso:
il delta non è attribuito al singolo indice, renderer o UI e non si rivendica
una riduzione della memoria. Il beneficio di latenza va letto insieme a questo
costo strutturale e al limite della misura RSS.

## Regressioni e gate completo

I test piccoli coprono riferimenti duplicati e condivisi, Finding senza
riferimenti, Evidence non selezionata filtrata dalla proiezione, ordine,
selezione vuota, rifiuto di Evidence mancanti, Unicode, quote, virgole, newline,
CRLF e prefissi formula `=`, `+`, `-`, `@`, tab e ritorno carrello. Il report
passa dagli initializer pubblici, che validano selezione e completezza dei riferimenti.
Il nuovo caso sulle disposition protegge specificamente la deduplicazione
per sola EvidenceID.

Formattazione, lint e diff-check dei file assegnati sono superati. Dopo il
confronto A/B, **12 test Release mirati sulla copia congelata** terminano con
exit 0 in 0,129 s; il [log mirato](allegati/GS-VER-202-204-test-mirati.txt)
conserva l'esecuzione. Nel successivo gate sul workspace passa anche il caso
aggiuntivo sulle disposition: il [log completo](allegati/GS-VER-202-204-gate.txt)
registra il test «Il CSV deduplica per EvidenceID entro il Finding anche con
disposition e reason diverse» superato.

Il coordinatore ha completato **`make verify` con exit 0**, profilo globale
macOS/iPadOS. Il [record del gate](allegati/GS-VER-202-204-gate.json) conferma
che i tre sorgenti produttivi del lotto conservano gli hash misurati.

| Controllo | Esito osservato |
| --- | --- |
| Swift Testing GlifiCore | 380 test superati |
| Swift Testing GlifiKit | 52 test superati |
| Test macOS dal workspace | 46 test distinti e 108 esecuzioni sulla destinazione, zero failure o skip |
| Oracoli indipendenti | 153 righe riprodotte e collegate ai test Swift |
| Operatori testuali CLI | 51 controlli su 15 fixture condivise, parità entro `1e-12` |
| Recovery dopo terminazione del processo | 22 checkpoint validi |
| veraPDF | Due PDF/A-2u conformi |
| macOS | Test/build Debug e build Release senza firma |
| iPadOS | Build Debug e Release senza firma per destinazione generica iOS Simulator |

Il [riepilogo nativo macOS](allegati/GS-VER-202-204-test-macos.json) distingue
46 test da 108 esecuzioni. Xcode segnala CoreSimulator `1171.7.0` precedente
a `1174.21.0` e l'avviso sulla dichiarazione di apertura in-place iPadOS:
le build generiche superate non attestano esecuzioni runtime del simulatore.
La corsa non convalida nuovi archivi o packaging App Store.

La successiva esecuzione Core/Kit, dopo le modifiche concomitanti ai pesi dei
termini e ai relativi test, termina con **exit 0: 381 test Core e 52 test Kit**.
Il [record del ripasso](allegati/GS-VER-202-204-ripasso-core-kit.json) conferma
che i **205 file sorgente e di test** controllati restano invariati durante la
corsa; il [log](allegati/GS-VER-202-204-ripasso-core-kit.txt) conserva gli esiti.
Questo ripasso è distinto dal gate globale sopra riportato e non modifica i
tre sorgenti produttivi del lotto.

## Limiti dell'evidenza

Non viene introdotta una soglia prestazionale vincolante. Le misure restano
limitate a questa macchina, con cache calda e Low Power Mode attivo, e non si
estendono a PDF, Markdown, scritture del bundle, UI, consumo energetico o
prestazioni dell'app completa.


## Pulizia finale

Rimossa la sola cache di lavoro del coordinatore dopo la chiusura delle prove:
**3.443.576 KiB, circa 3,28 GiB allocati** prima della rimozione. Il
[record di pulizia](allegati/GS-VER-202-204-pulizia.json) conferma l'assenza del
percorso e distingue la dimensione allocata dal delta di spazio libero APFS.
Allegati, log sanificati, inventari e archivio sorgenti verificato restano
conservati; toolchain, dipendenze e cache delle altre sessioni sono preservate.
