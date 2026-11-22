<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Progetto Xcode completo e verificabile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-306 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.2 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di perfezionare il progetto per il repository e i file attuali; contratto circoscritto dal coordinatore prima del codice |
| Riferimenti | RQ-005; RQ-062; RQ-063; GS-STD-001-08; GS-STD-001-16; GS-STD-001-29; GS-APL-007; GS-I18N-002; GS-DEV-002; ADR-0005; ADR-0015; ADR-0020 |

## Baseline e scopo

Il lotto usa la cattura isolata del checkout corrente, con base Git
`d368285010dca17f5ef72819da25b6890d0de32a`, **1212 file** e fingerprint
`fdda820908b8b675864c7f361ec89c7d077048808b2858064107fc0240fd1810`.
La cattura include i contributi 302/303/304 senza attribuirli al lotto 306 e
senza incorporarvi il successivo completamento KH 305 di origin/main.
GS-DOR-306 è un identificatore distinto, verificato nei registri e nei worktree.

Il risultato è un progetto navigabile e verificabile rispetto all'inventario
del repository, con configurazioni di test realmente distinte e metadati
documentali localizzati. Il lavoro è nel solo `/tmp/MacStudio306Work`;
il checkout condiviso e le lavorazioni degli altri agenti restano preservati.

## Scheda Definition of Ready

| Voce | Contratto e accettazione |
| --- | --- |
| outcome e confini | Navigator Xcode completo: cartelle native solo navigazione per docs, Scripts, Fixtures, Design, Distribution, Benchmarks e .github; GlifiCore visibile sotto Packages, con dipendenza SwiftPM locale esistente; sottocartelle Config, inclusa Testing del lotto 303; file radice espliciti; Apps espliciti con gruppo Tests. Configurazioni test Debug/Release separate, schema macOS corretto, catalogo InfoPlist it/en e controllo strutturale automatizzato. Stop dopo le prove definite sotto |
| requisiti | RQ-005: grafo e separazione app/Kit/Core preservati, prodotto GlifiKit esplicito anche nelle dipendenze del target test. RQ-062 e GS-STD-001-08: inventario navigabile, configurazioni, provenienza e verifica interrogabili. RQ-063: questa Ready precede produzione e nuove fixture sostanziali; TV-075/076 e verifica architetturale limitate al lotto |
| dominio/API | Target, prodotti, bundle ID, versioni, deployment target, package locale e lista ordinata dei Sources dei tre target invariati. Cartelle native senza associazione a target né membership implicita. Nessuna nuova API, dipendenza, algoritmo, schema o modifica ai sorgenti applicativi/package. Non duplicare i sorgenti SwiftPM nelle fasi app |
| failure semantics | Il checker restituisce errore non zero e diagnostici strutturati per riferimenti orfani, path non validi, cicli, duplicazioni, destinazioni incoerenti o membership indebita; nessun fallback parziale dichiarato equivalente alla validazione completa. Il profilo portabile dichiara il proprio perimetro ridotto. Nessuna modifica a failure, cancellazione, persistenza o recovery del prodotto |
| esperienza prevista | Il workspace canonico resta GlifiStudio.xcworkspace. Navigator coerente con i file attuali, senza rinomine o spostamenti fisici. Il tipo documento usa la chiave RAW già presente «Progetto Glifi Studio» in entrambi i descrittori nested del plist: un nuovo InfoPlist.xcstrings condiviso fornisce it/en senza cambiare il plist base. I lookup nel bundle compilato verificano le traduzioni; non attestano un dialogo Finder o un audit assistivo osservato |
| verifica | Resolver PBX nativo plutil→JSON su macOS, grafo e inventario; controlli XML/xcconfig portabili; fixture negative e self-test prima di inserire il controllo nel gate. Sei configurazioni risolte via Xcode (tre target per Debug/Release), test nativi reali in Debug e Release, lookup it/en nel bundle compilato, gate make verify macOS e preflight macOS senza firma. Fingerprint e confronto finale dei file identificano la composizione effettivamente provata; GS-VER-306 raccoglie solo esiti osservati |
| dati e migrazione | Nessun cambiamento a corpus, Artifact, progetto .glifi, lineage, UTI o estensione. La stringa sorgente dei due descrittori rimane invariata. Le cartelle del repository sono riferimenti di sviluppo, non dati aggiunti alle risorse del prodotto. Nessuna migrazione |
| sicurezza/privacy | Nessun entitlement, rete, telemetria, permesso, firma, team Apple, script build phase o accesso a file di prodotto nuovo. Il controllo considera il solo inventario autorizzato Git non ignorato; esclude .git, cache, file personali ed artefatti rigenerabili. Non modifica gli appunti grezzi. La rimozione della chiave LSApplicationSupportsSecureRestorableState e del solo marker che la pretende è motivata dalla policy AppKit documentata per SDK recenti, senza introdurre delegate o disabilitare secure coding |
| prestazioni/sistema | Nessun lavoro applicativo aggiunto. Il checker e le cartelle del navigator hanno costo proporzionato all'inventario, senza copia dei contenuti nei bundle. Le configurazioni Release dei test applicano ottimizzazione e simboli Release, distinguendosi dal Debug; nessun risultato di benchmark o miglioramento di latenza/energia è inferito |
| tracciabilità | CMP-306 inizialmente specified; GS-VER-306 pianificata. Prima della consegna aggiornare i soli riferimenti pertinenti a progetto, configurazione, controlli, indici, loop e stato di adozione, preservando i contributi 302/303/304 e gli stati EA ancora aperti |
| decisioni e recupero | Impiego di funzionalità Xcode e localizzazione native nell'architettura esistente, senza nuova ADR. Recupero mediante revert dei soli metadati/controlli del lotto, senza migrazioni o modifiche a codice e dati. Una modifica di membership o requisito oltre questo contratto richiede aggiornamento della Ready prima del codice |

