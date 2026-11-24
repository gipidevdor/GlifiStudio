<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-103 — Accordo per livelli di misura, Fleiss, Fisher esatto e χ² Monte Carlo

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-103 |
| Tipo | Evidenza di verifica con oracolo esterno, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-031, TV-034, TV-054, TV-056 e TV-073 |

## Ambito

Supera i limiti di GS-VER-084 (Fisher/Monte Carlo oltre 2×2) e GS-VER-088 (livelli ordinali e a
intervallo, tre o più codificatori, intervalli d'incertezza):

- `KrippendorffAlpha-v2` per livello dichiarato (`nominal`, `ordinal`, `interval`, `ratio`) sulla
  matrice di coincidenze con la funzione `δ²` del livello;
- `FleissKappa-v1` per codifiche complete di `m ≥ 2` codificatori (Cohen resta fuori dominio oltre
  due codificatori, per costruzione);
- `AlphaUnitBootstrap-v1`: intervallo percentile di alpha ricampionando le unità con
  `SplitMix64-v1` e seed registrato;
- `FisherExact2x2-v1` (convenzione bilaterale di R: tabelle con probabilità non superiore
  all'osservata entro `1e-7` relativo) e `ChiSquareMonteCarlo-v1` (permutazione delle etichette
  di colonna delle singole osservazioni, uniforme sulle tabelle a margini fissati,
  `p = (1 + #{χ²* ≥ χ²})/(B + 1)`);
- `coding-agreement-v2`: livello dichiarato nella richiesta (etichette numeriche obbligatorie oltre
  il nominale), alpha per livello, intervallo bootstrap, Fleiss; `corpus-document-term-association-v2`:
  p Monte Carlo (B = 2 000, seed registrato) e Fisher quando la tabella inclusa è 2×2; parità
  GlifiKit e CLI (`agreement`, `association`).

## Procedura e risultato

1. Krippendorff su tre codificatori e dieci unità con giudizi mancanti, contro l'implementazione in
   R sulla matrice di coincidenze: nominale 0,675257731958763, intervallo 0,862104187946885, ordinale
   0,804860524091293 entro `1e-12`; il nominale coincide con l'implementazione esistente; valori
   negativi rifiutati al livello `ratio`; intervallo bootstrap riproducibile dal seed;
2. Fleiss su quattro unità e tre codificatori: κ 0,234042553191489, `P̄` ½, `P̄_e`
   0,347222222222222 entro `1e-12`;
3. `fisher.test`: `[[3,1],[1,3]]` bilaterale 0,485714285714286 e unilaterale 0,242857142857143;
   `[[8,1],[2,5]]` 0,0349650349650349; odds ratio campionario 20;
4. χ² Monte Carlo (20 000 tabelle) entro 0,02 dal p esatto a margini fissati `34/70` del 2×2
   bilanciato, riproducibile dal seed; margini nulli rifiutati;
5. GlifiKit: accordo a intervallo sugli stessi dati di R (0,862104187946885), Cohen indisponibile
   con tre codificatori, Fleiss indisponibile con giudizi mancanti, etichette non numeriche
   rifiutate al livello ordinale; associazione con p Monte Carlo; `Scripts/verify.sh` verifica
   livello, Fleiss = 0 con due codificatori, intervallo ordinato, seed e numero di simulazioni; gate
   completo.

## Limiti

Il codebook (categorie gerarchiche, definizioni, versioni) e le codifiche persistite con autore e
tempo richiedono un modello di dominio dedicato (RF-043) non ancora presente: la richiesta di
accordo resta una tabella JSON esplicita. La provenienza per cella dell'associazione identifica
documento e termine di ogni residuo, non le singole occorrenze.

## Esito

**Superato localmente, con oracolo R, per alpha per livello, Fleiss, bootstrap di alpha, Fisher
esatto e χ² Monte Carlo, persistiti con parità GlifiCore/Kit/CLI.**
