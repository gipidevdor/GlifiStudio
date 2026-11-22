<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-026 — Analisi persistenti e riusabili

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-026 |
| Tipo | Evidenza di verifica del ciclo analitico persistente |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-004, TV-005, TV-008, TV-011, TV-031, TV-054, TV-056, TV-060 e TV-073 |

## Ambito

- payload `Codable` tipizzati, versionati e fail-closed per profilo corpus e
  keyness, legati al rispettivo `AnalysisNodeID`;
- `AnalysisDescriptor` deterministico pianificato prima del calcolo e verificato
  rispetto a selezione, revisioni, contratto di tokenizzazione, opzioni e policy
  numerica;
- commit automatico del profilo corpus come Artifact content-addressed;
- commit dei profili delle due popolazioni e di keyness, con dipendenze Artifact
  esplicite nel DAG;
- lookup verificato prima della lettura e tokenizzazione delle fonti, incluso il
  riuso dopo chiusura e riapertura del package;
- distinzione fra generazione sorgente e generazione committata, con
  `ArtifactID` e `AnalysisNodeID` propagati attraverso Core, GlifiKit e GlifiCLI.

## Procedura

1. creare un progetto, importare due revisioni e acquisire la generazione G2;
2. analizzare il corpus, verificare il commit a G3 e decodificare il payload
   persistito come uguale al risultato restituito;
3. ripetere la stessa analisi e verificare identità, generazione invariata e
   nessuna nuova chiamata al tokenizer sostituibile;
4. calcolare keyness e verificare i due profili dipendenza più il risultato,
   portando il progetto da G3 a G6;
5. ripetere keyness e verificare Artifact identico, generazione G6 e nessuna
   tokenizzazione aggiuntiva;
6. riaprire il package con una nuova istanza del motore e un tokenizer contatore,
   ripetere entrambe le operazioni e verificare zero invocazioni;
7. verificare il rifiuto di payload con schema futuro o incompatibile;
8. eseguire i contract smoke CLI e l'intero `make verify`, incluse le quattro
   build Xcode previste.

## Risultato osservato

- 60 test Swift complessivi superati: 54 GlifiCore e 6 GlifiKit;
- il profilo corpus passa da G2 a G3 una sola volta e viene riusato con lo stesso
  `ArtifactID` e `AnalysisNodeID`;
- keyness crea esattamente due profili dipendenza e un risultato da G3 a G6,
  quindi ogni ripetizione resta idempotente;
- la riapertura con tokenizer nuovo riusa entrambi i risultati con zero chiamate
  di tokenizzazione;
- mismatch di schema, versione, famiglia, descriptor o contenuto viene rifiutato
  senza promuovere dati incompatibili;
- output Core, GlifiKit e GlifiCLI espongono le identità e le due generazioni;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

La prova copre soltanto profilo corpus e keyness. Il payload è ancora codificato
in memoria ed è limitato a 64 MiB: streaming, spill e corpus L/XL restano aperti.
Non sono provati concorrenza fra processi, kill reale, power-loss, file provider,
garbage collection, progressi UI, dispositivi fisici o altre famiglie analitiche.
Il planner è verificato separatamente da GS-VER-027.

## Esito

**Superato localmente per il ciclo pianifica, calcola, persiste e riusa di profilo
corpus e keyness.** Non promuove il percorso Must o il prodotto a feature complete.
