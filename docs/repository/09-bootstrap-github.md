# Bootstrap del repository GitHub privato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REP-009 |
| Tipo | Procedura operativa |
| Versione | 1.2.0 |
| Stato | Pronto per esecuzione |
| Responsabile | Amministratore del repository, da confermare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Necessaria prima della creazione del remote |

## Scopo

Questa procedura porta la baseline locale in un nuovo repository GitHub privato senza affidarsi a impostazioni manuali non documentate. Creazione del repository, primo push e applicazione delle protezioni restano passaggi distinti, così nessuna automazione può rendere pubblico il progetto o scegliere il titolare implicitamente.

## Prerequisiti

- account o organizzazione GitHub scelti e autorizzati;
- piano che supporti ruleset su repository privati;
- GitHub CLI autenticata con accesso amministrativo al solo repository;
- `jq`, Git, Xcode 27 con Apple Swift 6.4 o successiva compatibile della serie 6,
  Swift 6 language mode e SwiftPM tools 6.4 disponibili;
- titolarità, contenuto degli appunti grezzi e BSD 3-Clause riesaminati;
- `make verify-app-store` superato sul working tree destinato al primo commit.

## 1. Prima baseline

Revisionare ogni file versionabile, quindi creare il primo commit con identità corretta. La firma è raccomandata quando è già configurata e verificabile; non attivare un obbligo di firma prima di averne provato il flusso.

Il repository remoto deve essere creato vuoto, con nome approvato, visibilità **Private** e senza README, licenza o `.gitignore` generati da GitHub. Il comando seguente è un esempio da adattare soltanto dopo l'approvazione del proprietario:

```sh
gh repo create OWNER/GlifiStudio --private --source . --remote origin --push
```

Dopo il push, verificare nella pagina GitHub la visibilità privata e attendere che i
job `verify` e `app-store-baseline` completino il primo ciclo.

## 2. Profilo di protezione

Il profilo `solo` richiede pull request, CI aggiornata, storia lineare, conversazioni risolte e vieta cancellazione o force push, ma non impone l'auto-approvazione impossibile di un unico maintainer.

Il profilo `team` aggiunge un'approvazione indipendente, revisione CODEOWNERS e approvazione dell'ultimo push. Prima di usarlo creare e revisionare l'ownership reale:

```sh
make github-codeowners OWNER=@OWNER_O_TEAM
```

## 3. Anteprima e applicazione

L'anteprima è sempre priva di modifiche remote:

```sh
make github-plan REPO=OWNER/GlifiStudio PROFILE=solo
```

L'applicazione richiede il flag esplicito incapsulato dal target seguente e rifiuta repository pubblici, archiviati o privi di `main`:

```sh
make github-apply REPO=OWNER/GlifiStudio PROFILE=solo
```

La procedura configura funzionalità, merge, topic, etichette, Actions, Dependabot e ruleset. È idempotente: una seconda esecuzione aggiorna la configurazione con lo stesso nome invece di duplicarla.

## 4. Audit

Eseguire dopo ogni variazione amministrativa e almeno a ogni riesame trimestrale degli accessi:

```sh
make github-audit REPO=OWNER/GlifiStudio PROFILE=solo
```

L'audit confronta il remote con `Config/GitHub/`, incluse visibilità, branch, funzionalità, strategie di merge, topic, permessi Actions, SHA pinning, etichette, Dependabot e ruleset.

## 5. Controllo finale

Aprire una pull request di prova, osservare `verify` e `app-store-baseline`, provare
che il fallimento di ciascuno blocchi il merge, correggerlo e completare uno squash
merge. Verificare poi cancellazione del branch, storia lineare e assenza di privilegi
di scrittura nel token dei workflow.

Secret scanning, push protection, code scanning e alcune ruleset per repository privati dipendono dal tipo di proprietario e dal piano. La procedura abilita le funzioni disponibili e dichiara quelle indisponibili; una funzione non disponibile resta un rischio esplicito coperto dai controlli locali, non un controllo fittiziamente superato.

## Ripristino da applicazione parziale

Ogni passaggio è ripetibile. Se GitHub rifiuta una funzione per piano o policy dell'organizzazione, non aggirare il controllo: conservare l'errore senza token, correggere prerequisito o profilo e rieseguire. L'audit finale identifica qualunque impostazione rimasta divergente.

## Riferimenti

- [Creazione di un repository con GitHub CLI](https://cli.github.com/manual/gh_repo_create)
- [REST API per le ruleset](https://docs.github.com/en/rest/repos/rules)
- [REST API per i permessi Actions](https://docs.github.com/en/rest/actions/permissions)
- [Gestione delle funzioni di sicurezza](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-security-and-analysis-settings-for-your-repository)
