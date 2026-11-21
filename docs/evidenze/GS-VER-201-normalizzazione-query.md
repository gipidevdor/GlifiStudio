<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-201 — Normalizzazione costante del termine query

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-201 |
| Tipo | Evidenza di ottimizzazione misurata e verifica mirata |
| Versione | 1.1.0 |
| Stato | Superato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-201; RF-080; RQ-009; RQ-042; RQ-063 |
| Riferimenti | GS-STD-001-17; GS-QRY-001; TV-009; TV-053; TV-060; CMP-201 |

## Perimetro

La [GS-DOR-201](../pianificazione/dor-ottimizzazione-termine-query.md) è Ready
prima del coding. Nel ramo `term` di `GlifiQueryEvaluator`, il valore
confrontabile della query viene ora calcolato una volta prima della scansione
dei token. La trasformazione resta quella esistente: NFC e lowercase italiano
per il campo `normalized`, forma richiesta dal contratto per gli altri campi.

Non cambiano grammatica, AST, digest, coordinate, KWIC, ordinamento, troncatura,
budget, cancellazione o API. La scansione rimane lineare nel numero di token;
le normalizzazioni del termine indipendenti dal token passano da una per
confronto a una per valutazione. Non vengono aggiunti indice o cache globale.

## Identità e metodo A/B

L'esperimento usa una copia stabile di **263 file** di `Packages/GlifiCore` e
`Fixtures`, acquisita dalla copia di lavoro basata su
`a86a53b512bd777f191c89692e0c573a3d37a3ff` con gli incrementi concomitanti.
Hash prima/dopo copia, compilazione e misura controllano l'identità dell'input.
La baseline precede la patch produttiva.

Tra baseline e candidato sono sostituiti **soltanto due file Core**:
`GlifiQueryEvaluator.swift` e `GlifiProjectPackage.swift` per
[GS-VER-200](GS-VER-200-letture-verificate-passata-unica.md). Il confronto
dell'intero inventario conferma esattamente queste due differenze. Tutti gli
altri kernel, fixture, harness e configurazioni rimangono identici; le
ottimizzazioni analitiche parallele non entrano nel confronto.

| Artefatto | SHA-256 |
| --- | --- |
| Evaluator baseline | `4b219c48473703545d00aee03b1c8a592acd4e9327b76a0f2648c9407cbfa9d5` |
| Evaluator candidato | `7c51f0cbce4b4dc3d8d9cd9a411ab9e74bd8e97748ead65e384967941bb06cbb` |
| Package baseline | `5f5c41369b04aa5c900d628c99c3dd1daf6d115d6385afd705b1465c62bd142a` |
| Package candidato | `52b12ceb69048812039b75fa759724a4c670310df3f496e4020abd6c504e3b98` |
| `GlifiValidatedReadBenchmarks.swift`, entrambe le fasi | `670788f7234343173ca344d923d3bfb4d5b8215b8ebb4b95856ad7967bfb5dde` |
| `GlifiBenchmark/main.swift`, entrambe le fasi | `85680eba669f017744f433382b33ee40c74c97c28adcf5e5ab1187fadc2b89e8` |

Gli inventari ordinati hanno SHA-256
`922310132c83d8749d0160059fb071d17ab665f80e3f35fb9a4da17df4721dad`
per la baseline e
`57d10e86bb8508cd906b16cc310dcbb97bf7f8ebb1f59e8bdad994d22a0fbc0d`
per il candidato.

Il modo `GlifiBenchmark --validated-reads-query` prepara una fonte con
**100.000 token**: ripete 12.500 volte le otto forme Unicode
`Città PERCHÉ caffè già élite naïve über résumé`. La query testuale
`normalized:ZZZZASSENTEÉ` è assente e forza la scansione completa. Importazione,
tokenizzazione e parsing sono **fuori dal timer**.

La fonte ha SourceRevisionID fisso
`source-revision:00000000-0000-0000-0000-000000000201`. Il risultato atteso è
costruito indipendentemente dall'esecuzione: `matchedScope=false`, zero match,
`isTruncated=false`. Un warm-up e sette campioni vengono confrontati
esattamente dopo la chiusura del timer: **otto risultati su otto identici**
in entrambe le fasi.

| Identità della fixture | Valore |
| --- | --- |
| SHA-256 dei byte della fonte | `598ef075f7168bfd6b02e4ab984002a46302f3e009ea06caaf34f2918de0a220` |
| Digest QueryAST canonico | `sha256:21c7e3373750b108e2c3a3c14f414248be3388c3cb17997aef083aba7a062794` |

## Ambiente e risultati

Baseline e candidato usano Release su **Mac16,3**, sistema osservato
`Version 27.2.1 (Build 26B131)`, Xcode 27.2 (`27B52`), Apple Swift 6.4.2
(`swiftlang-6.4.2.1.9`, clang `2100.4.1.1`), target riportato
`arm64-apple-macosx27.2.0`. Nessun deployment target viene abbassato.
Entrambe le corse iniziano e finiscono con stato termico **nominal** e
**Low Power Mode attivo**. La cache del sistema operativo è calda, senza flush.
Prima delle misure non risultano altri benchmark o compilatori attivi; la
corsa candidata attende la conclusione della compilazione analitica concorrente.
Esecutore: Codex, 2026-11-21.

