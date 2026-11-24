# 23. Gestione di problemi, rischi e incidenti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-23 |
| Tipo | Capitolo normativo |
| Versione | 0.1.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 23.1 Problemi e rischi

Ogni elemento deve avere identificatore, descrizione, probabilità o evidenza, impatto, responsabile, mitigazione e stato. Un rischio accettato **DEVE** indicare chi lo accetta e fino a quando.

## 23.2 Severità dei difetti

| Severità | Criterio |
| --- | --- |
| S0 — Critica | Perdita o esposizione di dati, risultato scientificamente errato non rilevabile, esecuzione di codice o blocco generale senza recupero |
| S1 — Alta | Funzione primaria inutilizzabile, corruzione recuperabile o regressione grave senza workaround ragionevole |
| S2 — Media | Comportamento errato circoscritto con workaround |
| S3 — Bassa | Difetto minore, cosmetico o documentale senza impatto sostanziale |

S0 e S1 **DEVONO** bloccare il rilascio salvo decisione eccezionale documentata dal product owner, responsabile qualità e responsabile sicurezza/dati quando applicabile.
