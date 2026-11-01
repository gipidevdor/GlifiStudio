# 28. Stato di adozione iniziale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-28 |
| Tipo | Capitolo normativo |
| Versione | 1.13.0 |
| Stato | Attivo |
| Responsabile | Amministratore del repository, provvisorio |
| Ultima modifica | 2026-11-01 |
| Approvazione | Registro operativo; baseline normativa ancora proposta |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

| Area | Stato al 2026-09-15 | Azione necessaria |
| --- | --- | --- |
| Standard interno | Completo, proposto | Assegnare responsabili e approvare la baseline |
| Documentazione controllata | Strutturata e verificata automaticamente | Approvare gli information item sostanziali |
| Requisiti | Baseline candidata | Assegnare priorità, metriche e validazione stakeholder |
| Architettura | Separazione prodotto/motore accettata (ADR-0002) | Mantenere il gate `check-architecture` e la superficie Kit |
| Fondazione scientifica | GS-MET-001 e ADR-0013 definiti; nucleo Must con ValidationManifest V0–V4 | Mantenere oracoli; review scientifica esterna e dataset ranking aperti |
| Esperienza utente | GS-UX-001 e UI Must su GlifiKit (G3 candidato, GS-VER-035…071, GS-VER-074…083) | VoiceOver dispositivo, studi UX e soglie G4 |
| Design implementativo | Dieci specifiche GS-DOM–GS-PROD; G1 leggero chiuso; G2 headless chiuso | Chiudere G4/G5 su dispositivi e distribuzione |
| Tracciabilità | Matrice machine-readable; DoR operativa (GS-DOR-001, CMP-014) | Aggiungere scheda DoR a ogni nuova vertical slice |
| Controllo versione | Primo commit pubblicato su `main` nel remote privato canonico | Applicare protezioni server-side quando disponibili |
| Codice e test | Baseline eseguibile macOS/iPadOS, package condiviso, facciata diagnostica e policy runtime coperte da test | Evolvere per vertical slice guidate dai requisiti |
| Ciclo documentale macOS | Target Swift Testing del modello reale, senza app host; creazione non distruttiva e conservazione della sessione su apertura fallita (GS-VER-140) | Verifica con `make test-macos` e nel gate; GUI, file coordination e autorizzazioni sandbox reali restano da validare |
| Toolchain Swift | Apple Swift 6.4, Swift 6 language mode, SwiftPM tools 6.4 e strict concurrency verificati | Rivalutare solo con una toolchain Xcode 27 compatibile o nuova ADR |
| Sicurezza e privacy | GS-SEC-001 completo per asset, trust boundary e THR-001–THR-020; zero telemetria e logging tipizzato | Assegnare responsabile ed eseguire corpus avversario, fuzz, kill test e audit build |
| API e CLI | GS-API-001 pre-1.0 definisce lifecycle, async, failure, stream, exit status e compatibilità; solo status è implementato | Implementare vertical slice e contract test senza promettere ABI prematura |
| Eccellenza ingegneristica Apple | GS-STD-001-29 e ADR-0024 definiscono criteri EA-* e soglie iniziali; presupposti ereditati verificati o configurati, nessun nuovo gate | Introdurre per fase test plan con sanitizer, test UI con `performAccessibilityAudit`, metriche XCTest, DocC, diff API e classi hardware di riferimento (EA-T-01…07, EA-M-01/02) |
| Sostenibilità macOS | Decision table Low Power Mode/termica/memoria/lifecycle implementata nel core | Collegare l'adattatore event-driven e acquisire baseline Instruments col primo flusso lungo |
| GitHub | Remote privato, impostazioni, 20 etichette, Dependabot e audit attivi | Abilitare piano per ruleset, Secret Scanning e push protection |
| CI | Workflow con `static-quality` (Ubuntu), `format-check` e `verify` (Xcode 27), più `app-store-baseline` con cache SPM; esecuzione remota soggetta al budget Actions | Ottenere check verdi su runner dichiarati |
| Coverage e benchmark | Regole definite, soglie non ancora approvate | Introdurre con le prime funzioni e hot path reali |
| App Store | Distribuzione non in elenco approvata; identità, metadati, privacy, icona e gate versionati | Completare prodotto, account Apple, URL, screenshot, dispositivi e TestFlight |
| Rilascio | Preflight e packaging senza firma predisposti; pubblicazione intenzionalmente assente | Assegnare identità di firma e superare ogni gate di submission |
| Licenza | BSD-3-Clause attiva | Definire titolarità e modello contributivo |
| Piattaforme iniziali | macOS 27 e iPadOS 27 approvate | Definire classi hardware e parità |
| Backup | Remote primario attivo; piano definito | Configurare copia indipendente e provare il ripristino |

Un elemento `Configurato` non è `Verificato` finché non esiste un'esecuzione osservata nell'ambiente dichiarato. La baseline locale viene verificata da `make verify`; protezioni, backup e CI remote richiedono evidenze successive.
