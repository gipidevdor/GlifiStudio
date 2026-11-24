<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-231 — Lookup delle etichette fonte nelle viste macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-231 |
| Tipo | Evidenza di verifica applicativa macOS |
| Versione | 1.3.0 |
| Stato | Superato nel perimetro automatico macOS sul checkpoint ffbfb431 |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | GS-DOR-231; RQ-009; RQ-013; RQ-047; RQ-063 |

## Perimetro e base

Il candidato finale conserva tutti gli output e riduce il batch di 1 000 fonti
per 10 000 lookup da 49,061791 a 2,069916 ms nel confronto Release. Conserva
anche regressioni esplicite nei casi piccoli e first-only: il vantaggio non è
universale. Gate e preflight del checkpoint ffbfb431 sono superati.
Il perimetro è il lookup del primo ordinale della fonte nei due client macOS,
con label, fallback, ordine e snapshot corrente conservati.

Il lavoro è iniziato nel repository isolato `/tmp/MacStudio230Work`, sulla base
`f6bba3e280de23b87f30e164c8970c4c0883af59`. È poi integrato nel checkout originale
basato su `02c1c666437a58743dba40193b9a94d4a7a3a11c`, preservando il WIP GUI 222.
Le modifiche documentali sono applicate da proposta a tre vie con preflight di
tutti gli SHA originali e backup; matrice unita per identificatore e voci di
entrambi i lavori conservate. I guard equivalenti della HomeView e i nuovi
riferimenti PBX sono integrati senza sovrascrivere il lavoro GUI.
Questi incrementi non introducono formati, algoritmi scientifici, dipendenze o
nuove funzionalità.

## Prima generazione verificata, candidato prestazionale respinto

La prima generazione, conservata in archivio, contiene **924 file**, con
manifest SHA-256
`4d6969dd2bc3fa769c87ba40a88fa207a3f28624ec138aa50c9f6f688aa2ded9`.
`make verify-macos` sul nuovo snapshot termina con **exit 0**: 423 test Core
più 63 Kit, totale 486; 194 righe di oracoli, due PDF/A-2u conformi, 51 controlli
CLI, 22 checkpoint recovery e contratto CLI QueryAST superati. Test/build Debug
e build Release macOS sono superati. I test nativi contano **67 definizioni e
224 esecuzioni**, dieci parametrizzate con 167 run più 57 non parametrizzate,
zero fallite/saltate e `runtimeWarnings: []`; riepilogo sanificato
`generations/4d6969dd/final-native-results.json` nel dossier finale.
Anche `Scripts/check-app-store-packaging.sh --macos-only` termina con exit 0
sul medesimo snapshot: analisi Release, archivio macOS senza firma e controlli
plist/privacy/assets superati. Log `generations/4d6969dd/packaging-macos.log`, SHA-256
`1eb2d47f79eb61e919289386a723100b3bc9126b7d043691d52b116b21faec29`.
CMP-230/232 sono `verified` nel solo perimetro automatico dello snapshot;
CMP-231 non eredita il risultato della prima generazione: il relativo helper
ArraySlice è respinto dalle misure riportate sotto. Manifest, archivio e log
di questa generazione sono conservati nel sottodossier `generations/4d6969dd`.
Le prove native isolate restano distinte dai gate combinati e non
promuovono automaticamente GUI 222, iPadOS o G4.

Il confronto live effettuato nella fase successiva al primo freeze rileva un
cambiamento GUI 222 in
`Apps/Shared/StudioHomeView.swift`: contesto workspace e status bar sono
riposizionati nel detail. Selettori e guard della query restano invariati e i
sette file specifici del lotto risultano identici al confronto, ma il file
condiviso HomeView non è interamente uguale allo snapshot. Il gate 4d6969dd non
attesta tale layout successivo, che appartiene a GS-VER-222; non si dichiara
una corrispondenza globale di tutti i sorgenti posseduti o della copia corrente.

## Generazione finale verificata

