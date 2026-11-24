# ADR-0005 — Interfaccia internazionalizzabile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0005 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Chiarimento di prodotto del 2026-09-15 |
| Integra | ADR-0004 per la sola lingua di presentazione |
| Sostituisce | Nessuno |

## Contesto

ADR-0004 sceglie l'italiano come lingua iniziale. Questa scelta non deve trasformarsi in un accoppiamento tra testi italiani, codice dell'interfaccia, motore e dati persistenti.

## Decisione

L'interfaccia è internazionalizzabile fin dalla prima baseline. Usa un catalogo Xcode condiviso, chiavi semantiche stabili e selezione della lingua demandata alla piattaforma. Italiano e inglese sono le prime localizzazioni complete; l'italiano rimane la lingua sorgente.

La lingua dell'interfaccia è indipendente dalla lingua selezionata per l'analisi di un corpus.

## Alternative considerate

- interfaccia inizialmente solo italiana da internazionalizzare in seguito;
- stringhe italiane usate direttamente come chiavi di localizzazione;
- catalogo condiviso con chiavi semantiche e almeno due localizzazioni verificate.

È accettata la terza alternativa perché rende dimostrabile l'internazionalizzazione senza legare l'identità delle risorse alla formulazione italiana.

## Conseguenze positive

- Nuove lingue possono essere aggiunte senza modificare il motore.
- Modificare il testo italiano non invalida la chiave usata dal codice.
- macOS e iPadOS condividono copertura e terminologia.

## Conseguenze negative e rischi

- Il catalogo richiede manutenzione e revisione per ogni modifica dell'interfaccia.
- Due traduzioni presenti non provano da sole che tutti i layout futuri siano adattabili.
- Plurali e formati complessi richiederanno test mirati quando introdotti.

## Verifica della decisione

Si applicano [GS-I18N-002](../internazionalizzazione-interfaccia.md) e TV-015. Il quality gate deve validare il catalogo italiano/inglese e compilare entrambi i target.
