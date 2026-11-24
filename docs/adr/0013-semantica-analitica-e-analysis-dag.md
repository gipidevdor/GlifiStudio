<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0013 — Semantica analitica backend-neutral e Analysis DAG

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0013 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Direzione scientifica esplicita dell'iniziatore del progetto |
| Fonte | Richiesta di revisione della fondazione scientifica del 2026-09-15 |
| Sostituisce | Nessuno |

## Contesto

La baseline separa già GUI, motore, persistenza e backend Apple, ma concentra metodi
scientifici differenti in pochi requisiti generici. `GlifiStatistics` non descrive
algebra lineare, matrici sparse, distanze, grafi, ottimizzazione e pseudo-casualità.
La pipeline documentale S0–S6, da sola, non rappresenta le dipendenze ramificate tra
matrici, ponderazioni, test, modelli, cluster, reti e visualizzazioni.

Senza un contratto scientifico precedente all'implementazione, due backend possono
usare formule o casi nulli differenti pur esponendo lo stesso nome, e una cache non
può sapere precisamente quali risultati invalidare.

## Decisione

1. GS-MET-001 diventa la specifica normativa della semantica matematica,
   statistica, linguistica e algoritmica.
2. Ogni artefatto persistibile usa un `AnalysisDescriptor` concettuale completo di
   algoritmo, versione, dati, preprocessing, parametri, seed, backend, precisione,
   software e dipendenze.
3. Le analisi successive a S0–S6 formano un Analysis DAG aciclico con invalidazione
   transitiva e riuso dei nodi validi.
4. Si introduce `GlifiMath` come fondazione concettuale backend-neutral per
   statistica, algebra lineare, matrici sparse, distanze, grafi, ottimizzazione e
   PRNG. Non viene ancora imposto un nuovo target Swift.
5. `GlifiStatistics` resta il nome dell'area inferenziale costruita sopra tale
   fondazione; `GlifiAnalysis` orchestra le famiglie analitiche.
6. Swift, Accelerate, BNNS, Core ML e Metal/MPS sono backend delle primitive e non
   autorità sulla semantica dei metodi.
7. Ogni algoritmo dichiara classe D0, D1, P1 o N1 e una politica di verifica
   indipendente dalla GUI.

## Alternative considerate

- ampliare soltanto `GlifiStatistics`: respinto perché confonde responsabilità
  statistiche con algebra, grafi, ottimizzazione e rappresentazioni;
- modellare ogni analisi come fase S7/S8 lineare: respinto perché impedisce
  dipendenze ramificate e riuso selettivo;
- lasciare formule ai backend Apple: respinto perché lega correttezza e
  riproducibilità a implementazioni e versioni di piattaforma;
- creare subito numerosi target Swift: rinviato finché profili e dipendenze non siano
  stabilizzati da vertical slice.

## Conseguenze

- requisiti, architettura, test e persistenza possono riferirsi a contratti precisi;
- la cache può invalidare soltanto i discendenti effettivi;
- nuovi backend Apple possono essere promossi tramite equivalenza e benchmark;
- aumenta il lavoro iniziale di specifica, fixture e reference testing;
- corpus gold, tolleranze e selezione MVP restano decisioni esplicite da chiudere.

## Verifica della decisione

- ogni famiglia pubblica è indicizzata da GS-MET-001;
- requisiti RF-026–RF-046 e RQ-023–RQ-029 sono tracciati;
- VA-03 e VA-06 descrivono descriptor, DAG e backend-neutrality;
- i primi vertical slice implementativi producono descrittori serializzabili e
  superano reference test su almeno due percorsi indipendenti quando applicabile.
