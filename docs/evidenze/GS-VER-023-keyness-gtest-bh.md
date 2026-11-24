<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-023 — Keyness G-test ed effect size con BH

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-023 |
| Tipo | Evidenza di verifica inferenziale, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-008, TV-011, TV-031, TV-056, TV-064 e TV-073 |

## Ambito

- confronto token-based di due gruppi espliciti, non vuoti e disgiunti di
  `SourceRevisionID` appartenenti alla stessa generazione `.glifi` verificata;
- `GTest-v1`, p-value `ChiSquareSurvival-df1-erfc-v1`, `OddsRatio-HA-v1`,
  `LogRatio-HA-v1-base2` e `BenjaminiHochberg-v1` sull'intera famiglia;
- conservazione di frequenze, tassi, popolazioni, identità dei metodi, soglia
  diagnostica, minimo atteso, direzione, policy numerica e tolleranza;
- ordinamento deterministico, digest SHA-256 e limite applicato prima della
  materializzazione di oltre 100.000 ipotesi;
- failure tipizzate per gruppi vuoti, duplicati o sovrapposti, revisioni assenti,
  popolazioni senza token, margini degeneri e opzioni invalide;
- parità di contratto attraverso GlifiCore, GlifiKit e GlifiCLI `keyness` JSON v1.
- signpost locale `CompareKeyness` privo di contenuti, path e identificatori.

## Procedura

1. confrontare `casa casa mare` contro `casa città città` con revisioni fisse;
2. verificare G, p, q, odds ratio, log ratio, direzione e conteggio minimo atteso
   per `casa`, `città` e `mare` entro tolleranza assoluta `1e-12`;
3. ricalcolare G-test, funzione di sopravvivenza χ², effect size HA e procedura BH
   in Python senza importare GlifiCore;
4. ripetere il confronto e verificare identità completa, digest e ordinamento;
5. attraversare una generazione persistita e la superficie actor-isolated di
   GlifiKit senza esporre path o dettagli interni del package;
6. importare le fixture TXT/Markdown tramite CLI, ricavare gli ID dallo snapshot e
   verificare l'envelope `keyness` completo;
7. eseguire `make verify`, incluse entrambe le app in Debug e Release.

## Risultato osservato

- 53 test Swift complessivi superati: 47 GlifiCore e 6 GlifiKit;
- il sesto reference seed scientifico viene ricalcolato indipendentemente dal
  codice prodotto e coincide entro `1e-12`;
- p-value e q-value restano in `[0, 1]`, il segno dell'effect size determina la
  direzione e le celle attese basse sono dichiarate senza alterare il risultato;
- lo smoke JSON restituisce generazione, popolazioni, sette termini, identità dei
  metodi, diagnostica e digest per le fixture persistite;
- input invalidi non modificano l'ultima generazione committata;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

Questa evidenza isolava il risultato bounded in memoria e non provava persistenza
in AnalysisDescriptor/DAG/Artifact, intervalli di confidenza, selezione Fisher
pre-registrata, campioni grandi o sbilanciati, corpus gold, fuzzing, benchmark su
hardware reale, review scientifica esterna o UI comparativa accessibile. Il
diagnostico su celle attese non trasforma automaticamente il test scelto.
Persistenza e riuso sono acquisiti separatamente da
[GS-VER-026](GS-VER-026-analisi-persistenti-riusabili.md).

## Esito

**Superato localmente per `keyness-gtest-ha-bh-v1` attraverso GlifiCore,
GlifiKit e GlifiCLI.** Non promuove l'intero sistema inferenziale o il percorso
Must 0.1 a feature complete.
