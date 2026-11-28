<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-329 — Contesto coerente della fonte da codificare

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-329 |
| Tipo | Verifica correttiva della presentazione |
| Versione | 1.0.0 |
| Stato | RED riprodotto; GREEN nativo e gate integrato macOS superati |
| Responsabile | Codex con coordinamento delle verifiche native |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta di perfezionamento del codice e della semantica |
| Riferimenti | GS-DOR-329; RF-043; RQ-011; RQ-047; RQ-058; GS-APL-001; GS-UX-001-09; GS-UX-001-16 |

## Difetto e confine di pubblicazione

Il caricamento di una nuova fonte pubblicava i segmenti prima del numero di
caratteri e dell'identità selezionata; azzerava subito il passaggio risolto.
Una failure intermedia lasciava segmenti B associati all'identità A. Dopo
l'aggiornamento dell'identità, una failure nel recupero dei testi delle
codifiche poteva lasciare invece il nuovo contesto B con il dizionario A.

La correzione prepara segmenti, numero di caratteri, stato qualitativo e testi
in variabili locali. La funzione privata riceve esplicitamente revisione e stato
da usare e restituisce un dizionario, senza pubblicare. Dopo l'ultima lettura
il modello controlla la cancellazione e pubblica tutti i campi sul Main Actor
senza await fra le assegnazioni. Soltanto il successo elimina il passaggio
risolto precedente. Il proprietario delle operazioni, le failure e la stessa
azione di retry restano quelli esistenti.

Il wrapper di aggiornamento dei testi già usato dagli altri flussi qualitativi
delega alla stessa risoluzione; nessuna API Kit/CLI, DTO, storia, schema o
nuova dipendenza. Le letture del caricamento non registrano eventi.

## RED deterministico

Le prove usano due fonti sintetiche distinte, un codebook e una codifica per
fonte. Il contesto A comprende già un passaggio risolto e i testi delle sue
codifiche. Il runtime iniettato interrompe la seconda admission (numero di
caratteri) oppure la terza (risoluzione dei testi delle codifiche B), tramite
pressione critica o cancellazione del task corrente: quattro combinazioni.

Il RED nativo del coordinatore termina con exit 65: **7 definizioni, 10
esecuzioni, 4 casi falliti e 6 passati**. Falliscono tutte le interruzioni;
restano verdi il rifiuto busy e i controlli preesistenti di selezione
KWIC/visuale. La pressione e la cancellazione producono le failure tipizzate
attese; sono le assegnazioni anticipate a violare la conservazione dello stato.

Una prova separata sospende una riapertura con il gate già esistente, tenta
B durante busy e verifica l'intero contesto A invariato, quindi rilascia il
gate e verifica il retry riuscito. Non richiede attese temporali o nuove API
di fault injection.

## Verifiche completate e limiti

La scheda Ready precede i test e il fix; la produzione resta congelata durante
il RED. Dopo conferma del RED viene applicata la sola correzione del modello,
con formattazione, lint mirato sui due file Swift e diff check superati.

Il gate finale `make verify`, eseguito dal coordinatore sullo snapshot
composito isolato, termina con **exit 0 in 589,88 secondi**. La verifica nativa
attraverso `GlifiStudio.xcworkspace` comprende **135 definizioni e 425
esecuzioni superate, zero failure e zero skip**, senza warning runtime.
Sono GREEN le quattro combinazioni di interruzione, la prova busy con retry
e le regressioni di selezione e codifica incluse nella composizione macOS.

Il dossier locale `macOS-2026-11-27-semantics` conserva `native-summary.json`,
`composite-verification-summary.json`, il risultato nativo e il log completo
`composite-make-verify.log`. Il digest SHA-256 del log è
`dccda4c30b675a31188afc0dce651a4aaa3d5c56f2a233bb659f9f6da2e6a28a`.
I **608 input controllati** mantengono prima e dopo il gate il fingerprint
`36b05ea14bbeafe91150b84edb8ab74a67a240e75b9430f553797f262714d259`:
la verifica riguarda gli stessi sorgenti congelati. Il
[riepilogo strutturato](allegati/GS-VER-329-verifica.json) distingue RED,
GREEN nativo e gate integrato e registra i digest dei due file Swift.

Si tratta di una correzione del modello condiviso verificata attraverso il
target nativo macOS. Non attesta iPadOS, finestre reali, audit VoiceOver o
G4/G5; nessun miglioramento prestazionale viene dichiarato.
