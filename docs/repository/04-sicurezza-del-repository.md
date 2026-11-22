# Sicurezza del repository

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REP-004 |
| Tipo | Piano di controllo |
| Versione | 1.0.0 |
| Stato | Attivo |
| Responsabile | Responsabile sicurezza e privacy, da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline operativa richiesta dal promotore |

## Minacce considerate

La baseline tratta almeno furto di credenziali, account compromessi, dipendenze o azioni CI sostituite, workflow con privilegi eccessivi, esecuzione di codice non fidato, fuga di dati nei log, commit di materiale di firma, branch non protetti, fork e backup dimenticati, file di grandi dimensioni e symlink esterni.

## Controlli presenti

- `.gitignore` esclude stato locale, build, diagnostica, credenziali e firma.
- `Scripts/check-secrets.py` rileva file vietati e pattern ad alta confidenza senza stampare il valore.
- `Scripts/check-repository.py` controlla struttura, dimensione, collisioni di nome, symlink, permessi CI e SHA delle azioni.
- Il workflow usa token in sola lettura, checkout senza credenziali persistenti, timeout e cancellazione delle esecuzioni obsolete.
- Issue e pull request ricordano la minimizzazione dei dati.

Questi controlli riducono errori comuni, ma non sostituiscono un secret scanner completo, la protezione lato server o una revisione umana.

## Regole operative

Autenticazione a più fattori e passkey sono richieste per gli account con accesso. I token personali devono essere granulari, avere scadenza breve e non essere usati quando GitHub App o token effimeri sono sufficienti. Nessun workflow esegue codice di pull request privilegiato tramite `pull_request_target`.

Le dipendenze CI sono trattate come codice eseguibile. L'aggiornamento automatico apre una pull request, ma non autorizza l'integrazione: changelog, provenienza e differenze rilevanti vanno revisionati.

## Incidenti

In caso di segreto esposto: revocarlo o ruotarlo immediatamente, preservare le evidenze necessarie, valutare log e fork, rimuovere il valore dall'uso corrente e analizzare la cronologia. Riscrivere la storia non annulla l'esposizione e richiede una decisione coordinata. Le segnalazioni seguono [SECURITY.md](../../SECURITY.md).
