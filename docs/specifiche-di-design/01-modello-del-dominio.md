<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Modello del dominio

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOM-001 |
| Tipo | Specifica di design del dominio |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-16 |
| Approvazione | Baseline proposta; da approvare al gate G1 |
| Riferimenti | GS-SRS-001; GS-MET-001; GS-UX-001; ADR-0014; ADR-0016 |

## Scopo e confine

Questa specifica definisce il linguaggio del dominio condiviso da GlifiCore,
GlifiKit, GlifiCLI e dalle app. Governa identità, relazioni, invarianti e lifecycle;
non governa il layout su disco, le formule GS-MET o il layout dell'interfaccia.

I tipi di dominio **NON DEVONO** dipendere da SwiftUI, AppKit o UIKit. I nomi
localizzati non sono identità e non entrano nell'uguaglianza degli oggetti.

## Regole trasversali

- Ogni entità usa un identificatore opaco, tipizzato e stabile. Identificatori di
  tipi diversi non sono confrontabili e non sono ricavati da percorso o titolo.
- Due entità sono uguali soltanto se hanno lo stesso tipo e ID. Il contenuto uguale
  può motivare deduplicazione, non uguaglianza d'identità.
- Ogni mutazione persistibile crea una nuova revisione immutabile o un evento di
  dominio; non riscrive retroattivamente un fatto già citato da un artefatto.
- Data e ora persistite sono `Instant` UTC; calendario, locale e fuso sono
  attributi espliciti quando influenzano il significato.
- Collezioni con risultato osservabile hanno un ordinamento esplicito e un
  tie-break stabile. Non si usa l'ordine accidentale di hash map o filesystem.
- I riferimenti tra aggregate sono ID tipizzati. Un riferimento non risolto è uno
  stato degradato esplicito, mai un oggetto vuoto inventato.

## Entità e value object

| Oggetto | Natura | Identità e responsabilità |
| --- | --- | --- |
| `Project` | Aggregate root | Confine documentale; possiede cataloghi e policy, non i byte esterni |
| `Source` | Entità | Provenienza logica di un contenuto acquisito |
| `SourceRevision` | Entità immutabile | Snapshot di byte, digest, origine e stato di accesso |
| `Document` | Entità | Unità documentale riconoscibile dall'utente |
| `DocumentRevision` | Entità immutabile | Rappresentazione estratta e struttura di una revisione di fonte |
| `Corpus` | Aggregate root | Definizione logica e revisionabile di una raccolta |
| `CorpusVersion` | Entità immutabile | Selezione risolta di revisioni documentali e metadati |
| `Investigation` | Aggregate root | Domanda, intenzione, piano, storia e selezione editoriale |
| `Question` | Value object versionato | Testo originale, lingua, autore e istante |
| `AnalyticalIntent` | Value object tipizzato | Identificatore semantico e slot risolti secondo GS-UX-001 |
| `CollectionProfile` | Artefatto | Profilo versionato di qualità, struttura e capacità |
| `AnalysisPlanRevision` | Entità immutabile | DAG risolto, motivazioni, esclusioni e budget |
| `AnalysisNode` | Entità semantica | Operazione versionata con input, parametri e output attesi |
| `Artifact` | Entità immutabile | Risultato macchina con tipo, descriptor, digest e lineage |
| `Evidence` | Entità immutabile | Osservazione interpretabile fondata su uno o più artefatti |
| `Finding` | Entità revisionata | Affermazione editoriale deterministica supportata da Evidence |
| `Caveat` | Value object tipizzato | Limite, impatto, severità, ambito e rimedio possibile |
| `SourceReference` | Value object | Collegamento tipizzato a intervalli o regioni di una rappresentazione |
| `Annotation` | Entità revisionata | Etichetta umana o automatica con autore, schema e riferimento |
| `MetadataField` | Entità | Nome stabile, tipo, cardinalità, vincoli e policy dei mancanti |
| `MetadataValue` | Value object | Valore tipizzato, provenienza e stato di validazione |
| `MethodDescription` | Value object versionato | Descrizione presentabile di un contratto GS-MET |
| `InvestigationEvent` | Entità immutabile | Azione semantica nella storia dell'indagine |
| `ReportRevision` | Entità immutabile | Selezione ordinata di findings, evidenze, fonti e testo editoriale |
| `ExportManifest` | Artefatto | Inventario, versioni, digest e provenance di un export |

## Cardinalità normative

```text
Project 1 ── 0..* Source 1 ── 1..* SourceRevision
Project 1 ── 0..* Document 1 ── 1..* DocumentRevision
Source 1 ── 0..* Document
DocumentRevision * ── 1 SourceRevision
Project 1 ── 0..* Corpus 1 ── 0..* CorpusVersion
Project 1 ── 0..* Investigation 1 ── 1..* AnalysisPlanRevision
CorpusVersion * ── 1..* DocumentRevision
AnalysisPlanRevision 1 ── 1..* AnalysisNode
AnalysisNode 1 ── 0..* Artifact
Finding 1 ── 1..* Evidence ── 1..* Artifact
Evidence 1 ── 1..* SourceReference
ReportRevision 1 ── 0..* Finding
```

Un `Source` può produrre più documenti quando il formato contiene unità logiche;
ogni DocumentRevision MVP deriva da una sola SourceRevision esatta. Un
`CorpusVersion` non possiede documenti: ne congela la selezione. Una stessa
`DocumentRevision` può appartenere a più versioni senza duplicazione. Un
`Finding` senza Evidence valida non può essere pubblicabile; un risultato con
dati insufficienti è rappresentato da stato e Caveat, non da Evidence fittizia.

