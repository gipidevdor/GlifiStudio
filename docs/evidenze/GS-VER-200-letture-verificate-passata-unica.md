<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-200 — Letture verificate a passata unica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-200 |
| Tipo | Evidenza di ottimizzazione misurata e verifica mirata |
| Versione | 1.1.0 |
| Stato | Superato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-200; RQ-009; RQ-043; RQ-044; RQ-063 |
| Riferimenti | GS-STD-001-17; GS-DAT-001; TV-009; TV-051; TV-060; CMP-200 |

## Perimetro

La [GS-DOR-200](../pianificazione/dor-ottimizzazione-letture-verificate.md) è
Ready prima del coding. Le API `sourceData` del progetto e del recovery
read-only e `artifactData` verificavano due volte l'intero payload: una passata
streaming per validare il riferimento e una seconda per restituire i byte
verificati. L'incremento separa i controlli del riferimento dalla lettura;
hash, dimensione e buffer restituito vengono verificati nella stessa passata.

Restano i controlli di percorso canonico, tipo regolare, singolo hard link,
dimensione, digest e cancellazione per chunk, con un controllo di cancellazione
prima di allocare il buffer. Le verifiche streaming senza trattenimento dei
byte restano disponibili per apertura e verifica del package. Nessuna cache di
fiducia persistente, formato, API pubblica, commit o backend viene introdotto.

La riduzione strutturale è da due a una lettura/hash applicativi per payload;
non implica dimezzamento dell'I/O fisico o della memoria. La prima passata
precedente era già streaming, senza un secondo buffer completo trattenuto.

## Identità e metodo A/B

La copia di lavoro deriva da `a86a53b512bd777f191c89692e0c573a3d37a3ff` con gli
incrementi locali concomitanti. Per isolare l'esperimento dalle ottimizzazioni
analitiche concorrenti, sono stati copiati con `copy2`, senza hardlink,
**263 file** di `Packages/GlifiCore` e `Fixtures`. Gli hash prima/dopo la copia,
dopo la compilazione e dopo la misura hanno confermato la stabilità dell'input.

La baseline Release è stata acquisita **prima delle modifiche produttive**.
Nella stessa copia sono stati poi sostituiti soltanto
`GlifiProjectPackage.swift` e `GlifiQueryEvaluator.swift`, quest'ultimo per
[GS-VER-201](GS-VER-201-normalizzazione-query.md). Il confronto di tutti i 263
file rileva **esattamente queste due differenze**; ogni altro kernel, fixture,
harness e configurazione del package resta identico. La copia candidata è
rimasta invariata durante compilazione e misura.

| Artefatto | SHA-256 |
| --- | --- |
| Inventario baseline, JSON ordinato | `922310132c83d8749d0160059fb071d17ab665f80e3f35fb9a4da17df4721dad` |
| Inventario candidato, JSON ordinato | `57d10e86bb8508cd906b16cc310dcbb97bf7f8ebb1f59e8bdad994d22a0fbc0d` |
| Package baseline | `5f5c41369b04aa5c900d628c99c3dd1daf6d115d6385afd705b1465c62bd142a` |
| Package candidato | `52b12ceb69048812039b75fa759724a4c670310df3f496e4020abd6c504e3b98` |
| Evaluator baseline | `4b219c48473703545d00aee03b1c8a592acd4e9327b76a0f2648c9407cbfa9d5` |
| Evaluator candidato | `7c51f0cbce4b4dc3d8d9cd9a411ab9e74bd8e97748ead65e384967941bb06cbb` |
| `GlifiValidatedReadBenchmarks.swift`, entrambe le fasi | `670788f7234343173ca344d923d3bfb4d5b8215b8ebb4b95856ad7967bfb5dde` |
| `GlifiBenchmark/main.swift`, entrambe le fasi | `85680eba669f017744f433382b33ee40c74c97c28adcf5e5ab1187fadc2b89e8` |

Il modo dedicato `GlifiBenchmark --validated-reads-query` evita SVD, Louvain e
gli altri workload predefiniti. Le fonti sono UTF-8 italiano sintetico di
1, 8 e 32 MiB; gli Artifact contengono testo ASCII in JSON canonico, con 12 byte
aggiuntivi di involucro. ProjectID, SourceID primari/secondari e SourceRevisionID
sono deterministici. Un'importazione estranea conserva l'Artifact selettivo e
permette al recovery di leggere la generazione precedente verificata.

