<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Documentazione

Scegli il percorso che serve al tuo lavoro.

| Per… | Parti da… |
| --- | --- |
| Sviluppare e contribuire | [Ambiente di sviluppo](ambiente-di-sviluppo.md) · [Loop di sviluppo e qualità](loop-di-sviluppo-e-qualita.md) · [Contratto GlifiKit e GlifiCLI](api/README.md) |
| Definire il prodotto | [Requisiti](requisiti.md) · [Esperienza utente](esperienza-utente/README.md) · [Specifiche di design](specifiche-di-design/README.md) |
| Applicare un metodo analitico | [Contratti dei metodi](metodi-analitici/README.md) · [Architettura](architettura.md) · [Glossario](glossario.md) |
| Verificare il lavoro | [Scenari di analisi](pianificazione/scenari-di-analisi.md) · [Tracciabilità](tracciabilita.md) · [Evidenze](evidenze/README.md) · [Roadmap](roadmap.md) |
| Decidere e preparare il rilascio | [Decisioni architetturali](adr/README.md) · [Governo del repository](repository/README.md) · [Preparazione App Store](app-store/README.md) |

## Quali documenti seguire

Lo [standard di progetto](standard-di-progetto.md) è la norma interna principale.
Il [piano di documentazione](piano-documentazione.md) definisce struttura,
metadati, versionamento, revisione e qualità dei documenti.

La documentazione è una baseline candidata controllata. Visione, metodi,
esperienza e dieci specifiche di design hanno ruoli distinti. La
[baseline del prodotto 0.1](specifiche-di-design/10-product-baseline-mvp.md)
(GS-PROD-001) ne delimita il perimetro.

Consulta [tracciabilità](tracciabilita.md) ed [evidenze](evidenze/README.md) per
le capacità implementate, le verifiche riferite alle singole revisioni e le
approvazioni ancora aperte. La completezza dei documenti non equivale a prodotto
completo.

<details>
<summary>Consulta il registro completo dei documenti</summary>

| Campo | Valore |
| --- | --- |
| Identificatore | GS-IDX-001 |
| Tipo | Indice degli information item |
| Versione | 0.20.2 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-22 |
| Approvazione | Non ancora approvato |

