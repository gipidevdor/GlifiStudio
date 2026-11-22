<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-301 — Integrazione della baseline e sincronizzazione Git

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-301 |
| Tipo | Evidenza di integrazione e verifica |
| Versione | 1.0.0 |
| Stato | In verifica |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di commit, push, integrazione in main, eliminazione dei branch e allineamento remoto |

## Perimetro salvato

L'integrazione conserva il lavoro della copia principale, la baseline remota
`b5b0097`, i due checkpoint GUI e il completamento KH fino al commit `32b06f7`.
Le correzioni numeriche, i limiti, le identità canoniche e il refactoring remoti
sono mantenuti insieme alla GUI più recente e ai contratti CLI/Kit condivisi.
I checkpoint GUI precedenti sono conservati come antenati senza ripristinare
versioni di codice o documenti superate: questa topologia ha valore di recupero
e giustifica l'eccezione al normale squash prevista da GS-REP-002.

I riferimenti GUI sono consolidati nei documenti GS-VER-273/274 e GS-DOR-273/274;
GS-VER-234 continua a identificare la distinta riverifica di correttezza. Le
evidenze storiche restano limitate ai rispettivi checkpoint.

L'utente ha esplicitamente scelto di pubblicare lo snapshot salvato e conservare
separatamente il lavoro KH successivo ancora in corso. Quel worktree e i suoi
file sono preservati; le modifiche successive a `32b06f7` non sono presentate
come incluse o verificate da questa pubblicazione.

## Contratti e verifica

La risoluzione mantiene il trasporto dei limiti graph e i DTO completi di
profilo. Il controllo di parità espande anche le richieste KH annidate e
confronta i casi del compilatore con le fixture senza conteggi fissi. Lo
snapshot contiene 54 fixture per 36 tag testuali, inclusi 15 profili KH;
l'inventario pubblico aggiornato comprende 2.753 dichiarazioni.

Compilazione CLI, controlli statici e risoluzione dei collegamenti documentali
sono superati. Il gate conclusivo `make verify` viene eseguito prima della
pubblicazione su `main`; esiti e limiti saranno registrati qui al termine.

## Pubblicazione e conservazione

GitHub ha rifiutato il primo push per la protezione dell'email privata. Soltanto
i commit nuovi non pubblicati sono stati ricreati con l'indirizzo pubblico
`noreply` dell'account; nessun force push o riscrittura remota.

I branch remoti storici sono rimossi dopo la prova di inclusione in
`origin/main`. Il branch temporaneo di integrazione è rimosso dopo il push della
baseline finale. I worktree utili restano disponibili in stato detached;
cache e temporanei della presente verifica vengono rimossi al termine.
