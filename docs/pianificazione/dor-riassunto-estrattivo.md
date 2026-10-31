<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Riassunto estrattivo deterministico (GS-MET-001-19)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-013 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.1.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-16 |
| Approvazione | Richiesta dell'iniziatore di proseguire lo sviluppo; prima slice verificata (GS-VER-146), seconda slice in verifica (GS-VER-149) |
| Riferimenti | GS-MET-001-19; GS-MET-001-07; GS-API-001 § 9; RF-042; RQ-025; RQ-027; TV-036; ADR-0013 |

## Confini e criteri di accettazione

**Ready** per l'implementazione, non per la chiusura della verifica.

| Voce | Evidenza |
| --- | --- |
| outcome e confini | Due famiglie sullo stesso Artifact, `SentenceTFIDFMean-v1` e `CentroidCosine-v1`, scelte con `method`, con budget in frasi o token; nessuna generazione di testo, nessuna ridondanza, nessun modello linguistico |
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
- Seconda slice (`CentroidCosine-v1`): metodo come parametro del descrittore, vettore frase e
  centroide fissati in GS-MET-001-19 prima del codice, flag `isEligible` persistito per frase
  con decodifica dei payload precedenti, oracolo esteso con righe `CENTROID_*`, `--method` in
  CLI; nessuna migrazione.

## Verifica e tracciabilità

Controlli statici e formattazione sulla macchina di sviluppo; compilazione, test e
`make verify` sul runner `xcode-27` tramite il workflow `Verifica`. Risultati e limiti
sono registrati in [GS-VER-146](../evidenze/GS-VER-146-riassunto-estrattivo.md) (prima
slice, superata sul runner remoto, CMP-096 `verified`) e in
[GS-VER-149](../evidenze/GS-VER-149-riassunto-centroide.md) (seconda slice, CMP-097
`implemented` finché il gate remoto non la promuove), nella matrice di tracciabilità (RF-042,
TV-036). Nessuna nuova decisione architetturale: la variante era
già candidata in GS-MET-001-19.

## Rischi e recupero

Il segmentatore di frasi è quello del contratto linguistico italiano: errori di confine si
riflettono nel riassunto e sono misurati da GS-VER-137/138, non qui. Con un solo documento
l'IDF liscio resta definito; con `IDF-unsmoothed-v1` i punteggi sono tutti nulli: la media
TF-IDF seleziona per posizione, il centroide esclude ogni frase come vettore nullo
(`isEligible = false`), comportamenti dichiarati e non corretti in silenzio. Rollback
tramite revert; nessuna migrazione dei package.
