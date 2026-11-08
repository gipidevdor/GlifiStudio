<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-167 — Validazione dei costi del riassunto

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-167 |
| Tipo | Evidenza di regressione e robustezza |
| Versione | 1.0.0 |
| Stato | In verifica; preflight nativo locale da eseguire |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-14 |
| Approvazione | GS-DOR-013; richiesta dell'iniziatore di proseguire lo sviluppo |
| Riferimenti | GS-MET-001-19 1.5.1; GS-VER-165; RF-042; TV-036; CMP-164 |

## Difetti e correzione

Sulla base `4c59a50`, il conteggio pubblico `GlifiSummaryCandidateSentence.characterCount`
non era validato. Costi `[-1, 1, 1]` con limite 1 selezionavano tutte le frasi; costi
`[1, Int.max, 1]` causavano overflow nel confronto `consumato + costo ≤ limite` dopo la
prima scelta. Riproduzione su Swift 6.2/Linux x86_64 con il sorgente del summarizer
compilato in isolamento e tipi di dominio/pesi sostituiti: uscita normale nel primo caso,
trap SIGILL nel secondo. Non è un'esecuzione del package GlifiCore né un gate Apple.

Il Core ora rifiuta conteggi non positivi prima dello scoring con
`summary.invalid-character-count` (`invalidInput`), anche per candidate ineleggibili e per
le altre unità di budget. Il confronto `costo ≤ limite − consumato` protegge sia la scansione
per rank sia MMR; soltanto i costi accettati sono sommati. Nessuna variazione di formule,
parametri, descrittori, payload o risultati per input validi.

## Regressioni

- `summaryRejectsNonpositiveCharacterCounts`: `Int.min`, −1 e zero; con e senza token;
  tutte le unità, tutti i metodi e ridondanza assente/MMR con λ 0, 0,5 e 1; failure tipizzata
  e chiave di messaggio localizzata.
- `characterBudgetSkipsExtremeCostsWithoutOverflow`: costi `[1, Int.max, 1]`, limiti 1 e 2,
  tutti i metodi e le stesse politiche; la frase estrema è saltata e consumo/ordine restano
  nel budget dopo una prima selezione, anche quando il budget è già esaurito.

## Verifiche e limiti

Sulla VM Linux/Swift 6.2 passano `make quality-static`, `make check-failure-taxonomy`,
`make check-failure-messages`, `./Scripts/format.sh --check` e `git diff --check`.
Il sorgente corretto, compilato in isolamento con language mode 6 e strict concurrency
completa, rifiuta 216 combinazioni di costi non positivi e supera 24 combinazioni con
`Int.max`; 720 payload di input validi sono byte-identici alla base. Questi controlli
sostituiscono i tipi di dominio e i pesi: non verificano l'integrazione GlifiCore.

Il test mirato del package si arresta prima della compilazione: richiede Swift tools 6.4,
ma la VM dispone di 6.2. `make verify` e `make verify-app-store` terminano con codice 2
per l'opzione BSD `df -g`, assente su Linux; non è un esito delle asserzioni Swift.
I gate CI saranno registrati nella PR, separatamente dal preflight locale Apple ancora
necessario. La PR resta in bozza finché il preflight locale non è soddisfatto.

Il Core puro non possiede il testo per verificare che un conteggio positivo sia esatto;
il motore continua a ricavarlo dagli scalari dell'intervallo sorgente. Nessuna attestazione
di benchmark, accessibilità, PDF/A, firma o distribuzione. CMP-164, `verified` su `main`
`4c59a50` per GS-VER-165, torna `implemented`: `verified` richiede che ogni evidenza collegata
sia superata, e lo ridiventa con la registrazione della CI su `main` dopo il merge.