Il candidato Sendable è integrato nel checkout originale preservando il WIP
successivo. La verifica dell'incremento usa un nuovo snapshot di **924 file**,
manifest SHA-256
`ffbfb43191444018a5bd6163e90a46a6ed2c0c832a0fd5a7180449f963470b13`:
checkpoint combinato 4d6969dd più helper finale e documenti 230–232 aggiornati,
sulla base `02c1c666437a58743dba40193b9a94d4a7a3a11c`.
Il nuovo snapshot esclude il WIP 223 e il riposizionamento successivo di
workspaceContext/statusBar. Non è la certificazione della copia di lavoro
condivisa corrente o di tutto il suo codice.

`make verify-macos` e `Scripts/check-app-store-packaging.sh --macos-only`
terminano entrambi con **exit 0** sul nuovo fingerprint. Passano **486 test
Core/Kit** (423 Core e 63 Kit), 194 righe di oracoli, due PDF/A-2u, 51 controlli
CLI su 15 fixture condivise con parità entro 1e-12, 22 checkpoint recovery e
QueryAST. Test nativi Debug e build Release sono superati: **67 definizioni e
224 esecuzioni**, dieci parametrizzate con 167 run più 57 non parametrizzate,
zero fallite/saltate e `runtimeWarnings: []`.