## Aggregate e confini transazionali

`Project`, `Corpus` e `Investigation` sono aggregate root. Una singola operazione
transazionale modifica un solo aggregate e pubblica eventi per le conseguenze
sugli altri. Il runtime può coordinare una saga recuperabile, ma non può nascondere
una transazione distribuita non atomica dietro un metodo sincrono.

Gli artefatti analitici sono content-addressed e immutabili. Il progetto conserva
la raggiungibilità dall'ultima revisione valida; una raccolta differita può
eliminare soltanto oggetti non raggiungibili e ricostruibili secondo GS-DAT-001.

## Lifecycle

| Oggetto | Stati ammessi | Transizioni principali |
| --- | --- | --- |
| SourceRevision | `staging`, `available`, `externalUnavailable`, `superseded`, `quarantined` | import, verifica, perdita accesso, nuova revisione, rilevamento minaccia |
| DocumentRevision | `pending`, `extracting`, `ready`, `partial`, `failed`, `superseded` | estrazione, checkpoint, completamento, errore, nuova fonte |
| CorpusVersion | `draft`, `frozen`, `retired` | modifica selezione, congelamento, ritiro |
| Investigation | `draft`, `planned`, `running`, `review`, `complete`, `archived` | domanda, piano, esecuzione, revisione, relazione, archiviazione |
| AnalysisPlanRevision | `proposed`, `accepted`, `executing`, `completed`, `cancelled`, `failed` | planning, conferma, run, terminale |
| Artifact | `staged`, `valid`, `stale`, `corrupt`, `unavailable` | commit, invalidazione, controllo integrità, perdita riferimento |
| Finding | `candidate`, `supported`, `suppressed`, `insufficient`, `included`, `superseded` | interpretazione, assessment, editoria, nuova revisione |

Gli stati terminali restano interrogabili per audit. Cancellazione e fallimento non
eliminano automaticamente checkpoint o artefatti precedentemente validi.

## Invarianti epistemiche

1. `Artifact`, `Evidence`, `Finding` e `ReportRevision` sono classi distinte.
2. Ogni Evidence registra l'algoritmo e gli input che la rendono riproducibile.
3. Ogni Finding registra la versione della regola interpretativa e tutte le
   Evidence considerate, incluse quelle confliggenti o escluse con motivazione.
4. Un Caveat dichiara ambito e impatto; la propagazione non può ridurne la severità
   senza una regola versionata e verificabile.
5. Un Report non converte output generativo in fatto. Testo generativo eventuale è
   marcato, separato e sempre riconducibile a contenuto verificabile.
6. Il lineage rimane valido attraverso revisioni: un riferimento indica sempre la
   revisione esatta, non genericamente “il documento corrente”.

### Slice di dominio implementata

La baseline eseguibile introduce `EvidenceID` e `FindingID` distinti, derivati dal
contenuto canonico con SHA-256 e domain separation. `Evidence` conserva Artifact,
AnalysisNode, digest del descriptor, metodi, misure tagged, incertezza, effect
size, SourceReference esatte, categoria epistemica, validità e caveat. `Finding`
conserva proposizione strutturata, riferimenti alle evidenze, assessment per
famiglia, rule set, chiave localizzabile, fattori editoriali e categoria
`deterministicallyInterpreted`.

Il payload `studio.glifi.artifact.interpretation.v1` ricalcola identità e
canonicalizzazione in decodifica e fallisce chiuso in caso di duplicati, valori
non finiti, riferimenti irrisolti, lineage incompleto o Finding senza Evidence.
La slice riguarda il profilo descrittivo e keyness. Investigation collega domanda,
intento, piano, Interpretation e selezione ordinata dei FindingID mediante eventi
append-only ramificabili; evidenze confliggenti, altri eventi cognitivi e
persistenza autorevole del Report restano da implementare. La prima
`ReportRevision` esportabile è una proiezione immutabile e content-addressed di un
head: conserva domanda, lineage, soli Finding selezionati e chiusura esatta delle
Evidence referenziate, senza diventare un Artifact analitico.

## Metadati

I tipi MVP sono `string`, `integer`, `decimal`, `boolean`, `instant`, `localDate`,
`duration`, `controlledTerm` e liste omogenee. Ogni campo dichiara cardinalità,
unità, normalizzazione, valore mancante e ordinamento. Conversioni fallite non
diventano stringhe silenziosamente: producono un problema di qualità riferibile.

## Eliminazione e privacy

L'eliminazione logica produce un tombstone e rimuove l'oggetto dalle nuove
selezioni. L'eliminazione fisica avviene solo dopo analisi di raggiungibilità,
chiusura delle scene e commit riuscito. Se una fonte incorporata è eliminata,
artefatti che ne espongono contenuto non possono sopravvivere come cache
“anonime”. Backup e copie esportate restano fuori dalla garanzia e sono dichiarati
all'utente.

## Criteri di conformità

- test di cardinalità, invarianti e transizioni di stato;
- round-trip degli ID senza collisione fra tipi;
- property test di immutabilità delle revisioni e stabilità dell'ordinamento;
- rifiuto di Finding senza Evidence e di SourceReference senza revisione;
- nessuna importazione di framework UI dal modulo di dominio.
