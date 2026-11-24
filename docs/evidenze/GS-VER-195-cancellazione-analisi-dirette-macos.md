<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-195 — Cancellazione delle analisi dirette macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-195 |
| Tipo | Evidenza di ownership e cancellazione applicativa |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro automatico macOS dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-195; RQ-011; RQ-058; ADR-0033 |

## Perimetro e identità

Ultimo lotto prima del freeze: riassunto, BM25, frequenze/ngrammi, MTLD,
profilo corpus e keyness diretti passano dal helper applicativo macOS che
possiede il task. La barra esistente espone Annulla; `run` conserva ownership
dello stato occupato e il defer del helper rilascia l'handle soltanto al termine.
La cancellazione del task chiamante viene propagata al figlio.

Copia di lavoro basata su `a86a53b512bd777f191c89692e0c573a3d37a3ff`, con gli
incrementi concomitanti preservati. La DoR precede il codice; nessuna nuova
revisione o CI remota viene attestata. iPadOS delega al `run` originario senza
task aggiuntivo o nuova azione UI.

## Contratto terminale

`cancelAnalysis` richiede soltanto l'annullamento, anche se ripetuto; non azzera
handle o busy prematuramente. Errori e stato conservato restano quelli Kit.
Un risultato già committato può precedere la cancellazione e non viene
convertito artificialmente in failure; risultati e receipt validi restano validi.

## Contratto di verifica

Observer didSet deterministico dell'handle, doppia richiesta cancel con
ownership/busy conservati fino al terminale, pulizia e retry. Verificare la
propagazione dal chiamante al figlio e il caso tardivo di commit valido senza
falsa failure. Nessun sleep o polling. Integrare test dei sei flussi e controlli
macOS/preflight dopo freeze, mantenendo separati esiti mirati e gate.

## Revisione prima della prova integrata

Modello, sei callback e azione della barra implementati dopo Ready. Revisione
indipendente di helper, ownership, onCancel e condizioni della view senza
difetti concreti nel perimetro. Il risultato mirato del modello è registrato sotto; nessun esito del gate è
anticipato.

## Prova del modello osservata

`make test-macos` termina con **exit 0: 36 definizioni di test, 45 esecuzioni,
0 fallite, 0 saltate**. La suite `StudioDocumentLifecycleTests` comprende
33 definizioni e 42 esecuzioni; tre test runtime concomitanti completano il
target e non vengono attribuiti al lotto 195.

Le tre nuove definizioni producono otto esecuzioni: sei analisi con annullamento
ripetuto, ownership/busy conservati prima del terminale, risultati precedenti e
retry; propagazione della cancellazione del chiamante; cancellazione tardiva
senza falsa failure con risultato committato, receipt e preview preservati.
La cancellazione del piano di GS-VER-186 resta superata. Non viene rivendicata
una fase RED del vecchio modello per un'API ancora assente.

Lint strict dei due file del modello/test e `git diff --check` sono superati.
Il successivo gate integrato e il preflight macOS sono superati; CMP-195 è `verified` nel perimetro delle sei analisi testate.

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

Nessuna API Kit/Core, formula o formato scientifico nuovo. La cancellazione di
altre operazioni non analitiche e lo sviluppo iPadOS non entrano nel lotto.
Mac bloccato e scelta di soli test automatici: GUI reale, VoiceOver, utenti,
dispositivi, G4, firma e App Review rimangono distinti dai risultati automatici.