Creazione, importazione, serializzazione dell'Artifact e apertura del recovery
sono fuori dal timer. Ogni scenario esegue **un warm-up e sette campioni**;
il confronto esatto dei risultati avviene dopo aver fermato il timer. Byte,
digest, radice delle fonti, descriptor, nodo e ArtifactID coincidono fra le
due fasi e in tutte le **otto letture** di ciascuno scenario. I valori esatti
sono conservati nei rapporti allegati.

La cache del sistema operativo è **calda**, senza flush. Prima delle misure
non erano attivi altri `GlifiBenchmark`, `xcodebuild` o `swift-frontend`; la
corsa candidata ha atteso la compilazione analitica concorrente. Nessuna
soglia prestazionale viene introdotta.

## Ambiente

| Componente | Baseline e candidato |
| --- | --- |
| Hardware | `Mac16,3` |
| Sistema osservato | `Version 27.2.1 (Build 26B131)` |
| Xcode | 27.2, build `27B52` |
| Apple Swift | 6.4.2, `swiftlang-6.4.2.1.9`, clang `2100.4.1.1` |
| Target riportato da Swift | `arm64-apple-macosx27.2.0` |
| Configurazione | Release |
| Stato termico iniziale/finale | `nominal` → `nominal` in entrambe le fasi |
| Low Power Mode iniziale/finale | `true` → `true` in entrambe le fasi |
| Esecutore e data | Codex, 2026-11-21 |

Sistema, build e target sono riportati come osservati; nessun deployment target
è stato abbassato. Lo stato energetico non è stato modificato per la misura.

## Risultati delle letture

Entrambe le esecuzioni terminano con **exit 0**. Valori in millisecondi:
mediana e intervallo minimo–massimo dei sette campioni.

| API Core | Taglia | Baseline mediana [min–max] | Candidato mediana [min–max] | Riduzione della mediana |
| --- | --- | --- | --- | --- |
| Progetto `sourceData` | 1 MiB | 2,032 [2,014–2,060] | 1,050 [1,035–1,069] | 48,35% |
| Recovery `sourceData` | 1 MiB | 2,010 [1,993–2,040] | 1,045 [1,021–1,066] | 47,99% |
| Progetto `artifactData` | 1 MiB + 12 byte | 2,033 [2,024–2,058] | 1,059 [1,038–1,098] | 47,93% |
| Progetto `sourceData` | 8 MiB | 13,547 [13,114–14,120] | 7,074 [6,994–7,129] | 47,78% |
| Recovery `sourceData` | 8 MiB | 13,284 [13,133–13,335] | 6,997 [6,974–7,040] | 47,33% |
| Progetto `artifactData` | 8 MiB + 12 byte | 13,668 [13,626–13,821] | 7,113 [7,030–7,270] | 47,96% |
| Progetto `sourceData` | 32 MiB | 57,140 [57,078–57,327] | 29,193 [29,081–29,261] | 48,91% |
| Recovery `sourceData` | 32 MiB | 57,352 [57,092–60,729] | 29,251 [29,139–29,501] | 49,00% |
| Progetto `artifactData` | 32 MiB + 12 byte | 58,186 [57,572–59,041] | 29,271 [29,127–29,678] | 49,69% |

Le nove mediane migliorano di **1,90–1,99 volte**, con risultati identici.
Il benchmark misura queste API di GlifiCore; non misura GlifiKit, decodifica
`sourceText`, prestazioni dell'interfaccia o velocità dell'app completa.

`/usr/bin/time -l` riporta un picco RSS dell'**intero processo**, comprensivo
di setup e scenario query, di **2.884.009.984 byte** nella baseline e
**1.848.049.664 byte** nel candidato. Il dato è informativo: il confronto
comprende entrambe le ottimizzazioni e non attribuisce il delta a una singola
API, al buffer del payload o alla UI.

## Verifiche mirate e allegati

Il filtro combinato delle ottimizzazioni, eseguito dopo le misure, termina
con exit 0: **39 test Core e due test Kit**. I nuovi test delle letture
comprendono 32 casi sui quattro ingressi fonte/Artifact normale/recovery
contro otto condizioni, più quattro casi di cancellazione. Conservano
byte, codici di errore, no-follow, limiti, manifest e canary esterno e
permettono una nuova lettura valida. Sono inoltre eseguite regressioni su
directory intermedie e recovery.

