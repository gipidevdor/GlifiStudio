<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Roadmap iniziale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-PLAN-001 |
| Tipo | Piano di validazione e sviluppo |
| Versione | 1.2.1 |
| Stato | Attivo |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Allineata a GS-PROD-001 e allo stato G1/G2 del percorso produttivo 0.1 |
| Riferimento | ISO/IEC/IEEE 15289:2019, profilo tailored |

## Natura del documento

Questa roadmap è subordinata alla baseline
[GS-PROD-001](specifiche-di-design/10-product-baseline-mvp.md). Riduce per primi i
rischi di `.glifi`, SpanMap, QueryAST, Analysis DAG, runtime bounded e navigazione;
le capacità post-MVP non entrano accidentalmente nelle prime fasi.

Stato storico osservato al 2026-09-17: **Fase 0/G1 formale leggera chiusa**; **Fase 1/G2
headless sostanzialmente realizzata** (evidenze GS-VER-018…033); **Fase 2** è il
focus produttivo (UI Must sul Kit esistente).

Riconciliazione documentale del 2026-11-21: il percorso Must e gli incrementi
successivi dispongono delle evidenze locali citate nelle rispettive fasi. La
candidatura funzionale G3 non chiude G3 formale, G4 o G5
([GS-VER-057](evidenze/GS-VER-057-checklist-candidatura-g3.md)). Le verifiche
storiche non attestano il gate completo della copia condivisa corrente;
implementazioni concomitanti e loro verifiche restano distinte.

## 1. Fase 0 — Decisioni e prove di fattibilità

Obiettivo: rendere misurabili i vincoli prima di stabilizzare l'architettura.

Uscita registrata: gate **G1 leggero** — GS-PROD Must congelati, ADR-0002 accettato,
owner minimi su DOM/DAT/ANA/UI/VAL/PROD, decisioni hardware/benchmark/CODEOWNERS
parcheggiati se non bloccano la UI slice.

## 2. Fase 1 — Vertical slice headless

Obiettivo: dimostrare l'intera catena senza GUI.

```text
TXT/Markdown UTF-8 → `.glifi` → normalizzazione/SpanMap → `it-token-v1`
                  → QueryAST/KWIC → Artifact/Evidence
```

**Stato:** realizzato e verificato localmente (package, import, query, profilo,
keyness, planner, execute, investigation, export via Core/Kit/CLI). Uscita: gate
**G2** architetturale per il percorso headless.

Restano aperti recovery power-loss completa e indice inverted streaming. Il gold
italiano su prosa reale è disponibile e verificato per il perimetro di
[GS-VER-138](evidenze/GS-VER-138-gold-italiano-su-prosa-reale.md): un solo capitolo,
senza annotazioni lemma/POS/NER né soglie assolute approvate; la copertura
linguistica rappresentativa resta da ampliare. La UI nativa Must è realizzata
nella Fase 2 e non è più una capacità interamente assente.

## 3. Fase 2 — Primo flusso interattivo (focus corrente)

Obiettivo: offrire un percorso utente completo nelle applicazioni native macOS e iPadOS.

Stato registrato al 2026-09-17: **candidato funzionale G3** (GS-VER-035…071,
GS-VER-074…083). GS-VER-057 mantiene aperto G3 formale; audit dispositivo, studi
UX e gate G4/G5 restano aperti anche dopo gli incrementi successivi.

Il focus corrente è completare prima macOS; lo sviluppo dedicato iPadOS è
rimandato secondo ADR-0033. I lotti applicativi precedenti usavano soli test
automatici. La successiva [ADR-0034](adr/0034-riprogettazione-gui-e-laboratorio-avanzato.md)
autorizza la riprogettazione della GUI e l'accesso agli operatori già realizzati,
con risultati avanzati di sessione e osservazione delle finestre quando possibile
([GS-VER-222](evidenze/GS-VER-222-riprogettazione-gui.md)). Le evidenze storiche di build
macOS/iPadOS restano valide per le revisioni dichiarate, senza sostituire audit
GUI, VoiceOver o prove su dispositivo. L'interfaccia essenziale dispone di
verifiche automatiche locali in
[GS-VER-150](evidenze/GS-VER-150-interfaccia-essenziale.md), con audit UI aperti.

