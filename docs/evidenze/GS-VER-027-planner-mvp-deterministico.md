<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-027 — Planner MVP deterministico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-027 |
| Tipo | Evidenza di verifica del planner analitico |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-005, TV-041, TV-054, TV-060 e TV-073 |

## Ambito

- undici `AnalyticalIntent` canonici indipendenti dalla lingua di presentazione;
- catalogo `capability-catalog-mvp-v1` con dati, precondizioni, qualità, metodi,
  dipendenze, backend, fallback, output, determinismo, cost model e limiti per
  profilo corpus e keyness;
- CollectionPlanningProfile osservato con scope, revisioni, formati, byte, lingua
  configurata e radice delle fonti;
- decision table per intenti supportati/non supportati, scope vuoto, gruppi
  mancanti o sovrapposti e budget insufficiente;
- espansione canonica di keyness in profilo target, profilo riferimento e
  confronto con archi di dipendenza espliciti;
- rationale strutturato con inclusioni, esclusioni, rinvii, caveat, backend e
  fallback vuoti espliciti;
- payload `analysis-plan.v1`, AnalysisDescriptor, Artifact e generazioni
  persistenti attraverso Core, GlifiKit e GlifiCLI.

## Procedura

1. pianificare `review.completely` con le fonti fornite in ordini diversi e
   confrontare byte semanticamente equivalenti, step, costi e rationale;
2. verificare piano non eseguibile e motivo stabile per scope vuoto, capability
   non disponibile nell'MVP, lingua analitica non supportata e gruppi mancanti;
3. applicare budget zero e verificare `deferred` senza step parziali;
4. rifiutare revisioni ignote o gruppi fuori scope con failure `plan` tipizzata;
5. persistere un piano `compare.objects`, ripeterlo e riaprirlo verificando stessa
   identità e nessuna nuova generazione;
6. decodificare una richiesta GlifiKit JSON minimale e verificare lo stesso piano;
7. eseguire due processi CLI `plan --request` sullo stesso package e verificare
   idempotenza, identità, dipendenze e conteggio Artifact;
8. eseguire `make verify`, incluse le quattro build Xcode previste.

## Risultato osservato

- 65 test Swift complessivi superati: 58 GlifiCore e 7 GlifiKit;
- input e sorgenti riordinati producono lo stesso piano canonico;
- `compare.objects` produce tre step ordinati e keyness dipende dai due profili;
- `review.completely` include soltanto capability rilevanti e sostenibili, con
  keyness marcata conditional finché le popolazioni token non sono confermate;
- esclusioni, rinvii e condizioni mancanti non vengono simulati come risultati;
- il piano passa da G2 a G3 una sola volta e viene riusato dopo riapertura;
- la CLI limita la richiesta a 1 MiB e il secondo processo conserva generazione e
  ArtifactID;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

Il catalogo eseguibile contiene soltanto profilo corpus e keyness. L'esecuzione
del piano e i progressi di confine sono acquisiti separatamente da GS-VER-028. Il
profilo pre-piano non comprende ancora token confermati, metadati tipizzati, tempo,
duplicazioni, qualità linguistica, OCR o rappresentatività. Il budget del piano è
statico; le condizioni termiche/memoria vengono applicate soltanto all'admission
dell'esecutore. Override esperti, Investigation persistente, UI localizzata,
progresso intra-nodo, studi con utenti e dispositivi fisici restano aperti.

## Esito

**Superato localmente per `planner-mvp-v1` deterministico, spiegabile, bounded e
persistente.** Non promuove GS-ANA-001 o il percorso Must a feature complete.
