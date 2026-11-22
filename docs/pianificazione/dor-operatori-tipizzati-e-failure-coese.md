<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Operatori tipizzati e failure coese

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-286 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.1 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di iterare e perfezionare la razionalizzazione organica del codice |
| Riferimenti | [Issue #45](https://github.com/gipidevdor/GlifiStudio/issues/45); RQ-007/011/058/060/063; GS-STD-001-10/12/29; GS-MET-001-23; GS-API-001 |

## Scheda Definition of Ready

| Voce | Contratto dell’incremento |
| --- | --- |
| outcome e confini | Base `76e5871`. Il solo AST privato delle regole ammette operatori binari noti; un enum possiede precedenza e applicazione esaustiva. TextAnalytics ed ExploratoryCompletion condividono la tabella di traduzione failure già identica. Stop quando i cataloghi stringa duplicati e la seconda tabella sono rimossi, con equivalenza verificata |
| requisiti e accettazione | CMP-286: RQ-007/011/060/063, stessi risultati, evidenze, errori, budget e cancellazione delle regole. CMP-287: RQ-007/058/060/063, successo e tutti i campi delle failure conservati, incluso il fallback senza informazioni sensibili. API e CLI restano equivalenti alla baseline |
| dominio/API | Enum e AST privati, non Codable e non persistiti; la sola costruzione binaria passa dal parser. Conversione soltanto dei token non quotati. Il catalogo di ambiguità del lexer resta distinto e invariato. Il mapper esistente diventa una funzione interna condivisa nello stesso modulo Kit, senza protocolli o configurazioni |
| failure semantics | Entrambi gli operandi sono valutati sinistra-destra prima dell’applicazione, anche per AND/OR. Finitezza, evidenze, risorse e checkpoint restano nelle posizioni attuali. Il ramo invalid-operator è irraggiungibile dall’API e sostituito dall’esaustività del tipo. La policy Kit conserva conversione Core, CancellationError e fallback; nessun controllo preventivo nuovo o passthrough Studio aggiunto |
| esperienza prevista | Nessuna vista, stringa, navigazione o risorsa modificata; nessun nuovo flusso di accessibilità. Interfacce e trasporti pubblici invariati |
| verifica | Baseline compilata e API/CLI conservate prima delle patch. Contratti pubblici indipendenti per 12 operatori, associazione, precedenza, valutazione eager, evidenze UTF-8, citazioni e rifiuti. Contratto del mapper con errori sintetici e canary. Confronto API, byte CLI, test mirati e `make verify` macOS; revisione indipendente. GS-VER-286 candidata |
| dati e migrazione | Nessuna modifica a grammatica KH-coding-compatible-v2, schema, digest, formato, identità, I/O, transazioni o recovery; nessuna migrazione |
| sicurezza/privacy | Nessun nuovo input, privilegio, rete, dipendenza o dato reale. Validazione e limiti esistenti conservati; errori sconosciuti non espongono il contenuto del dato o dell’errore |
| prestazioni/sistema | Refactoring di invarianti, senza promessa di accelerazione. Stessa complessità e budget; nessun task, actor, callback asincrono, stato condiviso o copia di corpus introdotto. Nessuna misura prestazionale necessaria per rivendicazioni non effettuate |
| tracciabilità | CMP-286/287 inizialmente specified prima del coding. Evidenza, architettura, tracciabilità e registri aggiornati insieme; nessuna promozione della maturità scientifica |
| decisioni e recupero | Nessun nuovo ADR secondo GS-STD-001-10 §10.2: confini e contratti restano quelli esistenti. Revert senza migrazioni. Esclusi Root/WIP delle altre chat, PDF/EPUB, persistenza, progetto Xcode, configurazioni e checker GS-306 |

**Ready** prima del primo cambiamento implementativo. macOS è il gate corrente;
iPadOS è rinviato su richiesta dell’iniziatore. Gli altri mapper Kit conservano
le rispettive policy: la condivisione riguarda soltanto le due tabelle identiche.

## Integrazione dei nuovi scenari e del progetto Xcode

Dopo i gate locali e remoti superati su `a7f1ccc`, main ha pubblicato GS-303 e
GS-306 in `d6b4828`. Il lotto integra esattamente questa base, preservando
codice, configurazioni, test e stati della matrice. I sei sorgenti del lotto
restano identici al primo checkpoint; confronto API/CLI ripetuto contro la
nuova base. Gli esiti del gate macOS sul codice unito sono registrati nella
[PR #46](https://github.com/gipidevdor/GlifiStudio/pull/46), separatamente dalle
prove originarie. Nessuna configurazione o correzione del planner è riscritta.

## Integrazione della pipeline PDF/EPUB

La successiva base pubblicata `b401c08` introduce il lotto documentale
PDF/EPUB. Il refactoring la integra preservando codice, configurazioni,
fixture, test e le 170 voci della matrice upstream; restano aggiunte soltanto
CMP-286/287. I sei sorgenti del lotto sono identici ad `a7f1ccc`. Le migrazioni
e i nuovi formati provengono dal lotto documentale e non vengono riscritti
qui. Il confronto contro questa base conferma API e 164 + 69 risposte CLI
identiche. Il gate macOS corrente è registrato nella PR #46 dopo la sua
esecuzione, distinto dal gate originario e dal precedente gate locale
su `c61c80e` (832 test Core/Kit, 125 definizioni
native e 409 esecuzioni).
