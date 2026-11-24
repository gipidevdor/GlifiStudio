# ADR-0004 — Italiano come lingua iniziale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0004 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Direzione di prodotto del 2026-09-15 |
| Sostituisce | Nessuno |

## Contesto

Glifi Studio necessita di una lingua sorgente determinata per evitare testi misti e contratti impliciti. Il dominio richiede inoltre una configurazione linguistica predefinita, distinta dalla lingua con cui l'interfaccia comunica.

## Decisione

- L'italiano (`it`) è la lingua sorgente iniziale delle app macOS e iPadOS.
- Italiano Italia (`it_IT`) è il locale predefinito iniziale.
- L'italiano (`it`) è la lingua predefinita dell'analisi quando il progetto non ne specifica una.
- Le stringhe dell'interfaccia sono mantenute in un catalogo Xcode condiviso.
- Identificatori, formati persistenti, errori strutturati e API del motore restano indipendenti dalla lingua di presentazione.

## Alternative considerate

- inglese come lingua sorgente con sola traduzione italiana;
- italiano incorporato direttamente nei sorgenti senza catalogo;
- italiano come lingua sorgente e catalogo predisposto per estensioni future.

È accettata la terza alternativa. Conserva una baseline italiana coerente senza impedire localizzazioni o backend linguistici successivi.

## Conseguenze positive

- La prima esperienza utente è coerente in italiano.
- Accessibilità e localizzazione condividono le stesse risorse su macOS e iPadOS.
- La lingua dell'analisi è esplicita e può essere registrata nella provenienza.

## Conseguenze negative e rischi

- Ogni nuovo testo deve essere gestito nel catalogo e verificato.
- L'italiano iniziale non costituisce prova di qualità linguistica per ogni funzione.
- L'aggiunta di altre lingue richiederà traduzione, fixture e criteri di accettazione specifici.

## Verifica della decisione

Si applicano [GS-I18N-001](../localizzazione-italiana.md) e TV-014. Il quality gate deve compilare entrambi i target con il catalogo condiviso e verificare che la regione di sviluppo effettiva sia `it`.
