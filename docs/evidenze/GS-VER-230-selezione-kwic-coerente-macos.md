<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-230 — Selezione KWIC e fonte coerenti su macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-230 |
| Tipo | Evidenza di verifica applicativa macOS |
| Versione | 1.3.0 |
| Stato | Superato nel perimetro automatico macOS sul checkpoint ffbfb431 |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | GS-DOR-230; RF-009; RF-017; RQ-011; RQ-047; RQ-058 |

## Perimetro e base

Identificatore selezionato e fonte sono pubblicati insieme dopo fetch riuscito; busy o failure conservano la coppia precedente. Intervalli e revisione devono corrispondere.

Il lavoro è iniziato nel repository isolato `/tmp/MacStudio230Work`, sulla base
`f6bba3e280de23b87f30e164c8970c4c0883af59`. È poi integrato nel checkout originale
basato su `02c1c666437a58743dba40193b9a94d4a7a3a11c`, preservando il WIP GUI 222.
Le modifiche documentali sono applicate da proposta a tre vie con preflight di
tutti gli SHA originali e backup; matrice unita per identificatore e voci di
entrambi i lavori conservate. I guard equivalenti della HomeView e i nuovi
riferimenti PBX sono integrati senza sovrascrivere il lavoro GUI.
Questi incrementi non introducono formati, algoritmi scientifici, dipendenze o
nuove funzionalità.

## Prima generazione verificata (4d6969dd)

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
CMP-231 non eredita tale esito: il helper di quella generazione è respinto dalle misure.
La prima generazione è nel sottodossier `generations/4d6969dd` del dossier finale.
Le prove native isolate restano distinte dai gate combinati e non
promuovono automaticamente GUI 222, iPadOS o G4.

Il confronto live eseguito dopo il primo freeze rileva un cambiamento GUI 222 in
`Apps/Shared/StudioHomeView.swift`: contesto workspace e status bar sono
riposizionati nel detail. Selettori e guard della query restano invariati e i
sette file specifici del lotto risultano identici al confronto, ma il file
condiviso HomeView non è interamente uguale allo snapshot. Il gate 4d6969dd non
attesta tale layout successivo, che appartiene a GS-VER-222; non si dichiara
una corrispondenza globale di tutti i sorgenti posseduti o della copia corrente.

## Generazione finale verificata (ffbfb431)

Il checkpoint finale contiene **924 file**, con manifest SHA-256
`ffbfb43191444018a5bd6163e90a46a6ed2c0c832a0fd5a7180449f963470b13`.
Deriva dal checkpoint 4d6969dd con il helper Sendable finale e i documenti del
lotto aggiornati; è sulla base `02c1c666437a58743dba40193b9a94d4a7a3a11c`.
Esclude il WIP 223 e il riposizionamento successivo di workspaceContext/statusBar,
che rimangono preservati nella copia condivisa. Non certifica l'intero checkout
corrente o le modifiche concorrenti.

`make verify-macos` e `Scripts/check-app-store-packaging.sh --macos-only`
terminano entrambi con **exit 0** sul nuovo fingerprint. Passano 423 test Core
più 63 Kit, totale **486**, 194 righe di oracoli, due PDF/A-2u, 51 controlli CLI
su 15 fixture condivise con parità entro 1e-12, 22 checkpoint recovery e QueryAST.
Test nativi Debug e build Release sono superati: **67 definizioni e 224
esecuzioni**, dieci parametrizzate con 167 run più 57 non parametrizzate,
zero fallite/saltate e `runtimeWarnings: []`.

Il preflight supera analisi Release, archivio macOS senza firma, metadati
Info.plist, privacy manifest e asset. I riepiloghi sanificati sono
`final-native-results.json` e `packaging-final-results.json` nel dossier finale;
quest'ultimo lega il preflight al helper finale e al log SHA-256
`76baa784469fa73543e324b9a5d16bfff488b28729405545dc39cda6198109e2`.
CMP-230, CMP-231 e CMP-232 sono `verified` nel solo perimetro automatico di
questo checkpoint. Dossier:
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-ffbfb431/`.
La generazione 4d6969dd resta conservata separatamente e non viene riscritta.

## Riproduzione RED prima della patch

RED/GREEN con due fonti, opener sospeso, failure e retry; coerenza della presentazione e ramo iPad invariato. Gli esiti derivano dalle esecuzioni, non dalla sola presenza dei test.

La prima corsa RED combinata 230/232 termina con exit 65 e cinque test falliti.
Tre percorsi confermano difetti pertinenti: ID KWIC cambiato durante busy,
ID visuale cambiato durante busy e contesto non azzerato per mark senza fonte.
Le altre due prime failure sono aspettative errate del test sul retained state:
la corruzione fonte Core dichiara `readOnlyRecovery`, non
`lastCommittedGeneration`. Sono corrette soltanto queste aspettative, senza
patch produttiva o indebolimento del controllo. Non sono quindi rivendicati
cinque RED puliti; l'esito della seconda corsa è registrato separatamente.

La seconda corsa RED, dopo la sola correzione delle aspettative di test e con
modello produttivo ancora originale, termina con **exit 65, cinque definizioni,
cinque fallite e zero saltate**. Tutte raggiungono assert pertinenti sulla
coppia ID/fonte o sull'azzeramento del contesto, senza failure di preparazione.
Log `/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-ffbfb431/230-232-red-corrected.log` e riepilogo
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-ffbfb431/230-232-red-corrected-results.json`.
Il fix produttivo segue questa riproduzione.

## GREEN mirato e stato

`make test-macos` completo nel repository isolato termina con **exit 0,
60 definizioni e 200 esecuzioni, zero fallite e zero saltate**;
`runtimeWarnings: []`. Le esecuzioni parametrizzate sono 149, più 51 non
parametrizzate. I cinque nuovi test di coerenza 230/232 sono superati.
Log `/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-ffbfb431/230-232-green.log` e riepilogo
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-ffbfb431/230-232-green-results.json`.

Per KWIC sono provati busy con opener sospeso, failure della fonte con coppia
precedente conservata e retry; la review della view verifica anche il guard
di revisione e il pulsante disabilitato durante busy. Non si attribuisce una
prova GUI a questa review. Ramo iPad e ownership di run restano invariati.

La DoR Ready precede la patch produttiva; CMP-230 è `verified` nel perimetro
automatico del checkpoint ffbfb431, con gate e preflight superati. Le prove storiche
198/199 non vengono estese a questo lotto.

## Limiti

Soltanto macOS e verifiche automatiche. Nessuna attestazione di GUI reale,
VoiceOver, iPadOS, autosave, file provider, G4 o CI remota. Le modifiche degli
altri programmi sono preservate e richiedono le rispettive evidenze.
