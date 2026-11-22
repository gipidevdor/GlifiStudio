<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-286 — Operatori tipizzati e failure coese

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-286 |
| Tipo | Evidenza di refactoring interno |
| Versione | 1.2.0 |
| Stato | Superato nel perimetro macOS dichiarato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di perfezionare la razionalizzazione organica |
| Riferimenti | [Issue #45](https://github.com/gipidevdor/GlifiStudio/issues/45); GS-DOR-286; CMP-286/287; GS-AD-001 |

## Confini e invarianti

Baseline originaria `76e5871`, compilata prima delle patch. Dopo GS-303/306
i confronti sono stati ripetuti contro `d6b4828`; la successiva integrazione
PDF/EPUB assume come base `b401c08`. I risultati positivi descritti sotto
restano associati ai rispettivi checkpoint, senza attribuirli alla nuova
composizione prima della verifica.
L’AST privato delle regole usa
un enum per i 12 operatori binari: l’inizializzatore raw-value riconosce i token,
mentre precedenza e applicazione hanno switch esaustivi. Il parser è l’unico
costruttore dell’espressione binaria. Il vecchio errore invalid-operator non era
raggiungibile dall’API: nessun AST esterno o serializzato poteva introdurre un
operatore sconosciuto dopo il riconoscimento del parser.

Il lexer resta integralmente invariato: il suo insieme di ambiguità lessicali
non coincide con il catalogo binario e conserva termini con trattini e sintassi
di prossimità. Il contesto valuta entrambi gli operandi sinistra-destra e mantiene
finitezza, evidenze, deduplicazione, limiti e checkpoint nelle stesse posizioni.
La grammatica KH-coding-compatible-v2 e il formato delle regole non cambiano.

TextAnalytics ed ExploratoryCompletion riusano un’unica funzione interna con la
policy già presente, eliminando la seconda tabella identica delle failure. Nessun nuovo
protocollo, task, actor, configurazione o wrapper asincrono. Le altre famiglie
Kit conservano le proprie differenze; non si aggiungono cancellazione preventiva
né passthrough delle failure Studio alla policy condivisa.

## Verifica

L’[allegato di verifica](allegati/GS-VER-286-verifica.json) registra baseline,
digest delle sei sorgenti interessate, confronti e limiti.

- Catalogo privato di 12 operatori; payload String dell’AST e catalogo String
  delle precedenze sostituiti da riconoscimento raw-value e due switch esaustivi.
  Lexer identico byte per byte; blocco finitezza/evidenze/risorse identico salvo
  il confronto tipizzato della disgiunzione.
- Due tabelle di failure → una, riusata da 15 ingressi delle due facciate.
  Corpo della funzione condivisa identico all’originale, salvo visibilità da
  privata a interna. Gli altri mapper non cambiano.
- Sul checkpoint originario, sulla precedente base `d6b4828` e sulla nuova
  base `b401c08`, superficie pubblica Core/Kit identica con `swift-api-digester`, dopo il solo
  ordinamento delle dichiarazioni di primo livello; nessuna rimozione di membri,
  parametri, attributi o disponibilità. Nessuna certificazione ABI implicita.
- Sul checkpoint originario, sulla precedente base `d6b4828` e sulla nuova
  base `b401c08`, 164 casi CLI generali e 69 richieste sulle regole: stdout, stderr e codici di
  uscita identici alla baseline, senza normalizzazione di campi. Per 45 richieste
  sono confermati anche valori o errori attesi espliciti sulla baseline.
  I casi CLI usano token nativi; i token esterni espliciti sono coperti dalle
  API Core. L’eseguibile congelato non dipende da librerie Glifi dinamiche.
- Mirati superati: 23 definizioni Core e 13 Kit. Nuovi contratti: sette test
  Core con 69 righe parametrizzate e confini lessicali; sei test Kit su identità,
  invocazione singola, cancellazione, failure complete e privacy.
- Gate originario su `a7f1ccc`, `make verify` macOS superato: 671 test Core e 151 Kit; 117 test nativi,
  349 esecuzioni, zero failure o skip; build Debug/Release. Superati 189 controlli
  su 63 fixture testuali, 260 confronti completi sulle 130 operazioni Kit/CLI,
  51 rifiuti di trasporto, 64 rifiuti bounded della CLI di progetto, 22 checkpoint
  process-kill e due PDF/A-2u.
- Revisioni indipendenti di Core, Kit e documenti: nessun rilievo implementativo
  azionabile. Corrette prima della consegna due precisazioni editoriali.

Il primo run mirato ha rifiutato la nuova fixture `!1 + 1 == 1`. La CLI congelata
riproduce il rifiuto `coding.unspaced-operator` e ammette `! 1 + 1 == 1`:
corretta la fixture e aggiunto il rifiuto esplicito di `!1`, senza cambiare il
lexer o indebolire il controllo.

Le misure strutturali riguardano rappresentabilità e duplicazione, senza promessa
di accelerazione o soglia di righe. CMP-286/287 restano `implemented`, senza
promuovere la maturità scientifica. Il gate corrente è macOS; iPadOS è rinviato.
Xcode emette i diagnostici CoreSimulator/device preesistenti anche selezionando
macOS; test e build Mac sono superati. I lotti concorrenti PDF/EPUB e progetto
Xcode, e il Root, restano preservati.

## Riproduzione e conservazione

Compilare la baseline corrente `b401c08` in una cache isolata, conservando eseguibile CLI e dump
`swift-api-digester` prima delle patch. Estrarre Core/Kit con target
`arm64-apple-macosx27.0`, SDK macOS, Swift 6, `-avoid-location` e
`-avoid-tool-args`; ordinare soltanto le dichiarazioni di primo livello per il
confronto JSON. Il confronto CLI generale riusa
`docs/evidenze/allegati/GS-VER-280/compare-cli.py` con `--reference`, `--candidate`,
`--workspace` e `--output`. Il confronto specifico legge le 69 espressioni
esplicite dei nuovi contratti e confronta le risposte complete con token nativi.

```sh
swift test --package-path Packages/GlifiCore \
  --filter 'GlifiCodingOperatorContractTests|GlifiTextAnalysisFailureContractTests|khCoding|codingReaudit|studioCompletion|khKit'
make verify
```

Usare Python 3.12 o successivo compatibile, toolchain e veraPDF previsti dal
repository. Acquisire il lock degli script se si riusa una cache di build.
Log, dump API compressi, confronti CLI completi e programma del confronto
specifico restano nelle prove locali del lotto; le build rigenerabili si
rimuovono alla chiusura tramite il gestore della cache.

## Integrazione precedente di scenari e progetto Xcode

I sei sorgenti del refactoring restano identici al checkpoint `a7f1ccc`,
che ha superato gate locale e due flussi remoti macOS. I conflitti nei cinque
registri condivisi sono risolti conservando entrambi i contributi: codice,
progetto, configurazioni e test di `d6b4828` restano quelli pubblicati dagli
altri lotti, con le sole aggiunte CMP-286/287 alla matrice. API e 164 + 69
risposte CLI sono nuovamente identiche alla base aggiornata.

I conteggi del gate originario nell’allegato sono associati esplicitamente
a `a7f1ccc`: non descrivono i nuovi scenari GS-303 o i controlli GS-306.
Il gate sul codice unito, i relativi conteggi finali e il preflight macOS sono
registrati nella [PR #46](https://github.com/gipidevdor/GlifiStudio/pull/46)
sul suo head finale, mantenendo distinta la provenienza delle evidenze.

## Integrazione corrente PDF/EPUB

Main ha poi pubblicato la pipeline documentale in `b401c08`. Il merge
conserva integralmente i file upstream fuori dal delta del refactoring,
compresi contenuti e permessi Git; 484 file di codice, configurazioni e test
sono controllati separatamente. La matrice mantiene esattamente le 170 voci
e le proprietà di primo livello upstream, con le sole aggiunte CMP-286/287.
I tre conflitti nei registri sono risolti conservando il corpo upstream,
la sola aggiunta del lotto e una singola riga Versione. I sei sorgenti del
refactoring restano identici ad `a7f1ccc`.

Il precedente gate locale sulla composizione `c61c80e` ha superato 832 test
Core/Kit, 125 definizioni native e 409 esecuzioni. L’allegato lo registra
come fase distinta dal gate originario `a7f1ccc`, i cui conteggi restano
invariati. Le precedenti prove API/CLI contro `d6b4828` sono conservate in
una sezione storica: non attestano i risultati contro `b401c08`.

Il confronto sulla nuova base è ora completato: API Core/Kit e tutte le
164 + 69 risposte CLI sono identiche a `b401c08`, con 45 aspettative esplicite
confermate sulla baseline. L’allegato conserva i risultati e i digest dei
rapporti completi. Il gate corrente sul codice unito e il preflight finale
macOS restano distinti dalle verifiche precedenti e sono registrati nella
[PR #46](https://github.com/gipidevdor/GlifiStudio/pull/46) sul relativo head.
