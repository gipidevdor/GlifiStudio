<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-024 — AnalysisDescriptor e DAG analitico bounded

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-024 |
| Tipo | Evidenza di verifica del dominio analitico |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-004, TV-005, TV-027, TV-028, TV-054 e TV-060 |

## Ambito

- `AnalysisNodeID` e `ArtifactID` tipizzati, content-addressed e validati;
- `studio.glifi.analysis-descriptor.v1` completo dei campi semantici della slice;
- valori di parametro tagged, NFC, signed-zero canonico e rifiuto dei non finiti;
- JSON a chiavi ordinate, digest SHA-256 domain-separated e round-trip fail-closed;
- DAG immutabile con deduplica, limiti, dipendenze/schema, cicli e ordine
  topologico deterministico;
- sottografo minimo, invalidazione esatta dei discendenti e riuso degli Artifact
  soltanto con descriptor, schema, digest, stato e antenati validi.

## Procedura

1. costruire descriptor equivalenti con ordine delle mappe, NFC e segno dello zero
   diversi e confrontare digest e node ID;
2. modificare un parametro semantico e verificare il cambio di identità;
3. eseguire round-trip di descriptor e grafo, rifiutando versione futura e numero
   non finito;
4. costruire un grafo ramificato in ordini differenti, deduplicare un nodo e
   confrontare ordine e risultato;
5. richiedere un ramo, cambiare un nodo intermedio e verificare rispettivamente
   soli antenati e soli discendenti;
6. marcare stale l'Artifact intermedio e verificare il riuso del ramo fratello e
   del nodo indipendente, non del discendente;
7. provare dipendenza assente, ciclo e limiti nodi/archi;
8. eseguire `make verify`, incluse le quattro build Xcode previste.

## Risultato osservato

- 56 test Swift complessivi superati: 50 GlifiCore e 6 GlifiKit;
- descriptor equivalenti producono gli stessi byte canonici, digest e ID;
- i candidati duplicati convergono a un solo nodo e l'ordine di input non cambia il
  grafo;
- riferimenti mancanti, cicli, identità incoerenti, versioni future e budget
  superati falliscono senza produrre un grafo autorevole;
- invalidazione e riuso preservano i fratelli e i nodi indipendenti;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

Questa evidenza resta limitata alla slice logica e in memoria; la successiva
GS-VER-025 prova commit del grafo nel package, deduplica fisica, invalidazione e
checkpoint. Restano aperti recovery completa, scheduler concorrente, backpressure,
garbage collection e Artifact prodotti automaticamente dalle analisi esistenti.
Questi ultimi sono acquisiti separatamente da
[GS-VER-026](GS-VER-026-analisi-persistenti-riusabili.md). I test sintetici non
sostituiscono fuzzing e benchmark massivi.

## Esito

**Superato localmente per identità, serializzazione e semantica strutturale di
`analysis-dag-v1`.** Questa evidenza non copriva persistenza ed esecuzione,
acquisite separatamente da [GS-VER-025](GS-VER-025-persistenza-artifact-dag.md) e
[GS-VER-026](GS-VER-026-analisi-persistenti-riusabili.md).
