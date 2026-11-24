<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-106 — planner-v2: capability estese pianificate, eseguite e tracciate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-106 |
| Tipo | Evidenza di verifica del planner, dell'esecuzione e dell'interpretazione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-027, TV-028, TV-054, TV-056 e TV-073 |

## Ambito

Attua [ADR-0025](../adr/0025-estensione-analitica-planner-v2.md): le famiglie verificate in
GS-VER-092…105 diventano pianificabili ed eseguibili, superando il limite «wiring nel planner»
dichiarato dalle evidenze precedenti.

- `planner-v2` con `capability-catalog-v2`: il catalogo MVP (profilo corpus, keyness) resta
  invariato e sempre per primo; si aggiungono sette capability dichiarative con intenzioni,
  numero minimo di fonti, gruppi richiesti, operazione, schema di output, modello di costo
  (`profile-plus-N-per-source-v1`) e caveat:
  associazione documento×termine, collocazioni a finestra, rete a finestra, Correspondence
  Analysis, clustering gerarchico (Ward, `k = min(3, n−1)`), similarità fra gruppi e confronto di
  gruppo sulla lunghezza dei documenti; i parametri scelti dal planner (per esempio la finestra
  `standardPlanned` ±4 con conteggio congiunto minimo 1) sono costanti dichiarate;
- decisioni per capability con motivi stabili (`planner.intent-not-supported`,
  `planner.comparison-groups-required`, `planner.insufficient-sources`, rinvio per limiti o
  budget); le capability estese incluse sono `conditional` perché alcune precondizioni dipendono
  dal contenuto (coppie co-occorrenti, inerzia non nulla, documenti non vuoti);
- esecuzione: `GlifiPlannedOperation` con sette nuove operazioni eseguite tramite le operazioni
  persistite esistenti, con riuso degli Artifact identici fra piani diversi;
- interpretazione: gli output estesi entrano come input `supplementary` nel lineage
  (`sourceArtifactIDs`) senza generare findings; un piano composto solo da capability estese
  produce un esito esplicito `interpretation.family-without-rules`.

## Procedura e risultato

1. `review.completely` su due fonti con gruppi: quattro passi MVP invariati (costo 1 412) seguiti da
   sei passi estesi con costi derivati dalle formule dichiarate (totale 12 940); clustering escluso
   con `planner.insufficient-sources`;
2. `identify.themes` su una fonte: solo la rete a finestra, CA e clustering esclusi con motivo;
   `trace.change` resta senza capability (`planner.no-capability-for-intent`);
3. `compare.objects`: cinque passi (profili, keyness, similarità, confronto di gruppo); generazioni,
   Artifact e revisioni di progresso aggiornati nei test dell'esecutore e di GlifiKit;
4. esecuzione end-to-end su tre fonti: `explore.relationships` materializza associazione,
   collocazioni, rete e CA con schemi di output coerenti con il catalogo; `identify.themes` riusa gli
   stessi Artifact di rete e CA e aggiunge il clustering;
5. `Scripts/verify.sh`: identità `planner-v2`/`capability-catalog-v2`, passi e operazioni estesi del
   piano CLI, numeri di generazione ricalcolati per esecuzione reale (la similarità CLI riusa ora
   l'Artifact prodotto dal piano); gate completo `make verify` con build Xcode macOS e iPadOS.

## Limiti

Le regole interpretative (findings) per le famiglie estese non sono ancora specificate: gli output
sono tracciati ma non generano proposizioni. L'interfaccia macOS/iPadOS mostra i piani ma non ha
ancora viste dedicate agli output estesi (GS-UX-004).

## Esito

**Superato localmente: planner-v2 pianifica, esegue e traccia le capability estese in modo
deterministico, con il catalogo MVP invariato.**
