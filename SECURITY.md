<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Politica di sicurezza

## Versioni supportate

Il prodotto non ha ancora rilasci pubblici. La sola linea supportata è la revisione corrente di `main`; prototipi, branch e build locali non costituiscono versioni supportate.

## Segnalare una vulnerabilità

Poiché il repository è privato, inviare la segnalazione direttamente all'amministratore del repository attraverso il canale privato associato all'accesso al progetto. Se il canale non è noto, chiedere all'amministratore un contatto sicuro usando soltanto una descrizione neutra.

Non aprire issue, discussioni o pull request contenenti dettagli sfruttabili, credenziali, documenti reali o dati personali. Non includere segreti neppure a scopo dimostrativo.

La segnalazione dovrebbe contenere:

- componente e revisione interessati;
- prerequisiti e impatto osservato;
- procedura minima di riproduzione con dati sintetici;
- eventuale mitigazione nota;
- modalità sicura per proseguire il confronto.

## Gestione

Gli obiettivi operativi, non vincolanti come SLA, sono presa in carico entro tre giorni lavorativi e prima valutazione entro sette. La vulnerabilità riceve un identificatore privato, severità, responsabile, analisi dell'impatto, correzione o deroga e test di regressione quando sicuro.

La divulgazione, l'eventuale advisory e il coordinamento di una release correttiva vengono concordati prima di rendere pubblici i dettagli. I dati ricevuti sono minimizzati e accessibili soltanto alle persone necessarie alla risposta.

## Ambito prioritario

Sono particolarmente rilevanti parser e importatori, accesso ai file, sandbox ed entitlement, persistenza, gestione di input ostili, fuga di dati attraverso log o diagnostica, supply chain, modelli ML e strumenti esposti a sistemi generativi.

Il modello normativo di asset, confini di fiducia, minacce THR-001–THR-020,
controlli e verifiche è [GS-SEC-001](docs/sicurezza/README.md). Una segnalazione può
citare gli ID senza includere nell'issue o nel titolo dettagli sfruttabili.