| ID | Information item | Scopo | Riferimento | Stato |
| --- | --- | --- | --- | --- |
| GS-STD-001 | [Standard di progetto e indice dei capitoli](standard-di-progetto.md) | Un documento autonomo per ogni argomento normativo del ciclo di vita | ISO/IEC/IEEE 12207:2026 e profilo associato | Proposto |
| GS-DMP-001 | [Piano di documentazione](piano-documentazione.md) | Governo, configurazione e qualità documentale | ISO/IEC/IEEE 15289:2019 | Bozza controllata |
| GS-ID-001 | [Identità e convenzioni di denominazione](identita-del-progetto.md) | Nome canonico, identificatori tecnici e regole d'uso | ADR-0007 | Attivo |
| GS-VIS-001 | [Visione e principi](visione-e-principi.md) | Contesto, finalità, stakeholder, necessità e confini | ISO/IEC/IEEE 29148:2018 | Bozza controllata |
| GS-SRS-001 | [Specifica dei requisiti](requisiti.md) | Requisiti software e attributi di verifica | ISO/IEC/IEEE 29148:2018; ISO/IEC 25010:2023 | Bozza controllata |
| GS-MET-001 | [Specifica normativa dei metodi analitici](metodi-analitici/README.md) | Contratti matematici, statistici, linguistici e algoritmici verificabili | Letteratura scientifica primaria; ADR-0013 | Bozza controllata |
| GS-UX-001 | [Specifica dell'esperienza utente](esperienza-utente/README.md) | Paradigma d'indagine, intenzioni, planner, findings, navigazione e validazione human-centred | ISO 9241-210:2019; Apple HIG; ADR-0014 | Bozza controllata |
| GS-DSG-IDX-001 | [Specifiche di design implementativo](specifiche-di-design/README.md) | Dieci contratti per dominio, dati, lingua, query, analisi, runtime, UI, visualizzazione, validazione e prodotto | GS-DOM-001–GS-PROD-001; ADR-0016 | Bozza controllata |
| GS-SEC-001 | [Threat model e architettura di sicurezza](sicurezza/README.md) | Asset, trust boundary, input ostili, controlli, rischio residuo e gate | NIST SSDF; Apple Platform Security; ADR-0019 | Bozza controllata |
| GS-API-001 | [Contratto GlifiKit e GlifiCLI](api/README.md) | Lifecycle, async, progressi, cancellazione, failure, compatibilità e protocollo headless | Swift API Design Guidelines; ADR-0002; ADR-0019 | Bozza controllata |
| GS-TRC-001 | [Matrice di tracciabilità](tracciabilita.md) | Collega necessità, requisiti, architettura e verifica | ISO/IEC/IEEE 29148:2018 | Bozza controllata |
| GS-AD-001 | [Descrizione dell'architettura](architettura.md) | Stakeholder, concern, viewpoint, view e decisioni | ISO/IEC/IEEE 42010:2022 | Bozza controllata |
| GS-GLO-001 | [Glossario](glossario.md) | Vocabolario comune e termini controllati | Supporta tutti gli information item | Bozza controllata |
| GS-LIC-001 | [Politica di licenza](licenza.md) | Ambito BSD-3-Clause, copyright e materiali di terzi | OSI/SPDX | Attivo |
| GS-LIC-002 | [Provenienza degli algoritmi](algoritmi-e-provenienza.md) | Fonti, avvisi, materiali di test e confini degli strumenti esterni | Fonti primarie e inventario revisionato | Revisione locale con limiti dichiarati |
| GS-I18N-001 | [Baseline linguistica italiana](localizzazione-italiana.md) | Lingua e locale predefiniti dell'analisi testuale | ADR-0004 | Bozza controllata |
| GS-I18N-002 | [Internazionalizzazione dell'interfaccia](internazionalizzazione-interfaccia.md) | Catalogo, chiavi semantiche, formattazione e indipendenza linguistica | ADR-0005 | Bozza controllata |
| GS-APL-* | [Pratiche e portafoglio tecnologico Apple](apple/README.md) | UI, documenti, AI on-device, accelerazione Apple silicon, dati, sistema, qualità e distribuzione | ADR-0006; ADR-0008; documentazione Apple | Attivo |
| GS-DEV-001 | [Ambiente di sviluppo](ambiente-di-sviluppo.md) | Toolchain, workspace, schemi e quality gate locale | [Configurazione](standard/08-gestione-della-configurazione.md), [Swift](standard/12-implementazione-swift.md), [quality gate](standard/20-integrazione-continua-e-quality-gate.md) | Bozza controllata |
| GS-DEV-002 | [Loop di sviluppo e qualità](loop-di-sviluppo-e-qualita.md) | Formattazione, dialetto Swift 6, `make quality` e CI early-fail | ADR-0020; [GS-STD-001-12](standard/12-implementazione-swift.md); [GS-STD-001-20](standard/20-integrazione-continua-e-quality-gate.md) | Bozza controllata |
| GS-REP-* | [Governo del repository](repository/README.md) | Accessi, Git, GitHub, CI, segreti, backup e passaggio futuro a pubblico | ADR-0009; standard di configurazione e sicurezza | Attivo |
| GS-AS-* | [Preparazione App Store](app-store/README.md) | Distribuzione non in elenco, record, metadati, privacy, accessibilità, TestFlight, qualità e submission | ADR-0011; App Review Guidelines | Attivo |
| GS-PLAN-001 | [Roadmap](roadmap.md) | Sequenza di validazione e sviluppo | ISO/IEC/IEEE 15289:2019 | Proposta |
| GS-ISS-001 | [Decisioni aperte](decisioni-aperte.md) | Questioni irrisolte e chiusura mediante ADR | ISO/IEC/IEEE 15289:2019 | Attivo |
| GS-ADR-* | [Registro ADR](adr/README.md) | Decisioni architetturali e rationale | Supporta ISO/IEC/IEEE 42010:2022 | Attivo |
| GS-TST-001 | [Scenari di analisi](pianificazione/scenari-di-analisi.md) | Inventario operativo, workflow e riferimenti ai test condivisi/macOS | GS-STD-001-16; GS-API-003 | Implementato |
| GS-VER-* | [Registro delle evidenze](evidenze/README.md) | Risultati riproducibili dei controlli di qualità | [Modello di evidenza](standard/appendice-c-modello-di-evidenza.md) | Attivo |
| GS-DOR-* | [Registro Definition of Ready](pianificazione/README.md) | Contratti e stato di ingresso delle unità di lavoro | GS-STD-001-07 | Attivo |
| GS-WVR-* | [Registro delle deroghe](deroghe/README.md) | Eccezioni temporanee, mitigazioni, scadenze e piano di rientro | [Disciplina delle deroghe](standard/24-deroghe-e-non-conformita.md) | Attivo |

</details>

<details>
<summary>Consulta convenzioni e fonti</summary>

## Convenzioni

- **Baseline candidata** indica un contenuto ricavato dalle fonti ma non ancora formalmente approvato.
- **Proposta** indica una scelta introdotta per rendere operativa la pianificazione e ancora da approvare.
- **Aperto** indica un tema per cui non esiste ancora una decisione.
- I requisiti usano identificatori permanenti (`NS-*`, `RF-*`, `RQ-*` e `CV-*`) per poter essere citati da issue, test e decisioni.
- I metodi analitici usano `GS-MET-*`; nome, variante, formula, precondizioni e
  classe di determinismo fanno parte del contratto e non possono essere sostituiti
  da un'etichetta generica.
- La famiglia `GS-UX-*` governa semantica dell'interazione e modello mentale senza
  duplicare formule GS-MET o regole specifiche dei profili Apple.
- Le specifiche `GS-DOM-001`–`GS-PROD-001` trasformano quei contratti in design
  implementabile senza duplicarne l'autorità; il loro indice è GS-DSG-IDX-001.
- GS-SEC-001 governa i confini di fiducia trasversalmente; GS-API-001 governa
  l'unico contratto applicativo condiviso da app e CLI senza rendere stabili
  operazioni ancora non implementate.
- La matrice GS-TRC possiede una rappresentazione machine-readable che distingue
  `specified`, `implemented`, `verified` e `blocked`; documentare non equivale a
  promuovere una clausola.
- Le decisioni architetturali importanti vengono registrate come ADR e non riscritte retroattivamente: se cambiano, un nuovo ADR sostituisce il precedente.
- I termini definiti nel glossario mantengono lo stesso significato in tutti gli information item.

## Fonti

- `appunti-1.txt`: visione di prodotto, tecnologie, pipeline e capacità analitiche; il testo termina a metà della sezione 23.
- `appunti 2.txt`: principi e invarianti di ingegneria del software; il testo termina all'inizio della sezione 31.

Le fonti sono materiale di lavoro. In caso di divergenza futura, fanno fede le decisioni esplicitamente approvate e gli ADR accettati.

</details>
