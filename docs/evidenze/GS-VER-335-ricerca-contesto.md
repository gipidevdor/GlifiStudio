<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-335 — Contesto e stato dei risultati di ricerca

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-335 |
| Tipo | Regressione della presentazione di ricerca macOS |
| Versione | 1.0.0 |
| Stato | Superato; RED/GREEN nativi, gate macOS e preflight completati |
| Responsabile | Codex con esecuzione serializzata dal coordinatore |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta di perfezionamento UX/UI con verifiche durante lo sviluppo |
| Riferimenti | GS-DOR-335; GS-UI-001; GS-UX-001-07; GS-UX-001-09; GS-STD-001-15; GS-STD-001-29 |

## Difetto e confine

La ricerca aggiorna risultato, espressione eseguita e selezione prima della
lettura asincrona della fonte del primo riscontro. Se quella lettura viene
rifiutata o cancellata, il contesto valido precedente viene sostituito da
uno stato parziale. Il campo modificabile può inoltre mostrare una nuova
ricerca accanto alle concordanze precedenti, senza indicatore esplicito di
aggiornamento; l'espressione effettiva si trova nella provenienza espandibile.

La correzione prepara risultato e fonte in variabili locali e li pubblica
insieme a espressione e selezione dopo un ultimo controllo della cancellazione,
senza await fra le assegnazioni. La bozza resta indipendente dal risultato
conservato e la vista distingue le due mediante componenti SwiftUI nativi,
senza cambiare API, sintassi, task owner o persistenza.

## Prove predisposte prima del fix

La suite nativa `StudioSelectionConsistencyTests` aggiunge quattro definizioni
e cinque esecuzioni previste:

- seconda admission rifiutata per pressione critica oppure task cancellato,
  dopo aver trovato i riscontri di una fonte diversa: risultato, espressione,
  selezione, fonte e snapshot precedenti devono restare invariati; il retry
  pubblica il nuovo contesto completo;
- query non valida: conservazione del contesto effettivamente eseguito;
- ricerca durante una riapertura sospesa: rifiuto busy senza perdita di stato;
- ricerca riuscita senza riscontri: nuovo risultato vuoto con selezione e fonte
  azzerate, espressione aggiornata e progetto invariato.

Fixture, gate e runtime iniettato sono sintetici e già disponibili. Non
usano attese temporali per determinare l'esito.

Il coordinatore ha eseguito il RED sul modello precedente attraverso
`GlifiStudio.xcworkspace`: exit 65. Il riepilogo conta **11 definizioni, dieci
passate e una fallita**. I contatori di `devicesAndConfigurations` dello stesso
riepilogo riportano **13 esecuzioni passate e due fallite**, quindi 15 esecuzioni
complessive. Le due esecuzioni fallite appartengono all'unica definizione
parametrica di interruzione e producono le sette issue confermate dal coordinatore.
Falliscono le assertion sul contesto pubblicato anticipatamente; non ci sono
altri test falliti. Il dossier locale `macOS-2026-11-27-bdd-ux` conserva
`query-red-summary.json`, il risultato nativo e `query-red.log`, SHA-256
`2bd70f448eab2c25e1798e5bba61ad0177cc1cf23ecbb0a04fba1738fe1f3c1e`.

## Stato dei risultati e precondizioni

La proprietà `isQueryDraftChanged` confronta la bozza, ripulita dei soli spazi
esterni, con l'espressione realmente eseguita. L'avviso nativo `Label` con
SF Symbol `info.circle` combina i contenuti per l'accessibilità e distingue
bozza e risultato effettivo. L'espressione eseguita è visibile nel riepilogo,
fuori dalla provenienza espandibile. Un risultato vuoto conserva la ricerca
effettiva nella `ContentUnavailableView.search` di sistema. Cambiare o svuotare
la bozza non cancella risultati e selezione validi; tornare all'espressione
eseguita rimuove l'avviso senza ricalcolo.

Prima di avere un progetto, la ricerca riusa le azioni esistenti della
panoramica: Salva per il nuovo documento non salvato, oppure Nuovo/Apri e
Riapri quando disponibile. Un progetto senza fonti offre Importa e accesso
a Fonti. L'editor e la richiesta di focus non promettono una ricerca prima
dell'importazione. Questi stati usano `ContentUnavailableView`, pulsanti,
stili e colori semantici di sistema e le chiavi di localizzazione condivise.

