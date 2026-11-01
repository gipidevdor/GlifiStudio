# Governo del repository

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REP-IDX-001 |
| Tipo | Indice operativo del repository |
| Versione | 1.4.0 |
| Stato | Attivo |
| Responsabile | Amministratore del repository, provvisorio |
| Ultima modifica | 2026-10-03 |
| Approvazione | Baseline operativa richiesta dal promotore |

Questa sezione traduce lo standard di progetto in una configurazione concreta per
il repository privato `gpicchiarelli/GlifiStudio`. Distingue i controlli attivi da
quelli che richiedono un piano o budget GitHub diverso.

## Documenti

| ID | Argomento | Stato |
| --- | --- | --- |
| GS-REP-001 | [Modello di governo privato](01-modello-di-governo-privato.md) | Operativo |
| GS-REP-002 | [Strategia Git e pull request](02-strategia-git-e-pull-request.md) | Operativo |
| GS-REP-003 | [Configurazione GitHub](03-configurazione-github.md) | Applicata per le funzioni disponibili |
| GS-REP-004 | [Sicurezza del repository](04-sicurezza-del-repository.md) | Operativo e progressivo |
| GS-REP-005 | [CI e runner Xcode 27](05-ci-e-runner-xcode.md) | Configurato; `static-quality`/`format-check`/`verify`/`app-store-baseline` |
| GS-REP-006 | [Segreti e firma Apple](06-segreti-e-firma-apple.md) | Divieto attivo; provisioning rinviato |
| GS-REP-007 | [Backup e recupero](07-backup-e-recupero.md) | Da attivare e provare |
| GS-REP-008 | [Passaggio futuro a pubblico](08-passaggio-a-pubblico.md) | Gate definito |
| GS-REP-009 | [Bootstrap del repository GitHub privato](09-bootstrap-github.md) | Eseguito; limitazioni registrate |

## Stato della baseline

Il repository remoto privato, il primo commit, le impostazioni conservative, le
etichette e Dependabot sono attivi. Ruleset, auto-merge, Secret Scanning e push
protection non sono disponibili sul piano corrente; i profili restano versionati.
La CI Xcode 27 ha eseguito per la prima volta i workflow sul runner ospitato il
2026-10-03 ([GS-VER-141](../evidenze/GS-VER-141-prima-ci-remota-verde.md)); il budget
Actions resta una condizione osservata, non garantita. Non sono presenti segreti,
certificati o workflow di rilascio.

`CODEOWNERS` non è attivato finché non esiste un handle o team GitHub verificato. Il template e il generatore sono pronti; inserire un proprietario fittizio produrrebbe una protezione solo apparente.
