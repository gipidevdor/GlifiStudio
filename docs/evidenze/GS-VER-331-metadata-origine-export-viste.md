<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-331 — Metadati della fonte nell'export delle viste

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-331 |
| Tipo | Regressione di provenienza e confine delle failure |
| Versione | 1.0.0 |
| Stato | RED riprodotti e GREEN finale mirato; gate macOS integrato da completare |
| Responsabile | Codex con verifica serializzata dall'integratore |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di correttezza semantica |
| Riferimenti | GS-DOR-331; GS-API-003; GS-MET-001-22; GS-VIZ-001; GS-VER-320; CMP-331 |

## Difetto e RED sul runtime precedente

L'export della sessione verificava soltanto la presenza dell'Artifact nella
generazione corrente. Nodo, analisi e metodo della specifica Codable erano
copiati nell'export senza confronto con la fonte persistita. Il controllo
offline verificava correttamente la coerenza interna del nuovo bundle, ma
non poteva accertare quell'associazione a una fonte esterna.

La nuova suite `GlifiVisualExportSourceTests` genera viste reali da testi
sintetici nelle cinque varianti rappresentabili: factor plot PCA,
dendrogramma, rete di finestra, rete documento-termine e tabella di
collocazioni. Altera uno per volta `analysisNodeID`, `analysisIdentifier`
e `methodIdentifier`, mantenendo l'ArtifactID corrente. Ogni variante viene
eseguita tramite chiamata nativa e JSON condiviso `project-call`.

Il secondo comando SwiftPM dell'integratore, prima di cambiare il runtime
export, ha confermato:

- 30 alterazioni accettate e 30 destinazioni erroneamente pubblicate;
- due ulteriori export, nativo e JSON, riusciti dopo la corruzione di un
  byte del payload sorgente della sola fixture, con altre due destinazioni
  erroneamente pubblicate;
- due viste con assi PCA alternativi correttamente esportate.

La prima versione ha tre definizioni e 14 esecuzioni: 12 negative fallite e due positive
superate, per 64 issue attese. Il target Kit complessivo comprendeva 167
definizioni e non aveva altre issue. I due errori separati del target Core
nel medesimo comando appartengono a GS-VER-328. Il
[rapporto strutturato](allegati/GS-VER-331-verifica.json) conserva digest e
conteggi senza incorporare il log grezzo o percorsi personali.

## Correzione e confine

La sessione confronta il nodo dichiarato con il nodo dell'Artifact e
l'identità dell'analisi con quella del descriptor. Il metodo viene poi
letto dalla fonte tipizzata, senza ricalcolo:

| Schema della fonte | Identità del metodo |
| --- | --- |
| multivariata v2 | `method.identifier` |
| rete di finestra v1 | `graphIdentifier` |
| rete documento-termine v2 | `graphIdentifier` |
| collocazioni di finestra v2 | `universeIdentifier` |

Le letture condividono i controlli di presenza, schema, nodo e digest del
progetto. Gli altri schemi vengono rifiutati esplicitamente. Metadati
incompatibili producono `visual-export.source-mismatch`, categoria
`invalidInput`, operazione `export`, retry `afterCorrection`, stato
`unchanged` e nessun argomento. Il messaggio specifico italiano/inglese
richiede di rigenerare la vista senza esporre ID o percorsi. L'Artifact
assente conserva `visual-export.stale-artifact`.

Il confine mantiene codice, categoria, retry, stato e argomenti delle
failure di lettura, riportando l'operazione `export`. La regressione del
payload corrotto richiede espressamente `project.artifact-digest-mismatch`,
`corruption`, `never`, `readOnlyRecovery` e operazione `export`.

La cancellazione è controllata prima e dopo la nuova lettura asincrona e
ancora dal writer fino al commit atomico. Dopo admission conserva la
failure di export `operation.cancelled`, stato `unchanged`, senza
pubblicazione. Il writer, i checkpoint di cancellazione e la verifica
offline non sono modificati. La review dei call site di sessione
preesistenti ha confermato viste generate da risultati reali; le fixture
sintetiche autonome del solo writer rimangono invariate.

## Admission e terzo comando

La review indipendente ha evidenziato che l'admission rimaneva fuori dal
nuovo confine: una sessione chiusa riferiva l'operazione `persistProject`
e una task già cancellata conservava `lastCommittedGeneration` anziché
`unchanged`. Prima di cambiare quel punto sono stati aggiunti due test
nativi separati. Il terzo comando completo ha riprodotto esattamente queste
due issue nel target Kit, 169 definizioni, mentre le precedenti 14
esecuzioni di fonte e assi alternativi e le regressioni di cancellazione
preesistenti erano GREEN. Il target Core, 781 definizioni, era interamente
GREEN in quel comando.

L'unica ulteriore correzione sposta `ensureOpen(.export)` dentro il
`do/catch` del solo `exportVisualization`. La sessione chiusa conserva
`project.session-closed`, `invalidInput`, `afterCorrection` e
`lastCommittedGeneration` con operazione `export`; la cancellazione prima
dell'admission conserva `operation.cancelled`, `export`, `newRequest`
e `unchanged`. Gli altri lifecycle restano invariati. La suite finale
ha cinque definizioni e 16 esecuzioni.

## Verifiche e limiti

Taxonomy delle failure e catalogo messaggi hanno superato i controlli
statici dopo il candidato: 140 siti con categorie letterali conformi e
23 chiavi GlifiKit tradotte in entrambe le lingue; `git diff --check`
non ha rilevato errori negli elementi del lotto. Il GREEN finale mirato
`core-green.log` passa con 17 definizioni Kit e 28 Core, zero issue.
Tutte le 16 esecuzioni di questa suite, incluse le due admission, e le
regressioni di cancellazione/visualizzazione sono GREEN. I digest dei
tre file del candidato coincidono con quelli registrati nel rapporto;
il fingerprint dei 590 input runtime congelati è registrato separatamente
dall'integratore. Il secondo agente non ha individuato blocker nuovi nella
lettura della fonte, nelle fixture o nel contratto del writer.

I sei check negativi permanenti di processo CLI e il gate macOS integrato
rimangono coordinati dall'integratore e non sono ancora attestati qui.

Il confronto riguarda i metadati del produttore. Non impone l'uguaglianza
con una vista standard, non autentica coordinate, valori o trasformazioni
modificati dal chiamante e non estende il significato della verifica
offline. Non aggiunge API pubbliche, backend, schema persistente o
formule. Non attesta audit GUI, accessibilità manuale o iPadOS.

Le fixture usano package temporanei propri, chiudono le sessioni e
rimuovono sorgenti ed export al termine. La prova di corruzione apre Core
solo per ispezionare il percorso generato dell'Artifact prima di alterare
il payload temporaneo: non modifica dati dell'utente o package di lavoro.
