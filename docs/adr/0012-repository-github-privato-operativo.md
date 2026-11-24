# ADR-0012 — Repository GitHub privato operativo

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0012 |
| Tipo | Architecture Decision Record |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Richiesta esplicita dell'iniziatore del progetto |

## Contesto

ADR-0010 ha scelto GitHub e una configurazione dichiarativa senza assegnare account,
URL o profilo operativo. L'account autenticato autorizzato è `gpicchiarelli`; il
repository omonimo non esisteva e la baseline locale era pronta al primo commit.

## Decisione

Il remote canonico iniziale è il repository privato
[`gpicchiarelli/GlifiStudio`](https://github.com/gpicchiarelli/GlifiStudio). `main` è
il branch predefinito e il profilo amministrativo è `solo` finché non vengono
assegnati altri proprietari verificati.

La configurazione applica ogni controllo supportato dal piano. Ruleset, auto-merge,
Secret Scanning e push protection restano `required-if-available`: non devono essere
simulati quando GitHub li rifiuta per il piano del repository privato. I profili
versionati restano la sorgente desiderata e vanno attivati dopo l'upgrade appropriato.

Il runner `xcode-27` resta la baseline CI. Se il budget Actions ne impedisce l'avvio,
il fallimento viene registrato come blocco infrastrutturale e non aggirato usando una
toolchain precedente.

## Conseguenze

- commit e push hanno un riferimento remoto canonico;
- il merge manuale deve rispettare la disciplina di pull request finché `main` non è
  protetto server-side;
- i gate locali restano obbligatori ma non sostituiscono la CI;
- il budget Actions e un piano con protezioni private sono prerequisiti per rendere
  pienamente operativi i controlli remoti;
- `CODEOWNERS` resta inattivo fino alla definizione di ownership reale.

## Alternative considerate

- Rendere pubblico il repository: respinto perché viola la decisione di riservatezza.
- Indebolire la toolchain CI: respinto perché contraddice la baseline Xcode 27.
- Installare subito un runner self-hosted: respinto finché non esistono isolamento,
  manutenzione, hardening e risposta agli incidenti.
