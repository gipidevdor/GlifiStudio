<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-088 — Cohen's Kappa e Krippendorff's Alpha nominale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-088 |
| Tipo | Evidenza di verifica inferenziale e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza osservata parziale di TV-008 e TV-034 |

## Ambito

- `GlifiAgreementAnalysis.cohenKappa`: `CohenKappaNominal-v1` per due
  codificatori sulle stesse unità, una sola categoria nominale per unità,
  indefinito quando `p_e=1`;
- `GlifiAgreementAnalysis.krippendorffAlphaNominal`: `KrippendorffAlpha-v1`
  con funzione di disaccordo nominale (`δ²=0` se le categorie coincidono,
  altrimenti `1`), matrice delle coincidenze, esclusione esplicita delle
  unità con meno di due giudizi non mancanti, indefinito quando `D_e=0`;
- mancanti espliciti (`nil`) ammessi in Krippendorff, mai in Cohen (le due
  liste devono avere la stessa lunghezza).

## Procedura

1. verificare Cohen's Kappa sull'accordo perfetto (`κ=1`, calcolato da
   `p_o=1` e `p_e=13/25=0,52` per frazione esatta) e sull'accordo al livello
   del caso (`κ=0`, `p_o=p_e=0,5`);
2. verificare che `p_e=1` (nessuna variabilità fra le categorie osservate)
   sia rifiutato invece di produrre un κ fuori dominio;
3. verificare Krippendorff's Alpha su due unità con accordo perfetto interno
   ma categorie diverse fra unità: `D_o=0` esatto e `α=1` per calcolo
   indipendente sulla formula dichiarata (`D_e=0,6` calcolato a mano);
4. verificare che una singola categoria ovunque (`D_e=0`) sia rifiutata
   invece di produrre un alpha fuori dominio;
5. verificare che le unità con un solo giudizio non mancante siano escluse
   dal conteggio (`includedUnitCount`) senza alterare il risultato sulle
   unità qualificate;
6. verificare failure tipizzate per liste disallineate e assenza di unità
   qualificate.

## Risultato osservato

- Cohen's Kappa coincide entro `1e-9` con i valori calcolati
  indipendentemente sui due casi a forma chiusa;
- `p_e=1` è rifiutato con `agreement.kappa-undefined`;
- Krippendorff's Alpha sul caso di accordo perfetto produce `α=1` entro
  `1e-9`, con `D_o` esattamente zero;
- una sola categoria ovunque è rifiutata con `agreement.alpha-undefined`;
- le unità con un solo giudizio non mancante sono escluse correttamente
  dal conteggio delle unità incluse;
- input disallineati o privi di unità qualificate sono rifiutati con
  `GlifiFailure` tipizzata senza produrre un risultato parziale.

## Limiti

Questa evidenza copre soltanto il calcolo bounded in memoria su liste/matrici
fornite direttamente dal chiamante. Non prova codebook, categorie
gerarchiche, codifiche persistite con autore/tempo/versione, tre o più
codificatori per Cohen (fuori dominio per costruzione), livelli ordinali o
d'intervallo per Krippendorff, intervalli d'incertezza, persistenza in
Artifact/DAG, wiring Kit/CLI o un dataset gold per la review scientifica
esterna.

## Esito

**Superato localmente per `CohenKappaNominal-v1` e `KrippendorffAlpha-v1`
(nominale) in GlifiCore.** Non promuove RF-044 a feature complete né sostituisce
la review scientifica esterna.