Il preflight supera analisi Release, archivio macOS senza firma, metadati
Info.plist, privacy manifest e asset. I riepiloghi sanificati sono
`final-native-results.json` e `packaging-final-results.json`; log finali
`verify-macos.log`, SHA-256
`af45860bb34fb68bc38c2fc01bf093d8fb9286885f3b56361b3399c52918a0a6`,
e `packaging-macos.log`, SHA-256
`76baa784469fa73543e324b9a5d16bfff488b28729405545dc39cda6198109e2`.
Misure, parità, review, integrazione e nuovo gate giustificano CMP-231
`verified` nel solo perimetro automatico di questo checkpoint. Dossier finale:
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-ffbfb431/`.

## Contratto di verifica applicato

Helper reale lineare congelato prima del candidato; DTO, output completo identico,
due warmup e sette campioni grezzi Release per sette scenari, incluso early-hit
ripetuto. Costruzione dell'indice compresa nel batch; fixture e checksum fuori
timer. Nessun claim SwiftUI.body, GUI o energia.

La DoR Ready precede la patch produttiva. CMP-231 parte `specified`, passa a
`implemented` con il candidato misurato e integrato e a `verified` soltanto
con il gate/preflight del nuovo contenuto identificato. Le prove storiche
198/199 non vengono estese a questo lotto.

## Preparazione della baseline

L'estrazione del helper lineare realmente usato dalle due viste è completata,
senza introdurre il dizionario; lint/diff e compilazione/test nativi del lotto
sono superati. Il build Release del supporto di misura è pronto, ma i dati
pilota acquisiti durante un archivio esterno concorrente sono esclusi dal
confronto prestazionale formale. Baseline e candidato richiedono il controllo
dei compilatori osservati ai checkpoint prima e dopo il run. Low Power Mode è
osservato attivo e la termica finale nominale;
la configurazione dell'utente non è modificata. Nessun beneficio è attribuito
a questa fase preparatoria.

## Sonde diagnostiche non rappresentative, non promosse

Le prime passate senza `xcodebuild`/`swift-frontend` osservati ai due checkpoint,
usano pseudo-ID SHA di 87 caratteri e stringhe richiesta condivise con le fonti.
Non rappresentano i SourceRevisionID UUID di 52 caratteri e lo storage distinto
di snapshot/risultati: sono conservate soltanto come diagnostica, senza claim
prestazionali applicativi. Usano sette scenari, due warmup e sette campioni.
Ambiente osservato:
arm64, macOS 27.2.1 build 26B131, dieci processori logici e 16 GiB di memoria;
Low Power Mode attivo e termica nominale, senza cambiare preferenze dell'utente.
Il settimo scenario first-only è aggiunto prima delle misure candidate e usa lo
stesso harness per entrambe le implementazioni.

L'helper lineare ha SHA-256
`e94ad93f3f3b131d7380b8de7727ed8d483bfce2b7956917289986878fb3aade`;
il primo candidato adattivo 2×N ha SHA-256
`72feb37365ca9390af61f5f4c860c1a9486a13fb62611be7c72504a26e33da94`.
Input hash, interi output e relativi hash sono identici in tutti i sette casi.

| Fonti × lookup | Baseline mediana ms | Primo candidato mediana ms |
| --- | ---: | ---: |
| 10 × 3 | 0,000375 | 0,001583 |
| 100 × 1 000 | 0,554417 | 0,213500 |
| 1 000 × 0 | 0,000041 | 0,000042 |
| 1 000 × 1 | 0,000125 | 0,000209 |
| 1 000 × 50 | 0,238542 | 0,364333 |
| 1 000 × 10 000 | 48,874584 | 2,098375 |
| 1 000 × 10 000, solo primo ID | 0,442250 | 1,485708 |

Il rapporto 23,29× del caso lungo appartiene soltanto a questa sonda di stringhe,
non è un risultato prestazionale del client. Le regressioni a cinquanta lookup e
first-only motivano ulteriori ipotesi, senza promuovere questo passo. I casi
minuscoli restano visibili, senza trattare differenze di nanosecondi come nuove
soglie. Campioni grezzi e output completi sono conservati in
`/tmp/MacStudio230Evidence/231-sha-pilot-baseline.json` e
`231-sha-pilot-step1.json`.

Ready 1.3 precede il nuovo tuning: budget conservativo 64×N e fast path del
primo ID prima di mappa/contatore. Sono euristiche interne motivate dai dati,
senza modifica di soglie scientifiche o gate. Il nuovo candidato richiede
misure e test propri; in quella fase CMP-231 resta `specified` fino all'esito.

Ready 1.3.2 precede il protocollo rappresentativo finale: UUID deterministici
canonici validati con Foundation fuori timer, richieste decodificate mediante
JSON separato con valori identici e storage indipendente. Tutti gli stadi sono
rimisurati con il medesimo harness aggiornato; le sonde precedenti non
sostituiscono quel confronto. Le successive iterazioni portano il confronto a
cinque implementazioni: baseline, tre candidati respinti e candidato Sendable.

## Protocollo UUID: baseline e passo intermedio

Le prime due passate del protocollo finale sono completate con exit 0,
medesimo harness corretto, UUID canonici e richieste decodificate separatamente,
lifetime esplicito oltre il clock finale. Due warmup e sette campioni per fase;
Low Power Mode attivo e termica nominale. I JSON `231-baseline.json` e
`231-step1.json` nel dossier temporaneo sostituiscono le sonde SHA come dati
rappresentativi per queste due implementazioni.

| Fonti × lookup | Baseline mediana ms | Passo intermedio 2×N mediana ms |
| --- | ---: | ---: |
| 10 × 3 | 0,000458 | 0,001709 |
| 100 × 1 000 | 0,562834 | 0,176584 |
| 1 000 × 0 | 0,000042 | 0,000042 |
| 1 000 × 1 | 0,000125 | 0,000250 |
| 1 000 × 50 | 0,253458 | 0,295958 |
| 1 000 × 10 000 | 49,061791 | 1,604542 |
| 1 000 × 10 000, solo primo ID | 0,530792 | 1,226125 |

Anche il protocollo rappresentativo conferma le regressioni del passo 2×N
a cinquanta lookup e first-only: questo passo non è adottato. I passi 64×N sono
riportati nelle sezioni successive; i tentativi rifiutati dal controllo delle
compilazioni non sono risultati comparativi. Nessuno stato viene promosso per
la sola presenza di questi due JSON.

Le fasi hanno confini distinti: `constructionOnly` misura soltanto il
costruttore dell'helper; `lookupOnly` include anche l'eventuale costruzione lazy
della mappa nel ciclo, ed `endToEnd` comprende costruttore, lookup e output.
Non è una misura di lookup puro con indice già pronto; il teardown è fuori
timer mediante la garanzia di lifetime dichiarata.

## Secondo candidato respinto

Il candidato 64×N con fast path e ricerca ArraySlice ha SHA-256
`a1e3c20c9f116300d2df6626192d7357e6810cec685a8f5711f4d2eb1fceeffb`.
Il run ammesso dal controllo dei compilatori termina con exit 0; tutti i sette
input e output completi coincidono, ma le latenze peggiorano:

| Fonti × lookup | Baseline mediana ms | Secondo candidato mediana ms |
| --- | ---: | ---: |
| 10 × 3 | 0,000458 | 0,001709 |
| 100 × 1 000 | 0,562834 | 0,709500 |
| 1 000 × 0 | 0,000042 | 0,000042 |
| 1 000 × 1 | 0,000125 | 0,000125 |
| 1 000 × 50 | 0,253458 | 2,366125 |
| 1 000 × 10 000 | 49,061791 | 6,265542 |
| 1 000 × 10 000, solo primo ID | 0,530792 | 0,520542 |

La regressione circa 9,3× a cinquanta lookup impedisce l'adozione anche di
questo candidato; il miglioramento del caso lungo non la cancella. I dati sono
conservati in `231-step2.json`, `231-step2-run.log` e
`231-comparison-step2-rejected.json` nel dossier temporaneo.

## Terzo candidato respinto

Ready 1.4 precede il ripristino di `Array.firstIndex` sull'intero Array al posto
di ArraySlice, conservando budget 64×N, fast path e contatore indice+1 o N per
assenza. Il terzo helper ha SHA-256
`63a23fc8bc6bc95fe1f262f3f2d22a507e046b49d94e4d31866c8623a9d4d6b3`.
Il run termina con exit 0 e output completi identici, ma regredisce ancora:

| Fonti × lookup | Baseline mediana ms | Terzo candidato mediana ms |
| --- | ---: | ---: |
| 10 × 3 | 0,000458 | 0,002042 |
| 100 × 1 000 | 0,562834 | 0,558084 |
| 1 000 × 0 | 0,000042 | 0,000042 |
| 1 000 × 1 | 0,000125 | 0,000125 |
| 1 000 × 50 | 0,253458 | 1,587333 |
| 1 000 × 10 000 | 49,061791 | 4,631709 |
| 1 000 × 10 000, solo primo ID | 0,530792 | 0,520459 |

La regressione circa 6,26× a cinquanta lookup impedisce l'adozione anche di
questo passo. Dati completi in `231-step3.json` e `231-step3-run.log`.
Il disassembly dei candidati individua copie/distruzioni del DTO nel percorso
ArraySlice e controlli dell'executor MainActor nel predicato per elemento,
anche nel percorso Array. Sono osservazioni del codice emesso; l'attribuzione
di una quota temporale a ciascun costo resta un'inferenza, non un profiling
separato dei due costi.

## Candidato con predicato Sendable: misura completata

Ready 1.5 precede l'annotazione esplicita `@Sendable` del solo predicato.
Il confronto legge `source.sourceRevisionID` e cattura il parametro String
immutabile; non cattura `self`, contatore, mappa o stato UI. Lettura dell'Array,
budget e costruzione/cache restano nel metodo MainActor. Non sono introdotti
Task, thread, hop, unsafe o API pubbliche.

L'helper ha SHA-256
`db90c0a69b575a88c5a245d107fac4323683d8e393727167c5c7c7c09a98940e`.
Il disassembly dell'oggetto Release dell'app reale sullo snapshot ffbfb431,
con isolamento predefinito MainActor, conferma un ciclo lineare di 13
istruzioni uguale a quello del benchmark, salvo la rilocazione della chiamata
al confronto String. Nel ciclo non compaiono controlli dell'executor per
elemento né copie/distruzioni dell'intero DTO. Resta un controllo dell'executor
fuori dal ciclo dopo un match: non sono rimossi tutti i controlli dell'actor.
L'oggetto conservato ha SHA-256
`00cb26ec58fe636c32dedde788001c771004f87f700f7c53694e77792873287c`;
review e assembly sono in `231-native-app-object-review.json` e relativo
allegato, con oggetto in `231-native-object/StudioSourceLookup.o`.
Questo confronto di codice non misura il tempo dell'app o di SwiftUI e non
dimostra equivalenza ABI dell'intero binario.

Il run finale termina con exit 0; tutti i cinque stadi hanno input hash,
interi output e output hash identici nei sette scenari. È verificato anche
l'oracolo indipendente degli indici: sequenza ciclica primo/medio/ultimo/assente,
oppure soli zeri nello scenario first-only. Mediane, estremi e sette campioni
per ognuna delle tre metriche sono ricalcolati dai JSON.

| Fonti × lookup | Baseline mediana ms | Candidato Sendable mediana ms |
| --- | ---: | ---: |
| 10 × 3 | 0,000458 | 0,000584 |
| 100 × 1 000 | 0,562834 | 0,199667 |
| 1 000 × 0 | 0,000042 | 0,000042 |
| 1 000 × 1 | 0,000125 | 0,000166 |
| 1 000 × 50 | 0,253458 | 0,263750 |
| 1 000 × 10 000 | 49,061791 | 2,069916 |
| 1 000 × 10 000, solo primo ID | 0,530792 | 0,702792 |

Il batch lungo migliora di circa **23,70×** e quello 100×1 000 di circa
**2,82×**. Il beneficio non è universale: cinquanta lookup aumentano di
0,010292 ms, circa 4,06%; first-only aumenta di 0,172 ms, circa 32,4%.
Le differenze dei casi 10×3 e 1 000×1 sono frazioni di microsecondo e non
supportano rapporti di velocità significativi. Lo scenario senza lookup
conserva la mediana osservata.

La dispersione resta visibile: per il batch lungo finale i sette campioni
vanno da 1,765417 a 2,603000 ms; per cinquanta lookup da 0,255708 a 0,299500 ms;
per first-only da 0,518791 a 0,908333 ms. Campioni completi, tre segmenti
temporizzati e output sono in `231-candidate.json` e relativo run log.
Le misure osservano il compromesso del helper e non stabiliscono una soglia
di frame, di rilascio o un tempo di rendering della GUI.

Tutti gli stadi finali usano il medesimo harness SHA-256
`3565dc2d064a48623d69210481f58cc862e2674e31640cdf5c889a65b2d29fa4`,
due warmup e sette campioni Release sul Main Actor. Le fixture e la loro
preparazione restano fuori timer; la promozione lazy della mappa è dentro il
batch e dentro `lookupOnly`. I dati osservano arm64, macOS 27.2.1, Swift 6.4.2,
Low Power Mode attivo e termica nominale nel riepilogo finale. Le statistiche
di memoria di `/usr/bin/time -l` riguardano l'intero processo, non le sole
allocazioni dell'indice.

Il benchmark usa GlifiKit congelato dalla base `f6bba3e`; il confronto del
contratto DTO è separato dal gate dell'app combinata. Il helper legge soltanto
`sourceRevisionID` e l'ordine/count dell'Array. La parità del sottoinsieme di
sorgenti non è una certificazione ABI dell'intera app.

Il test nativo `StudioSourceLookupTests` controlla ID assenti, snapshot vuoto,
primo duplicato, riordino e sostituzione dello snapshot, attraversando sia la
fase lineare sia la mappa lazy. Il duplicato non iniziale viene controllato
anche dopo la promozione, senza farsi mascherare dal fast path del primo ID.
La prova funzionale non viene presentata come misura prestazionale.

Le misure non trasferiscono il risultato del gate 4d6969dd al nuovo helper:
la promozione usa i test nativi e il nuovo gate/preflight ffbfb431, con
fingerprint e risultati propri.

Il runner controlla soltanto l'assenza osservata di `xcodebuild` e
`swift-frontend` prima e dopo il run. Non garantisce macchina inattiva, assenza
di carichi CPU/I/O non compiler o assenza di contesa nell'intervallo fra i due
checkpoint. Le condizioni energetiche sono quelle registrate: Low Power Mode
attivo e termica nominale nel riepilogo finale. Le misure non dimostrano
responsività GUI, consumo energetico o un beneficio universale.

## Limiti

Soltanto macOS e verifiche automatiche. Nessuna attestazione di GUI reale,
VoiceOver, iPadOS, autosave, file provider, G4 o CI remota. Le modifiche degli
altri programmi sono preservate e richiedono le rispettive evidenze.