- creazione e apertura di un progetto `.glifi`;
- importazione TXT/Markdown con avanzamento e errori non distruttivi;
- domanda, intenzione e scope con CollectionProfile e piano `planner-mvp-v1`;
- esecuzione del piano con stati applicabili/`insufficientEvidence`;
- analisi corpus e confronto keyness anche come azioni dirette in UI;
- ricerca QueryAST/KWIC e salto a coordinate di fonte;
- catena Finding → Evidence → Caveat / ranking / supporto con salto alla fonte;
- storia Investigation append-only, selezione editoriale e Report;
- export PDF/Markdown/CSV/JSON con manifest di provenance;
- ValidationManifest V0–V4 per profilo corpus, keyness, query, export, planner,
  interpretazione, storia Investigation ed esecuzione piano;
- parity dello stesso piano via GlifiKit/GlifiCLI;
- rispetto continuo di GS-SEC/GS-API sui confini Kit e CLI.

Uscita: gate **G3** feature-complete 0.1 sul percorso Must.

## 4. Fase 3 — Documenti e corpus ricchi

Obiettivo: estendere acquisizione e analisi preservando la stessa pipeline.
**Fuori dalla baseline 0.1**: PDF, OCR, formati office, metodi Should.
La richiesta esplicita del 2026-11-22 autorizza l'incremento PDF/EPUB di
ADR-0044 e GS-DOR-310: PDFKit, Vision e importatore EPUB bounded. La sua
verifica è distinta da G3 formale/G4/G5; formati office restano aperti.

## 5. Fase 4 — Analisi avanzata

Obiettivo: capacità specialistiche dopo la stabilizzazione dei dati fondamentali.
**Esplicitamente post-MVP:** CA/PCA/topic, embedding, Foundation Models, sync.

Stato storico al 2026-09-19: l'incremento analitico post-0.1 (ADR-0025, programma GS-DOR-002) ha già
portato in GlifiCore, GlifiKit, CLI e planner-v2 contingenza, dispersione, similarità, statistica
inferenziale e non parametrica, collocazioni, reti, CA/PCA/LSA/NMF e clustering, verificati contro
oracoli indipendenti (GS-VER-084…111), con findings secondo ADR-0026.

Gli incrementi successivi documentano capacità già realizzate che non vengono
riaperte come nuovi task:

- intenzioni estese e viste dedicate derivate dagli Artifact nelle app
  ([GS-VER-113](evidenze/GS-VER-113-intenzioni-estese-nelle-app.md),
  [GS-VER-114](evidenze/GS-VER-114-viste-dei-risultati-estesi.md)); restano aperti
  copertura di ogni operazione e parametro diretto, audit assistivi e resa su
  dispositivo;
- codebook e codifiche persistite, accordo, integrazione nelle app e selezione
  strutturata per frasi o caratteri (GS-VER-126…129); la selezione diretta con
  puntatore e gli audit su dispositivo restano distinti;
- famiglie native di libreria comprendenti MDS, SOM, CLARA, Naive Bayes e LDA,
  con verifiche numeriche e trasporto Kit/CLI
  ([GS-VER-160](evidenze/GS-VER-160-operatori-analitici-nativi.md),
  [GS-VER-161](evidenze/GS-VER-161-revisione-scientifica-operatori.md),
  [GS-VER-162](evidenze/GS-VER-162-parita-operatori-kit-cli.md)). Le varianti e i
  rispettivi manifest conservano il proprio stato scientifico; ADR-0032 non
  estende automaticamente progetto persistente, planner o UI. L'accesso UI
  successivo è autorizzato separatamente da ADR-0034 e mantiene i risultati in
  memoria distinti dagli Artifact persistiti.

Il completamento algoritmico di GS-DOR-168 e il laboratorio macOS di
[GS-PLAN-002](pianificazione/programma-analisi-testuale-macos.md) dispongono di
evidenze per incremento: il codice presente nella copia condivisa non
ne attesta da solo la verifica o la promozione scientifica. Embedding, Foundation
Models e sincronizzazione restano fuori dal perimetro iniziale.

## 6. Principio di rilascio

Ogni fase deve lasciare il sistema corretto, misurabile e utilizzabile. I gate G4 e
G5 aggiungono dispositivi fisici, accessibilità, performance, sicurezza, TestFlight,
firma, App Review e approvazione unlisted. Nessuna fase successiva giustifica un
placeholder o una regressione nel percorso Must.
