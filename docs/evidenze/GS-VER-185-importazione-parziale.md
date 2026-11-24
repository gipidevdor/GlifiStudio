<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-185 — Stato coerente dopo un'importazione parziale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-185 |
| Tipo | Evidenza di correzione e verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente nel perimetro dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-164; RF-002; RF-003; RQ-058 |

## Identità della verifica

Gli esiti descrivono la copia di lavoro basata su
`a86a53b512bd777f191c89692e0c573a3d37a3ff` con l'incremento GS-VER-185. Nessuna
esecuzione CI remota o revisione successiva viene attestata da questa evidenza.

## Difetto e perimetro

Il modello condiviso pubblicava snapshot e profilo soltanto dopo il completamento
di tutti i file selezionati. Ogni import GlifiKit conferma invece una generazione
indipendente: il fallimento di un file successivo lasciava le fonti già importate
nel batch incorporate nel package ma assenti dalla presentazione. Anche i contatori di
progresso rimanevano valorizzati in caso di errore.

La correzione pubblica snapshot, profilo e nome dopo ciascun commit riuscito e
azzera i contatori in ogni esito. La failure resta visibile e il batch si ferma
al primo errore. Non cambia la semantica transazionale: i file già incorporati
rimangono disponibili; risultati analitici, storia e selezioni mantengono il
lineage esistente.

## Regressioni

Regressioni del modello reale nel target `GlifiStudioMacTests`, con package e
file sintetici:

- file valido seguito da file non valido e da un file non raggiunto: primo
  commit visibile, profilo e nome coerenti, failure presente, contatori azzerati;
- query e riapertura confermano il contenuto incorporato prima dell'errore;
- errore prima di qualsiasi commit: snapshot, profilo e nome precedenti conservati;
- import riusciti TXT/Markdown: stato finale coerente e sessione riutilizzabile.

## Riproduzione prima della correzione

Le tre regressioni sono state aggiunte prima di modificare il modello.
`make test-macos` sui sorgenti originali termina con **exit 2** (`xcodebuild`: 65).
Il bundle xcresult riporta **11 test, 9 superati, 2 falliti, 0 saltati**:

- `partialImportPublishesCommittedSourcesAndStopsAtTheFailure`: la presentazione
  conserva generazione 1 anziché 2, numero di fonti e profilo precedenti, e i
  contatori non vengono azzerati;
- `failureBeforeAnyImportPreservesThePreviousPresentation`: il contatore totale
  resta 2 dopo il rifiuto del primo file.

La regressione del batch interamente valido supera il controllo. L'esecuzione
usa Xcode 27.2 e Apple Swift 6.4.2. L'avviso dell'host sul framework CoreSimulator
1171.7, precedente al 1174.21 richiesto da Xcode, è distinto dalle failure del
modello macOS osservate nel bundle.

## Verifica dopo la correzione

`make test-macos` sul modello corretto termina con **exit 0**. Il bundle xcresult
riporta **11 test superati, 0 falliti, 0 saltati**, compresi i tre nuovi scenari.
La verifica usa macOS 27.2.1 arm64, Xcode 27.2 e Apple Swift 6.4.2.
Il controllo strict di formattazione dei due sorgenti Swift modificati e
`git diff --check` sono superati; la revisione indipendente del diff non rileva
difetti nel perimetro.

`make verify` termina con **exit 0** e conferma nuovamente **11 test macOS superati, 0 falliti,
0 saltati**, con riepilogo xcresult `Passed` e nessun runtime warning. Riproduce
inoltre **293 test Core e 37 test Kit**, **137 righe di oracoli numerici**,
**51 controlli CLI su 15 fixture** e **22 checkpoint di process-kill recovery**.
Le build Debug e Release macOS, e quelle iPadOS per destinazione generica
Simulator, sono completate. `Scripts/check-app-store-packaging.sh` termina con **exit 0**:
analisi statica e archivi senza firma di entrambe le app validi. CMP-108 è
`verified` nel solo perimetro della presentazione dopo importazioni parziali.

Le build emettono gli avvisi preesistenti di CoreSimulator e dell'app iPadOS:
l'app apre file senza dichiarare `LSSupportsOpeningDocumentsInPlace` o
`UISupportsDocumentBrowser`. Il gate superato non attesta zero warning, una prova
UI iPadOS o il superamento di G4.

Nella corsa di `make verify` la validazione PDF/A è **saltata per assenza di
veraPDF**. La ricerca locale non trova il validatore; il controllo esplicito con
`--require` termina con exit 1. La successiva prova integrativa completa questa
verifica separatamente, senza installare strumenti globali.

## Prova integrativa PDF/A

Dopo il completamento del gate è eseguita una verifica separata, senza attribuirla
retroattivamente a `make verify`. Il filtro dei test di export scientifico supera
**6 test** e rigenera due PDF sulla stessa cache di compilazione.

Il validatore veraPDF 1.30.4, build del 2026-11-09 13:38 CET, è confrontato con la
[release ufficiale](https://github.com/veraPDF/veraPDF-library/releases/tag/v1.30.4)
e acquisito come [JAR pubblicato su Maven Central](https://repo.maven.apache.org/maven2/org/verapdf/apps/cli/1.30.4/cli-1.30.4.jar).
Viene eseguito in una directory temporanea isolata, con Java 11 già disponibile;
nessuna installazione globale. Il comando esistente
`Scripts/check-pdfa.py --directory /tmp/GlifiStudio164PDFA --require`, con
`VERAPDF` impostato al launcher isolato e Python 3.12 nel `PATH`, termina con
**exit 0: 2 PDF conformi PDF/A-2u**.

Identità SHA-256:

- JAR `org.verapdf.apps:cli:1.30.4`:
  `f00c4d2a18dd3af7e9450bc9ac6688726fc4acf1a9d97d52e3e992021e84f93e`;
- `report.pdf`:
  `41cd451609e10a2e3c10ae51c88e86669e8876015dc6ae28477e1ad58f35031f`;
- PDF lungo:
  `f065690d9203c9cba44714014269abeb2664db77f44f70e6721aad3890997cc0`.

Il digest del JAR è confrontato con i valori
[SHA-256](https://repo.maven.apache.org/maven2/org/verapdf/apps/cli/1.30.4/cli-1.30.4.jar.sha256)
e [SHA-512](https://repo.maven.apache.org/maven2/org/verapdf/apps/cli/1.30.4/cli-1.30.4.jar.sha512)
pubblicati. La firma PGP non è verificata. La prova integrativa non modifica gli
esiti o i warning della precedente esecuzione del gate.

Il validatore verificato viene conservato come strumento attivo nella cache
dedicata `~/Library/Caches/GlifiStudio/tools/veraPDF/1.30.4`, circa **15 MiB**,
selezionabile tramite `VERAPDF`. Non cambia il `PATH` globale e non aggiunge
dipendenze al repository o alle app; il digest del JAR viene ricontrollato dopo
il trasferimento. Il launcher nella destinazione stabile supera nuovamente il
controllo esistente sui due PDF con exit 0.

## Pulizia finale

Eliminati **4 328 756 KiB, pari a circa 4,128 GiB**, di cache di build, download
ridondanti e PDF temporanei dopo la verifica. Conservati i log e il riepilogo
utili come evidenza e il validatore attivo da circa 15 MiB nella cache dedicata.

## Limiti

La prova del modello non sostituisce audit GUI, VoiceOver, autorizzazioni sandbox,
file provider e dispositivi fisici. Nessuna modifica del formato `.glifi`, del
motore, di GlifiKit o delle regole di cancellazione è compresa nell'incremento.
