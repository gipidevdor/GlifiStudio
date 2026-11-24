<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-135 — Messaggi leggibili per ogni failure mostrata

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-135 |
| Tipo | Evidenza di correzione di difetto |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | GS-API-001 § 8; GS-UX-001-14 |

## Difetto

Le app mostravano la failure con `Text(LocalizedStringKey(failure.messageKey))`. Quando la chiave
non è nel catalogo, SwiftUI stampa la chiave stessa: l'utente leggeva
`failure.project.io-failed` al posto di una spiegazione. La misura del catalogo ha trovato 320
chiavi di failure prive di messaggio su circa 345 emesse dal motore, comprese quelle di
importazione, I/O, autorizzazione e corruzione, cioè proprio i casi che l'utente incontra quando
qualcosa va storto.

## Correzione

- **Ripiego per categoria**: ogni `GlifiFailureCategory` ha un messaggio in italiano e inglese. Se
  un codice non ha un messaggio proprio, l'interfaccia mostra quello della categoria, che resta
  vero per ogni codice della stessa classe. L'identificatore grezzo resta solo nel dettaglio
  diagnostico, accanto a `code`, `category` e `operation`, dove è utile a chi segnala un problema.
- **Chiavi di GlifiKit tradotte**: le 13 chiavi emesse dal confine applicativo che ne erano prive
  (sessione chiusa, limite di operazioni, export delle viste, identificatori di fonte non validi,
  varianti di analisi sconosciute) hanno ora un messaggio proprio.
- **Controllo nel gate**: `check-failure-messages.py` verifica che ogni categoria abbia il proprio
  messaggio in entrambe le lingue, che ogni `messageKey` letterale di GlifiKit sia tradotto e che
  le app risolvano il messaggio con il ripiego invece di stampare la chiave. Il controllo fallisce
  se qualcuno reintroduce `LocalizedStringKey(failure.messageKey)`.

## Procedura e risultato

1. `make check-failure-messages`: 11 categorie con ripiego, 17 chiavi di GlifiKit localizzate;
2. 24 nuove stringhe in italiano e inglese nel catalogo, controllate anche da
   `check-localization.py`;
3. build Xcode macOS e iPadOS verdi; `make verify` completo verde.

## Limiti

I codici interni di GlifiCore non hanno un messaggio proprio: ricadono sulla categoria. È una
scelta dichiarata, non una svista — undici messaggi veri valgono più di trecento frasi generiche —
ma significa che due difetti diversi della stessa categoria si presentano all'utente con lo stesso
testo. Assegnare un messaggio specifico ai codici che l'utente può effettivamente provocare
richiede una revisione caso per caso, non ancora fatta. Nessuna validazione con utenti sulla
comprensibilità dei testi.

## Esito

**Superato localmente: nessuna failure mostra più un identificatore grezzo all'utente, e il gate
impedisce di reintrodurre il difetto.**
