# Architecture Decision Records

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-IDX-001 |
| Tipo | Registro delle decisioni architetturali |
| Versione | 0.29.1 |
| Stato | Attivo |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-01 |
| Approvazione | Non applicabile; registro operativo |

Gli ADR documentano le scelte architetturali importanti, il contesto in cui sono state prese e le conseguenze accettate.

## Stati

- **Proposto**: in discussione.
- **Accettato**: decisione vigente.
- **Sostituito**: rimpiazzato da un ADR successivo.
- **Respinto**: valutato e non adottato.

## Indice

- [ADR-0001 — Piattaforme native iniziali: macOS e iPadOS](0001-piattaforme-native-macos-ipados.md) — Accettato
- [ADR-0002 — Separazione tra prodotto e motore](0002-separazione-prodotto-motore.md) — Accettato
- [ADR-0003 — Toolchain e baseline di sviluppo](0003-toolchain-e-baseline-di-sviluppo.md) — Accettato
- [ADR-0004 — Italiano come lingua iniziale](0004-italiano-lingua-iniziale.md) — Accettato
- [ADR-0005 — Interfaccia internazionalizzabile](0005-interfaccia-internazionalizzabile.md) — Accettato
- [ADR-0006 — Baseline applicativa Apple](0006-baseline-applicativa-apple.md) — Accettato
- [ADR-0007 — Denominazione Glifi Studio](0007-denominazione-glifi-studio.md) — Accettato
- [ADR-0008 — Portafoglio tecnologico Apple e strategia Apple silicon](0008-portafoglio-tecnologico-apple-silicon.md) — Accettato
- [ADR-0009 — Repository privato e integrazione controllata](0009-repository-privato-e-integrazione-controllata.md) — Accettato
- [ADR-0010 — GitHub come hosting privato e configurazione dichiarativa](0010-github-hosting-privato-e-configurazione-dichiarativa.md) — Accettato
- [ADR-0011 — Distribuzione App Store non in elenco](0011-distribuzione-app-store-unlisted.md) — Accettato
- [ADR-0012 — Repository GitHub privato operativo](0012-repository-github-privato-operativo.md) — Accettato
- [ADR-0013 — Semantica analitica backend-neutral e Analysis DAG](0013-semantica-analitica-e-analysis-dag.md) — Accettato
- [ADR-0014 — Esperienza guidata da indagini, intenzioni ed evidenze](0014-esperienza-guidata-da-indagini.md) — Accettato
- [ADR-0015 — Baseline Swift 6.4 e modalità linguistica Swift 6](0015-baseline-swift-6-4.md) — Accettato
- [ADR-0016 — Specifiche implementative e baseline prodotto 0.1](0016-specifiche-di-design-e-baseline-prodotto.md) — Accettato
- [ADR-0017 — Osservabilità locale senza telemetria applicativa](0017-osservabilita-locale-senza-telemetria.md) — Accettato
- [ADR-0018 — Runtime cooperativo e sostenibile su macOS](0018-runtime-cooperativo-sostenibile-macos.md) — Accettato
- [ADR-0019 — Sicurezza, API e conformità verificabile](0019-sicurezza-api-e-conformita-verificabile.md) — Accettato
- [ADR-0020 — Loop di qualità, dialetto Swift e CI early-fail](0020-loop-di-qualita-e-dialetto-swift.md) — Accettato
- [ADR-0021 — Storia dell'indagine append-only separata dagli Artifact](0021-storia-indagine-append-only.md) — Accettato
- [ADR-0022 — Export scientifico transazionale e verificabile](0022-export-scientifico-transazionale.md) — Accettato
- [ADR-0023 — Proiezioni PDF/A-2u e CSV verificabili](0023-export-pdf-a2u-csv.md) — Accettato
- [ADR-0024 — Barra di eccellenza ingegneristica di classe Apple](0024-eccellenza-ingegneristica-apple.md) — Accettato
- [ADR-0025 — Estensione analitica post-0.1 e planner-v2](0025-estensione-analitica-planner-v2.md) — Accettato
- [ADR-0026 — Policy di supporto per famiglia (chiusura di DA-029)](0026-policy-di-supporto-per-famiglia.md) — Accettato
- [ADR-0027 — Codebook e codifiche persistite (RF-043)](0027-codebook-e-codifiche-persistite.md) — Accettato
- [ADR-0028 — Invalidazione selettiva degli Artifact all'importazione di fonti](0028-invalidazione-selettiva-alla-reimportazione.md) — Accettato
- [ADR-0029 — Codifica qualitativa nelle app (estensione post-0.1)](0029-codifica-qualitativa-nelle-app.md) — Accettato
- [ADR-0030 — Corpus gold italiano di provenienza esterna](0030-corpus-gold-italiano-esterno.md) — Accettato
- [ADR-0031 — Approvazione numerica con oracoli eseguibili e tolleranze dichiarate](0031-approvazione-numerica-con-oracoli-eseguibili.md) — Accettato

## Modello per i nuovi ADR

Ogni ADR deve contenere titolo, stato, contesto, decisione, conseguenze e, quando utile, alternative considerate. Gli ADR accettati non vengono riscritti per adattarli a decisioni successive.

- [ADR-0032 — Operatori analitici nativi](0032-operatori-analitici-nativi.md) — Ambito accettato; capacità candidate
