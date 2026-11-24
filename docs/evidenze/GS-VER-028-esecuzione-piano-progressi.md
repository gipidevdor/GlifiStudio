<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-028 — Esecuzione affidabile del piano e progressi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-028 |
| Tipo | Evidenza di verifica del runtime analitico |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-005, TV-012, TV-056, TV-065, TV-071 e TV-073 |

## Ambito

- esecuzione degli step canonici `analyzeCorpus` e `compareKeyness` prodotti da
  `planner-mvp-v1`;
- admission prima del piano mediante snapshot di condizioni e
  `GlifiRuntimePolicy`;
- verifica di radice corpus, dipendenze, schema, completezza e raggiungibilità
  degli Artifact prima del terminale riuscito;
- progressi con OperationID, revisione, fase, step/nodo, unità, totale e qualità;
- stream GlifiKit `bufferingNewest(32)` posseduto dalla ProjectSession;
- massimo una esecuzione attiva per sessione, senza coda implicita non bounded;
- cancellazione tramite task Swift/handle e chiusura di sessione che cancella e
  attende le operazioni registrate;
- comando GlifiCLI `execute --request`, output JSON v1 e soppressione esplicita del
  progresso testuale con `--no-progress`.

## Procedura

1. creare un progetto con due revisioni e un piano `compare.objects`;
2. eseguire il piano su condizioni nominali iniettate e verificare Artifact
   target, riferimento e confronto in ordine canonico;
3. verificare revisioni di progresso monotone, totali non regressivi e un solo
   terminale dopo la generazione durevole;
4. ripetere l'esecuzione e verificare stessi Artifact senza nuova generazione;
5. iniettare stato termico `critical` e verificare rifiuto prima di ogni commit;
6. cancellare al primo evento e verificare failure `cancelled` e stato invariato;
7. cancellare dopo l'ultimo commit e verificare che l'esito durevole resti riuscito;
8. tentare una seconda esecuzione nella stessa sessione e verificare il rifiuto
   tipizzato senza coda implicita;
9. consumare lo stesso stream via GlifiKit e verificare ownership/lifecycle;
10. eseguire due processi CLI sullo stesso piano e confrontare output e generazione;
11. eseguire `make verify`, incluse le quattro build Xcode previste.

## Risultato osservato

- 69 test Swift complessivi superati: 61 GlifiCore e 8 GlifiKit;
- l'esecuzione iniziale persiste piano e tre output; il replay conserva
  generazione e identità degli Artifact;
- admission critica termina come `insufficientResources` senza modifiche;
- cancellazione prima della pianificazione termina come `cancelled` senza commit;
- cancellazione dopo l'ultimo Artifact non converte un commit durevole in failure;
- otto progressi del caso comparativo hanno revisioni `0...7`, fasi ordinate e
  avanzamento work-unit monotono;
- GlifiKit emette un solo `completed` oppure una sola failure tipizzata;
- la seconda esecuzione simultanea termina con `runtime.operation-limit-exceeded`;
- la CLI mantiene un solo documento JSON su `stdout` e il replay tra processi è
  idempotente;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

Il progresso misura i confini degli step, non ancora token, byte o partizioni
interne. La slice non persiste ExecutionRecord o checkpoint, non esegue rami in
parallelo e non prova backpressure con consumer reali lenti. L'adattatore runtime
predefinito osserva Low Power Mode e termica, ma pressione memoria e lifecycle
richiedono ancora l'adattatore event-driven delle app. Restano aperti benchmark,
pressure test, dispositivi fisici, UI analitica, Evidence/Finding ed export.

## Esito

**Superato localmente per esecuzione ordinata, bounded, cancellabile e riusabile
del piano MVP attraverso GlifiCore, GlifiKit e GlifiCLI.** Non promuove l'intero
GS-RUN-001 o il percorso Must 0.1 a feature complete.
