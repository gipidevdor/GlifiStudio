<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-092 — Wiring persistente dei moduli matematici derivati (GlifiCore/Kit/CLI)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-092 |
| Tipo | Evidenza di verifica inferenziale, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-004, TV-011, TV-029, TV-031, TV-032, TV-034, TV-035, TV-054, TV-056 e TV-073 |

## Ambito

Estende lo schema di GS-VER-091 (analizzatore puro → descriptor/Artifact →
`GlifiEngine` get-or-store → `GlifiStudioService` → comando CLI) a tutte le
primitive bounded rimaste non wired: contingenza, dispersione, statistica,
accordo, collocazione, rete e le misure di distanza ancora escluse dalla
similarità. Per non duplicare boilerplate il wiring usa un pattern generico:

- `GlifiDerivedAnalysisResult` (protocollo), `GlifiDerivedAnalysisArtifactPayload<Value>`,
  `GlifiProjectDerivedResult<Value>` e `GlifiAnalysisArtifactDescriptorFactory.derived`
  con dipendenze esplicite verso l'Artifact di profilo corpus da cui il
  risultato è derivato; `GlifiEngine.derivedArtifact` applica la stessa
  politica get-or-store già verificata (stesso nodeID → riuso senza
  ricalcolo né nuova generazione);
- sorgente dati naturale: la matrice sparsa del profilo corpus già persistito
  (`rowSourceRevisionIDs`, `terms`, `cells`), da cui si derivano per documento
  conteggi di token, frequenze relative e presenza dei termini; per l'accordo
  fra codificatori la sorgente è una richiesta JSON esplicita;
- operazioni GlifiCore/Kit e comandi CLI (testo e JSON v1):

| Operazione | Identificatore | Comando CLI | Primitive collegate |
| --- | --- | --- | --- |
| `analyzeAssociation` | `corpus-document-term-association-v1` | `association` | `PearsonChiSquareRxC-v1`, `CramersV-v1`, residui (GS-VER-084) |
| `analyzeDispersion` | `corpus-term-dispersion-v1` | `dispersion` | `GriesDPnorm-v1`, `JuillandD-equal-v1` (GS-VER-085) |
| `compareGroupMetric` | `document-metric-group-comparison-v1` | `group-metric` | `WelchT-v1`, `OneWayANOVA-v1` (GS-VER-087) |
| `analyzeCollocations` | `corpus-document-collocation-v1` | `collocations` | `PMI-v1`, `NPMI-v1`, `Dice-v1`, `Jaccard-v1`, `t-score-v1`, `logDice-v1` (GS-VER-089) |
| `analyzeLexicalNetwork` | `corpus-document-cooccurrence-network-v1` | `network` | `Degree-v1`, `WeightedDegree-v1`, `PageRank-v1`, `Betweenness-v1`, `HarmonicCloseness-v1` (GS-VER-090) |
| `assessCodingAgreement` | `coding-agreement-nominal-v1` | `agreement` | `CohenKappaNominal-v1`, `KrippendorffAlpha-v1` (GS-VER-088) |
| `compareSimilarity` v2 | `corpus-term-similarity-v2` | `similarity` | aggiunge `Euclidean-v1`, `Manhattan-v1`, `Hellinger-v1`, `JSdiv-v1`, `JSdist-v1`, `KL-v1` (GS-VER-086) |

## Procedura

1. verificare ogni analizzatore su fixture minime con valori attesi derivati a
   mano in forma chiusa (test `GlifiCorpusDerivedAnalysesTests`); l'accordo
   sulla fixture a quattro unità e due codificatori riproduce `kappa = 0`
   e `alpha = 1/8` esatti;
2. verificare via GlifiKit (`serviceDerivesPersistedAnalyses`) che ogni
   operazione persista un Artifact, che la seconda chiamata riusi lo stesso
   `artifactID`/`generation` e che gli input non validi falliscano con
   failure tipizzate `GlifiStudioFailure`;
3. estendere `Scripts/verify.sh` con i sei nuovi comandi CLI sul progetto
   condiviso del contract test (dopo `similarity`, prima di `project info`),
   con doppia invocazione di `association` e `agreement` per provare il
   riuso senza avanzare la generazione;
4. eseguire il gate completo `Scripts/verify.sh` (formato, dialetto,
   architettura, test, contract CLI, build Xcode macOS e iPadOS).

## Risultato osservato

- tutti i 117 test GlifiCore e 12 test GlifiKit passano; le nuove primitive
  riproducono i valori chiusi attesi;
- il contract test CLI riproduce i numeri reali di generazione: dopo
  `similarity` (`generation=12`) i sei nuovi comandi avanzano da `13` a `18`
  (un Artifact ciascuno, i profili corpus sono riusati), con
  `artifactCount` finale `13`; la seconda invocazione di `association` e
  `agreement` riusa `artifactID` e `generation` senza avanzare;
- `PageRank` dei nodi del grafo somma a 1 entro `1e-9` sui dati reali del
  contract test;
- `Scripts/verify.sh` termina con exit 0 su tutto il gate, incluso il lint
  di formattazione, dopo la correzione delle violazioni preesistenti in
  `Apps/Shared/StudioHomeView.swift` e `StudioHomeModel.swift` (solo
  riformattazione, nessuna modifica semantica).

## Limiti

Non sono implementati i metodi che richiedono decomposizione a valori singolari
(CA, PCA, LSA, NMF, clustering) né altre famiglie statistiche (Pearson/Spearman,
Mann-Whitney/Wilcoxon, Kruskal-Wallis, bootstrap, permutation): manca
un oracolo di validazione indipendente. Le co-occorrenze sono a livello di
documento (contesto = documento), non a finestra sul testo; la rete non ha
soglie, componenti né lineage per arco; il codebook per l'accordo è un input
JSON esplicito, non ancora una struttura di dominio persistita. Wiring nel
planner (`compare.objects`) e nell'interfaccia macOS/iPadOS restano fuori
ambito.

## Esito

**Superato localmente per il wiring persistente e riusabile, con parità
GlifiCore/Kit/CLI, di associazione, dispersione, confronto di gruppo,
collocazioni, rete lessicale, accordo fra codificatori e similarità estesa.**
Non promuove a feature complete i requisiti coinvolti.
