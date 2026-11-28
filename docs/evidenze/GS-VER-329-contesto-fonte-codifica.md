<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-329 — Contesto coerente della fonte da codificare

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-329 |
| Tipo | Verifica correttiva della presentazione |
| Versione | 0.1.0 |
| Stato | RED riprodotto; candidato applicato, GREEN e gate integrato pendenti |
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

Il candidato prepara segmenti, numero di caratteri, stato qualitativo e testi
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

## Candidato e verifiche ancora da completare

La scheda Ready precede i test e il fix; la produzione resta congelata durante
il RED. Dopo conferma del RED viene applicata la sola correzione del modello,
con formattazione, lint mirato sui due file Swift e diff check superati.
GREEN nativo, composizione macOS e regressioni qualitative sono coordinati
separatamente e non sono ancora attestati da questa versione dell'evidenza.
Il [riepilogo strutturato](allegati/GS-VER-329-verifica.json) distingue gli esiti.

Si tratta di una correzione del modello condiviso verificata attraverso il
target nativo macOS. Non attesta iPadOS, finestre reali, audit VoiceOver o
G4/G5; nessun miglioramento prestazionale viene dichiarato.
