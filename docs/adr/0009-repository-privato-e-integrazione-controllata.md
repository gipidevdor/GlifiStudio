# ADR-0009 — Repository privato e integrazione controllata

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0009 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Direzione di progetto del 2026-09-15 |
| Sostituisce | Nessuno |

## Contesto

Glifi Studio contiene visione, architettura, codice iniziale e materiale di provenienza ancora in definizione. Il progetto deve poter crescere con storia verificabile, collaborazione sicura e quality gate reali senza rendere pubblici prematuramente contenuti, identità o decisioni non approvate.

## Decisione

Il progetto adotta un repository Git privato con `main` come baseline integrata, branch brevi e pull request obbligatorie dopo il bootstrap. La struttura locale include policy, modelli, controlli riproducibili e un profilo GitHub-ready; la scelta e creazione del remote restano operazioni separate che richiedono titolare, account e piano verificati.

La CI usa Apple Silicon con Xcode 27, invoca lo stesso quality gate locale, applica permessi in sola lettura e fissa le azioni a commit immutabili. Firma, notarizzazione, pubblicazione e segreti Apple restano esclusi finché identità e distribuzione non sono decise.

Il repository non contiene corpus reali, dati personali, credenziali, materiale di firma o grandi artefatti non approvati. Il passaggio a pubblico richiede audit dell'intera storia, verifica dei diritti e approvazione esplicita.

## Conseguenze

- La baseline è pronta per un hosting privato senza dipendere da impostazioni non documentate.
- Le modifiche future hanno un percorso uniforme di proposta, revisione, verifica e integrazione.
- Alcune protezioni restano inattive finché non esiste il remote e devono essere verificate successivamente.
- `CODEOWNERS` non può essere attivato prima di conoscere identità o team reali.
- I minuti del runner macOS per repository privati e le funzioni di sicurezza dipendono dal provider e dal piano scelto.

## Alternative considerate

- repository pubblico immediato: respinto perché diritti, storia e governance non sono ancora sottoposti ad audit;
- soli file locali senza CI o policy: respinto perché non offre integrazione riproducibile né protezione collaborativa;
- workflow di rilascio completo fin dall'inizio: respinto perché richiederebbe segreti e identità Apple ancora aperti;
- `CODEOWNERS` con un segnaposto: respinto perché fornirebbe una garanzia apparente e non applicabile.

## Documenti applicativi

- [Governo del repository](../repository/README.md)
- [Gestione della configurazione](../standard/08-gestione-della-configurazione.md)
- [Integrazione continua e quality gate](../standard/20-integrazione-continua-e-quality-gate.md)
- [Sicurezza del repository](../repository/04-sicurezza-del-repository.md)
