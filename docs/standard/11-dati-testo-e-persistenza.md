# 11. Dati, testo e persistenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-11 |
| Tipo | Capitolo normativo |
| Versione | 0.3.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 11.1 Fonte e lineage

- La fonte originale **NON DEVE** essere modificata implicitamente.
- Ogni artefatto derivato **DEVE** identificare input, trasformazione, versione e parametri.
- Un risultato **DEVE** poter essere ricondotto al corpus e alla fonte applicabili.
- Ogni cella, punto, arco o aggregazione **DEVE** offrire lineage risolvibile quando GS-MET-001 lo richiede.
- Testo digitale e testo OCR **DEVONO** essere distinguibili.

Il contratto implementativo autorevole è [GS-DAT-001](../specifiche-di-design/02-dati-lineage-e-persistenza.md); le formule e le classi di lineage scientifico restano governate da GS-MET-001.

## 11.2 Identità

Documenti, corpus, analisi e artefatti persistenti **DEVONO** avere identità logiche stabili. Path, posizione e nome visualizzato **NON DEVONO** costituire l'identità.

Identificatori di domini differenti **DEVONO** essere tipi distinti anche quando condividono la rappresentazione numerica.

## 11.3 Unicode e offset

- Il significato di ogni offset **DEVE** specificare spazio di coordinate e unità.
- Byte, code unit UTF-16, scalar Unicode e grapheme cluster **NON DEVONO** essere trattati come equivalenti.
- Le conversioni di offset **DEVONO** essere testate con testo multilingue, emoji, combinazioni canoniche e input malformato.
- I confini tra chunk **NON DEVONO** cambiare il risultato semantico della decodifica o tokenizzazione.
- Le rappresentazioni canoniche **DEVONO** usare intervalli UTF-8 half-open legati
  a revisione e digest; ogni trasformazione di lunghezza **DEVE** fornire SpanMap
  componibili. UTF-16 e `String.Index` sono conversioni di presentazione.

## 11.4 Elaborazione massiva

- Importazione e trasformazioni fondamentali **DEVONO** supportare elaborazione incrementale.
- Le code tra fasi **DEVONO** avere limiti e backpressure.
- Le strutture massive **NON DEVONO** allocare un oggetto heap o duplicare una stringa per ogni occorrenza senza evidenza che il costo sia accettabile.
- Ogni limite di dimensione **DEVE** essere esplicito, configurabile quando opportuno e verificato prima dell'allocazione.

## 11.5 Persistenza e formati

Ogni formato proprietario persistente **DEVE** essere:

- specificato indipendentemente dall'ABI Swift;
- versionato e identificabile;
- validabile prima dell'uso;
- compatibile con una strategia di migrazione;
- resistente a troncamento, corruzione e valori fuori limite;
- esplicito rispetto a endianness, allineamento e checksum quando applicabili.

Cache ricostruibili e dati autorevoli **DEVONO** essere distinguibili. Una cache corrotta **DOVREBBE** poter essere eliminata e ricostruita senza perdere fonti o configurazioni.

Per la baseline 0.1, il progetto **DEVE** essere un package `.glifi` v1 con manifest
generazionale, SQLite di sistema per relazioni e file immutabili content-addressed
per payload. Fonti incorporate sono il default; riferimenti esterni sono espliciti,
security-scoped e verificati tramite digest. Cache e indici ricostruibili restano
fuori dal package.

Matrici e grafi massivi **DEVONO** poter usare rappresentazioni sparse, a blocchi o
persistite senza cambiare identità di righe, colonne, nodi o archi. Zero implicito,
valore mancante e valore non definito **NON DEVONO** essere confusi.

## 11.6 Migrazioni

Ogni modifica incompatibile al formato **DEVE** fornire migrazione, lettura compatibile o rifiuto esplicito e sicuro. Le migrazioni **DEVONO** essere idempotenti dove possibile, testate su fixture versionate e non distruttive prima della verifica del risultato. Il manifest **DEVE** diventare commit point soltanto dopo verifica completa; la versione corrente legge/scrive N e, quando esiste, legge N-1 su copia transazionale.

## 11.7 Analysis DAG

Descrittori e dipendenze **DEVONO** essere serializzati canonicamente. Una modifica
invalida transitivamente i soli discendenti semantici; artefatti indipendenti restano
riutilizzabili. Cicli, versioni sconosciute e digest incoerenti sono errori.
