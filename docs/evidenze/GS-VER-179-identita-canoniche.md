<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-179 — Codifica delle identità canoniche

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-179 |
| Tipo | Evidenza di correttezza e prestazioni |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con quattro agenti concorrenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Ottimizzazione complementare richiesta dall'iniziatore |
| Riferimenti | GS-DOR-179; CMP-187; GS-STD-001-12; GS-STD-001-17; GS-STD-001-29; GS-VER-207; GS-VER-178 |

## Perimetro

Base pubblicata db2bac1, ramo codex/canonical-producers-20261122 e worktree
isolato riutilizzato. Tre soli produttori: canonicalDigest di QueryAST e
CodingAgreementRequest, helper digest privato dell'export scientifico. Nuove
varianti analitiche, numerica, GUI, trasporti, sessioni e persistenza delle altre
chat sono esclusi. I tre file risultano liberi nelle copie di lavoro controllate.

La DoR precede test e harness. La baseline Release è compilata e acquisita prima delle sostituzioni
produttive, con sette riferimenti e regressioni verdi. Nessun nuovo formato,
parametro pubblico, helper condiviso, dipendenza o cache dei digest.

## Protocollo eseguito

Supporto opt-in già esistente nei test Core; un warm-up e sette campioni grezzi.
I due test misurati si eseguono con filtri distinti, in sequenza, per evitare
parallelismo fra benchmark. Ogni funzione misura scenari sequenziali piccoli e
grandi. Fixture, riferimenti, uguaglianza e SHA completi sono fuori timer.
Si registrano inventari, RSS dell'intero comando, termica e contesa; nessuna
soglia di rilascio, misura energetica o promozione scientifica.

Host Mac16,3, 16 GiB, dieci CPU logiche; macOS 27.2.1 (26B131), Xcode 27.2
(27B52), Apple Swift 6.4.2, alimentazione AC e Low Power Mode attivo. Nessuna
preferenza modificata. Soli dati sintetici e deterministici.

## Correttezza e perimetro delle prove

Sette test mirati Release passano prima e dopo. Query: algebra completa,
flag, scope, ordine, Unicode, query costruite direttamente e rifiuti tipizzati.
Accordo: quattro livelli, missing, ordine di coder/unità e livello nominale
legacy. Report: proiezione completa, selezione editoriale, Evidence inutilizzate,
contenuti vuoti e alterazioni di schema, ID e payload anche rihashati.

I riferimenti sono separati per JSON degli input, proiezione/envelope del
report e formatter precedente. Riutilizzano i modelli Codable annidati e la
factory ReportRevisionID; non costituiscono una seconda implementazione
indipendente di tutti i decoder. Ogni risultato, ID e JSON è confrontato
integralmente, oltre ai checksum di verifica fuori timer.

Solo tre espressioni return produttive cambiano fra gli inventari di 273 file
Swift. canonicalSHA256Digest condiviso, preimmagini, encoder, opzioni, schema,
validazioni e dodici consumer dell'helper scientifico restano invariati.
QueryAST.canonicalDigest conserva anche il comportamento su AST costruiti
senza validazione: questa ottimizzazione non introduce nuovi rifiuti.

## Risultati delle misure

Tre coppie prima/dopo per famiglia; le ultime due usano ordine A/B/B/A.
I bundle CoreTests compilati sono identificati con SHA-256 e quello precedente
è archiviato: --skip-build seleziona il bundle compilato e il confronto
dell'inventario prima/dopo ne documenta l'immutabilità. L'elaborazione del
manifest e altre attività dell'host restano esterne al timer del produttore. I due benchmark usano filtri esatti distinti.

