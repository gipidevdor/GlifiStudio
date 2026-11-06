<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Integrità dei documenti macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-163 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.2 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-06 |
| Approvazione | Prosecuzione dello sviluppo con focus macOS richiesta dall'iniziatore |
| Riferimenti | GS-STD-001-07; RF-001; RQ-043; GS-APL-005; GS-UX-001-12; ADR-0006 |

## Unità di lavoro

Correggere la creazione distruttiva e l'inizializzazione ripetuta dei package nelle app;
collegare Nuovo e Apri al ciclo documentale nativo di macOS. L'apertura fallita conserva la
sessione precedente. Nessuna modifica al formato `.glifi`, al motore o al perimetro del prodotto.

## Scheda Definition of Ready

| Voce | Evidenza |
| --- | --- |
| outcome e confini | Nuovo/Apri macOS usano DocumentGroup; un package non vuoto non viene mai rimosso dall'inizializzazione; attacco ripetuto idempotente |
| requisiti | RF-001, RQ-043; progetto, fonti e query precedenti ancora utilizzabili dopo apertura fallita |
| contratto di dominio/API | App → GlifiKit invariato; sostituzione della sessione soltanto dopo verifica della candidata |
| failure semantics | Destinazione occupata o non valida: errore localizzabile, nessuna cancellazione; sessione e generazione precedenti conservate |
| esperienza prevista | Nuovo crea una finestra documentale; Apri presenta il documento attraverso il sistema; componenti e label esistenti it/en, tastiera e VoiceOver nativi |
| verifica | Test Swift Testing del modello macOS in target Xcode dedicato; build dal workspace; make verify; evidenza candidata GS-VER-163 |
| dati e migrazione | Nessuna: generazioni e formato invariati; solo rimozione atomica di un placeholder vuoto del sistema |
| sicurezza/privacy | Nessuna rete, dipendenza o entitlement nuovo; URL selezionati dall'utente, accesso security-scoped bilanciato |
| prestazioni/sistema | Validazione del package resta nel Kit; nessuna scansione ricorsiva o cancellazione ricorsiva introdotta |
| tracciabilità | CMP-107, TV-001, TV-058; evidenza, matrice e registro DoR aggiornati nella stessa modifica |
| decisioni | ADR-0006 e GS-APL-005; nessuna nuova decisione architetturale |

## Limiti

**Ready** per la correzione e i test del ciclo documentale macOS.

File coordination, conflitti, salvataggio del wrapper documentale e audit VoiceOver su dispositivo
restano prove distinte di G4; questa correzione non ne dichiara il superamento.

## Avanzamento

Implementazione e otto test macOS completati (GS-VER-163). Il gate globale è stato eseguito e
resta non superato sui nuovi sorgenti analitici modificati contemporaneamente da un'altra
sessione; il preflight di packaging non è quindi completato. Nessuna modifica di quel
programma analitico viene dichiarata verificata da questa scheda.

Sul commit integrato `main` `a86a53b` (#27) i controlli CI `verify` e `app-store-baseline`
sul runner `xcode-27` sono superati, compreso il passo `xcodebuild test` dello schema
`GlifiStudio-macOS`; CMP-107 è `verified` sul gate G3 (GS-VER-163). Le prove G4 sopra restano aperte.
