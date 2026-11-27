<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-334 — Cucumber nel ciclo di sviluppo

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-334 |
| Tipo | Verifica del loop BDD |
| Versione | 1.0.0 |
| Stato | Superato nel profilo automatico macOS; audit interattivo distinto |
| Responsabile | Codex con revisione separata degli ingressi |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di usare Cucumber anche durante lo sviluppo |
| Riferimenti | GS-DOR-334; GS-BDD-001; GS-DEV-002; CMP-334; ADR-0046 |

## Comportamento verificato

`make test-bdd-list` elenca feature e righe espanse dall'inventario controllato,
senza build né cache. `make test-bdd-dev BDD_SELECT='TextQuery.feature:20'`
seleziona uno scenario; un nome privo di riga seleziona l'intera feature.
Più selezioni separate da virgola formano un'unione. Il comando verifica
esattamente il sottoinsieme: omissioni, scenari aggiunti, vuoti e passi non
superati falliscono. Il profilo completo continua a richiedere tutti gli esempi.

La regressione permanente su Make reale riproduce anche l’espansione di una
macro nel selettore. `unexport BDD_SELECT` e l’assegnazione semplice con
`$(value BDD_SELECT)` mantengono il dato letterale; ciascuna misura da sola
non basta. Il RED crea il marker sintetico; dopo il fix i 16 controlli passano,
Swift e cache non vengono raggiunti e uno scenario Cucumber reale resta verde.

La selezione passa al trasporto `CUCUMBER_SCENARIOS` upstream, con gli escape
`%25` e `%2C` previsti dal parser pinned; non si aggiunge un parser Gherkin o
una grammatica di tag. I filtri ambientali sono sostituiti soltanto nel comando
mirato. Il valore Make è esportato come dato, senza interpolazione shell.
Gli argomenti non validi vengono respinti prima di allocare cache o invocare
Swift. `:` è riservato alla riga e non è ammesso nel nome di una feature.

## Prove mirate osservate

| Prova | Esito |
| --- | --- |
| Self-test del verificatore | Superato: selezioni esatte, unione, overlap, riga inesistente, extra/omessi, passi non superati e report parziale rifiutato dal gate completo |
| `TextQuery.feature:20` reale | Exit 0; uno scenario e sei passaggi |
| `TextQuery.feature` reale | Exit 0; 14 scenari e 92 passaggi, anche con filtri ambientali avversi |
| `AnalyticalMethods.feature:20,TextQuery.feature:20` reale | Exit 0; due scenari e 13 passaggi |
| Lista senza Swift/cache | Nessuna invocazione dello stub Swift e nessuna cache creata |
| Riga inesistente | Rifiutata prima di lock e cache |
| Valore Make con quote e payload shell | Trattato come dato non valido; nessun marker eseguito |
| Regressioni cache | 16 test superati |
| Shell e whitespace | `zsh -n` e diff check superati |

Il RED iniziale del nuovo selettore era l'assenza della funzione di selezione,
seguita dal GREEN dei controlli positivi e negativi. Non viene presentato come
difetto di dominio. Le correzioni reali della UI hanno RED nativi distinti in
[GS-VER-335](GS-VER-335-ricerca-contesto.md) e
[GS-VER-336](GS-VER-336-catalogo-stato-accessibile.md).

## Provenienza e limiti

Manifest, lockfile, inventario delle 8 feature/122 scenari/697 passaggi e
licenze sono invariati rispetto a GS-VER-332. Non entra codice di sviluppo nel
prodotto. Istruzioni agenti, GS-DEV-002 e GS-BDD-001 prescrivono esempi,
RED pertinente, GREEN e refactoring, con suite completa prima della consegna.

Il dossier locale `macOS-2026-11-27-bdd-ux` conserva log e risultati mirati.
Il gate finale è registrato nell'[allegato](allegati/GS-VER-334-verifica.json).
Nessuna selezione parziale attesta l'intera collezione, UI o accessibilità.

## Chiusura automatica macOS

Le regressioni native mirate sono verdi: 18 definizioni / 22 esecuzioni.
`make verify` è superato in **503,55 s** sulla fase immutabile precedente
`4ca2364b5295b759dacffaa131c37240578fec8a20ea36c34056dfbdba3c2484`.
Dopo il fix della macro Make e la normalizzazione del solo formato del catalogo
(con dati JSON identici), `make verify-app-store` è superato in **810,27 s**:
include nuovamente il gate completo, analisi e archivio macOS senza firma.
La suite comprende 782 definizioni Core, 169 Kit e 65 BDD; il report richiede
8 feature, 122 scenari e 697 passaggi. I nativi confermano 144 definizioni e
435 esecuzioni, senza failure o skip; i controlli cache sono 16.

I **609 input controllati** hanno fingerprint finale SHA-256
`5ea8f0cc9877bc94349db307cd2279654b50c6e2b9a99d3b4a42ee0627bb4c1a`,
immutato alla chiusura. Il log `make-verify-app-store.log` ha SHA-256
`cc6bfe43eceeaf582993ee30b354a969617b17b594b404fb18b144e2bf7f4ebb`.
Gli allegati distinguono la fase mirata, il primo gate e il preflight finale;
i manifest e i riepiloghi nativi sono nel dossier locale. Nessuna firma,
submission App Store, qualifica iPadOS o verifica assistiva manuale è attestata.
