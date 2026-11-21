<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Ricerca indicizzata dei segmenti SpanMap

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-202 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di ottimizzare ancora ogni aspetto |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; GS-DAT-001; RF-009; RF-017; RQ-009; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Ridurre le scansioni complete in sourceRanges e composed usando ricerche sui segmenti ordinati, senza cambiare origine, ordine, coalescenza o classe delle relazioni. |
| requisiti | RF-009, RF-017, RQ-009, RQ-063; correttezza e compatibilità prima delle prestazioni |
| contratto di dominio/API | Indicatore privato derivato dai segmenti, escluso da CodingKeys; ricerca binaria soltanto quando gli intervalli sono non vuoti, ordinati e disgiunti; fallback lineare per le rappresentazioni legacy non conformi decodificate. Identici campi Codable, accettazione e failure precedenti. |
| failure semantics | Categorie e stato conservato invariati; nessuna scrittura nuova o risultato parziale; cancellazione applicabile preservata |
| esperienza prevista | Identici risultati e provenienza; componente headless, nessuna modifica UI o a localizzazione/accessibilità |
| verifica | Lookup sparsi e composizione su mappe sintetiche grandi; confronto completo con riferimento lineare, round-trip e JSON legacy disordinato/sovrapposto; limiti half-open e classi exact/contributive/derivational/synthetic. Baseline prima della patch, Release, un warmup e sette campioni grezzi, input/output confrontati fuori timer; GS-VER-202 candidata e make verify completo |
| dati e migrazione | Nessun nuovo formato, schema, migrazione o modifica di dati esistenti; soltanto strutture effimere locali |
| sicurezza/privacy | Solo dati sintetici deterministici, nessuna rete, privilegio, dipendenza o log di corpus; input avversari nei test |
| prestazioni/sistema | Conservare soltanto il beneficio osservato e dichiarare costo di preparazione, memoria, cache, termica e risparmio energetico; nessuna soglia G4 o promessa end-to-end nuova |
| tracciabilità | CMP-202 inizialmente specified; codice, regressioni, misure, evidenza e registri aggiornati nello stesso lotto |
| decisioni e recupero | Contratto vigente e ADR applicabili conservati; nessuna scelta architetturale nuova, rollback per revert puntuale |

**Ready** prima del coding. Il codice produttivo resta fermo fino alla baseline.
La revisione indipendente verifica anche equivalenza e limiti delle misure.
