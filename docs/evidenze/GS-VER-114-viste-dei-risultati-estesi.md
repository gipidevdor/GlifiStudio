<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-114 — Viste dei risultati estesi come proiezioni versionate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-114 |
| Tipo | Evidenza di proiezione visuale e integrazione UI |
| Versione | 1.1.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task P4 (seconda parte) di GS-DOR-002 |

## Ambito

Implementa per le analisi estese di `planner-v2` la separazione fra Artifact e vista richiesta da
GS-MET-001-22 e GS-VIZ-001:

- `GlifiEngine.storedDerivedResult(_:artifactID:in:)` rilegge un Artifact derivato persistito della
  generazione corrente, verificando schema di output e nodo produttore, **senza ricalcolo**;
- `GlifiStudioProjectSession.visualizations(for:)` costruisce le specifiche di vista degli output di
  un'esecuzione del piano; `glifi visualize` ne è il client headless;
- `GlifiStudioVisualization` è una specifica serializzabile e indipendente da SwiftUI: identità
  versionata, Artifact e nodo sorgenti, metodo, assi con dominio esplicito, segni con datum ID,
  classe di lineage e fonti, tabella equivalente con le stesse identità, osservazioni
  visibili/totali, riduzione, layout, regola di enfasi, esclusi, caveat e sintesi accessibile.

## Specifiche di vista

| Specifica | Artifact | Decisioni dichiarate |
| --- | --- | --- |
| `visual-spec.factor-plot.v1` | CA, PCA, LSA (`corpus-multivariate.v2`) | Due assi con quota di inerzia/varianza; dominio `[min(0, min), max(0, max)]` senza clipping; aspetto 1:1 per la CA (le distanze sono il contenuto del grafico); etichette sui punti con contributo superiore alla media `1/n` su almeno un asse (Greenacre, 2017); caveat `symmetric-map` per la CA e `low-plotted-share` se gli assi spiegano meno del 50 % |
| `visual-spec.dendrogram.v1` | HAC | Ordine delle foglie con il primo figlio a sinistra, identico a `hclust$order` di R; albero senza incroci; taglio nel punto medio fra la fusione `n−k` e la successiva, cioè all'altezza che produce i `k` gruppi salvati; caveat per altezze non monotone e per taglio non unico |
| `visual-spec.network.v1` | Rete a finestra | Layout circolare deterministico `layout.circular-community-pagerank.v1` (comunità, poi PageRank, poi termine); nessun seed, nessun layout stocastico; riduzione dichiarata ai 60 nodi con PageRank più alto, con archi soltanto fra nodi visibili; caveat `layout-not-metric` |
| `visual-spec.collocation-table.v1` | Collocazioni a finestra | Tabella nell'ordine dell'Artifact; valori mancanti come «n.d.», mai zero; riduzione dichiarata quando le soglie dell'Artifact (`reduction.artifact-thresholds.v1`) o il limite di coppie salvate (`reduction.stored-pair-limit.v1`, con caveat) lasciano meno coppie di quelle osservate |

La vista SwiftUI `StudioVisualizationView` disegna soltanto i segni dichiarati. Il colore non è mai
l'unico canale: ogni serie ha anche una forma propria (cerchio, quadrato, triangolo, rombo, esagono).
Le aree non codificano quantità. Ogni punto è anche un figlio accessibile con etichetta, valore e
azione. La tabella equivalente fa parte della stessa vista, conserva la selezione e apre la fonte
con l'azione «Apri la fonte». Le viste compaiono nel dettaglio del finding la cui evidenza cita
l'Artifact, al livello 3 della presentazione progressiva (GS-IA).

Ogni vista esporta i propri valori tabellari (GS-MET-001-22): la tabella equivalente in CSV
RFC 4180 (`GlifiStudioVisualizationBuilder.csv`), con colonna `datum` per l'identità condivisa con
i segni, identità stabili delle colonne come intestazione, reali nella rappresentazione più breve che
torna allo stesso valore binary64 e celle mancanti vuote, mai zero; la specifica completa in JSON.

## Procedura e risultato

1. `visualizationTableExportsLosslessCSV`: quoting RFC 4180 di virgole e virgolette, terminatori
   CRLF, cella mancante come campo vuoto;
2. `dendrogramLeafOrderMatchesR`: per i linkage single, complete, average e Ward.D2 l'ordine delle
   foglie coincide con `hclust$order` dell'oracolo `Tests/Oracles/R/visualization.R` (righe
   `DENDRO_*` in `expected.txt`, rieseguite da `make check-oracles`);
3. `serviceProjectsExtendedArtifactsIntoVisualizations`, su quattro fonti con due temi:
   - `identify.themes` produce esattamente un grafico fattoriale, un dendrogramma e una rete, tutti
     su Artifact del piano; la costruzione delle viste non aggiunge Artifact al progetto;
   - le coordinate dei documenti coincidono bit per bit con quelle della CA richiesta direttamente
     a GlifiKit, che per get-or-store ha lo stesso `artifactID`;
   - i domini contengono tutti i segni e l'origine; segni e righe della tabella hanno le stesse
     identità nello stesso ordine;
   - nel dendrogramma le foglie sotto ogni fusione appartengono tutte alla fusione (nessun
     incrocio) e il taglio lascia sopra di sé esattamente `k−1` fusioni;
   - i nodi della rete stanno sul cerchio unitario e ogni arco congiunge due nodi visibili;
   - `explore.relationships` produce la tabella delle collocazioni, senza segni grafici;
   - ogni specifica fa il round-trip JSON senza perdita e il CSV ha una riga per dato, con ogni
     reale riletto identico in binary64;
4. `check-localization.py` estrae dal sorgente GlifiKit ogni chiave `visual.*`, `caveat.visual.*`,
   colonna e serie emettibile, e ne verifica la traduzione in italiano e in inglese (60 chiavi);
5. contract test CLI in `verify.sh`: `glifi visualize <progetto> --request <richiesta.json>` con
   `explore.relationships` su due fixture restituisce l'envelope JSON v1 con tabella delle
   collocazioni e rete, identità di segni e righe allineate;
6. build Xcode macOS e iPadOS verdi dentro `make verify`.

## Limiti

- Accessibilità e resa percettiva non sono ancora verificate su dispositivo (VoiceOver, Dynamic Type,
  contrasto, Reduce Motion): restano nella checklist GS-UX-015 del gate G4.
- Il layout circolare privilegia leggibilità e determinismo; layout a forze o a stress
  richiederebbero seed e bound dichiarati e non sono implementati.
- Export PDF/PNG delle viste, inclusione delle viste nel pacchetto di esportazione con manifest e
  brushing fra viste collegate non sono implementati.
- Il salto alla fonte dai segni contributivi raggiunge il documento, non posizioni esatte; per le
  posizioni resta l'evidenza del finding.

## Esito

**Superato localmente: i risultati numerici estesi hanno viste dedicate, derivate dagli Artifact
persistiti senza ricalcolo, con tabella equivalente, lineage e caveat.**
