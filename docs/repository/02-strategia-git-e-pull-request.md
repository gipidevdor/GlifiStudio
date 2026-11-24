# Strategia Git e pull request

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REP-002 |
| Tipo | Procedura operativa |
| Versione | 1.0.0 |
| Stato | Attivo |
| Responsabile | Responsabile tecnico, da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline operativa richiesta dal promotore |

## Modello

Il progetto usa sviluppo basato su `main` con branch brevi. `main` rappresenta sempre la baseline integrata e non riceve modifiche dirette dopo l'attivazione della ruleset, salvo bootstrap iniziale o emergenza registrata.

I branch usano `feat/`, `fix/`, `docs/`, `refactor/`, `perf/`, `test/`, `build/`, `ci/` o `chore/` seguiti da una descrizione breve in minuscolo e trattini. Branch di rilascio lunghi non vengono introdotti finché il modello di distribuzione non lo richiede.

## Pull request

Una pull request deve essere piccola abbastanza da poter essere compresa e verificata, ma completa rispetto al proprio risultato. Deve contenere:

- contesto, risultato e criteri di accettazione;
- issue, requisiti, ADR ed evidenze collegati;
- test e, quando applicabile, benchmark o migrazioni;
- valutazione di privacy, sicurezza, accessibilità e localizzazione;
- rischio residuo e recupero.

Le revisioni bloccanti distinguono violazioni di requisito, difetti e rischi dalle preferenze non normative. Una conversazione non viene risolta dall'autore senza aver documentato l'esito.

## Integrazione e storia

Il metodo predefinito è squash merge, con titolo conforme ai messaggi di commit. Preserva una storia lineare e un cambiamento logico per commit su `main`. Un merge commit è ammesso soltanto quando la topologia ha valore documentale; il rebase locale non deve riscrivere commit già condivisi.

Tag di rilascio e tag di evidenza sono annotati e immutabili. Force push e cancellazione di `main` sono vietati. Una correzione dopo l'integrazione usa un nuovo commit o un revert, non una riscrittura.

## Bootstrap

Poiché il repository non ha ancora una baseline remota, il primo commit firmato può essere creato direttamente su `main`. Subito dopo il primo push si applicano le protezioni descritte in [GS-REP-003](03-configurazione-github.md); ogni modifica successiva passa da pull request.
