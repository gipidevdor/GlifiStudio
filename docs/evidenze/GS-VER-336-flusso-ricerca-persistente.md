<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-336 — Dataset e lavoro di ricerca persistenti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-336 |
| Tipo | Evidenza di integrazione Core, Kit, CLI e GUI macOS |
| Versione | 1.0.0 |
| Stato | In verifica |
| Responsabile | Codex, coordinamento della copia condivisa |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta sui quattro divari KH, escluso il multilingua |
| Riferimenti | ADR-0047; GS-API-004; GS-API-005; GS-API-006; GS-UX-001-17 |

## Ambito e stato delle verifiche

CSV/XLSX con anteprima, mapping e provenienza; metadati, sottoinsiemi e
preparazione italiana persistenti; acquisizione e ripristino delle analisi,
variabili derivate e collegamenti ai rapporti. Modifiche preesistenti preservate.

| Controllo | Esito osservato |
| --- | --- |
| Build Debug macOS senza firma | Superata prima delle rifiniture degli archivi; da ripetere sul finale |
| Primo mirato preparazione e stato | 14 test superati; riapertura, conflitti, cache e query preparate |
| Parser e integrazione tabellare | 3 test progetto e parser superati nel primo integrato; caso DTD ignorata corretto con rifiuto anticipato e regressione |
| Parità nativa/trasporto ricerca | Primo integrato ha rilevato differenze nella canonicalizzazione dei risultati; causa corretta, riverifica richiesta |
| Test app di editor e archivi | Predisposti; esiti da registrare |
| `make verify` macOS | Da eseguire sul contenuto finale |
| Audit percettivo e assistivo | Non attestato dai test di modello |

Gli esiti intermedi non attestano il contenuto finale o i gate esterni G4/G5.
XLS binario, formule, macro e collegamenti esterni sono rifiutati dal profilo
documentato; nessuna nuova lingua di analisi è introdotta.

## Pulizia

Le fixture possiedono directory temporanee e cleanup. Sono conservate cache
attive, evidenze utili, artefatti di altre attività e file dell'utente.
