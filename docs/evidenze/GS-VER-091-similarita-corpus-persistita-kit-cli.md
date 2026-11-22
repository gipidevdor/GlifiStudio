<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-091 — Similarità di corpus persistita con parità GlifiCore/Kit/CLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-091 |
| Tipo | Evidenza di verifica inferenziale, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-004, TV-011, TV-032, TV-054, TV-056 e TV-073 |

## Ambito

Prima verifica end-to-end che collega una delle primitive matematiche bounded
introdotte in questa sessione (GS-VER-086, `Cosine-v1`/`JaccardSet-v1`/
`DiceSet-v1`) al protocollo generazionale persistente e alle superfici
GlifiKit/GlifiCLI, seguendo esattamente lo stesso schema già verificato per
`keyness-gtest-ha-bh-v1` (GS-VER-023/026):

- `GlifiCorpusSimilarityAnalyzer.compare` (`corpus-term-similarity-v1`):
  costruisce il vocabolario unione ordinato di due profili corpus, allinea i
  vettori di frequenza relativa per `Cosine-v1` e le rispettive insiemi di
  termini presenti per `JaccardSet-v1`/`DiceSet-v1`; rifiuta un gruppo privo
  di termini invece di produrre un coseno fuori dominio;
- `GlifiAnalysisArtifactDescriptorFactory.corpusSimilarity` e
  `GlifiCorpusSimilarityArtifactPayload` (`studio.glifi.artifact.corpus-similarity.v1`):
  descriptor e payload canonici con dipendenze esplicite verso i due Artifact
  di profilo corpus già verificati;
- `GlifiEngine.compareSimilarity`: stessa politica get-or-store di
  `compareKeyness` — un nodeID già presente nello snapshot preparato viene
  riusato senza ricalcolo né nuova generazione;
- `GlifiStudioService.compareSimilarity` e `GlifiStudioCorpusSimilarityResult`
  (GlifiKit): stessa mappatura d'errore e stesso confine di visibilità del
  wrapper keyness, senza esporre tipi interni del motore;
- comando CLI `similarity <progetto.glifi> --target ... --reference ...`,
  testo e JSON v1, stesso schema di parsing di `keyness`.

## Procedura

1. verificare l'analizzatore puro su due corpus noti (`casa casa mare` /
   `casa città città`, la stessa fixture già usata per keyness): valori
   attesi calcolati indipendentemente dalla formula dichiarata — coseno
   `(2/9)/(5/9)=2/5=0,4` esatto, Jaccard `1/3`, Dice `0,5`;
2. verificare che due corpus identici producano similarità massima su ogni
   misura (`1,0`) e che un gruppo privo di termini sia rifiutato;
3. verificare via GlifiKit che lo stesso confronto persista un Artifact, che
   una seconda chiamata riusi lo stesso `artifactID`/`generation` senza
   ricalcolo, e che un identificatore non valido sia rifiutato con
   `corpus-similarity.invalid-source-identifier`;
4. estendere `Scripts/verify.sh` con due invocazioni CLI `similarity` sulle
   fixture condivise del contract test (dopo la storia dell'indagine, prima
   di `project info`, per non alterare i numeri di generazione già
   verificati altrove nello script) e verificare manualmente l'intera
   sequenza (`project create` → import ×2 → query ×2 → `analyze` → `keyness`
   → `plan`/`execute` ×2 → `investigation create`/`select` ×2 →
   `similarity` ×2 → `project info`) perché il gate `make verify` risulta
   bloccato da un problema di formattazione preesistente e non correlato in
   `Apps/Shared/StudioHomeView.swift`/`StudioHomeModel.swift`;
5. verificare che le app native (macOS Debug) continuino a compilare dopo la
   modifica di `GlifiEngine`/`GlifiKit` condivisi.

## Risultato osservato

- l'analizzatore puro riproduce `0,4`/`1/3`/`0,5` entro `1e-9` e `1,0` esatto
  sul caso di corpus identici;
- il gruppo privo di termini è rifiutato con `corpus-similarity.empty-group`
  invece di un coseno indefinito silenzioso;
- GlifiKit persiste, riusa (stesso `artifactID`/`generation` sulla seconda
  chiamata) e rifiuta identificatori non validi con lo stesso confine di
  visibilità già verificato per keyness;
- la sequenza CLI completa riproduce esattamente i numeri di generazione
  attesi (`sourceGeneration=11`, `generation=12` dopo il primo `similarity`,
  invariato sul secondo; `artifactCount` finale `7`, un solo Artifact nuovo
  perché i due profili corpus sono riusati da `keyness`) e riusa l'Artifact
  sulla seconda invocazione senza avanzare la generazione;
- la build Xcode macOS resta verde dopo le modifiche a `GlifiEngine.swift` e
  `GlifiStudioService.swift`.

## Limiti

Questa evidenza copre soltanto `Cosine-v1`/`JaccardSet-v1`/`DiceSet-v1` fra due
profili corpus. `Euclidean-v1`, `Manhattan-v1`, `KL-v1`, `JSdiv-v1`,
`JSdist-v1` e `Hellinger-v1` restano non wired, così come tutti gli altri
moduli bounded introdotti in questa sessione (contingenza, dispersione,
statistica, accordo, collocazione, rete): nessuno di questi ha ancora una
sorgente dati di dominio naturale già persistita da cui derivare l'input
(tabelle di contingenza, partizioni di dispersione extra, campioni numerici,
codifiche, co-occorrenze testuali, grafi). `make verify` nel suo complesso
resta bloccato da un problema di formattazione preesistente e non correlato
in `Apps/Shared/StudioHomeView.swift`/`StudioHomeModel.swift`: la sequenza
CLI che include `similarity` è stata eseguita ed è stata verificata
manualmente comando per comando, non ancora tramite un'esecuzione end-to-end
del gate completo. Wiring nel planner (`compare.objects`) e nell'interfaccia
macOS/iPadOS restano fuori ambito.

## Esito

**Superato localmente per `corpus-term-similarity-v1` persistito e riusabile
con parità GlifiCore/Kit/CLI.** Non promuove RF-036 a feature complete né le
altre primitive introdotte in questa sessione a wired.
