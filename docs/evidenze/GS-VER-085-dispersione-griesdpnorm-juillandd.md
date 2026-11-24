<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-085 — GriesDPnorm e Juilland D su partizione esplicita

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-085 |
| Tipo | Evidenza di verifica inferenziale e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza osservata parziale di TV-008 e TV-029 |

## Ambito

- `GlifiDispersionPartition` con `K` unità, dimensioni `n_i` e frequenze `f_i`
  esplicite, validate per forma e non negatività;
- `GriesDPnorm-v1` normalizzato sul massimo attingibile dalla stessa
  partizione, distinto dal valore grezzo `GriesDP-v1` già verificato in
  [GS-VER-022](GS-VER-022-profilo-corpus-riproducibile.md);
- `JuillandD-equal-v1`, definito soltanto per `K≥2` parti di uguale dimensione
  e `F>0`, mai applicato a partizioni diseguali sotto questo identificatore;
- valori non definiti (`F=0` o `N=0`) rifiutati con failure tipizzata invece di
  un risultato pari a zero.

## Procedura

1. verificare `GriesDP-v1=0` e `GriesDPnorm-v1=0` su una partizione
   proporzionale all'opportunità (`f_i` proporzionale a `n_i`), come richiesto
   esplicitamente dalla sezione Verifica di GS-MET-001-12;
2. verificare concentrazione massima su tre parti di uguale dimensione: valori
   attesi `DP=2/3`, `norma=1` e `D=0` calcolati indipendentemente per frazioni
   esatte e forma chiusa (`sd/mean = sqrt(K-1)` in questo caso particolare);
3. verificare che una partizione a dimensioni diseguali non riporti mai
   Juilland D, indipendentemente dalle frequenze;
4. verificare che una singola unità (`K=1`) calcoli comunque `GriesDP-v1` ma
   ometta norma e Juilland D;
5. verificare failure tipizzate per `F=0`, partizione vuota, forma incoerente
   e conteggi negativi.

## Risultato osservato

- `GriesDP-v1` e `GriesDPnorm-v1` sono entrambi zero entro `1e-12` sul caso
  proporzionale;
- sul caso di concentrazione massima, `DP`, norma e Juilland D coincidono
  entro `1e-9` con i valori calcolati indipendentemente;
- Juilland D è sempre assente per partizioni a dimensioni diseguali, anche
  quando le frequenze sarebbero altrimenti compatibili con un valore definito;
- `K=1` calcola `GriesDP-v1` ma omette esplicitamente norma e Juilland D
  anziché produrre un valore fuori dominio;
- input non validi sono rifiutati con `GlifiFailure` tipizzata senza produrre
  un risultato parziale.

## Limiti

Questa evidenza copre soltanto il calcolo bounded in memoria su una partizione
esplicita fornita dal chiamante. Non prova il wiring al profilo corpus
persistito, ad altre partizioni (temporale, per autore, per categoria), un
dispersion plot, persistenza in Artifact/DAG, esposizione via GlifiKit/CLI o
corpus gold. `GriesDP-v1` grezzo resta quello già verificato e persistito da
GS-VER-022/026; questa evidenza aggiunge solo le due misure mancanti come
primitiva riusabile indipendente.

## Esito

**Superato localmente per `GriesDPnorm-v1` e `JuillandD-equal-v1` in
GlifiCore.** Non promuove RF-035 a feature complete né sostituisce fixture con
permutazione delle unità o review scientifica esterna.
