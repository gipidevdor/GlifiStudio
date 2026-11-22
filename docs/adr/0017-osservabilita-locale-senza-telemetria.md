<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0017 — Osservabilità locale senza telemetria applicativa

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0017 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Richiesta esplicita di imporre le migliori scelte Apple per telemetria e log macOS |
| Sostituisce | Nessuno |

## Contesto

Glifi Studio tratta corpus potenzialmente sensibili. Diagnosi utile e tutela della
persona devono convivere senza aggiungere infrastruttura remota, identificatori o
SDK che aumentino superficie privacy, sicurezza, supply chain e launch time.

## Decisione

1. La 0.1 non usa telemetria applicativa, analytics, crash upload o session replay,
   proprietari o di terzi.
2. Xcode Organizer è il canale primario per le metriche aggregate delle build App
   Store rese disponibili da Apple per dispositivi partecipanti.
3. MetricKit non viene sottoscritto finché non esiste una funzione locale
   esplicita, minimizzata e testata che agisca sui suoi report; non è autorizzato un
   upload automatico.
4. Il codice usa un'unica facciata `GlifiDiagnostics` sopra Unified Logging, con
   subsystem, categorie, eventi e interpolazioni in allowlist.
5. Contenuti, query, prompt, estratti, path, URL, nomi file e identificatori
   personali non entrano in log o signpost, anche se redatti.
6. `OSSignposter` misura soltanto fasi costose con nomi statici e ID effimeri.
7. La 0.1 non offre bundle diagnostici; una futura esportazione deve essere
   volontaria, ispezionabile, limitata e redatta.
8. Privacy manifest, dichiarazione App Store, dipendenze e binario vengono
   confrontati nello stesso gate.

## Alternative considerate

- SDK di crash reporting esterno: respinto per raccolta, rete, dipendenza e
  identità non necessarie nella baseline;
- MetricKit con serializzazione locale preventiva: respinto perché conserva dati
  senza un'esperienza o decisione operativa che li utilizzi;
- soli `print` e log liberi: respinto perché privi di livelli, categorie, privacy e
  controllo statico;
- nessun log: respinto perché renderebbe opachi errori intermittenti e performance.

## Conseguenze

Privacy, launch e supply chain migliorano e l'osservabilità resta nativa. I dati di
Organizer possono essere scarsi per una distribuzione unlisted e non sostituiscono
test e Instruments. Alcuni problemi richiederanno riproduzione locale o una futura
esportazione esplicita.

## Verifica

GS-APL-014, `GlifiTelemetryPolicy`, `GlifiDiagnostics`, test Swift, audit statico,
privacy manifest e ispezione Console/Instruments costituiscono i controlli. Ogni
nuova dipendenza o uscita di dati invalida questa decisione finché non viene
approvata una decisione successiva.
