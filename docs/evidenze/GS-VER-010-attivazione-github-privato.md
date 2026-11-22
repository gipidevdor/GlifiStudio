# GS-VER-010 — Attivazione del repository GitHub privato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-010 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato con limitazioni del provider |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata sul remote |

## Ambito

Creazione, primo push, applicazione del profilo `solo` e audit del repository
[`gpicchiarelli/GlifiStudio`](https://github.com/gpicchiarelli/GlifiStudio).

## Procedura e risultato

- preflight `make verify-app-store`: superato localmente;
- primo commit `a416611203dd10e19b2d56e19c4619b31ed1fe74` su `main`;
- repository creato con visibilità `PRIVATE` e remote `origin` via HTTPS;
- configurazione applicata con `make github-apply ... PROFILE=solo`;
- audit finale `make github-audit ... PROFILE=solo`: stato zero;
- merge solo squash, aggiornamento branch e cancellazione post-merge configurati;
- Actions limitate a componenti GitHub, SHA obbligatori e token in sola lettura;
- Dependabot alerts e aggiornamenti automatici di sicurezza abilitati;
- catalogo remoto normalizzato alle 20 etichette dichiarate;
- Dependabot ha aperto la PR #1, lasciata intenzionalmente non integrata.

## Limitazioni osservate

Il piano GitHub dell'account non abilita ruleset su repository privato, auto-merge
dipendente dalla protezione, Secret Scanning o push protection. I profili restano
versionati e l'audit li segnala come non disponibili, non come controlli superati.

I job `verify` e `app-store-baseline` sono stati creati, ma GitHub non ha avviato
alcuno step perché un budget Actions impedisce ulteriore utilizzo. I run risultano
quindi rossi per infrastruttura, non per un test del progetto. Il runner
`xcode-27` non viene sostituito con una toolchain più vecchia.

## Esito e limiti

**Superato con limitazioni del provider.** Repository, commit, visibilità e
configurazione disponibile sono verificati. Restano bloccati: protezione server-side
di `main`, Secret Scanning/push protection, esecuzione CI e prova di ripristino del
backup. Per completarli servono piano/budget GitHub idonei o una futura decisione
approvata su infrastruttura alternativa.