## Gate completo e conservazione dei sorgenti

Il coordinatore ha completato **`make verify` con exit 0**, nel profilo globale
macOS e iPadOS, sulla copia di lavoro integrata. Il [record del gate](allegati/GS-VER-200-201-gate.json)
conserva l'esito e le identità dei sorgenti. Il [log sanificato](allegati/GS-VER-200-201-gate.txt),
originariamente `verify-full.log`, è stato riletto per i seguenti risultati;
questa corsa è distinta dal confronto A/B sui sorgenti congelati.

| Controllo | Risultato osservato |
| --- | --- |
| Swift Testing GlifiCore | 359 test superati |
| Swift Testing GlifiKit | 52 test superati |
| Test macOS dal workspace | 36 test distinti superati, 45 esecuzioni sulla destinazione; zero failure o skip |
| Oracoli indipendenti | 152 righe riprodotte e collegate ai test Swift |
| Parità degli operatori testuali | 51 controlli CLI su 15 fixture condivise, tolleranza `1e-12` |
| Recovery dopo terminazione del processo | 22 checkpoint di commit validi |
| veraPDF | Due PDF/A-2u conformi |
| QueryAST CLI | Parità, limiti, file ostili, permessi, argomenti e privacy superati |
| macOS | Test/build Debug e build Release senza firma |
| iPadOS | Build Debug e Release senza firma per destinazione generica iOS Simulator |

Il [riepilogo nativo macOS](allegati/GS-VER-200-201-test-macos.json) distingue
il conteggio dei 36 test da quello delle 45 esecuzioni. Le build iPadOS non sono
test runtime: Xcode segnala CoreSimulator installato `1171.7.0` precedente a
`1174.21.0`, metadati incompleti delle destinazioni generiche e un avviso sulla
dichiarazione di apertura in-place iPadOS. Questi limiti osservati rimangono
espliciti nonostante l'esito positivo del gate. La corsa non convalida nuovi
archivi o packaging App Store.

Il [record dell'archivio sorgenti](allegati/GS-VER-200-201-archivio-sorgenti.json)
conserva posizione e identità del Package/Fixtures congelato e dei due file
produttivi della baseline, senza cache di build. Sono stati verificati
**648.556 byte** e SHA-256
`0df3e8f7374e1e2409b2795208a935c8503f8a3d480395dc0c72d000d3519fad`.

## Allegati delle misure

- [Baseline con campioni grezzi e checksum](allegati/GS-VER-200-201-baseline.json).
- [Candidato con campioni grezzi e checksum](allegati/GS-VER-200-201-candidato.json).
- [Confronto e controlli di identità](allegati/GS-VER-200-201-confronto.json).
- [`time -l` della baseline](allegati/GS-VER-200-201-baseline-time.txt) e
  [del candidato](allegati/GS-VER-200-201-candidato-time.txt).

Gli allegati sono copie dei risultati osservati, con soli dati sintetici,
identificatori deterministici e percorsi sorgente relativi. Le fixture
temporanee sono rimosse dai `defer`; cache e copia di verifica sono state
conservate durante test e gate, poi eliminate dal coordinatore. Il [record di
pulizia](allegati/GS-VER-200-201-pulizia.json) conferma l'assenza della directory
e **2.939.008 KiB**, pari a **2,802856 GiB**, allocati nel solo percorso prima
della rimozione. Non è una misura del delta di spazio libero APFS. Allegati,
archivio compatto dei sorgenti, toolchain e cache delle altre attività sono
stati conservati.

## Limiti ed esito

**Superato nel perimetro misurato, mirato e del gate completo** su una sola macchina e con
Low Power Mode attivo. Non sono misure a disco freddo, soglie G4 o garanzie su
hardware diverso. Non si rivendicano dimezzamento della memoria, eliminazione
di copie `Data` o miglioramento dell'app completa.

CMP-095 resta distinto e blocked: l'ottimizzazione non
estende le garanzie su replacement, cleanup, SQLite, identità globale della
radice, ACL, file provider o durabilità ai power loss.
