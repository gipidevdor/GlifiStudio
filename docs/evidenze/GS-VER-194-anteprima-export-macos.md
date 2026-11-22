<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-194 — Anteprima export macOS fuori dal Main Actor

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-194 |
| Tipo | Evidenza di correzione e verifica macOS |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro automatico macOS dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-194; RQ-013; RQ-044; GS-APL-006 |

## Perimetro e identità

Il modello leggeva `report.md` con `Data(contentsOf:)` sul Main Actor dopo un
export riuscito. L'incremento limita la correzione alla preview facoltativa:
loader interno macOS nonisolated `@concurrent`, UTF-8 integrale fino a 1 MiB,
lettura no-follow/nonblocking di file regolare con budget e coerenza dimensionale.

Assenza, errori, file speciali, dati invalidi, superamento del limite o
cancellazione restituiscono nil; non viene presentato testo troncato. La receipt
e l'export autorevole non dipendono dal successo della preview. Il security
scope della destinazione rimane valido fino al completamento della lettura.
Il ramo iPadOS conserva il comportamento precedente.

Copia di lavoro basata su `a86a53b512bd777f191c89692e0c573a3d37a3ff`, con gli
incrementi concorrenti preservati. La DoR precede il codice; l'avvio segue il
coordinamento dopo B/C. Nessuna nuova revisione o CI remota è attestata.

## Contratto di verifica

Helper: UTF-8/BOM/Unicode, limite esatto e oltre limite, file assente, UTF-8
invalido, directory, symlink, FIFO e pre-cancellazione. Modello: export riuscito,
receipt valida e anteprima coincidente con il report. Review isolamento,
budget/stat e cleanup descriptor; gate e preflight macOS sul contenuto integrato.
Nessuna garanzia di snapshot sotto mutazioni della stessa dimensione viene inferita.

## Verifiche mirate osservate

Quattro nuovi test verificano Unicode/BOM e UTF-8 integrale, limite esatto di
1 MiB e rifiuto di un byte oltre, file assente/non UTF-8/directory/symlink/FIFO,
URL non file, task già cancellata ed export reale nei quattro formati con receipt
e anteprima esattamente uguale al Markdown committato. Review indipendente del
loader senza difetti concreti: budget e sentinella, coerenza stat/byte count,
retry EINTR, chiusura descriptor e cancellazione rispettano il contratto.

Prima del lotto 195, la prova integrata `make test-macos` termina con **exit 0**: target con
**33 definizioni di test, 37 esecuzioni, 0 fallite, 0 saltate**. La suite
`StudioDocumentLifecycleTests` contiene 30 definizioni e 34 esecuzioni; tre test
concomitanti del monitor runtime completano il conteggio del target e non vengono
attribuiti a questo incremento. Lint strict e `git diff --check` sono superati.
Il successivo gate del programma e il preflight macOS sono superati.

## Verifica integrata sullo snapshot

`make verify-macos` e `Scripts/check-app-store-packaging.sh --macos-only`
terminano entrambi con **exit 0** sullo snapshot descritto in
[GS-VER-188](GS-VER-188-gate-macos.md), manifest SHA-256
`07673ac2d88e369010ea0a065192e3c20ffd24c6ce5a8ee73940e3b309870b5f`.
Il gate conferma **36 definizioni / 45 esecuzioni macOS, 0 fallite, 0 saltate**,
build Debug/Release, analisi statica e archivio macOS senza firma; nessun runtime
warning nei risultati nativi. Tutti i controlli condivisi sono eseguiti.
Il profilo non esegue build iPadOS e non è gate globale, CI, prova di finestre
reali, autosave, audit VoiceOver o G4. Le ottimizzazioni successive di Core,
test e benchmark, avviate da altre sessioni, sono escluse da questa attestazione:
non è implicita compatibilità con la working copy successiva allo snapshot.

## Limiti

Mac bloccato e scelta esplicita di soli controlli automatici: nessuna verifica
GUI manuale, VoiceOver o su dispositivo è eseguita. La correzione circoscritta
non certifica zero problemi di accessibilità, Instruments, iPadOS, G4, firma o
App Review; non promuove un nuovo criterio EA a gate.
