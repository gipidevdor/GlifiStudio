<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-116 — MTLD-bidirectional-v1

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-116 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task Q2 di GS-DOR-003 |

## Ambito

Completa RF-027 con `MTLD-bidirectional-v1` di GS-MET-001-04 (McCarthy e Jarvis, 2010):

- `GlifiMTLD.measure`: fattore chiuso quando il TTR corrente diventa `≤ τ`, fattore parziale
  `(1 − TTR_coda)/(1 − τ)` sulla coda, valore direzionale `N/fattori`, `+∞` con zero fattori,
  media delle direzioni originale e invertita con la regola IEEE (`+∞` se una direzione è `+∞`);
  sequenza vuota non definita; `τ ∉ (0, 1)` rifiutata con `diversity.invalid-threshold`;
- `GlifiExtendedNonNegative`: `+∞` codificato in JSON come `"+Infinity"`, perché JSON non ammette
  infiniti; ogni altro marcatore o valore negativo o non finito è rifiutato in decodifica;
- Artifact `corpus-lexical-diversity-mtld-v1` per documento e sulla sequenza concatenata
  nell'ordine canonico delle revisioni (`source-revision-order-concatenation-v1`, la stessa politica
  di MSTTR e MATTR), con la mappatura token→type del profilo corpus (`it-token-v1`, NFC, minuscole
  italiane). È un nodo separato dal profilo: aggiungere MTLD al profilo avrebbe cambiato schema e
  identità di tutti gli Artifact a valle;
- `analyzeLexicalDiversity` in GlifiKit e `glifi diversity [--threshold τ]`.

## Procedura e risultato

1. `mtldMatchesR`: su un caso a mano di 16 token (direzioni 5,333… e 5,530…, media 5,432…), con
   `τ = 0,5`, su 200 token pseudo-casuali e su una sequenza costante, i valori coincidono entro
   `1e-12` relativo con l'implementazione indipendente di `Tests/Oracles/R/diversity.R`;
2. `mtldEdgeCasesAndEncoding`: tutti token distinti danno `+∞`; sequenza vuota `nil`; soglie
   `0`, `1`, negative e NaN rifiutate; round-trip JSON con `"+Infinity"` e rifiuto di `"Infinity"`;
3. `lexicalDiversityIsPersistedAndReused`: riuso per get-or-store; maiuscole e punteggiatura
   trattate come nel profilo; documento senza token lessicali non definito; soglia 1 rifiutata;
4. contract test CLI in `verify.sh` per `glifi diversity`.

## Limiti

L'oracolo R è un'implementazione indipendente della definizione normativa, non un pacchetto di
terze parti; la soglia `0,72` resta il valore candidato di GS-MET-001-04. MTLD non è indipendente da
genere, ordine e preprocessing.

## Esito

**Superato localmente: RF-027 è completo per le varianti di GS-MET-001-04.**
