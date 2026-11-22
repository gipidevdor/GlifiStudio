<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Visualizzazione scientifica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VIZ-001 |
| Tipo | Specifica di design delle visualizzazioni |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline proposta; prototipi percettivi e accessibili richiesti |
| Riferimenti | GS-MET-001-22; GS-UX-001-09; GS-UI-001; GS-DAT-001; ADR-0016 |

## Scopo e autorità

GS-MET-001-22 governa il significato scientifico e l'ammissibilità di una
visualizzazione. GS-VIZ-001 governa rendering prodotto, interazioni, riduzione dei
dati, lineage, accessibilità ed export. Un chart non è un Artifact scientifico: è
una vista versionata di Artifact immutabili.

## `VisualizationSpec`

Ogni vista serializzabile dichiara:

- ID/versione della specifica e Artifact sorgenti con digest;
- unità osservativa, campi e trasformazioni applicate;
- mark, canali di encoding, scale, domini, baseline e ordinamenti;
- aggregazione, filtro, binning, normalizzazione e missing/non-finite policy;
- strategia di downsampling o densità e relativo errore/coverage;
- mapping tra mark, dati, Evidence e SourceReference;
- stato di selezione, brush, zoom e confronto;
- descrizione accessibile, tabella equivalente e ordine di esplorazione;
- dimensione, tema semantico ed export profile.

Default impliciti che cambiano interpretazione sono vietati. Zoom e filtro della
vista non mutano l'Artifact; producono ViewState e rendono visibile lo scope.

## Contratti per famiglia

| Vista | Requisiti minimi |
| --- | --- |
| Barre/rank | Baseline zero salvo ragione esplicita; valore, denominatore, ordine e tie-break |
| Serie temporale | Granularità, timezone/calendario, intervalli irregolari, mancanti e incertezza |
| Distribuzione | Bin/estimator, numerosità, outlier policy e accesso alle osservazioni |
| Scatter CA/PCA | Assi con inerzia/varianza, qualità/contributo, scaling e punti supplementari |
| Heatmap | Ordine righe/colonne, scala percettiva, zero/missing e matrice accessibile |
| Dendrogramma | Metrica, linkage, altezza, leaf order e taglio non ingannevole |
| Network | Semantica nodo/arco, direzione, peso, soglia, layout/seed e componenti escluse |
| Contingenza | Osservate/attese/residui, segno, scala divergente e precondizioni |
| KWIC/tabella | Colonne stabili, contesto, ordinamento, virtualizzazione e salto alla fonte |

La terza dimensione prospettica non è usata per codificare dati nel prodotto 0.1.
Assi troncati, scale logaritmiche, normalizzazioni per gruppo e aggregazioni devono
essere evidenti nella vista e nell'export.

## Colore, forma e testo

Palette deriva da ruoli di sistema e viene valutata per contrasto e principali
deficienze cromatiche. Colore non è mai l'unico canale: forma, tratto, pattern,
posizione o etichetta forniscono ridondanza. Una scala sequenziale non viene usata
per valori divergenti; categorie senza ordine non usano una scala ordinata.

Etichette usano formatter locale senza alterare il valore. Precisione visualizzata
deriva dalla precision policy; tooltip non aggiunge cifre non significative.
Legenda è interattiva solo se l'azione è accessibile anche da tastiera e VoiceOver.

## Interazione e interactive lineage

Selezione di un mark produce un `VisualSelection` con datum ID, ArtifactID,
encoding e SourceReference. Le azioni minime sono: descrivi valore, confronta,
filtra/espandi, mostra Evidence, mostra metodo e vai alla fonte quando la classe di
lineage lo consente.

Brushing e linked views condividono ID di dati, non coordinate pixel. Zoom non
elimina punti dal conteggio dichiarato; downsampling conserva numerosità e rende
visibile se un mark aggrega più osservazioni. `exact`, `contributive`, `synthetic`
e `derivational` determinano la formulazione dell'azione “Mostra nella fonte”.

Tutte le interazioni sono disponibili con tastiera e alternative strutturate.
Focus non viene perso a ogni rerender. Reduce Motion disabilita transizioni non
essenziali senza nascondere il cambiamento di stato.

## Dataset grandi

Virtualizzazione, tiling, level-of-detail e aggregazione sono ammessi soltanto con
algoritmo deterministico e parametri nella VisualizationSpec. Campionamento casuale
registra seed e probability design. Estremi, selezioni e piccoli gruppi rilevanti
non possono sparire senza Caveat. La vista offre il numero di osservazioni
visibili/totali e un percorso verso la tabella completa o l'export.

Il rendering rispetta GS-RUN; una GPU è un backend sostituibile. Risultati visivi
tra CPU/GPU devono mantenere mapping, ordine, hit testing e tolleranze approvate.

## Accessibilità

Ogni visualizzazione ha:

1. titolo che esprime la domanda o il confronto;
2. sintesi testuale non causale;
3. descrizione di assi, scala, unità, scope e Caveat;
4. tabella equivalente navigabile e ordinabile;
5. navigazione per elementi significativi, con raggruppamento sui dataset grandi;
6. azioni accessibili equivalenti a pointer/touch;
7. supporto a VoiceOver e, quando disponibile e appropriato, audio graph.

La tabella è parte della stessa vista e conserva selezione/lineage; non è un export
separato usato come alibi di accessibilità.

## Export

Export umano: PDF vettoriale quando la vista lo consente, PNG ad alta densità per
uso raster, titolo, legenda, note, scope e Caveat. Export macchina: dati visualizzati
in CSV/JSON più VisualizationSpec ed ExportManifest. SVG può essere aggiunto solo
dopo audit di compatibilità e sicurezza; non è requisito MVP.

L'export dichiara filtri, dimensione, versione software, downsampling e data di
generazione. Un'immagine senza provenance non è considerata export scientifico
completo.

## Errori percettivi vietati

- area o volume per valori lineari senza trasformazione dichiarata;
- doppio asse con relazione non esplicita;
- interpolazione temporale che nasconde mancanti;
- jitter non deterministico non registrato;
- scala cromatica che rende missing equivalente a zero;
- clipping silenzioso, etichette sovrapposte usate come unica fonte o animazione
  necessaria per comprendere il risultato;
- causalità suggerita da frecce o linguaggio quando l'Artifact è associativo.

## Conformità

- fixture percettive per ogni famiglia e snapshot semanticamente revisionati;
- round-trip datum → Evidence → SourceReference e selezione tra linked views;
- test di aggregazione/downsampling contro dati completi;
- audit contrasto, VoiceOver, tastiera, Dynamic Type e Reduce Motion;
- export reimportabile per i dati e manifest verificabile per la vista;
- studi di comprensione che includano letture errate e caveat, non solo gradimento.
