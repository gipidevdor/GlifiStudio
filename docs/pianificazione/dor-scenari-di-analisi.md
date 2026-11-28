<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Test degli scenari di analisi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-303 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.1 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di realizzare tutti i test degli scenari di analisi e aggiornare la documentazione |
| Riferimenti | GS-STD-001-16; GS-TST-001; GS-API-003; GS-UX-001-17; RQ-058; RQ-063 |

## Perimetro e criterio di completamento

L'incremento completa la verifica delle funzioni già implementate: inventario
esaustivo delle varianti pubbliche, scenari di integrazione mancanti e risultati
automatici riproducibili. Non introduce algoritmi, backend, dipendenze o un nuovo
formato di progetto. Un'eventuale regressione produttiva deve essere riprodotta
e corretta senza indebolire l'oracolo.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Verificare gli scenari delle funzioni esistenti e documentare la copertura effettiva, senza nuova funzione di prodotto |
| failure semantics | Errori tipizzati, cancellazione, stato conservato e assenza di pubblicazioni tardive; nessuna attenuazione degli assert scientifici |
| Inventario | 130 varianti dei cinque ingressi Kit/CLI e 40 tag testuali, confrontati con baseline revisionata e compilatore |
| Planner | Tutti gli 11 intenti con expected espliciti, precondizioni, esecuzione, progresso, terminale, grounding e riuso |
| Persistenza | Tutte le 17 analisi corpus attraverso riuso, input invalido e riapertura; revisioni storiche e correnti distinte |
| Modelli | Tutti i 45 esempi operatori reali, invarianti, pagine complete, reset/cancellazione/retry, preview bounded, SOM e tempo |
| Scientifico | Proprietà e calcoli indipendenti oltre alla parità fra facciate; nessuna promozione dei manifest |
| Cancellazione | Tutte le fixture tipizzate e JSON, oltre alle barriere dei modelli durante task immediati |
| tracciabilità | Matrice controllata, GS-TST-001, GS-VER-303 e CMP-303; storico GS-VER-300 conservato |
| Verifica | Mirati pertinenti, controlli negativi del nuovo verificatore e `make verify` macOS sui sorgenti identificati |
| Conservazione | Worktree isolato con overlay stabile del WIP; trasferimento guardato dei soli contributi del lotto |
| Esclusioni | Nessuna promessa per ogni input, audit UI/assistivo, prestazione, iPadOS o chiusura G4/G5 |

**Ready.** Il lavoro originario riguarda test e documentazione dell'architettura
esistente. Alla sua registrazione i profili KH senza adattatore GUI erano
indicati come headless: una prova non inventa una route o una funzione di
prodotto mancante. Il successivo GS-DOR-335 introduce gli adattatori dei
diciannove profili e i `nativeBindings` operativi. La matrice corrente richiede
route, dispatch, viste e test coerenti prima di rimuovere un tag dall'insieme
headless, con inventario esaustivo e disgiunto; i nuovi esiti sono separati
in GS-VER-335.
