<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-306 — Progetto Xcode completo e verificabile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-306 |
| Tipo | Evidenza di implementazione e verifica dei metadati |
| Versione | 1.2.0 |
| Stato | Superato nel perimetro automatico macOS del checkpoint 328169f7; limiti interattivi aperti |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | GS-DOR-306 Ready prima del codice; gate, nativi Debug/Release e preflight superati sul checkpoint identificato |
| Riferimenti | GS-DOR-306; CMP-306; RQ-005; RQ-062; RQ-063; GS-STD-001-08; GS-STD-001-16; GS-APL-007; GS-I18N-002; GS-DEV-002 |

## Perimetro e provenienza

[GS-DOR-306](../pianificazione/dor-progetto-xcode-completo.md) delimita navigator,
configurazioni hostless, schema macOS, localizzazione InfoPlist e strumenti di
verifica. Non cambia sorgenti applicativi/package, API, dati, UTI, entitlement,
firma o comportamento analitico.

La cattura iniziale isolata comprende 1212 file con base
`d368285010dca17f5ef72819da25b6890d0de32a` e fingerprint
`fdda820908b8b675864c7f361ec89c7d077048808b2858064107fc0240fd1810`.
Include i contributi 302/303/304 senza attribuirli al lotto 306 e non incorpora
il successivo completamento KH 305. La baseline non è l'esito della nuova
verifica. Il nuovo ingresso congelato ha fingerprint
`328169f7f24d860cdba61dc87cba2d7cf88b0f5c19fead2e874bd3972d64d69a`
e comprende **1219 file**, con la stessa base Git d368285. Gate, test nativi
Release indipendenti e preflight sono terminati con exit 0; il confronto finale
conferma tutti i 1219 hash e modalità invariati durante le prove.

Questa è una composizione isolata che include i contributi 302/303/304 presenti
nella cattura. Il checkout principale è avanzato nel frattempo a `76e5871` con
nuovo Core 305: **le presenti corse non verificano quel nuovo runtime**.
Un successivo controllo strutturale dell'inventario integrato non estende gli
esiti numerici, nativi o di packaging a sorgenti diverse.

Le prove mirate sono conservate in
`~/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-project-306/`.

## Implementazione

| Area | Contratto attuato |
| --- | --- |
| Navigator | Dodici cartelle native soltanto di navigazione: sette radici del repository, quattro sottocartelle Config e GlifiCore sotto Packages; file radice espliciti e gruppo Tests con riferimenti conservati |
| Membership | Sources invariati: 29 macOS, 11 iPadOS, 30 test hostless; 16 file test e 14 sorgenti di supporto della baseline. Nessuna cartella del repository associata ai target. Il solo catalogo InfoPlist si aggiunge alle risorse dei due target app, non dei test |
| Dipendenze | GlifiKit rimane l'unico prodotto del package locale collegato ai tre target; il target test lo dichiara esplicitamente senza duplicare sorgenti SwiftPM |
| Configurazioni | Common contiene impostazioni neutre; gli ingressi Debug e Release ereditano i rispettivi profili. Release usa -O/wholemodule senza DEBUG, Debug -Onone con DEBUG; entrambe restano hostless |
| Schema | Analisi macOS in Release, BuildAction del target test attiva soltanto per testing; schema iPadOS conservato e verificato solo strutturalmente |
| Documento | InfoPlist.xcstrings condiviso it/en usa la sola chiave RAW «Progetto Glifi Studio», già presente in CFBundleTypeName e UTTypeDescription nested. Plist base, UTI e formato invariati |
| Secure coding | Rimossi la chiave LSApplicationSupportsSecureRestorableState non documentata e il solo marker che ne richiedeva la presenza. La policy AppKit documentata per app collegate con SDK macOS 14 o successivi è citata nella Ready; nessun delegate o entitlement aggiunto |

## Controlli mirati osservati

