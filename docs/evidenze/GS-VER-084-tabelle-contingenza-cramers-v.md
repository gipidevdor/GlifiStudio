<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-084 — Tabelle di contingenza, χ² RxC e Cramér's V

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-084 |
| Tipo | Evidenza di verifica inferenziale e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza osservata parziale di TV-008 e TV-031 |

## Ambito

- `GlifiContingencyTable` I×J con margini/totale derivati e validazione di
  forma e non negatività dei conteggi;
- `PearsonChiSquareRxC-v1` con esclusione esplicita di righe/colonne a margine
  zero e gradi di libertà ricalcolati sulle sole dimensioni incluse;
- `CramersV-v1` come effect size non direzionale;
- residuo grezzo, Pearson e standardizzato per cella, con `nil` esplicito dove
  il denominatore standardizzato non è positivo o la riga/colonna è esclusa;
- p-value asintotico tramite funzione gamma incompleta superiore regolarizzata
  (serie di Numerical Recipes per `x < a+1`, frazione continua altrove,
  approssimazione di Lanczos per `logΓ`), non solo il caso `df=1` già coperto
  dalla forma chiusa `erfc` del keyness.

## Procedura

1. costruire una tabella 2×3 con margini interi tondi (righe 40/60, colonne
   30/30/40, n=100) tale che le attese siano intere e χ² sia calcolabile per
   frazioni esatte senza dipendere dal codice in prova;
2. confrontare `chiSquareStatistic` con `475/36` esatto e `cramersV` con
   `sqrt(χ²/100)`;
3. confrontare `pValue` a `df=2` con la forma chiusa `exp(-χ²/2)`, valida solo
   per due gradi di libertà, indipendente dall'implementazione della gamma
   incompleta in prova;
4. su una tabella 2×2 distinta, confrontare `pValue` a `df=1` con
   `erfc(sqrt(χ²/2))`, la stessa identità già impiegata da
   [GS-VER-023](GS-VER-023-keyness-gtest-bh.md);
5. verificare l'esclusione di una riga e una colonna a margine zero da gradi di
   libertà, χ² e residui;
6. verificare simmetria degli scalari (χ², df, p, V) rispetto alla
   trasposizione della tabella;
7. verificare failure tipizzate per dimensioni vuote, forma incoerente,
   conteggi negativi, totale degenere e dimensioni insufficienti dopo
   l'esclusione.

## Risultato osservato

- χ², p-value a `df=2` e Cramér's V coincidono entro `1e-9` con i valori
  calcolati indipendentemente per forma chiusa/frazione esatta;
- il p-value a `df=1` prodotto dalla gamma incompleta generale coincide entro
  `1e-9` con la forma chiusa `erfc` già in produzione nel keyness, incrociando
  le due implementazioni;
- righe/colonne a margine zero sono escluse da gradi di libertà e residui
  senza propagare `NaN` o valori fuori dominio;
- gli scalari restano invarianti per trasposizione;
- input non validi sono rifiutati con `GlifiFailure` tipizzata senza calcolare
  risultati parziali.

## Limiti

Questa evidenza copre soltanto il calcolo bounded in memoria. Non prova
persistenza in AnalysisDescriptor/DAG/Artifact, esposizione via GlifiKit/CLI,
provenienza delle unità contribuenti per cella, Fisher/Monte Carlo RxC oltre
2×2, Correspondence Analysis (GS-MET-001-10) o UI. Wiring e persistenza restano
un incremento successivo, sullo stesso modello con cui GS-VER-026 ha assunto
GS-VER-023.

## Esito

**Superato localmente per `PearsonChiSquareRxC-v1` e `CramersV-v1` in
GlifiCore.** Non promuove RF-032 a feature complete né sostituisce Fisher/CI o
la review scientifica esterna.
