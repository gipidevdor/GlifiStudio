<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Riapertura attraverso il ciclo documentale macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-166 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.1.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Completamento macOS richiesto dall'iniziatore; confine nativo con dipendenza iniettabile |
| Riferimenti | GS-STD-001-07; RF-001; RQ-004; GS-APL-001; GS-APL-005; ADR-0006 |

## Problema e criterio di stop

Le tre azioni Riapri del client macOS riaprono una sessione nel modello corrente,
senza passare dal documento della finestra. La riapertura deve risolvere il
bookmark e inoltrare l'URL all'azione documentale nativa, conservando la sessione
e lo stato della finestra chiamante. Una prova Foundation rivela inoltre che la
combinazione macOS `.withSecurityScope` e `.minimalBookmark` rifiuta la creazione
del bookmark; la sola `.withSecurityScope` riesce.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Creare bookmark macOS con la sola `.withSecurityScope`, poi tutte le azioni Riapri risolvono il bookmark e chiamano una sola volta l'opener nativo della view; nessun percorso alternativo macOS che sostituisce direttamente la sessione |
| requisiti | RF-001, RQ-004; URL corretto inoltrato, snapshot/query/profilo/piano e URL del modello chiamante invariati; errore non distruttivo |
| dominio/API | Overload interno macOS-only di `reopenLastProject` con azione `@MainActor (URL) async throws -> Void` iniettabile; la view fornisce `openDocument`; nessun nuovo file/target o API Kit/Core |
| failure semantics | Bookmark assente o non risolvibile: failure esistente e nessuna chiamata all'opener; errore dell'opener: diagnostica esistente, sessione precedente utilizzabile; nessun rinnovo del bookmark durante Riapri o nuovo significato di `isStale` |
| esperienza prevista | Riapri segue il ciclo DocumentGroup come Apri; componenti, messaggi e localizzazione esistenti; stesso comando nativo nei tre punti della view |
| verifica | Prova nativa e primo RED su bookmark non nullo; secondo RED del routing dopo la sola correzione delle opzioni; test hostless con opener controllato: URL e singola invocazione, stato preservato, bookmark assente, failure opener; controllo dei tre callsite; RED/GREEN e gate macOS; GS-VER-187 candidata |
| dati e migrazione | Package e formato dei bookmark invariati; nuova creazione macOS con opzione security-scoped valida, `.minimalBookmark` iPadOS invariata; nessun elenco globale dei recenti o stato persistente aggiuntivo |
| sicurezza/privacy | Opzione `.withSecurityScope` per creazione macOS e opzioni security-scoped di risoluzione esistenti; apertura e lifetime documentale delegati al sistema; nessuna rete, entitlement, dipendenza o path aggiunto alle failure |
| prestazioni/sistema | Nessuna apertura aggiuntiva di sessione o ricalcolo; risoluzione bookmark e dispatch al confine nativo esistenti |
| tracciabilità | CMP-110 inizialmente `specified`; RF-001/RQ-004, TV-001/TV-058/TV-071, evidenza e CHANGELOG nello stesso cambiamento |
| decisioni e recupero | ADR-0006 e dipendenze iniettabili GS-APL-001; nessuna nuova decisione architetturale; revert limitato all'incremento, preservando GS-VER-185/186 |

**Ready** prima del coding. iPadOS conserva il comportamento esistente. I test
dimostrano il routing al confine nativo, non creazione o attivazione delle finestre
SwiftUI, autosave o G4. Il Mac bloccato e la scelta esplicita di soli test automatici
escludono una verifica manuale in questo turno.

## Estensione registrata prima della correzione delle opzioni

La prova Foundation della combinazione di opzioni produce `NSCocoaErrorDomain`
codice 256; il primo tentativo del test di riapertura si ferma su bookmark assente,
non dimostra ancora il difetto di routing. L'estensione `Ready` comprende la
correzione macOS della sola creazione, prima del secondo RED e del fix di routing.

La documentazione primaria Apple di
[`withSecurityScope`](https://developer.apple.com/documentation/foundation/nsurl/bookmarkcreationoptions/withsecurityscope)
vieta la combinazione con `.minimalBookmark` o `.suitableForBookmarkFile`.

## Avanzamento

Primo RED del bookmark e secondo RED del routing osservati separatamente.
Dopo le correzioni il modello supera 15 test senza failure o skip; CMP-110
`verified` dopo il gate macOS. Nessuna prova di finestre reali è inferita.

## Verifica finale del profilo macOS

Gate e preflight automatici superati sullo snapshot identificato in
[GS-VER-188](../evidenze/GS-VER-188-gate-macos.md). La clausola dell'incremento è
`verified` soltanto nel perimetro documentato; nessuna chiusura di GUI manuale,
VoiceOver, finestre reali, autosave, iPadOS o G4 è inferita.
