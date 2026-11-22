# ADR-0010 — GitHub come hosting privato e configurazione dichiarativa

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0010 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Direzione di progetto del 2026-09-15 |
| Sostituisce | Specifica la destinazione lasciata aperta da ADR-0009 |

## Contesto

ADR-0009 ha definito un repository Git privato e un profilo GitHub-ready senza scegliere il servizio remoto. Il progetto richiede ora una preparazione specifica, completa e coerente per GitHub, mantenendo però separati il contenuto versionato dalle identità e dalle autorizzazioni del futuro proprietario.

## Decisione

GitHub è il servizio previsto per il repository remoto privato. Le impostazioni desiderate vengono conservate in `Config/GitHub/` e validate localmente. Script idempotenti forniscono anteprima, applicazione esplicita e audit del remote mediante GitHub CLI e REST API.

Il progetto adotta:

- issue strutturate e catalogo di etichette controllato;
- pull request con tracciabilità, verifica e valutazione dei rischi;
- profilo ruleset `solo` senza auto-approvazione e profilo `team` con revisione indipendente;
- squash merge, storia lineare, blocco di cancellazione e force push;
- job richiesto `verify` su Xcode 27;
- GitHub Actions limitate, token read-only e riferimenti eseguibili fissati a SHA;
- Dependabot alerts e aggiornamenti di sicurezza;
- secret scanning e push protection quando disponibili sul piano e tipo di proprietario;
- `CODEOWNERS` attivabile soltanto con handle o team verificati.

La creazione del repository e il primo push non vengono automatizzati senza autorizzazione specifica del titolare. Il bootstrap rifiuta un repository che non risulti privato.

## Conseguenze

- Le impostazioni GitHub diventano revisionabili, ripetibili e auditabili.
- La configurazione può essere applicata senza affidarsi a una checklist manuale non verificata.
- Account o organizzazione, piano, URL definitivo e ownership restano decisioni amministrative aperte.
- Alcune funzioni di sicurezza per repository privati possono richiedere GitHub Pro, Team, Enterprise Cloud, Code Security o Secret Protection.
- Un cambio di provider richiederà un nuovo ADR e la sostituzione degli adattatori operativi, non dello standard di qualità.

## Alternative considerate

- configurazione interamente manuale dall'interfaccia: respinta perché non riproducibile e soggetta a drift;
- applicazione automatica alla semplice esecuzione: respinta perché produrrebbe modifiche esterne non intenzionali;
- un solo profilo con approvazione obbligatoria: respinto perché bloccherebbe il maintainer unico o indebolirebbe il team;
- attivazione preventiva di tutte le funzioni Advanced Security: respinta perché disponibilità e costi dipendono dal piano.

## Documenti applicativi

- [Bootstrap del repository GitHub privato](../repository/09-bootstrap-github.md)
- [Configurazione GitHub](../repository/03-configurazione-github.md)
- [CI e runner Xcode 27](../repository/05-ci-e-runner-xcode.md)
- [Sicurezza del repository](../repository/04-sicurezza-del-repository.md)
