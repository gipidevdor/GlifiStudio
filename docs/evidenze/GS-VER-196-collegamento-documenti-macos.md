<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-196 — Collegamento dei documenti macOS dopo operazioni occupate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-196 |
| Tipo | Evidenza di correzione e verifica applicativa macOS |
| Versione | 1.2.0 |
| Stato | Superato nel perimetro automatico macOS |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-196; RF-001; RQ-011; RQ-032; RQ-058 |

## Perimetro e identità

Il collegamento documentale richiesto mentre il modello è occupato veniva
scartato dal guard di `run`; il task SwiftUI legato al percorso non ripartiva
alla fine del busy. L'incremento macOS attende un segnale idle e mantiene
soltanto la richiesta più recente, con cancellazione riferita al proprio token.
Nessun polling, sleep, formato o nuova API Core/Kit.

Richiesta obsoleta o cancellata in attesa non apre sessioni né crea package.
Prima di attivare una candidata dopo un await si ricontrolla la validità;
errori conservano la sessione precedente e le risorse candidate vengono chiuse.
Il ramo iPadOS resta invariato.

Questo turno è distinto dallo snapshot `07673ac2…70b5f` del lotto precedente.
Usa il nuovo snapshot identificato sotto, che congela anche i contributi
concomitanti presenti in quel momento. Nessuna clausola scientifica delle altre
sessioni viene promossa da questa evidenza; i sorgenti successivi al freeze
restano esclusi dall'attestazione.

## Verifica

`make test-macos` è superato sul lotto 196–197: **47 definizioni e 128
esecuzioni, 0 fallite, 0 saltate**, con `runtimeWarnings: []` nel riepilogo
xcresult. Il totale comprende cinque test parametrizzati con 86 esecuzioni e
42 test non parametrizzati; non confonde definizioni ed esecuzioni.
Riepilogo sanificato `validated-macos-results.json` e log
`196-197-validated-green.log` sono conservati nel dossier indicato sotto.

La clausola CMP-196 è `verified` per questo perimetro automatico sul nuovo
snapshot. La DoR precede il fix di produzione; il gate del lotto precedente non
è riutilizzato come prova di questo codice. Gli avvisi host e dello strumento
sono distinti dai runtime warning dei test.

## Snapshot e gate conclusivo

La copia di lavoro basata su
`a86a53b512bd777f191c89692e0c573a3d37a3ff` è congelata in **830 file** con
manifest SHA-256
`58d18024b9029075bdad8ffd6c8bb41ad2f1d1d4196b6fbc26aab729dfe80e8b`.
Non è un nuovo commit né una prova CI remota.

`make verify-macos` e `Scripts/check-app-store-packaging.sh --macos-only`
terminano entrambi con **exit 0 sul medesimo snapshot**:

| Controllo | Esito osservato |
| --- | --- |
| SwiftPM | 381 test Core + 52 Kit = 433 superati |
| Oracoli | 153 righe superate |
| Export | Due PDF/A-2u conformi con veraPDF |
| CLI e fixture | 15 fixture, 51 controlli CLI, tolleranza 1e-12 |
| Recovery e QueryAST | 22 checkpoint recovery e contratto CLI QueryAST superati |
| Test nativi macOS | 47 definizioni, 128 esecuzioni, 0 fallite, 0 saltate; `runtimeWarnings: []` |
| App macOS | Build Debug/Release, analisi statica e archivio senza firma validi |

Nessuna build iPadOS è inclusa. Restano avvisi non fatali dell'host per
CoreSimulator `1171.7 < 1174.21` e metadati `MacPlaceholderOS`, oltre agli avvisi
diagnostici Xcode osservati nella corsa mirata. Non si dichiara una build priva
di qualsiasi avviso.

Il dossier locale
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-21-58d18024/`
conserva `source-manifest.json`, riepiloghi sanificati, log `verify-macos.log` e
`packaging-macos.log`, prove mirate e l'archivio dei sorgenti verificati.
`verified-source.tar.gz` misura **7 837 859 byte**, SHA-256
`6f6c28c68511348055877a442d98ddace7c84ab0409ab39cff5f0e7240279152`.
L'archivio e il manifest permettono di identificare il contenuto provato senza
attribuirlo a modifiche successive di altre sessioni.

## Confronto conclusivo e pulizia

Il confronto finale registra `allExecutableSourcesMatch: true`: tutti i file
eseguibili correnti corrispondono allo snapshot; anche i sette percorsi posseduti
dal lotto e i commenti DocC risultano invariati. I 17 percorsi modificati e sei
aggiunti dopo il freeze riguardano soltanto documentazione e conformità, inclusi
contributi di altre sessioni. Questi metadati finali non appartengono
all'impronta dei sorgenti provati e sono soggetti ai controlli statici conclusivi.
`final-source-comparison.json` e il resoconto di pulizia restano nel dossier.

Sono rimossi soltanto worktree e cache rigenerabili di questo lotto:
**2 541 532 KiB, circa 2,42 GiB**. Il worktree temporaneo viene rimosso tramite
Git; l'archivio degli 830 file, il manifest con contenuti/permessi, i log e i
riepiloghi utili restano nel dossier stabile. Toolchain attive, dipendenze,
file utente e cache delle altre sessioni sono conservati.

## RED osservato prima del fix

Il test con opener sospeso conferma la richiesta persa durante busy:
**37 definizioni, 46 esecuzioni, 45 superate, 1 fallita, 0 saltate**. URL e
ProjectID rimangono quelli precedenti dopo il rilascio dell'opener. Nessun fix
del modello è ancora applicato a questo tentativo; non è attestata una lettura
retroattiva della nuova DoR prima della riproduzione.
Il log `196-red.log` e l'audit dell'esecuzione restano disponibili; Xcode ha
rimosso automaticamente il vecchio bundle xcresult RED dopo le corse successive.
Non si dichiara conservato quel bundle.

## Copertura della revisione del fix

I cinque scenari deterministici forzano attesa/busy, richiesta più recente,
cancellazione in attesa, stessa URL e apertura fallita. La cancellazione durante
le letture della candidata non viene forzata da una seam di test: ricontrolli del
token dopo gli await, `candidate.close` e bilanciamento degli scope sono oggetto
di due revisioni del codice. Non sono rivendicati scenari simulati non eseguiti
né una prova GUI di tali letture. I cinque nuovi test sono superati nella corsa
GREEN complessiva descritta sopra.

## Limiti

Solo macOS e verifiche automatiche secondo il perimetro concordato. Nessuna
attestazione di finestre SwiftUI reali, autosave, file provider, VoiceOver,
validazione con utenti, iPadOS o G4. Nessuna nuova CI o commit viene attribuita
alle prove locali; la compatibilità con modifiche concomitanti richiede identità
ed esiti espliciti.
