<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Registro Definition of Ready

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-IDX-001 |
| Tipo | Registro delle schede Definition of Ready |
| Versione | 1.6.30 |
| Stato | Attivo |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Non applicabile; registro operativo |

Le schede DoR sono gate di ingresso al coding (GS-STD-001-07). Ogni unità di
lavoro sostanziale **DEVE** avere una scheda `Ready` o `Ready con rischio
accettato` prima del primo cambiamento implementativo.

## Focus corrente

Per richiesta esplicita dell'iniziatore, completare e auditare prima macOS. Lo
sviluppo dedicato iPadOS è rimandato; i controlli di regressione condivisi restano
attivi. Le evidenze del modello e dei gate locali non chiudono audit GUI,
dispositivi o G4. L'incremento GS-VER-185 è preservato.

Il [programma complementare macOS GS-PLAN-180](programma-complementare-macos.md)
distribuisce quattro agenti su query, feedback statico, revisione e integrazione,
preservando i confini del lavoro già in corso nell'altra chat.

## Indice

- [GS-DOR-302 — Robustezza trasversale della baseline](dor-robustezza-trasversale.md) — Ready; query, ingressi CLI, chiusura macOS e proprietà delle cache

- [GS-DOR-173 — Layout e visite dei kernel analitici](dor-layout-e-visite-analitiche.md) — Ready

- [GS-DOR-275 — Parità continua fra GlifiKit e CLI](dor-parita-continua-kit-cli.md) — Ready; trasporto condiviso, parametri completi e inventario pubblico derivato dal compilatore

- [GS-DOR-222 — Riprogettazione ergonomica della GUI](dor-riprogettazione-gui.md) — Ready con rischio accettato; nuova autorizzazione applicativa, verifiche autonome

- [GS-DOR-230 — Selezione KWIC e fonte coerenti su macOS](dor-selezione-kwic-coerente-macos.md) — Ready; selezione e fonte verificate sul checkpoint macOS ffbfb431
- [GS-DOR-231 — Lookup delle etichette fonte nelle viste macOS](dor-indice-fonti-ui-macos.md) — Ready; lookup misurato e verificato sul checkpoint macOS ffbfb431
- [GS-DOR-232 — Selezione visuale e contesto fonte coerenti su macOS](dor-selezione-visuale-coerente-macos.md) — Ready; selezione e policy senza fonte verificate sul checkpoint macOS ffbfb431

- [GS-DOR-176 — Cancellazione nelle repliche bootstrap](dor-cancellazione-resampling.md) — Ready

- [GS-DOR-175 — Integrità degli export scientifici](dor-integrita-export-viste.md) — Ready

- [GS-DOR-174 — Betweenness con molti cammini minimi](dor-betweenness-cammini-estremi.md) — Ready
- [GS-DOR-177 — Buffer indicizzati della betweenness](dor-betweenness-indicizzata.md) — Ready
- [GS-DOR-178 — Codifica dei digest degli export visuali](dor-digest-export-viste.md) — Ready
- [GS-DOR-179 — Codifica delle identità canoniche](dor-identita-canoniche.md) — Ready


- [GS-DOR-172 — Query sparse e qualità del clustering](dor-query-sparse-e-silhouette.md) — Ready

- [GS-DOR-171 — Integrazione e pubblicazione degli algoritmi](dor-integrazione-algoritmi.md) — Ready
- [GS-DOR-170 — Raffinamento di memoria e calcolo analitico](dor-raffinamento-algoritmi.md) — Ready
- [GS-DOR-169 — Ottimizzazione misurata degli algoritmi](dor-ottimizzazione-algoritmi.md) — Ready

- [GS-DOR-198 — Confronto keyness completo nel client macOS](dor-keyness-macos.md) — Ready; estensione E e ponte del livello di confidenza Kit, verifica autonoma
- [GS-DOR-199 — Identità e limiti del riuso keyness](dor-identita-keyness-macos.md) — Ready; dipendenza di correttezza del confronto E

- [GS-DOR-168 — Completamento degli algoritmi analitici](dor-completamento-algoritmi.md) — Ready