| Prova | Esito effettivo |
| --- | --- |
| Checker completo nativo | Exit 0: 215 oggetti, 12 cartelle, tre target e 1219 file inventariati al momento della prova; riferimenti, percorsi, fasi, Sources/Resources, package, schemi e configurazioni validi |
| Checker portabile | Exit 0 per XML/xcconfig; dichiara esplicitamente grafo PBX e inventario non verificati. Il self-test impedisce l'invocazione di strumenti nativi nel percorso portabile |
| Fixture semantiche | 23 casi negativi rifiutati, inclusi riferimenti orfani, path, cicli, duplicati, source di piattaforma errata, membership, package, schemi e configurazioni |
| Lessico PBX | Cinque fixture positive verificano commenti/stringhe ingannevoli, TargetAttributes annidati e chiavi quotate/escaped senza falsi positivi |
| Impostazioni risolte | Sei configurazioni dei tre target lette tramite Xcode; distinzione Debug/Release e impostazioni hostless osservate. La risoluzione iPadOS è solo metadata, senza build |
| Verificatore bundle | Sorgente Swift compilato; una fixture bundle sintetica positiva e sette negative superate. Verifica ancora sintetica di metadati/presenza risorse, distinta dal catalogo compilato del prodotto |
| Review indipendenti | Grafo/membership e configurazioni/schemi riesaminati; record review-project-graph.json e review-project-settings.json con i rispettivi limiti |

Il checker iniziale validava il solo grafo normalizzato da plutil. Il difetto
riprodotto accettava due definizioni raw identiche o quotate/commentate dello
stesso object ID e otteneva comunque 215 oggetti JSON. Il RED effettivo e il
GREEN del nuovo controllo sono separati in
`duplicate-definition-checker-red.json` e `duplicate-definition-checker-green.json`.
Il controllo lessicale aggiuntivo considera solo le chiavi immediate della mappa
objects, riconosce stringhe/commenti/escape e non scambia TargetAttributes per
nuove definizioni. plutil resta l'unico parser del grafo e riceve il testo già
controllato. La prima fixture RED ebbe un errore del solo harness per root
non canonicale; il record conserva anche tale passaggio, poi corretto prima
della riproduzione valida.

Una seconda review riproduce tre ulteriori falsi PASS: ID target ripetuto nella
lista del progetto, DEBUG inline nella configurazione Release del PBXProject e
Release del progetto associata alla base Debug. Il fix verifica l'unicità di ID
e nomi prima di costruire la mappa target e controlla basi/override delle due
configurazioni di progetto, oltre a quelle dei tre target. I tre RED/GREEN sono
in project-configuration-checker-red.json e project-configuration-checker-green.json;
PBX e xcconfig reali rimangono invariati.

La versione finale dello script ha SHA-256
`957c89fc89522372706057aee56d338e9ce53a333ef4ff0e1641db8f70ea30fd`.
`checker-results.json` identifica i tre profili effettivamente eseguiti; la
versione precedente rimane separata. Le fixture non modificano il PBX reale.

## Perimetro del delta e conservazione dei contributi

`source-scope-review.json` confronta l'inventario finale con la cattura iniziale:
**17 file esistenti modificati, sette aggiunti, zero rimossi**, per 24 percorsi
del lotto. I restanti **1195 file preesistenti** mantengono hash e modalità.
Il confronto diretto dei 1219 file del Work congelato coincide con il manifest.

Sono invariati tutti i 61 file Apps preesistenti, inclusi 46 sorgenti Swift,
i 340 file Packages, le 56 fixture del repository e i due appunti grezzi.
L'unica aggiunta in Apps è il catalogo InfoPlist.xcstrings dichiarato dal lotto.
Il confronto non attribuisce a 306 i contributi 302/303/304 già nella cattura e
non certifica eventuali ulteriori WIP del checkout principale.

Il record prepara un CAS per i soli 24 percorsi: hash/modalità attesi della
baseline oppure assenza per i nuovi file, e hash/modalità del candidato
congelato. Le osservazioni del checkout principale sono puntuali e non sono
un'autorizzazione o un'applicazione di patch; ogni trasferimento deve rileggere
lo stato corrente e preservare gli aggiornamenti concorrenti. I metadata
conclusivi successivi alle prove richiederanno aggiornamento del relativo CAS.

## Risultati conclusivi osservati

Le tre corse usano cache indipendenti e lo stesso fingerprint 328169f7.
I conteggi seguenti provengono da questa generazione; nessun risultato precedente
è trasferito automaticamente. `verify-results.json`, `packaging-results.json`
e `release-native-results.json` registrano ciascuno il proprio exit 0.