Due ulteriori test del modello verificano editing, spazi esterni, ripristino
della bozza, successo vuoto e chiusura, oltre alle precondizioni nessun
progetto/progetto vuoto/fonti importate. Il lotto finale aggiunge quindi
**sei definizioni e sette esecuzioni**. Formattazione, lint dei tre file Swift
e diff check sono superati.

## GREEN nativo osservato

L'esecuzione mirata finale del coordinatore sul candidato composito termina
con **exit 0**: `native-final-green-summary.json` registra **18 definizioni
passate e 22 esecuzioni passate**, senza failure, skip o warning runtime.
Le definizioni provengono dai contatori principali del riepilogo; le esecuzioni
dal relativo elemento `devicesAndConfigurations`. Le regressioni di ricerca,
comprese le due interruzioni e i retry, sono GREEN insieme alle altre prove
native selezionate. Il comando compila effettivamente i sorgenti applicativi
con le correzioni 335 e AX336; non equivale a una prova di interazione manuale.

Il dossier locale conserva `native-final-green.log`, SHA-256
`058866dab81dac4aba7b5cc824a81d0bb54f410fce62220215ca34b8cb322d83`,
e il riepilogo nativo. Il fingerprint dei **609 input controllati** di questa
fase, registrato dal coordinatore, è
`4ca2364b5295b759dacffaa131c37240578fec8a20ea36c34056dfbdba3c2484`.
Il rapporto strutturato conserva anche i digest dei tre file Swift del lotto.

## Gate integrato e preflight finale

Il successivo `make verify` autonomo supera il profilo macOS con **exit 0 in
503,55 secondi**, sul medesimo fingerprint `4ca236…` invariato durante la
verifica. `native-full-gate-summary.json` registra **144 definizioni e 435
esecuzioni passate**, senza failure, skip o warning runtime. Il dossier conserva
`make-verify.log`, SHA-256
`9430d074b630a54948fe834bd847fa3ee9a2417268c049a30f41a1e73c1e26a7`.

La fase finale parte dalla base `9bd9c69` e usa **609 input controllati** con
fingerprint
`5ea8f0cc9877bc94349db307cd2279654b50c6e2b9a99d3b4a42ee0627bb4c1a`.
Il cambio di fingerprint riguarda la normalizzazione del catalogo a JSON
equivalente e il trasporto di una variabile Make con la relativa regressione;
i tre file Swift di GS-VER-335 mantengono gli stessi digest. Il componente
`verify` del preflight finale è superato: il riepilogo
`native-final-preflight-summary.json` conferma nuovamente **144 definizioni
e 435 esecuzioni passate**, zero failure e skip.

Il preflight `make verify-app-store` complessivo termina con **exit 0 in
810,27 secondi**, sul fingerprint finale `5ea8f0…` invariato. Il log concluso
`make-verify-app-store.log`, SHA-256
`cc6bfe43eceeaf582993ee30b354a969617b17b594b404fb18b144e2bf7f4ebb`,
conferma analisi statica e archivi non firmati validi. I digest dei tre file
Swift di questo lotto sono stati ricontrollati dopo il preflight: tutti
coincidono con quelli registrati nel rapporto.

Il [rapporto strutturato](allegati/GS-VER-335-verifica.json) distingue gli esiti.

## Limiti

Il target nativo verifica il modello condiviso macOS. Non attesta l'uso reale
di tastiera, VoiceOver, Voice Control, contrasto, pseudo-lingua, destra-sinistra
o iPadOS. L'osservazione GUI richiesta non è stata eseguibile durante questa
fase perché la sessione macOS era bloccata; il GREEN automatico non viene
presentato come verifica visuale. Il preflight non attesta firma, invio o
approvazione App Review. Gli scenari Cucumber del package verificano
comportamenti Kit/CLI, non sostituiscono questa regressione dello stato di
presentazione. Non viene dichiarato un miglioramento prestazionale né una
promozione G4/G5.
