<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-WVR-005 — Conformità retroattiva richiesta dal runner CucumberSwift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-WVR-005 |
| Tipo | Deroga controllata al dialetto Swift dei test |
| Versione | 1.0.0 |
| Stato | Attiva nel solo ambito dichiarato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Decisione tecnica dell'agente attuatore nell'ambito dell'integrazione BDD richiesta; nessuna approvazione umana specifica dichiarata |
| Approvatore | Codex, agente attuatore della scelta tecnica circoscritta |
| Regole interessate | `AvoidRetroactiveConformances` di `.swift-format`; GS-STD-001-12 e GS-STD-001-20 |
| Ambito | Unica conformità `extension Cucumber: @retroactive StepImplementation` in `Packages/GlifiCore/Tests/GlifiBDDTests/GlifiBDDRunner.swift` |
| Scadenza | 2027-02-27 oppure aggiornamento di CucumberSwift che renda disponibile un ingresso equivalente senza conformità retroattiva, se precedente |
| Riferimenti | ADR-0046; GS-DOR-332; GS-BDD-001; GS-STD-001-24 |

## Motivazione

CucumberSwift 6.9.0 richiede una conformità del proprio tipo `Cucumber` al
proprio protocollo `StepImplementation` nel modulo consumer. `Cucumber` è
`final`, ha inizializzatore privato ed espone il singleton `shared`.
`loadStepDefinitions()` cerca la conformità tramite cast; il runner registra
un errore se manca anche quando step vengono registrati separatamente. Non
è disponibile un ingresso pubblico equivalente tramite oggetto del consumer.

La configurazione del progetto mantiene attiva
`AvoidRetroactiveConformances`. Si applica una sola soppressione locale
`swift-format-ignore: AvoidRetroactiveConformances`, immediatamente prima
della conformità richiesta, con riferimento a questa deroga.

## Rischio e impatto

Una futura versione della dipendenza potrebbe introdurre la stessa conformità
o modificare il contratto del protocollo. Questo può causare conflitto o errore
di compilazione nel bundle dei test. Il tipo e il protocollo appartengono allo
stesso modulo esterno; il consumer non può garantirne l'evoluzione. Non viene
aggiunta una conformità nel codice di produzione o in un prodotto distribuito.

## Alternative considerate

- Un wrapper locale non soddisfa il cast sul singleton e non può sostituire
  l'istanza; il tipo esterno non consente sottoclassi.
- Registrare la DSL prima dell'esecuzione non evita il controllo obbligatorio
  della conformità nel runner.
- Un fork della dipendenza sposterebbe nel progetto manutenzione e revisione
  del runtime di test; non è giustificato per questa singola integrazione.

## Mitigazione e verifica compensativa

- Versione diretta esatta e revisioni transitive bloccate nel lockfile.
- Uso del marcatore Swift 6 `@retroactive`, in un unico target di test.
- Nessuna modifica alla configurazione globale del formatter o ai gate.
- Compilazione Swift 6, `format-check`, scenari BDD e `make verify` macOS
  restano necessari; GS-VER-332 registra gli esiti osservati.
- Ogni aggiornamento di CucumberSwift riesamina questa conformità prima
  dell'adozione; nuovi usi non sono autorizzati da questa deroga.

## Piano di rientro

Alla prima versione upstream con registrazione/injection equivalente senza
conformità esterna, oppure alla scadenza, rivalutare il contratto. Adottare
l'ingresso pubblico, rimuovere conformità e soppressione, eseguire gli stessi
gate e registrare il rientro. Un rinnovo richiede nuova motivazione documentata;
la deroga non si estende automaticamente.
