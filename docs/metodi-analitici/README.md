<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Specifica normativa dei metodi analitici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001 |
| Tipo | Specifica normativa ingegneristico-scientifica |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-10-03 |
| Approvazione | Perimetro scientifico richiesto dall'iniziatore del progetto; baseline da revisionare |
| Riferimenti | GS-VIS-001; GS-SRS-001; ADR-0013 |

## Scopo e autorità

Questa specifica definisce la semantica scientifica delle analisi di Glifi Studio.
Serve a progettazione, implementazione, test, review e interpretazione dei risultati;
non è un manuale didattico e non prescrive un particolare layout dell'interfaccia.

La [specifica GS-UX-001](../esperienza-utente/README.md) governa intenzioni,
findings, progressive disclosure e navigazione. Un titolo comprensibile o una
vista orientata alla domanda non rinomina la variante scientifica sottostante.
GS-ANA-001 governa planning, DAG operativo e interpretation; GS-VAL-001 governa le
prove trasversali. Nessuno dei due può ridefinire formule o precondizioni GS-MET.

I documenti `GS-MET-001-*` sono parte normativa di questa specifica. In caso di
conflitto, una formula o precondizione definita nel documento specialistico prevale
su descrizioni generiche presenti in visione, requisiti o architettura. Gli ADR
governano le decisioni architetturali, ma non possono cambiare implicitamente il
significato matematico di un metodo versionato.

## Contratto minimo di ogni metodo

Un metodo reso disponibile dal prodotto **DEVE** dichiarare:

1. identificatore e versione logica dell'algoritmo;
2. significato, dominio d'uso e unità analitica;
3. input, output, parametri e valori predefiniti;
4. precondizioni, trattamento dei dati mancanti e casi degeneri;
5. formula, procedura o riferimento a una variante completamente specificata;
6. proprietà, limiti interpretativi e criteri di correttezza;
7. classe di determinismo, precisione e politica di tolleranza;
8. requisiti di provenienza, verificabilità e navigazione alle fonti;
9. comportamento incrementale, sparso o fuori memoria quando applicabile;
10. dataset o implementazione indipendente usati come oracolo di verifica.

Un comando generico come “TF-IDF”, “cluster”, “similarità” o “test statistico”
**NON DEVE** produrre un artefatto persistibile finché variante e parametri non sono
risolti in un `AnalysisDescriptor`.

## Principi scientifici vincolanti

- Dati osservati, trasformazioni, stime di modello, inferenze statistiche e output
  generativi **DEVONO** essere distinguibili.
- Un'associazione o una significatività statistica **NON DEVE** essere presentata
  come causalità.
- Un modello empirico, incluse le leggi di Zipf e Heaps, **NON DEVE** essere
  presentato come proprietà esatta del corpus.
- Significatività statistica ed effect size **DEVONO** essere conservate e
  interpretate separatamente quando entrambe sono applicabili.
- L'assenza di una precondizione matematica **DEVE** causare rifiuto esplicito,
  risultato non definito o passaggio a una variante dichiarata; non una correzione
  silenziosa.
- La GUI visualizza artefatti del motore e **NON DEVE** ridefinirne semantica,
  ordinamento, precisione o provenienza.
- Nessuna analisi fondamentale **DEVE** richiedere la materializzazione integrale
  del corpus o di una matrice quando esiste una strategia esatta incrementale,
  sparsa o a blocchi compatibile con il metodo.

## Information item della specifica

| ID | Argomento | Documento |
| --- | --- | --- |
| GS-MET-001-01 | Contratto dell'analisi e provenienza | [AnalysisDescriptor](01-analysis-descriptor-e-provenienza.md) |
| GS-MET-001-02 | Dipendenze e invalidazione | [Analysis DAG](02-analysis-dag-e-invalidazione.md) |
| GS-MET-001-03 | Riproducibilità numerica | [Determinismo e tolleranze](03-determinismo-e-tolleranze.md) |
| GS-MET-001-04 | Conteggi e sintesi | [Statistiche descrittive e diversità lessicale](04-statistiche-descrittive-e-diversita-lessicale.md) |
| GS-MET-001-05 | Regolarità empiriche | [Distribuzioni lessicali, Zipf e Heaps](05-distribuzioni-lessicali-zipf-heaps.md) |
| GS-MET-001-06 | Rappresentazione fondamentale | [Matrice unità-termine](06-matrice-unita-termine.md) |
| GS-MET-001-07 | Trasformazioni dei termini | [Ponderazione e BM25](07-ponderazione-termini-e-bm25.md) |
| GS-MET-001-08 | Confronto fra gruppi | [Keyness](08-keyness.md) |
| GS-MET-001-09 | Relazioni categoriali | [Tabelle di contingenza](09-tabelle-di-contingenza.md) |
| GS-MET-001-10 | Analisi fattoriale di frequenze | [Correspondence Analysis](10-correspondence-analysis.md) |
| GS-MET-001-11 | Associazione contestuale | [Co-occorrenza e collocazione](11-cooccorrenza-e-collocazione.md) |
| GS-MET-001-12 | Distribuzione interna | [Dispersione lessicale](12-dispersione-lessicale.md) |
| GS-MET-001-13 | Confronto matematico | [Similarità e distanze](13-similarita-e-distanze.md) |
| GS-MET-001-14 | Partizionamento | [Clustering](14-clustering.md) |
| GS-MET-001-15 | Spazi latenti | [Riduzione dimensionale e topic analysis](15-riduzione-dimensionale-e-topic-analysis.md) |
| GS-MET-001-16 | Strutture relazionali | [Reti lessicali](16-reti-lessicali.md) |
| GS-MET-001-17 | Evoluzione e gruppi | [Analisi temporale e metadata-first](17-analisi-temporale-e-metadata-first.md) |
| GS-MET-001-18 | Qualità NLP | [Valutazione dei servizi linguistici](18-valutazione-servizi-linguistici.md) |
| GS-MET-001-19 | Sintesi | [Riassunto estrattivo](19-riassunto-estrattivo.md) |
| GS-MET-001-20 | Codifica umana | [Content analysis qualitativa](20-content-analysis-qualitativa.md) |
| GS-MET-001-21 | Inferenza | [Fondazione statistica](21-fondazione-statistica.md) |
| GS-MET-001-22 | Presentazione | [Visualizzazioni scientifiche](22-visualizzazioni-scientifiche.md) |

## Evoluzione

Una nuova variante **DEVE** ricevere una versione logica distinta quando può cambiare
il risultato a parità di descrittore. Alias commerciali o nomi di libreria non
costituiscono versioni scientifiche. Un metodo sperimentale **PUÒ** essere esposto
soltanto se marcato come tale e sottoposto agli stessi obblighi di provenienza.
