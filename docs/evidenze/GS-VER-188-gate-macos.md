<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-188 — Profilo esplicito di verifica macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-188 |
| Tipo | Evidenza di correzione e verifica |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro automatico macOS dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-167; RQ-005; RQ-063 |

## Perimetro e identità

Il profilo esplicito macOS mantiene tutti i controlli condivisi e omette soltanto
le azioni iPadOS rimandate dall’iniziatore. Il gate globale resta invariato.

Copia di lavoro basata su `a86a53b512bd777f191c89692e0c573a3d37a3ff`, con
l’incremento GS-VER-185 preservato e gli incrementi macOS concomitanti. Nessuna
CI remota o revisione successiva viene attestata.

## Snapshot della verifica integrata

Il gate parte da una copia isolata della working copy, basata su
`a86a53b512bd777f191c89692e0c573a3d37a3ff`. Sono confrontati esattamente
contenuto e permessi di **768 file** prima dell'esecuzione. Identità SHA-256
del manifest canonico `source-manifest.json`:

`07673ac2d88e369010ea0a065192e3c20ffd24c6ce5a8ee73940e3b309870b5f`.

`make verify-macos` viene eseguito su tale snapshot, con Python 3.12 e veraPDF
verificato nella cache dedicata. L'esecuzione è completata con exit 0. Gli
incrementi di altre sessioni presenti nella copia
sono preservati; eventuali modifiche successive verranno confrontate separatamente.
Il digest identifica lo snapshot, non un nuovo commit, una build CI o G4.

## Fasi integrate osservate sullo snapshot

La corsa di `make verify-macos` supera **347 test Core e 52 test Kit** riportati
da SwiftPM, **152 righe di oracoli numerici**, **due PDF/A-2u conformi**,
**51 controlli CLI su 15 fixture**, **22 checkpoint di process-kill recovery**
e il contratto CLI QueryAST. veraPDF è selezionato esplicitamente dalla cache
verificata: la validazione PDF/A è eseguita direttamente in questa corsa.
Nessun controllo condiviso risulta saltato in queste fasi.

Il gate e il preflight macOS terminano con **exit 0**. Test nativi:
**36 definizioni, 45 esecuzioni, 0 fallite, 0 saltate**, senza runtime warning
nei risultati; la suite del modello comprende 33 definizioni e 42 esecuzioni,
più tre test runtime concomitanti. Build Debug e Release macOS, analisi statica
e archivio macOS senza firma validi. Nessuna build iPadOS è eseguita.
Il profilo automatico non è equivalente al gate globale, CI, audit di finestre,
autosave, VoiceOver o G4.

## Contratto di verifica

Verifica della sintassi, argomenti non validi rifiutati prima di temporanei/cache,
rami di piattaforma e target Make; esecuzione del profilo macOS e preflight
con analisi e archivio macOS senza firma. Nessuna equivalenza al gate globale.

Gli esiti effettivi riportati sopra precedono la promozione della clausola di
conformità; la sola presenza dei test o dei comandi non ne attesta il superamento.

## Controlli mirati osservati

Implementazione revisionata indipendentemente: il profilo predefinito conserva
i quattro comandi di build/analisi/archivio iPadOS e i relativi controlli plist e
risorse, tutti subordinati al profilo globale. I controlli condivisi restano attivi.
Il parser comune risiede in `Scripts/build-cache.sh`; il wrapper App Store
inoltra gli argomenti con validazione preventiva.

Nove prove di argomenti invalidi sui tre script, per opzione sconosciuta,
duplicata e argomento aggiuntivo, terminano con **exit 2 prima di temporanei e
cache**. Parsing dei profili globale/macOS, `zsh -n`, `make -n` e
`git diff --check` superati. La diagnostica usa `ZSH_ARGZERO`. I controlli mirati restano distinti dalla successiva esecuzione reale
del profilo macOS, superata; CMP-111 è `verified` nel perimetro dichiarato.

## Conservazione della prova riproducibile

Lo snapshot resta invariato durante il gate. L'evidenza utile è conservata in
`~/Library/Caches/GlifiStudio/evidence/macOS-2026-11-21-07673ac2/`: manifest
completo, risultati JSON macOS sanificati, log e archivio dei 768 file testati.
`verified-source.tar.gz` misura **7 706 117 byte**, SHA-256:

`b2dd58c6c6fbc5094fba0cc0e832b7e52bc60ddea661f0d5e448cfdca49ded4e`.

L'archivio non include `.git`; base e manifest identificano la provenienza,
senza attribuire un nuovo commit o una verifica CI.

## Confronto con il lavoro successivo

Lo snapshot principale rimane invariato durante il gate. Il primo confronto
rileva soltanto metadati; un controllo successivo rileva anche modifiche a
`GlifiBenchmark/main.swift` e quattro nuovi `*OptimizationBenchmarks.swift`.
Il primo tentativo mirato del benchmark incontra un timeout del type checker
in un'espressione nested-map; la stessa sessione esterna corregge già il codice
prima del reread, senza modifiche da questo programma. La riesecuzione Debug
termina con exit 0, durata di build riportata 1,76 secondi. È una compilazione
diagnostica separata, non un nuovo gate o una misura di prestazioni algoritmiche.

Successivamente altre sessioni avviano turni distinti di ottimizzazione
(GS-DOR-169, GS-DOR-200/201), modificando anche Core, test e benchmark.
Il confronto conclusivo nel dossier riporta **60 file differenti** dal primo
snapshot, inclusi documenti e ottimizzazioni successive. Il risultato
`ourVerifiedInputsUnchanged=true` riguarda i **16 path posseduti** di App, Kit,
CLI, shell, progetto e test del mapping, e la dichiarazione Core dei range risolti
rimasta invariata; non significa che tutte le dipendenze Core siano immutate.

Tutti i successivi cambiamenti sono esclusi dall'attestazione dello snapshot
`07673ac2…70b5f`. Anche gli input del benchmark cambiano nuovamente dopo la
compilazione diagnostica: non viene attestato il benchmark corrente o la
compatibilità del lotto applicativo con le ottimizzazioni in corso. Tali turni
hanno owner ed evidenze proprie; nessun loro sorgente viene modificato, eliminato
o promosso da questo programma.

## Pulizia finale del lotto

Rimossi **2 351 604 KiB, circa 2,243 GiB**, della sola cache MacAudit, del
worktree temporaneo dello snapshot e dei manifest temporanei, inclusi gli
artefatti della compilazione diagnostica. L'elenco dei worktree torna al solo
checkout originale; sessioni e cache degli altri programmi restano intatte.

Conservati il dossier di verifica con log, riepiloghi sanificati e archivio
principale riproducibile, oltre al validatore veraPDF attivo da circa 15 MiB.
La pulizia non estende l'attestazione alle ottimizzazioni successive nella
working copy e non richiede nuove build dei loro sorgenti in movimento.

## Limiti dell’audit

Mac bloccato e scelta esplicita dell’iniziatore di proseguire soltanto con test
automatici: nessuna verifica GUI manuale, VoiceOver, finestre SwiftUI reali,
autosave o G4. Lo sviluppo dedicato iPadOS è rimandato. Firma, App Review e
completamento della piattaforma non sono dimostrati dai controlli hostless.
