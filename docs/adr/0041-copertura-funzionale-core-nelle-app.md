<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0041 — Copertura delle capacità analitiche del core nelle app

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0041 |
| Versione | 1.0.0 |
| Stato | Accettato per ambito e architettura; verifiche separate |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di includere tutte le features del core nelle funzionalità applicative |
| Riferimenti | ADR-0002; ADR-0024; ADR-0031; ADR-0033; ADR-0034; GS-DOR-223 |

## Contesto

Il laboratorio precedente espone dodici operazioni esplorative, ma una parte
delle analisi persistite, della statistica generale e delle valutazioni resta
raggiungibile solo da codice. La nuova richiesta estende la copertura funzionale
dell'app macOS alle capacità analitiche utente già realizzate in GlifiCore.

Gli identificatori, i digest, i kernel numerici e le primitive di persistenza
sono infrastruttura dei percorsi: non vengono trasformati in pulsanti separati.
La disponibilità della UI non promuove lo stato scientifico di un metodo.

## Decisione

1. Conservare i percorsi correnti e aggiungere accessi per analisi dirette del
   corpus, statistica, operatori su matrici/grafi e valutazione temporale/linguistica.
   Il catalogo deve permettere di trovare famiglie e metodi per nome e scopo.
2. Usare le API persistite esistenti quando l'operazione è già definita sul
   progetto. Pubblicare il risultato soltanto dopo avere letto anche lo snapshot
   aggiornato. Non introdurre nuovi Artifact o migrazioni `.glifi`.
3. Per gli operatori puri usare facciate GlifiKit tipizzate, esecuzione fuori dal
   Main Actor, input bounded espliciti e risultati di sessione. Le app non
   importano GlifiCore e non ricostruiscono formule scientifiche.
4. Date, gruppi, partizioni, classi, giudizi e annotazioni gold sono forniti dalla
   persona. Le assegnazioni aggiuntive restano in memoria e sono congelate con
   l'esito; non vengono inferite dai nomi dei file. Gli evaluator linguistici
   confrontano annotazioni dichiarate e non diventano un backend NLP.
5. Consentire le valutazioni e la statistica indipendenti senza imporre un
   progetto. Riutilizzare l'ownership applicativa della cancellazione, conservare
   l'output precedente su failure e invalidare i dati al cambio progetto.
6. Le facciate dei nuovi operatori possono esportare i propri DTO JSON tipizzati
   con identità di procedura, parametri effettivi e valori non finiti rappresentati
   esplicitamente. Questi JSON sono esiti o richieste di sessione, non un nuovo
   formato di progetto, né un rapporto persistito o una promozione nel planner.
7. Conservare tabelle equivalenti, paginazione bounded, stato scientifico e caveat;
   distinguere mancanti, risultati non definiti e zero. Usare controlli nativi,
   stringhe italiane/inglesi e parametri avanzati progressivi.

## Conseguenze e verifica

Il perimetro applicativo macOS si amplia senza nuove dipendenze, rete,
entitlement, telemetria o algoritmi. Le nuove facciate e presentazioni richiedono
prove di parità con le API del core, casi invalidi e cancellazione. La copertura
è registrata in GS-VER-223; `make verify` resta obbligatorio. Il comportamento
assistivo e l'efficacia ergonomica richiedono prove distinte. Lo sviluppo
dedicato iPadOS e la chiusura G4/G5 restano separati secondo ADR-0033.

## Allineamento al completamento nativo del core

La composizione include la baseline `1375950` e le capacità approvate nell'ADR-0035
del completamento nativo. Si aggiungono selezione LDA, MDS ordinale e multiavvio,
SOM avanzata, tre metodi di comunità, due layout e foresta minima, Simpson e
pipeline linguistica con disponibilità locale, annotazioni e codifica su unità
con variabili esplicite. Le annotazioni automatiche restano distinte dagli
evaluator gold/predetti e non diventano un formato di annotazione persistente.
