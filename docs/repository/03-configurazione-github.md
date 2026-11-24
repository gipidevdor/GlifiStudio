# Configurazione GitHub

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REP-003 |
| Tipo | Checklist di configurazione |
| Versione | 1.3.0 |
| Stato | Pronto per applicazione |
| Responsabile | Amministratore del repository, da confermare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Richiesta prima della creazione del remote |

## Creazione

- Visibilità: **Private**.
- Branch predefinito: `main`.
- Inizializzazione server: nessun README, licenza o `.gitignore` aggiuntivo, perché la baseline locale li contiene già.
- Funzioni collaborative: issue abilitate; wiki e discussion disabilitate finché non hanno uno scopo governato.
- Fork: disabilitati, oppure consentiti soltanto se esiste un bisogno esplicito e una politica di cancellazione.
- Merge: squash abilitato e predefinito; merge commit e rebase merge disabilitati nella fase iniziale; cancellazione automatica dei branch integrati.

I valori canonici sono versionati in `Config/GitHub/repository-settings.json`; le etichette sono in `Config/GitHub/labels.json`. Ogni variazione amministrativa deve aggiornare prima questi file, essere revisionata e poi applicata mediante [GS-REP-009](09-bootstrap-github.md).

## Ruleset di `main`

Dopo il primo push applicare una delle ruleset versionate in `Config/GitHub/rulesets/`. Il profilo `solo` evita l'auto-approvazione; il profilo `team` richiede un revisore indipendente e CODEOWNERS. Entrambi:

- richieda pull request prima dell'integrazione;
- richiedono i controlli `verify` e `app-store-baseline` aggiornati sul commit più recente;
- invalidano approvazioni obsolete e richiedono la risoluzione delle conversazioni;
- impedisca force push e cancellazione del branch;
- richieda storia lineare;
- non dichiarano bypass permanenti.

La firma dei commit va resa obbligatoria appena tutti i contributori dispongono di
firma verificata e il flusso di automazione è compatibile. Le funzioni disponibili
per repository privati dipendono dal piano GitHub: ogni regola non disponibile deve
essere registrata come rischio e coperta, per quanto possibile, da revisione e CI.
`branchRulesets = required-if-available` rende questa degradazione esplicita; il
profilo versionato resta pronto per l'attivazione appena il piano la consente.

## Actions

- Permessi predefiniti del token: sola lettura.
- Pull request da workflow: disabilitate salvo esigenza successiva.
- Azioni ammesse: preferibilmente GitHub; ogni azione esterna deve essere approvata e fissata a SHA completo.
- Runner self-hosted: vietati finché non esistono isolamento, aggiornamento, osservabilità e procedura di bonifica.
- Retention log e artefatti: minima compatibile con diagnosi e audit; nessun contenuto utente nei log.

## Sicurezza e dipendenze

Abilitare dependency graph, Dependabot alerts e aggiornamenti di sicurezza quando disponibili sul piano. Valutare code scanning, secret scanning, push protection e dependency review prima di considerarli controlli obbligatori: la loro disponibilità privata può dipendere dal piano e non deve essere simulata nella documentazione.

## Proprietà del codice

Creare `.github/CODEOWNERS` soltanto dopo aver verificato l'handle del titolare o il team. Proteggere poi il file con la stessa ruleset e richiedere revisione del proprietario per `Config/`, `.github/`, `Scripts/`, `docs/adr/`, sicurezza e firma.

## Verifica finale

Eseguire una pull request di prova che fallisca intenzionalmente un controllo, verificare il blocco, correggerla e integrarla. Conservare screenshot o esportazione delle impostazioni sensibili in un archivio amministrativo protetto, non nel repository.

## Riferimenti operativi

- [Creazione di ruleset](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository)
- [Regole disponibili per ruleset](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [Uso sicuro di GitHub Actions](https://docs.github.com/en/actions/reference/security/secure-use)
- [Opzioni di configurazione Dependabot](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)
