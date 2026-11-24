<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Riprogettazione ergonomica della GUI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-222 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready con rischio accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di riprogettare e ottimizzare la GUI includendo il lavoro già realizzato |
| Riferimenti | RF-046; RF-087; RQ-012; RQ-030; RQ-058; RQ-063; GS-UI-001; GS-UX-001-17; ADR-0034 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Navigazione per compiti, strumenti esistenti riconoscibili e accessibili, contesto del progetto esplicito e risultati leggibili; laboratorio avanzato macOS tramite GlifiKit, senza nuovi algoritmi o formati persistenti |
| requisiti | RF-046/RF-087 e RQ-012/030/058/063: preservare fonti, scope, caveat, metodo e lineage; la richiesta di ergonomia è un obiettivo da valutare, non un risultato certificabile dal solo codice |
| dominio/API | Le app usano soltanto GlifiKit; progetto e indagine mantengono gli aggregate esistenti. Le nuove esecuzioni degli operatori in memoria sono risultati di sessione, distinti dagli Artifact persistiti |
| failure semantics | Precondizioni e budget verificati prima del calcolo; errori tipizzati e cancellazione posseduta, conservazione del risultato valido precedente; nessun risultato incompleto presentato come completo né annotazione linguistica inventata |
| esperienza prevista | Sidebar e accessi agli strumenti per compito, ricerca delle destinazioni, un'azione primaria contestuale; parametri avanzati progressivi; stati vuoto, lavoro, errore e dati insufficienti; tastiera, label it/en, testo scalabile e ordine di lettura logico |
| verifica | Controlli statici documentali/localizzazione/architettura, test mirati di bridge e modello, test Core/Kit e build tramite `make verify`; GS-VER-222 raccoglie soltanto esiti osservati. GUI reale e audit assistivi richiedono accesso al Mac sbloccato |
| dati e migrazione | Nessun nuovo schema `.glifi`; richieste, selezioni e risultati avanzati in memoria hanno ciclo di vita della sessione e vengono invalidati al cambio progetto. Le analisi già persistite conservano i loro contratti |
| sicurezza/privacy | Soltanto fonti del progetto autorizzato e API Kit; nessuna rete, dipendenza, entitlement, telemetria o esportazione automatica. Le regole sono dati dichiarativi, senza `eval` |
| prestazioni/sistema | Calcoli e preparazione di matrici/presentazioni fuori Main Actor con limiti Kit; tabelle bounded e navigabili. Nessun vantaggio di latenza o energia dichiarato senza misura |
| tracciabilità | CMP-222 inizialmente `specified`, collegata a GS-UI-001 e GS-VER-222; indici, matrice di tracciabilità e CHANGELOG aggiornati nel lotto |
| decisioni | ADR-0034 autorizza il ponte UI degli operatori già esistenti, limitatamente alle esecuzioni di sessione; ADR-0032 resta storico per il suo incremento. Nessuna promozione scientifica, chiusura G4/G5 o modifica della baseline 0.1 |

## Rischio accettato e recupero

**Ready con rischio accettato** per l'incremento applicativo e i confini sopra
definiti, con verifiche ergonomiche e assistive da completare separatamente.

La richiesta esplicita autorizza l'implementazione; non elimina la necessità di
audit con persone e tecnologie assistive. L'iniziatore resta owner delle prove
manuali e della successiva valutazione ergonomica prima di G4. Il Mac bloccato
può impedire screenshot e interazioni reali; tale limite deve comparire
nell'evidenza e nella consegna se ancora presente.

L'incremento è recuperabile rimuovendo i soli accessi/presentazioni nuovi, senza
migrazioni del progetto. I risultati scientifici preesistenti restano governati
dai loro metodi e manifest; il nuovo client non cambia formule o tolleranze.
