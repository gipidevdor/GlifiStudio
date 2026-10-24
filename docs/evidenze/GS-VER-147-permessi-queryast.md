<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-147 — Permessi dell'ingresso QueryAST

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-147 |
| Tipo | Evidenza di regressione headless |
| Versione | 1.1.0 |
| Stato | Superato sul runner Xcode 27 con i limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-24 |
| Approvazione | Correzione del contratto GS-DOR-012; regressione G3 superata |
| Riferimenti | GS-VER-143; GS-DOR-012; GS-API-001; RF-080; RQ-044; RQ-046; TV-053; TV-060; CMP-081 |

## Ambito e correzione

La review di PR #15 ha rilevato che `query --ast` classificava `EACCES` e
`EPERM` come errori transitori. Ora apertura, `fstat` e lettura mappano entrambi
a `query.ast-unreadable`, categoria `authorizationDenied` e retry
`afterUserAction`. Gli altri errori I/O restano `transientIO` con
`transientBackoff`; `ELOOP` in apertura resta un file non regolare. L'exit code
resta 6 per entrambe le categorie, come richiesto dal protocollo CLI esistente.

La failure mantiene stato `lastCommittedGeneration`, operazione `query` e argomenti vuoti:
nessuna esposizione di percorso, contenuto o dettaglio POSIX. Nessuna modifica
al formato persistente, al modello AST o alle API pubbliche. Il contratto CLI
non dichiara più erroneamente indisponibile l'ingresso AST da file.

## Regressioni nel gate

`Scripts/check-query-ast.py` rende un file AST non leggibile con `chmod(0)`,
verifica categoria, retry, exit code e stato preservato, ripristina i permessi
in `finally` e ripete la query con esito positivo. Il percorso contiene il
canary già controllato su stdout/stderr. La prova richiede un utente non root
e fallisce esplicitamente se questa precondizione manca, senza saltare il test.
Il caso file mancante controlla che la tassonomia I/O transitoria resti invariata.

## Verifiche osservate e limiti

`make quality-static`, `make check-failure-taxonomy`, `make check-failure-messages`,
`Scripts/format.sh --check`, `git diff --check` e controllo sintattico Python
superati su Linux. `make verify` e `make verify-app-store` tentati: exit 2 sul
controllo disco `df -g`, opzione BSD non disponibile su GNU/Linux.
Questa VM Linux dispone di Swift 6.2, non di Apple Swift 6.4/macOS 27:
non può attestare build o test del prodotto. I gate Xcode 27 della PR sono
l'evidenza richiesta per la verifica dinamica.

Sulla revisione finale `f1e112ba5664a7a0bb56d7cb4884eb064b9779cb` di
[PR #18](https://github.com/gpicchiarelli/GlifiStudio/pull/18), `verify`
(job `117221998396`) e `app-store-baseline` (job `117221926507`) sono passati
su macOS 27.0.1, runner `xcode-27-arm64`, insieme a `static-quality` e
`format-check`. Entrambi i job nativi riportano 246 test Swift superati.
Il log del 2026-10-16 riporta esplicitamente
«QueryAST CLI: parità, limiti, file ostili, permessi, argomenti e privacy superati».
La validazione PDF/A è stata saltata dal gate per assenza di veraPDF; non viene
attestata. Il preflight App Store non attesta firma, pubblicazione o accettazione
dello store. Il riepilogo della parità G3 e la promozione di CMP-081 sono in
[GS-VER-143](GS-VER-143-ingresso-queryast.md).

Il test di permessi induce `EACCES`; non induce separatamente un errore `EPERM`
da sandbox/ACL né una revoca concorrente durante `fstat` o lettura. Nessuna deroga ai gate.

## Recupero

Revert del commit senza migrazione. La regressione del test ricorsivo QueryAST
è già corretta separatamente da PR #17 e non viene duplicata qui.