| Workload | Mediana prima, coppie 2/3 (s) | Mediana dopo, coppie 2/3 (s) | Rapporto prima/dopo |
| --- | --- | --- | --- |
| `canonical-input-agreement-large` | 0.262691 / 0.262984 | 0.256783 / 0.262531 | 1.023× / 1.002× |
| `canonical-input-agreement-small` | 0.099114 / 0.101708 | 0.062619 / 0.063239 | 1.583× / 1.608× |
| `canonical-input-query-composed` | 0.075764 / 0.076074 | 0.072836 / 0.074448 | 1.040× / 1.022× |
| `canonical-input-query-small` | 0.205035 / 0.210186 | 0.033716 / 0.033892 | 6.081× / 6.202× |
| `report-digest-decode-findings128-batch4` | 0.054514 / 0.053092 | 0.053207 / 0.053100 | 1.025× / 1.000× |
| `report-digest-decode-findings4-batch128` | 0.068310 / 0.068332 | 0.064374 / 0.063254 | 1.061× / 1.080× |
| `report-digest-init-findings128-batch4` | 0.029883 / 0.029032 | 0.028838 / 0.028935 | 1.036× / 1.003× |
| `report-digest-init-findings4-batch128` | 0.039245 / 0.039116 | 0.034058 / 0.034268 | 1.152× / 1.141× |

I casi grandi sono controlli: vantaggi marginali o assenti non sono presentati
come accelerazioni robuste. Tutte le 48 osservazioni hanno identici input e
risultati completi. I rapporti descrivono questo host e questi workload, senza
soglie o estrapolazioni all'intera applicazione. Il censimento ps riguarda
compilatori/build, include nomi fra parentesi potenzialmente terminati e non
prova isolamento dell'host. La prima coppia è acquisita prima/dopo la build;
le due successive non avviano compilazioni di questa chat fra le corse.

[Campioni, inventari e riscontri completi](allegati/GS-VER-179-misure.json)
registrano anche RSS massimo del comando intero, con harness e riferimenti:
non è una misura di allocazioni o memoria del solo codificatore. Il timer
include encoder e SHA del produttore; esclude solo verifiche e preparazione.
I log grezzi e il protocollo restano in /tmp/GlifiCanonical179Reports.

## Gate congiunto

La prima esecuzione su db2bac1 supera 560 test Core, 112 Kit, 95 controlli
CLI, due PDF/A-2u e 22 checkpoint recovery. Viene interrotta dal coordinatore
prima della chiusura per integrare la revisione pubblicata 1728fc1: non è
presentata come gate completo superato.

Il merge 013dea0 preserva le tre espressioni ottimizzate e i banchi di prova.
Le misure restano riferite alla patch sulla base db2bac1; la composizione con
il refactoring privato è verificata separatamente. Il nuovo inventario contiene
275 file Swift. AGENTS e Make pubblicati danno priorità a macOS: make verify
usa quel profilo; iPadOS richiede una richiesta esplicita e non viene avviato.

La nuova esecuzione termina con exit 0: **560 test Core + 112 Kit + 99 nativi
macOS = 771 test**, 95 controlli CLI su trenta fixture, due PDF/A-2u e 22
checkpoint recovery. Passano anche 194 righe di oracoli numerici e 64 casi
Fraction indipendenti. Debug/test e Release macOS completati. Tutti i 275 file
Swift dell'inventario integrato restano invariati fino alla fine del gate.
CMP-187 resta implemented: nessuna promozione scientifica, attestazione App
Store o chiusura G4 viene dichiarata.

Il simulatore dell'host segnala la versione 1171.7.0 contro 1174.21.0 richiesta
da Xcode; il gate macOS termina comunque. iPadOS non viene verificato in questo
lotto, in conformità alla nuova priorità pubblicata. Le ultime modifiche dopo
il gate riguardano soltanto registri ed evidenze e ricevono controlli statici
finali.

## Chiusura e pulizia

Le due raccolte di risultati nativi sono archiviate e verificate file per file:
666 file ciascuna. I log grezzi, campioni, fonti, inventari e protocollo sono
conservati anche in `~/Library/Caches/GlifiStudio/evidence/GS-VER-179`.
Rimossi soltanto cache e binari rigenerabili di questa sessione:
**2,181,716 KiB, circa 2.08 GiB**, misurati con du prima
della rimozione. Non è una differenza df isolata su APFS. Toolchain,
dipendenze, prove utili e file delle altre chat sono conservati.

make quality finale termina con exit 0 dopo la chiusura dei registri:
controlli statici, dialetto Swift e formattazione superati.
