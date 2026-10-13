<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Riassunto estrattivo deterministico (GS-MET-001-19)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-013 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-03 |
| Approvazione | Richiesta dell'iniziatore di proseguire lo sviluppo; review della PR pendente |
| Riferimenti | GS-MET-001-19; GS-MET-001-07; GS-API-001 § 9; RF-042; RQ-025; RQ-027; TV-036; ADR-0013 |

## Confini e criteri di accettazione

**Ready** per l'implementazione, non per la chiusura della verifica.

| Voce | Evidenza |
| --- | --- |
| outcome e confini | Una sola famiglia, `SentenceTFIDFMean-v1`, con budget in frasi o token; nessuna generazione di testo, nessuna ridondanza, nessun modello linguistico |
| failure semantics | Budget non valido, gruppo vuoto o fonte duplicata: `invalidInput`/`insufficientData` con codici `summary.*` tipizzati; intervallo non risolvibile: `invariantViolation` |

- Fissare in GS-MET-001-19 unità, token inclusi, pesi, rank, budget, eleggibilità,
  ridondanza e ordine di output della variante, prima del codice.
- Primitiva pura in GlifiCore sulle frasi del tokenizzatore italiano con pesi
  GS-MET-001-07 dichiarati; Artifact `corpus-extractive-summary-v1` con descrittore completo
  e riuso get-or-store; l'Artifact conserva intervalli, non testo.
- Mirror in GlifiKit (`analyzeExtractiveSummary`, con testo risolto delle frasi scelte) e
  CLI (`glifi summarize`), con parità dei parametri e delle failure.
- Oracolo indipendente in Python, `expected.txt`, test Swift su oracolo, casi limite e
  persistenza, contract test CLI in `verify.sh`.
- Nessuna dipendenza, rete, telemetria o formato persistente alternativo.

## Verifica e tracciabilità

Controlli statici e formattazione sulla macchina di sviluppo; compilazione, test e
`make verify` sul runner `xcode-27` tramite il workflow `Verifica`. Risultati e limiti
sono registrati in [GS-VER-144](../evidenze/GS-VER-144-riassunto-estrattivo.md), nella
matrice di tracciabilità (RF-042, TV-036) e in CMP-096, che resta `implemented` finché la
review non promuove l'evidenza. Nessuna nuova decisione architetturale: la variante era
già candidata in GS-MET-001-19.

## Rischi e recupero

Il segmentatore di frasi è quello del contratto linguistico italiano: errori di confine si
riflettono nel riassunto e sono misurati da GS-VER-137/138, non qui. Con un solo documento
l'IDF liscio resta definito; con `IDF-unsmoothed-v1` i punteggi sono tutti nulli e la
selezione segue la posizione, comportamento dichiarato e non corretto in silenzio. Rollback
tramite revert; nessuna migrazione dei package.
