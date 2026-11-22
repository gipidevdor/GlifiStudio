<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-233 — Completamento nativo delle varianti KH Coder

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-233 |
| Tipo | Evidenza di implementazione e verifica del completamento headless |
| Versione | 1.0.0 |
| Stato | Superato localmente nel perimetro dichiarato |
| Responsabile | Codex, coordinamento e tre agenti specializzati |
| Ultima modifica | 2026-11-22 |
| Approvazione | Completamento esplicito autorizzato; gate locale completo superato |
| Riferimenti | RF-087; TV-087; TV-088; CMP-160; CMP-162; GS-DOR-233; ADR-0035; GS-MET-001-23; GS-API-002 |

## Perimetro

Worktree isolato `glifi-kh-completion-20261122`, base `02c1c66`, con integrazione
conservativa di `main` `b59292f`. Il checkout applicativo concorrente è preservato.
Sono implementati Girvan–Newman/CNM/Walktrap, FR/KK, foresta Prim, Simpson,
SMACOF ordinale e multi-start, SOM esagonale/U-matrix/Ward, selezione K LDA e
pipeline italiana opzionale. Nove operazioni aggiuntive condividono il contratto
Core/Kit/CLI; nessuna nuova dipendenza, persistenza, rete o integrazione GUI.
La DoR successiva all’avvio autorizzato è dichiarata in GS-DOR-233.

Le varianti nuove restano `candidate`. Il riferimento pubblico KH non attesta
parità numerica con l’edizione chiusa corrente, né approvazione scientifica V6.
L’[inventario dei sorgenti e della verifica](allegati/GS-VER-233-verifica.json)
registra le identità SHA-256 dei 272 file Core/Kit/CLI, test e fixture/script.

## Verifica indipendente

Per i grafi, le partizioni e i guadagni sono confrontati con enumerazione dei
cammini minimi su 64 grafi, riferimento CNM su 48, potenze Markov/Ward dense su
32 e alberi enumerati esaustivamente su 32. FR coincide con il riferimento
scalare completo; KK controlla energia e convergenza. Sono esercitati pesi,
loop/paralleli, isolati, tie canonici, ammissione e cancellazione.

Gli oracoli MDS includono triangolo equilatero, minimo 1D `1/9`, regressione
isotona tramite tutte le partizioni monotone e passo Guttman indipendente.
La ricerca controlla tutti gli avvii e sceglie il minimo effettivo. SOM esagonale
è confrontato con una formula batch scalare entro `1e-11`; U-matrix, singleton e
Ward controllano geometria, bordi, albero e identità.

LDA verifica formule indipendenti delle quattro diagnostiche, likelihood
collassate enumerate, catena preesistente invariata, vocabolario solo training,
OOV e predizione held-out senza leakage. L’ammissione include theta, candidati e
fold; i documenti context-free usano il prior analitico. Un caso con 20.000
documenti e oltre dieci milioni di sweep dichiarati non esegue sweep inutili.
Accelerate fornisce dot product vDSP e SVD LAPACK senza costruire vettori singolari.

La pipeline linguistica verifica 680 parole sintetiche contro il riferimento
ufficiale Snowball italiano 3.1.0, con provenienza/digest nell’allegato. Offset e
identità UTF-8, concorrenza, unknown/notRequested e rifiuto delle annotazioni
richieste mancanti sono controllati. Lemma e POS risultano disponibili sull’host;
non sono scaricati asset. Il modello Apple non espone una versione e non riceve
un’attestazione di accuratezza su corpus rappresentativi.

## Esiti osservati

| Controllo | Risultato | Ambito |
| --- | --- | --- |
| Suite finale Release | 483 Core + 78 Kit, exit 0 | Include SIMD2 e integrazione performance di main; tutti i sorgenti coincidono con l’inventario |
| Suite Debug del gate | 483 Core + 78 Kit, exit 0 | Contenuto identico alla versione Release |
| Parità CLI/Kit | 30 fixture, 90 controlli passati | Tolleranza assoluta/relativa `1e-12`; input ostili e protocollo |
| Oracoli numerici | 194 righe riprodotte | Riferimenti già collegati ai test Swift; nuovi oracoli specifici descritti sopra |
| Recovery process-kill | 22 checkpoint validi | Pubblicazione e recupero dei commit di progetto |
| PDF/A-2u | 2 PDF conformi con veraPDF | Export integrativi del gate |
| Applicazione macOS | 55 funzioni, 195 esecuzioni; zero fallimenti/saltati | Bundle xcresult conservato; nessun runtime warning nei test |
| macOS e iPadOS | Debug e Release senza firma superati | iPadOS compilato per destinazione generica Simulator; nessun test runtime sul simulatore |
| `make verify` | Exit 0, profilo completo | Controlli statici, linguistici/architetturali, CLI e tutte le configurazioni previste |

