<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Codifica delle identità canoniche

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-179 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta di ottimizzare evitando sovrapposizioni alle altre chat |
| Riferimenti | GS-STD-001-12 § 12.7; GS-STD-001-17; GS-STD-001-29; GS-VER-207; GS-VER-178; RQ-009; RQ-023; RQ-028; RQ-042; RQ-063 |

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Ridurre le formattazioni ripetute dei digest pubblici di QueryAST, richieste di accordo e revisioni di report; tre soli produttori Core. |
| contratto | Riusare canonicalSHA256Digest interno già esistente; stessi input a CryptoKit, encoder, opzioni JSON, prefisso, minuscole, ordine e identità complete. |
| failure semantics | Nessuna modifica a validazione, ordine dei controlli, errori tipizzati, decoder o formati; stesse API pubbliche e operazioni Kit/CLI. Nessuna cache dei digest o nuova dipendenza. |
| verifica | Riferimenti completi con formatter precedente e JSON indipendente; query eterogenee/composte, accordi nominali/numerici con missing e Unicode, report completi e decodifica. Fixture piccole/grandi e regressioni dei rifiuti già esistenti. |
| prestazioni | Supporto Release opt-in già disponibile nei test Core, un warmup e sette campioni; preparazione, uguaglianza e SHA completi fuori timer. Baseline e harness congelati prima della patch; ripetizioni ravvicinate, RSS e contesa dichiarati. Nessuna soglia nuova. |
| ownership | Agente query/accordo: nuovo test dedicato; agente report: secondo test dedicato; agente integrazione: tre sostituzioni produttive dopo la baseline; coordinatore: documenti, misure, gate e chiarimento del solo testo measurementScope del supporto test. |
| esclusioni | Nuove varianti analitiche, numerica, multivariata, resampling, GUI, Kit, CLI, sessioni, ProjectPackage, Engine e file occupati dalle altre chat. Nessuna modifica all'helper digest condiviso. |
| dati e migrazioni | Dati sintetici deterministici, nessuna rete o corpus reale; nessuna migrazione o nuovo formato persistente. |
| tracciabilità | CMP-187; GS-VER-179; codice, test, documenti e riscontri nello stesso incremento. |
| uscita | Conservare cambiamenti corretti con beneficio misurato; revisione indipendente, make verify completo, controlli documentali finali e pulizia dei soli artefatti del lotto. |

**Ready** sulla base pubblicata `db2bac1`, nel ramo isolato
`codex/canonical-producers-20261122`, prima di modificare test, harness e
produzione. I tre file risultano liberi nei worktree controllati. La baseline
precede ogni sostituzione produttiva; i rapporti prestazionali restano locali
e non chiudono approvazioni scientifiche, audit dell'interfaccia o G4.

Il supporto precisa che soltanto lo SHA di verifica è escluso dal timer:
encoder e SHA del produttore pubblico sono inclusi nelle operazioni misurate.
La precisazione è congelata prima della baseline e non modifica il timer.