| Verifica | Esito effettivo |
| --- | --- |
| Gate make verify macOS | Exit 0, 695,872 secondi; controlli condivisi e build Debug/Release macOS superati |
| Package Core/Kit | 793 test: 644 Core e 149 Kit, entrambi superati; il riepilogo Core usa la forma singolare «1 suite» |
| Oracoli | 236 righe numeriche riprodotte; 64 casi Binary64 Fraction distinti, senza codice prodotto |
| Trasporto analitico | 63 fixture condivise e 189 controlli CLI, parità entro 1e-12; tutti i 40 casi request enumerati dal compilatore coperti da fixture |
| Parità Kit/CLI | 130 operazioni e 260 confronti completi; 51 rifiuti JSON/versione/risorse/file/permessi/argomenti/privacy |
| CLI di progetto | 64 controlli bounded di file request, permessi, privacy e rifiuto prima della mutazione |
| Scenari | Inventario di 170 varianti e cinque workflow d'integrazione verificato contro compilatore e riferimenti ai test; non equivale ad audit GUI |
| Recovery e query | 22 checkpoint process-kill superati e QueryAST CLI superato |
| PDF/A-2u | Due PDF conformi nella stessa run |
| Nativi Debug | 125 definizioni, 409 esecuzioni; 22 parametrizzate generano 306 run, più 103 non parametrizzate. Zero failure, skip, expected failure e runtime warning; insights vuoti |
| Nativi Release indipendenti | Exit 0, 399,374 secondi; nuovo bundle con 125 definizioni e 409 esecuzioni, stessa riconciliazione 125−22+306. Zero failure, skip, expected failure e runtime warning; insights vuoti |
| Sei configurazioni risolte | Exit 0 per i tre target in Debug/Release; iPadOS soltanto risoluzione dei metadati |
| Checker progetto | 215 oggetti, 12 cartelle, 1219 file; 23 fixture negative e cinque positive lessicali superate |
| Verificatore bundle sintetico | Una fixture positiva e sette negative superate, distinte dalla prova sul prodotto reale |
| Bundle reale compilato | Lookup Foundation it/en: «Progetto Glifi Studio» e «Glifi Studio Project»; metadati generati minimo macOS 27.0 e SDK macosx27.2; risorse richieste presenti |
| Ispezione payload | 15 voci esaminate; zero corrispondenze con i soli nomi di directory ed estensioni vietati dichiarati nel report. Non è una garanzia contro qualunque contenuto inatteso |
| Preflight macOS | Exit 0, 687,505 secondi; analisi Release e archivio senza firma validi |
| Identità post-gate | 1219 hash e modalità invariati; archivio dei sorgenti confrontato con il manifest |

`debug-native-results.json` e `release-native-summary.json` identificano bundle
separati della rispettiva corsa e riconciliano definizioni, parametrizzazione ed
esecuzioni. ID di dispositivo/risultato, hostname e path assoluti dei bundle non
sono necessari ai riepiloghi. I diagnostici host di incompatibilità CoreSimulator
e placeholder Mac sono distinti dai runtimeWarnings vuoti degli xcresult;
non si dichiara un log di build privo di ogni diagnostico.

Il report del bundle reale è `packaging-bundle-results.json`. Le risorse
obbligatorie sono PrivacyInfo.xcprivacy e Assets.car; catalogo e descrizioni
sono controllati nel prodotto compilato. Il report nega esplicitamente una
verifica di Finder/LaunchServices e della restoration interattiva.
Il log finale del preflight ha SHA-256
`98065830ceb5eeda9bec58f1d2faae54f1ab675ff19ab160e95d59d8b99dd6d9`.
L'archivio dei sorgenti ha SHA-256
`712725bb5839cf90da980c15c4d3151f6164019d81dc3a3df32793e53e7efa05`.

## Chiusura e integrazione dei soli metadati

CMP-306 resta **implemented** secondo il perimetro richiesto: l'evidenza è
superata per gli automatici sopra elencati, senza promuovere gli aspetti
interattivi, iPadOS o i criteri EA non attuati.

La documentazione conclusiva aggiorna nove file dopo le prove. Il confronto
con il manifest deve ammettere soltanto questi cambi editoriali: nessuno
script, sorgente, PBX, xcconfig o catalogo compilato viene modificato dopo il
gate. Il trasferimento futuro dei 24 percorsi del lotto richiede CAS aggiornato
per i metadati conclusivi e preservazione dei nuovi contributi del checkout
principale; la presente prova resta legata alla composizione 328169f7.

## Limiti

Nessuna interazione osservata nel navigator Xcode, Finder o LaunchServices,
restoration reale, focus o tecnologia assistiva è attestata. Il lookup delle
risorse nel bundle non proverà di per sé la presentazione del Finder.
La configurazione Release non è un test plan EA-T-01: sanitizer, UI, metriche,
localizzazione visuale, G4/G5 e iPadOS conservano i propri stati aperti.
Il lotto non firma, notarizza, pubblica o introduce dipendenze/entitlement.