Il gate completo usa Xcode 27.2 e Swift 6.4.2. Gli avvisi di riuso della scratch
tramite symlink riguardano artefatti poi rigenerati e rimossi. Xcode segnala il
servizio CoreSimulator 1171.7.0 precedente al build 1174.21.0 e placeholder senza
versione OS; le build generiche Simulator passano, senza attestare runtime.
Resta l’avviso applicativo preesistente sulla dichiarazione di apertura in-place
iPadOS: non è modificato in questo lotto di algoritmi. Questi diagnostici e i
digest dei log sono registrati nell’allegato; nessun esito è presentato come privo
di avvisi di ambiente o applicazione.

## Prestazioni misurate

I [report grezzi](allegati/GS-VER-233-benchmark.json) conservano ambiente,
campioni, checksum di input/risultato e confronto completo fuori timer. Host
Mac16,3, dieci CPU logiche, 16 GiB, macOS 27.2.1 (26B131), Swift 6.4.2; termica
nominale e Low Power Mode attivo. Nessuna preferenza di sistema è modificata.

FR simmetrico riduce il lavoro delle coppie rispetto al riferimento diretto.
Il confronto aggiuntivo scalare simmetrico/SIMD2 usa 21 coppie per taglia e ordine
alternato: SIMD vince 20/21 a 64 nodi e 21/21 a 128, con rapporti mediani 1,046× e
1,041×. Ogni taglia conserva 44 confronti completi con SHA-256 coincidente.
SIMD2 è promosso mantenendo ordine di accumulo, stopping, limiti e identità;
la baseline scalare rimane congelata nel benchmark. Le coppie sono descrittive,
non campioni statistici indipendenti o soglie di rilascio.

Il workload di 2.000 dot product da 64 elementi passa da 82,500 a 30,834 µs di
mediana con vDSP, circa 2,68×; la parità scalare è entro `1e-12`. Il rapporto
riguarda questo kernel, non l’intera selezione LDA (2,694 ms nel caso sintetico
32×32, K 2/3 e due fold). Le misure ordinarie usano un warm-up e sette campioni,
con otto controlli completi per risultato. Report separati coprono MDS/SOM e
pipeline linguistica; non sono inventati confronti storici per operatori nuovi.

## Integrazione e limiti

Il payload nativo pubblico preserva l’accesso tipizzato richiesto dal lotto GUI;
lo switch di `StudioAdvancedAnalysisModel` nel checkout concorrente deve gestire
esplicitamente il nuovo caso `.advanced`. Non è incluso nel gate di questo lotto.
`GlifiStudioCodeCrosstab.codes` è disponibile in memoria senza cambiare il JSON v1.

Il gate riguarda il workspace isolato, non il working tree GUI in evoluzione,
la CI remota o hardware fisico iPad. Energia, audit di accessibilità su dispositivo,
accuratezza linguistica rappresentativa e firma scientifica esterna restano distinti.
Log, report e provenienza utili vengono conservati; le scratch inattive vengono
rimosse al termine senza toccare cache o worktree delle altre chat.

## Conservazione e pulizia

Log, JSON di parità, provenienza e bundle xcresult macOS compresso sono conservati
in `~/Library/Caches/GlifiStudio/evidence/GS-VER-233`. Gli allegati versionati
contengono inventario, esiti e 21 report benchmark; l’archivio locale mantiene
le prove grezze. La [pulizia misurata](allegati/GS-VER-233-pulizia.json) rimuove
soltanto scratch rigenerabili e temporanei di questo lotto. Il worktree sorgente
resta utile per l’integrazione GUI; toolchain, dipendenze e lavoro concorrente
sono preservati. Lo spazio riportato è allocazione misurata prima della rimozione,
non una differenza dello spazio libero APFS.

## Riesame successivo

[GS-VER-234](GS-VER-234-riverifica-correttezza-completezza.md) registra difetti
successivamente individuati su input estremi e risorse, e corregge l’attribuzione
della matrice parola-contesto. I risultati di questa evidenza restano storici
per `c6fd88e`: non attestano assenza di difetti né completa parità con KH.
