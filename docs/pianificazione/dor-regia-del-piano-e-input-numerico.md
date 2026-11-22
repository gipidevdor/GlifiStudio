<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Regia del piano e input numerico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-284 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di iterare la razionalizzazione organica del codice |
| Riferimenti | [Issue #43](https://github.com/gipidevdor/GlifiStudio/issues/43); GS-AD-001; GS-STD-001-10/12/29; GS-API-001; RQ-005/007/011/023/060/063 |

## Scheda Definition of Ready

| Voce | Contratto dell’incremento |
| --- | --- |
| outcome e confini | Separare l’esecuzione del singolo passo dalla regia del piano e rimuovere la grammatica decimale duplicata nei due editor Kit. Base `d368285`. Criterio di stop: una costruzione del risultato del passo, una risoluzione dell’artefatto persistito per keyness/capability estese, una grammatica numerica condivisa |
| requisiti e accettazione | Regia CMP-284: RQ-005/011/023/063, confini, cancellazione e riferimenti agli artefatti invariati. Editor CMP-285: RQ-007/060/063, errori distinti e contratti Kit/CLI invariati. Le verifiche esistenti di riuso, generazioni, progressi e pressione passano; entrambi gli editor mantengono decimali, esponenti, zero con segno e failure di famiglia |
| dominio/API e ownership | Helper del passo privato nello stesso actor e file. Corpus restituisce il record già ottenuto; gli altri percorsi condividono lo snapshot successivo. Nessun nuovo punto di sospensione, task, actor, API o accesso pubblico. Il parser Kit interno restituisce un valore opzionale; ciascun chiamante conserva il proprio errore |
| failure semantics | Admission, dipendenze, controllo schema, contatori, finalizzazione e catch restano nella regia. Nessuno snapshot aggiunto al corpus; stesso ordine di await e I/O. I separatori misti, overflow e valori non finiti continuano a essere rifiutati. La lettura delle righe resta specifica di ciascun editor |
| esperienza prevista | Nessuna modifica di interfaccia, testi o flussi. Compatibilità CLI/Kit mantenuta. Nessuna nuova valutazione di accessibilità necessaria: viste e contenuti invariati |
| verifica | Build della baseline prima delle patch; confronto API Core/Kit, CLI e suite di esecuzione/runtime. Casi pubblici indipendenti per grammatica numerica e failure. `make verify` macOS prima della consegna; evidenza candidata GS-VER-284 e revisione separata delle patch |
| dati e migrazione | Nessun cambiamento a schema, identità, formato, lineage, commit point o recovery; nessuna migrazione |
| sicurezza/privacy | Nessun nuovo input, privilegio, rete, dipendenza o corpus reale. Input editor già limitato dai chiamanti; la grammatica esistente è conservata integralmente |
| prestazioni/sistema | Manutenibilità senza promessa di accelerazione. Nessun nuovo lavoro asincrono, scansione, copia di corpus o I/O; non si modificano kernel numerici. Misure strutturali e compatibilità, senza benchmark prestazionali non pertinenti |
| tracciabilità | CMP-284/285 inizialmente specified nella matrice isolata prima del coding; GS-VER-284 raccoglie risultati e limiti. Solo merge additivo dei registri condivisi dopo coordinamento con GS-303 |
| decisioni e recupero | Attuazione interna dei confini esistenti: nessun nuovo ADR secondo GS-STD-001-10 §10.2. Patch reversibile senza dati da migrare. Nessuna scrittura nel Root, nei file di controllo o nelle suite occupate dalle altre chat |

**Ready** prima del coding. iPadOS escluso dal gate corrente per la priorità
macOS richiesta dall’iniziatore. Il possibile difetto di budget del planner
emerso nell’audit è stato segnalato alla chat di correttezza: non viene corretto
implicitamente in questo refactoring.

## Integrazione delle correzioni concorrenti

Dopo i gate locali e remoti superati su `53cf248`, main ha pubblicato le
correzioni KH in `00d1cd1` e la minimizzazione delle evidenze in `a2716ef`.
Il lotto integra esattamente `a2716ef`, preservandone codice, test e stati di
matrice. I quattro file di produzione del refactoring restano identici alla
prima revisione verificata. Il confronto API/CLI viene ripetuto contro la nuova
base; gli esiti del gate sul codice unito sono registrati nella PR #44,
separatamente dai risultati originari. Nessun nuovo fix numerico è introdotto
dal refactoring.
