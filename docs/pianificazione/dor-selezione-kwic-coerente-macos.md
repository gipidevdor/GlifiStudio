<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Selezione KWIC e fonte coerenti su macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-230 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Nuova richiesta di correzioni e ottimizzazioni; difetto della coppia selezione/fonte confermato |
| Riferimenti | RF-009; RF-017; RQ-011; RQ-047; RQ-058; GS-UX-001-09; GS-DOR-166; GS-STD-001-07 |

## Problema e criterio di stop

`selectQueryMatch` modifica l'identificatore selezionato prima dell'admission di
`run` e prima del caricamento della fonte. Durante busy una selezione B può
quindi restare associata al testo A; la view applica gli intervalli B al testo A.
La correzione macOS pubblica la coppia soltanto dopo il caricamento riuscito,
senza await fra le assegnazioni; busy o failure conservano la coppia valida.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Solo selezione KWIC e relativa presentazione macOS: identificatore selezionato e testo fonte pubblicati insieme dopo fetch riuscito; nessuna selezione anticipata quando il modello rifiuta un'operazione occupata; iPadOS conserva il ramo esistente |
| requisiti | RF-009/RF-017 e RQ-011/047/058; identità della revisione e intervalli originali coerenti con il testo mostrato, coppia precedente conservata su busy/failure, retry riuscito |
| contratto di dominio/API | `selectQueryMatch` resta asincrono e usa sessione/DTO Kit esistenti; fetch in variabile locale dentro `run`, quindi pubblicazione sincrona sul Main Actor, senza sospensione intermedia. `run` rimane proprietario di busy e cleanup; nessuna API pubblica, formato o task owner nuovo |
| failure semantics | Load/session failure propagata mediante gli errori tipizzati esistenti; nessuna sostituzione parziale di selezione o testo e nessun recupero fittizio. Rendering fail-closed: intervalli della selezione applicati soltanto alla revisione corrispondente; niente offset estratti usati sui byte originali |
| esperienza prevista | Stessa azione KWIC e fonte nativa; il pulsante macOS può essere disabilitato durante busy ma il guard del modello resta necessario; nessun nuovo flusso o messaggio, componenti e comportamento di tastiera/accessibilità esistenti preservati |
| verifica | RED prima del fix con due fonti distinte e query che produca match di entrambe; opener GS-DOR-166 sospeso tramite continuazione mantiene busy deterministico mentre si tenta B dopo aver mostrato A. GREEN per coppia invariata durante busy, failure del caricamento con precedente coppia conservata e retry riuscito; coerenza revisione/intervalli nella presentazione; gate/preflight macOS sul nuovo contenuto, GS-VER-230 candidata |
| dati e migrazione | Solo stato effimero della selezione; nessuna modifica di query, Artifact, coordinate, SpanMap, package, storia o migrazione; i risultati 198/199 restano storici |
| sicurezza/privacy | Fonti autorizzate della sessione e confini Kit invariati; nessun contenuto o path nuovo nei log, rete, entitlement o dipendenza; nessun highlight attribuito a revisione diversa |
| prestazioni/sistema | Stesso caricamento Kit e stessi bounds; nessuna nuova elaborazione o I/O onerosa sul Main Actor, attesa attiva o scansione globale. È una correzione di stato, senza claim prestazionale o benchmark richiesto per questo spostamento di assegnazioni |
| tracciabilità | CMP-230 inizialmente `specified`; RF-009/RF-017, TV-003/TV-058/TV-071, nuova evidenza, programma e CHANGELOG nello stesso incremento; nessuna promozione prima dei risultati |
| decisioni e recupero | Invariante di provenienza già previsto da GS-UX-001-09; nessuna nuova ADR o soglia. Revert puntuale macOS senza migrazione, preservando programmi 171/172/205–208 |

**Ready** prima della patch di produzione. Le prove sono automatiche: nessuna
attestazione di finestre SwiftUI reali, VoiceOver, file provider, iPadOS o G4.
Una verifica di altri selettori visuali rimane distinta finché non ha difetto e
contratto confermati; non entra implicitamente in questa correzione.
