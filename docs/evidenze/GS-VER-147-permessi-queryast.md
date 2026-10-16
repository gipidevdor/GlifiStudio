<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-147 — Permessi dell'ingresso QueryAST

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-147 |
| Tipo | Evidenza di regressione headless |
| Versione | 1.0.0 |
| Stato | Parziale; statici superati, verifica nativa pendente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-16 |
| Approvazione | Correzione del contratto GS-DOR-012; verifica pendente |
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
l'evidenza richiesta per la verifica dinamica. Il test di permessi induce
`EACCES`; non induce separatamente un errore `EPERM` da sandbox/ACL né una
revoca concorrente durante `fstat` o lettura. Nessuna deroga ai gate.

## Recupero

Revert del commit senza migrazione. La regressione del test ricorsivo QueryAST
è già corretta separatamente da PR #17 e non viene duplicata qui.