- [GS-DOR-001 — Percorso produttivo 0.1](dor-percorso-produttivita-0-1.md) — Ready
- [GS-DOR-002 — Programma dell'incremento analitico post-0.1](dor-incremento-analitico-post-0-1.md) — Ready con rischio accettato
- [GS-DOR-003 — Programma di completamento dei metodi specificati](dor-completamento-metodi.md) — Ready
- [GS-DOR-004 — Programma di robustezza e contratti trasversali](dor-robustezza-e-contratti.md) — Ready
- [GS-DOR-005 — Programma di lineage componibile e parità dei client](dor-lineage-e-parita.md) — Ready
- [GS-DOR-006 — Programma di privacy delle failure e revisioni delle fonti](dor-privacy-e-revisioni.md) — Ready
- [GS-DOR-007 — Codebook e codifiche persistite (ADR-0027)](dor-codebook-e-codifiche.md) — Ready
- [GS-DOR-008 — Codifica qualitativa nelle app](dor-codifica-nelle-app.md) — Ready con rischio accettato
- [GS-DOR-009 — Selezione libera del passaggio](dor-selezione-libera-del-passaggio.md) — Ready con rischio accettato
- [GS-DOR-010 — Invalidazione selettiva alla reimportazione (ADR-0028)](dor-invalidazione-selettiva.md) — Ready con rischio accettato
- [GS-DOR-011 — Accessi ai file persistiti del package](dor-accessi-file-package.md) — Ready
- [GS-DOR-013 — Riassunto estrattivo deterministico (GS-MET-001-19)](dor-riassunto-estrattivo.md) — Ready
- [GS-DOR-020 — Interfaccia essenziale](dor-interfaccia-essenziale.md) — Ready con rischio accettato; registrazione per integrazione

- [GS-DOR-160 — Operatori analitici delle famiglie KH Coder](dor-operatori-analitici.md) — Ambito autorizzato

- [GS-DOR-162 — Richieste analitiche riproducibili](dor-richieste-analitiche.md) — Ready

- [GS-DOR-163 — Integrità dei documenti macOS](dor-documenti-macos.md) — Ready

- [GS-DOR-164 — Stato della presentazione dopo un'importazione parziale](dor-importazione-parziale.md) — Ready

- [GS-DOR-165 — Ownership della cancellazione nel modello macOS](dor-cancellazione-modello-macos.md) — Ready; implementazione e profilo automatico macOS verificati

- [GS-DOR-166 — Riapertura attraverso il ciclo documentale macOS](dor-riapertura-nativa-macos.md) — Ready; implementazione e profilo automatico macOS verificati

- [GS-DOR-167 — Profilo esplicito di verifica macOS](dor-gate-macos.md) — Ready; implementazione e profilo automatico macOS verificati

- [GS-DOR-180 — Feedback statico delle failure](dor-controlli-statici-failure.md) — Ready
- [GS-DOR-181 — Profondità dell'AST delle query testuali](dor-profondita-query-testuale.md) — Ready

- [GS-PLAN-002 — Programma di completamento dell’analisi testuale macOS](programma-analisi-testuale-macos.md) — Attivo; inventario e backlog distinti dalla disponibilità API

- [GS-DOR-190 — Riassunto estrattivo nel laboratorio macOS](dor-riassunto-macos.md) — Ready; implementazione e profilo automatico macOS verificati

- [GS-DOR-191 — Ranking BM25 nel laboratorio macOS](dor-bm25-macos.md) — Ready; implementazione e profilo automatico macOS verificati

- [GS-DOR-192 — Frequenze, n-grammi e MTLD nel laboratorio macOS](dor-frequenze-mtld-macos.md) — Ready; implementazione e profilo automatico macOS verificati

- [GS-DOR-182 — Runtime macOS guidato dagli eventi](dor-runtime-eventi-macos.md) — Ready
- [GS-DOR-183 — Verifica bounded del manifest candidato](dor-manifest-candidato.md) — Ready

- [GS-DOR-200 — Ottimizzazione delle letture verificate](dor-ottimizzazione-letture-verificate.md) — Ready
- [GS-DOR-201 — Normalizzazione costante del termine query](dor-ottimizzazione-termine-query.md) — Ready

- [GS-DOR-193 — Contenuto accessibile delle fonti macOS](dor-contenuto-accessibile-macos.md) — Ready; correzione statica e build macOS verificate, audit VoiceOver aperto

- [GS-DOR-194 — Anteprima export macOS fuori dal Main Actor](dor-anteprima-export-macos.md) — Ready; implementazione e profilo automatico macOS verificati

- [GS-DOR-195 — Cancellazione delle analisi dirette macOS](dor-cancellazione-analisi-dirette-macos.md) — Ready; implementazione e profilo automatico macOS verificati

- [GS-DOR-202 — Ricerca indicizzata dei segmenti SpanMap](dor-ottimizzazione-spanmap-indicizzata.md) — Ready

- [GS-DOR-203 — Riuso dei confini dei token speciali](dor-ottimizzazione-token-speciali.md) — Ready

- [GS-DOR-204 — Indice locale dei riferimenti Evidence nel CSV](dor-ottimizzazione-indice-export-csv.md) — Ready

- [GS-DOR-197 — Ponderazione TF/TF-IDF nel laboratorio macOS](dor-ponderazione-termini-macos.md) — Ready; nuovo turno, verifica autonoma

- [GS-DOR-196 — Collegamento dei documenti macOS dopo operazioni occupate](dor-attach-documentale-macos.md) — Ready; nuovo turno, verifica autonoma

- [GS-DOR-205 — Coda ordinata del DAG analitico](dor-ottimizzazione-coda-dag.md) — Ready

- [GS-DOR-206 — Appartenenza indicizzata nella proiezione CA](dor-ottimizzazione-proiezione-ca.md) — Ready

- [GS-DOR-207 — Validazione e codifica esadecimale dei digest](dor-ottimizzazione-codifica-digest.md) — Ready

- [GS-DOR-208 — Supporto condiviso dei benchmark dei test](dor-ottimizzazione-supporto-benchmark-test.md) — Ready

- [GS-DOR-223 — Copertura funzionale del core nell’app](dor-copertura-core-app.md) — Ready con rischio accettato; ADR-0041

- [GS-DOR-273 — Barriera di reset dei laboratori macOS](dor-barriera-reset-laboratori-macos.md) — Ready; Gate e preflight macOS superati sul checkpoint ea48ba88/base137; iPadOS, GUI manuale e G4 esclusi

- [GS-DOR-274 — Presentazione corpus coerente su macOS](dor-presentazione-corpus-coerente-macos.md) — Ready; Gate e preflight macOS superati sul checkpoint ea48ba88/base137; iPadOS, GUI manuale e G4 esclusi

- [GS-DOR-233 — Completamento delle varianti native KH Coder](dor-completamento-kh-coder.md) — Ready per prosecuzione e verifica; registrazione successiva all’avvio autorizzato

- [GS-DOR-260 — Integrazioni native Apple coordinate](dor-integrazioni-native-apple.md) — Ready; letture bounded, attività macOS, comandi nativi e candidato Accelerate misurato



- [GS-DOR-234 — Riverifica di correttezza e completezza KH](dor-riverifica-correttezza-kh.md) — Ready per il gate delle correzioni e della mappa di copertura

- [GS-DOR-280 — Struttura e coesione del codice](dor-struttura-e-coesione-del-codice.md) — Ready; responsabilità, lifecycle e commit condivisi

- [GS-DOR-300 — Chiusura delle lacune funzionali KH Coder](dor-completezza-funzionale-kh.md) — Ready; Core/Kit/CLI e verifica delle varianti pubbliche

- [GS-DOR-303 — Test degli scenari di analisi](dor-scenari-di-analisi.md) — Ready; [piano GS-TST-001](scenari-di-analisi.md) e matrice eseguibile

- [GS-DOR-304 — Componenti e campi nativi nei laboratori macOS](dor-hig-laboratori-macos.md) — Ready; implementazione, gate e preflight macOS superati sul checkpoint 9c9e0098; audit interattivi aperti

- [GS-DOR-306 — Progetto Xcode completo e verificabile](dor-progetto-xcode-completo.md) — Ready; gate, nativi Debug/Release e preflight macOS superati sul checkpoint 328169f7; limiti interattivi e nuovo Core 305 separati

- [GS-DOR-286 — Operatori tipizzati e failure coese](dor-operatori-tipizzati-e-failure-coese.md) — Ready; invarianti del parser e policy Kit condivisa