## Contratti tecnici delimitati

1. **Navigator e risorse.** Ogni file dell'inventario deve essere rappresentato
   da riferimento esplicito, cartella nativa, package gestito da SwiftPM oppure
   esclusione motivata per metadata Xcode/prodotti impliciti. I dodici root di
   cartella proposti non hanno membership in alcun target. I Sources restano
   esattamente quelli iniziali. Le Resources aggiungono soltanto il catalogo
   InfoPlist ai due target app; il target test non lo riceve.
2. **Configurazioni e schema.** macOS-Tests.xcconfig resta l'ingresso Debug;
   un file Common condivide soltanto impostazioni neutre e un nuovo
   macOS-Tests-Release.xcconfig include Release. I valori effettivi devono
   distinguere -Onone/DEBUG da -O/wholemodule senza DEBUG, mantenendo i test
   hostless, Swift 6, MainActor predefinito, strict concurrency e warning come
   errori. Lo schema macOS analizza in Release; il target test ha una
   BuildActionEntry attiva soltanto per testing. Lo schema iPadOS e i suoi
   riferimenti sono verificati staticamente, senza build iPadOS.
3. **Checker e casi negativi.** Controllare oggetti/ID, relazioni dei gruppi,
   risoluzione path, liste di fasi e configurazioni, riferimenti package e
   product, target e configurazioni degli schemi, cicli include e copertura
   dell'inventario. Anche PBXProject deve usare basi Debug/Release corrette senza
   override inline; la lista target deve avere ID e nomi univoci prima di essere
   indicizzata. Le fixture negative includono almeno riferimento mancante,
   path assente, ciclo, duplicato, schema verso target errato e aggiunta indebita
   di cartelle/file del repository alle risorse o ai Sources. Su Ubuntu
   quality-static invoca --portable; il gate macOS invoca --self-test e
   validazione completa. Un target Make dedicato permette la verifica mirata.
4. **Localizzazione e secure coding.** Il catalogo ha sourceLanguage it e le
   traduzioni it/en della sola chiave RAW già presente. Il controllo verifica
   entrambe le posizioni nested, membership e lookup compilato. La rimozione
   della chiave non documentata non è prova di ripristino delle finestre:
   tale interazione resta separata.

## Ready e limiti

**Ready** per il perimetro di metadati e strumenti sopra definito, prima del
primo edit implementativo. Nessun nuovo xctestplan, harness UI, sanitizer,
benchmark, pubblicazione o processo di firma appartiene al lotto. I criteri
EA «Da introdurre», GUI manuale, G4/G5 e iPadOS restano aperti. Le prove del
checkpoint iniziale e dei lotti precedenti non diventano automaticamente prove
della nuova composizione.

## Fonte primaria della decisione secure coding

Le [note AppKit per macOS 14, Restorable State](https://developer.apple.com/documentation/macos-release-notes/appkit-release-notes-for-macos-14)
documentano l'abilitazione automatica della codifica sicura dello stato per app
collegate con SDK macOS 14.0; il progetto usa SDK e deployment macOS 27. La
[API NSApplicationDelegate](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationsupportssecurerestorablestate(_:))
è distinta da una chiave Info.plist: il lotto non introduce il delegate e non
presenta la chiave rimossa come API supportata. Fonti consultate il 2026-11-22.

## Raffinamento del controllo prima del gate

La review del checker ha riprodotto duplicati raw normalizzati dal parser e
incoerenze delle configurazioni di progetto/identità target. I fix restano nel
contratto di integrità del progetto: nessuna nuova API, target o modifica alle
configurazioni reali. Sono verificati 23 casi negativi e cinque positivi
lessicali; il successivo esito del gate è registrato nella chiusura seguente. La Ready iniziale
prima del codice resta conservata separatamente, senza retrodatazione degli esiti.

## Chiusura nel perimetro automatico macOS

[GS-VER-306](../evidenze/GS-VER-306-progetto-xcode-completo.md) registra gate,
test nativi Release indipendenti e preflight senza firma superati sul checkpoint
`328169f7f24d860cdba61dc87cba2d7cf88b0f5c19fead2e874bd3972d64d69a`:
1219 file, base d368285 con overlay 302/303/304. I nativi Debug e Release hanno
ciascuno 125 definizioni e 409 esecuzioni senza failure, skip o runtime warning;
il confronto finale mantiene tutti gli hash e le modalità. Le prove riguardano
questa composizione, non il nuovo Core 305 del checkout principale avanzato.

CMP-306 resta implemented. Lookup it/en e ispezione del bundle compilato non
attestano Finder, LaunchServices o restoration reale. iPadOS, UI/assistive,
test plan EA-T-01, G4/G5, firma e pubblicazione restano separati.