Entrambe le esecuzioni terminano con **exit 0**. Valori in millisecondi:

| Scenario | Baseline | Candidato |
| --- | --- | --- |
| Mediana, termine normalizzato assente su 100.000 token | 187,203 | 88,112 |
| Minimo–massimo dei sette campioni | 186,084–189,836 | 87,499–88,845 |

La mediana scende del **52,93%**, pari a **2,125 volte** la velocità osservata
prima. L'affermazione riguarda questo scenario assente con scansione completa;
non è una misura di tutte le query, di phrase/regex, del parsing o della UI.
La scansione e gli altri costi della valutazione restano presenti.

Il picco RSS da `/usr/bin/time -l` passa da **2.884.009.984** a
**1.848.049.664 byte** nell'intero processo che esegue sia letture sia query,
**setup incluso**. È un dato informativo comune a GS-VER-200/201: non è una
misura per singola API, un'attribuzione del risparmio alla sola query o una
promessa sulla memoria dell'app.

## Verifiche mirate e allegati

Il filtro combinato successivo alle misure termina con exit 0:
**39 test Core e due test Kit**. Le tre funzioni aggiunte per il termine
coprono dieci combinazioni Unicode/campo/valore, anche tramite decodifica
QueryAST e confronto di digest, intervalli e KWIC; cinque limiti risultati
da zero a quattro; cancellazione prima della scansione. Il filtro include
inoltre il fuzz di 3.000 query valide/malformate, parser, AST, evaluator,
query del motore e parità Kit.

## Gate completo e conservazione dei sorgenti

Il coordinatore ha successivamente completato **`make verify` con exit 0**,
profilo globale macOS/iPadOS, sulla copia di lavoro integrata. Il [record del gate](allegati/GS-VER-200-201-gate.json)
conserva esito e identità dei sorgenti. La rilettura del [log sanificato](allegati/GS-VER-200-201-gate.txt),
originariamente `verify-full.log`, conferma **359 test Core e 52 test Kit**, 152 righe di
oracoli indipendenti riprodotte e collegate ai test Swift, 51 controlli CLI su
15 fixture condivise entro `1e-12`, 22 checkpoint di recovery validi, due
PDF/A-2u conformi con veraPDF e parità/limiti/privacy QueryAST CLI superati.

I test macOS dal workspace e le build Debug/Release macOS e iPadOS senza firma
sono passati. Il [riepilogo nativo macOS](allegati/GS-VER-200-201-test-macos.json)
registra **36 test distinti e 45 esecuzioni sulla destinazione**, senza failure
o skip. Le build iPadOS usano una destinazione generica iOS Simulator e non
attestano test runtime: il log segnala CoreSimulator `1171.7.0` precedente a
`1174.21.0`, metadati incompleti delle destinazioni generiche e un avviso sulla
dichiarazione di apertura in-place iPadOS. La corsa non convalida nuovi archivi
o packaging App Store.

Il [record dell'archivio sorgenti](allegati/GS-VER-200-201-archivio-sorgenti.json)
conserva Package/Fixtures congelato e i due sorgenti produttivi della baseline,
senza cache di build: **648.556 byte**, SHA-256 verificato
`0df3e8f7374e1e2409b2795208a935c8503f8a3d480395dc0c72d000d3519fad`.
Il gate sulla copia integrata resta distinto dall'esperimento A/B che isola
i soli due cambiamenti produttivi.

## Allegati delle misure

- [Baseline con sette campioni grezzi e checksum](allegati/GS-VER-200-201-baseline.json).
- [Candidato con sette campioni grezzi e checksum](allegati/GS-VER-200-201-candidato.json).
- [Confronto e identità dei risultati](allegati/GS-VER-200-201-confronto.json).
- [`time -l` baseline](allegati/GS-VER-200-201-baseline-time.txt) e
  [candidato](allegati/GS-VER-200-201-candidato-time.txt).

I rapporti condivisi conservano dati sintetici, hash dei sorgenti e i controlli
esatti di query, fonte, radici, descriptor e Artifact. Non contengono dati
personali o percorsi locali assoluti. Le fixture temporanee vengono rimosse;
cache e copia di verifica sono state conservate durante test e gate, poi
eliminate dal coordinatore. Il [record di pulizia](allegati/GS-VER-200-201-pulizia.json)
conferma assenza della directory e **2.939.008 KiB** (**2,802856 GiB**) allocati
prima della rimozione, senza dedurre un equivalente aumento dello spazio libero
APFS. Evidenze compatte, toolchain e cache delle altre attività restano conservate.

## Limiti ed esito

**Superato nel perimetro misurato, mirato e del gate completo** su una sola macchina, in Release,
con cache calda e Low Power Mode attivo. Soglie G4 e hardware di riferimento
restano separati; non vengono introdotti gate prestazionali o estese le
garanzie alle query non misurate.

Le misure Core non certificano l'esperienza GUI, l'accessibilità,
prestazioni su dispositivo o l'intero percorso dell'app.
