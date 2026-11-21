<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-181 — Profondità dell'AST delle query testuali

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-181 |
| Tipo | Evidenza di regressione Core e parità Kit |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro mirato; gate integrato non superato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Attuazione GS-DOR-181; esito tecnico limitato alle prove dichiarate |
| Riferimenti | GS-DOR-181; CMP-181; GS-QRY-001; RQ-042; RQ-063; TV-053; TV-060 |

## Ambito e correzione

Sulla base `a86a53b` con il working tree corrente, il parser testuale limitava
parentesi e NOT, ma poteva restituire un AST oltre `maximumDepth` attraverso
AND, OR e catene NEAR/BEFORE. Una catena di 34 termini e 33 operatori di
prossimità produce 67 nodi e profondità 33, oltre il limite standard 32.
Il valutatore rifiutava successivamente quell'albero.

`QuerySyntaxParser` ora visita l'AST con una pila esplicita prima di restituirlo.
La radice ha profondità zero e ogni arco aggiunge uno. La visita osserva la
cancellazione e percorre soltanto i nodi già limitati dal budget del parser;
non aggiunge ricorsione. Restano attivi i limiti sintattici, di byte e nodi.
Il superamento produce `query.depth-limit-exceeded`, categoria
`insufficientResources`, operazione `query`, con coordinate prive di contenuto.
La validazione semantica delle regex resta nel valutatore.

La modifica comprende esclusivamente `GlifiQueryParser.swift` e
`GlifiQueryParserTests.swift`, oltre a questa evidenza e alla tracciabilità
curata dal coordinatore. Nessuna API, grammatica, schema persistente o UI nuova.

## Ambiente e regressioni

Esecuzione locale su macOS 27.2.1 (`26B131`), Xcode 27.2 (`27B52`),
Apple Swift 6.4.2 (`swiftlang-6.4.2.1.9`), Swift Testing 2403.
Package e scratch SwiftPM isolati sotto una directory temporanea dedicata,
senza utilizzare la cache di build comune.

Le regressioni controllano:

- catene NEAR e BEFORE a profondità 32 accettate e a profondità 33 rifiutate;
- AND implicito, OR e combinazioni AND/OR/NOT al limite e oltre;
- radice a profondità zero e parità con la decodifica dell'AST canonico;
- codice, categoria, operazione, presenza delle coordinate e assenza del
  contenuto della query nella failure;
- conservazione del limite sulle parentesi e della validazione regex separata.

## Verifiche osservate

| Prova | Ingresso | Esito |
| --- | --- | --- |
| Riproduzione prima della correzione | Copia del parser originale e nuove regressioni; `swift test --filter queryParserBounds` | Exit 1 atteso: 2 test falliti, 6 issue; quattro casi booleani e i due casi NEAR/BEFORE |
| Prima prova dopo la correzione | Copia corretta; `swift test --filter 'query\|fuzzQuery'` | 20 test Core superati; test Kit non eseguibile per fixture assente nel layout temporaneo |
| Prova dopo il ripristino del layout di verifica | Stesso parser e test corretti; copia con `Packages/GlifiCore` e `Fixtures/Query`; medesimo filtro | Exit 0: 20 test Core e 1 test Kit superati; inclusi 3.000 input del fuzz query |
| Formattazione | `swift format lint --strict --configuration .swift-format` sui due file Swift | Exit 0 |
| Whitespace | `git diff --check` sui due file Swift | Exit 0 |

La prima prova dopo la correzione cercava
`Fixtures/Query/v1/cases.json` all'esterno della copia: il test di parità ricava
la radice risalendo da `#filePath`. È un errore di preparazione del layout
temporaneo, distinto dalle regressioni del prodotto. La ripetizione ha
preservato la struttura del repository e copiato la fixture sintetica esistente.
La build finale è durata 22,18 s; i 20 test Core 0,521 s, il test Kit 0,050 s;
il fuzz query 0,520 s. Questi tempi descrivono l'esecuzione osservata e non
costituiscono un benchmark.

Il comando finale usa `swift test --package-path <radice-temporanea>/Packages/GlifiCore
--scratch-path <radice-temporanea>/Build --filter 'query|fuzzQuery'`.
La riproduzione iniziale impiegava la stessa copia prima della correzione con
il filtro `queryParserBounds`. I file sorgente condivisi non sono stati
ripristinati temporaneamente per ottenere il fallimento atteso.

## Identità dei file verificati e limiti

SHA-256 degli ingressi Swift della prova finale:

| File | SHA-256 |
| --- | --- |
| `Packages/GlifiCore/Sources/GlifiCore/GlifiQueryParser.swift` | `55b69a1c43f1219413e825ef311d8becdc48e55a336844c35977347f6a3fbc5c` |
| `Packages/GlifiCore/Tests/GlifiCoreTests/GlifiQueryParserTests.swift` | `27265652d51e63a8016f1a7470a12fb1f5b08f025b6e0f59c5667c1aa6d05607` |

`make verify` sul working tree integrato è stato eseguito dal coordinatore il
2026-11-21 con Python 3.12.14, cache e temporanei dedicati. Exit di `make` 2:
repository, segreti, toolchain, configurazione GitHub e naming superati; arresto
in `check-docs.py` per modifiche concomitanti estranee al lotto:

- `dor-riassunto-macos.md` e `dor-completamento-algoritmi.md` condividono
  l'identificatore `GS-DOR-168`;
- `dor-completamento-algoritmi.md` non contiene i marker `outcome e confini` e
  `**Ready` richiesti dal controllo.

Il gate si è fermato prima di oracoli, test integrati e build; nessuno di questi
è attribuito a questa esecuzione. Le prove mirate sopra restano distinte dalla
verifica globale, da ripetere dopo la stabilizzazione dei documenti concomitanti.
Nessuna nuova attestazione su indice, streaming, audit GUI o G4. Recupero tramite
revert, senza migrazione.

Nel controllo documentale finale la collisione di ID non è più presente;
restano i due marker mancanti nel DoR degli algoritmi. Sono invece superati
`check-compliance.py`, i due controlli failure, formatter strict sui file Swift
dell'incremento e `git diff --check`. I checksum degli ingressi coincidono con
quelli della prova mirata.

La copia e lo scratch temporanei sono stati rimossi dopo la verifica: spazio
allocato misurato prima della pulizia, 470.436 KiB (circa 459 MiB). Sono
conservati codice, test e questa evidenza; cache e file delle altre attività
restano fuori dalla pulizia.

## Chiusura del gate dopo la stabilizzazione documentale

La ricognizione GS-VER-184 ha risolto i marker documentali che bloccavano il
primo lotto. Il successivo `make verify` globale del coordinatore termina con
exit 0 sulla composizione finale: 347 test Core, 52 Kit, 36 macOS, oracoli, CLI,
22 checkpoint recovery, due PDF/A-2u e build Debug/Release delle due piattaforme.
Il preflight macOS su snapshot identico è anch'esso superato. Gli esiti finali
e i limiti sono registrati in [GS-VER-182](GS-VER-182-runtime-eventi-macos.md);
i blocchi precedenti restano sopra come risultati storici delle prime prove.
