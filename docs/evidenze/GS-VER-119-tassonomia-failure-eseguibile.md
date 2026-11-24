<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-119 — Tassonomia delle failure eseguibile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-119 |
| Tipo | Evidenza di contratto trasversale |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task S1 di GS-DOR-004 |

## Ambito

RQ-058 richiede che API, CLI, runtime e UI usino la tassonomia trasversale e dichiarino per ogni
esito retry e stato che rimane valido. La tabella di GS-API-001 § 8 diventa codice:

- `GlifiFailureTaxonomy.retry` e `.retained`: disposizioni di retry e stati conservati ammessi per
  ciascuna delle undici categorie; `defaultRetry` e `defaultRetained(_:preferred:)` ne danno i
  valori canonici;
- `GlifiFailure.init` asserisce l'appartenenza alla tabella: ogni failure costruita da un test in
  debug è controllata;
- gli helper che derivavano retry e stato con espressioni locali usano ora i default della tabella;
- `Scripts/check-failure-taxonomy.py`, nel gate, legge la tabella dal sorgente Swift e controlla
  tutti i siti con categoria letterale, anche quelli che nessun test esercita.

## Violazioni trovate e corrette

| Sito | Prima | Dopo |
| --- | --- | --- |
| limiti di byte, package e risorse (`insufficientResources`, 9 siti) | retry `afterCorrection` | `afterConditionsChange` |
| `analysisFailure` con `staleArtifact` | retry `afterCorrection` | `newRequest` |
| `investigation.invalid-history`, rendering, viste (`invariantViolation`) | stato `unchanged` | `validityUnknown` |
| `project.session-closed`, input non valido nel package | retry `never` o `newRequest` | `afterCorrection` |
| `project.source-not-found` (`insufficientData`) | stato `readOnlyRecovery` | `lastCommittedGeneration` |
| `export.noncanonical-manifest` (`corruption`) | stato `validityUnknown` | `readOnlyRecovery` |
| interruzione simulata del commit (`transientIO`) | retry `newRequest` | `transientBackoff` |
| sonda di recovery (`insufficientData`) | retry `never` | `afterCorrection` |

Codici, categorie, operazioni e chiavi di messaggio non cambiano.

## Procedura e risultato

1. `failureTaxonomyIsCompleteAndSelfConsistent`: ogni categoria ha righe non vuote; i default sono
   ammessi per ogni stato preferito; esempi normativi della tabella;
2. `failureHelpersRespectTaxonomyForEveryCategory`: undici helper parametrici producono failure
   ammesse per ogni categoria e chiave `failure.<code>`;
3. l'intera suite (Core e Kit) passa con l'asserzione attiva;
4. `check-failure-taxonomy.py`: 105 siti conformi; controllo negativo con un sito
   `insufficientResources`/`afterCorrection`/`validityUnknown` che fa fallire lo script;
5. la CLI assegna un codice d'uscita a ogni categoria (`invariantViolation` → 70).

## Limiti

L'asserzione è attiva solo nelle build di debug; nelle build di release la conformità è garantita
dallo script statico e dagli helper condivisi. Le espressioni non letterali sono accettate solo se
passano da `GlifiFailureTaxonomy` o producono valori ammessi.

## Esito

**Superato localmente: RQ-058 ha un contratto eseguibile per retry e stato conservato.**
