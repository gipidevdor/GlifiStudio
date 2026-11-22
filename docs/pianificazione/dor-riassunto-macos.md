<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Riassunto estrattivo nel laboratorio macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-190 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di completamento analitico; ADR-0033; GS-PLAN-002 |
| Riferimenti | RF-042; RF-077; RF-078; RQ-058; GS-MET-001-19; GS-UX-001-17; GS-DOR-013 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Flusso contestuale macOS di riassunto tramite GlifiKit: scope visibile, budget frasi/token, due scoring e ridondanza assente/MMR con λ; frasi estratte in ordine sorgente, metodo e lineage ispezionabili |
| requisiti | RF-042, RF-077, RF-078, RQ-058; richiesta effettiva rispettata, riuso persistente invariato, selezione e testo identici alla API; fonte originale evidenziata soltanto con mapping SpanMap valido |
| dominio/API | Core resolved e DTO selected aggiungono `sourceRanges`; gli offset esistenti rimangono del testo estratto e i commenti DocC lo dichiarano; DTO precedenti decodificano mapping vuoto, senza inventarlo; app dipende soltanto da Kit |
| failure semantics | Errori GlifiKit preservati, nessuna correzione silenziosa di budget/λ; risultato precedente conserva proprio lineage su failure; mapping vuoto significa non disponibile e apre fonte intera senza highlight, con indicazione esplicita |
| esperienza prevista | GS-UX-001-17, prima del codice; nessuna generazione, nessun nuovo finding scientifico; dettaglio progressivo, testi it/en, componenti nativi, tastiera e label accessibili; UI dedicata solo macOS |
| verifica | Core/Kit: Markdown, BOM e Unicode multibyte, intervalli estratti distinti dall'originale, sourceRanges esatti o contributivi da SpanMap, riuso Artifact e decode legacy; modello macOS: parametri/scope, frasi, fonte, failure e cambio progetto; gate `verify-macos` e preflight, GS-VER-190 candidata |
| dati e migrazione | Artifact e descriptor persistiti invariati; mapping derivato al momento della risoluzione dalle revisioni incorporate; nessuna migrazione o formato di progetto nuovo |
| sicurezza/privacy | Solo fonti del progetto e API Kit/Core; nessuna rete, dipendenza, entitlement, testo generato o mapping approssimato; coordinate invalide falliscono secondo tassonomia esistente |
| prestazioni/sistema | Riutilizzare calcolo e admission esistenti; mapping bounded al resolver già presente, nessun caricamento aggiuntivo nella view o calcolo sul Main Actor; limiti corpus invariati |
| tracciabilità | CMP-190 inizialmente `specified`; RF-042/RF-077/RF-078, TV-036/TV-058/TV-071, specifica UX/API, evidenza e CHANGELOG nello stesso cambiamento |
| decisioni e recupero | ADR-0033 approva solo estensione app post-0.1 e mapping; metodi GS-MET-001-19 invariati; rollback per revert senza migrazione, preservando GS-VER-185…188 |

**Ready** prima del codice Core/Kit e applicativo. La baseline storica 0.1 resta
invariata; iPadOS, B/BM25, C/frequenze-MTLD, famiglie assenti, GUI manuale,
validazione con utenti e G4 non sono dichiarati completati da questo incremento.

## Avanzamento

Mapping Core/Kit verificato con due test mirati; modello macOS con 19 test
dichiarati e 20 esecuzioni superate, senza failure o skip. CMP-190 `verified`
dopo il gate integrato macOS; nessuna chiusura di GUI manuale o G4.

## Verifica finale del profilo macOS

Gate e preflight automatici superati sullo snapshot identificato in
[GS-VER-188](../evidenze/GS-VER-188-gate-macos.md). La clausola dell'incremento è
`verified` soltanto nel perimetro documentato; nessuna chiusura di GUI manuale,
VoiceOver, finestre reali, autosave, iPadOS o G4 è inferita.
