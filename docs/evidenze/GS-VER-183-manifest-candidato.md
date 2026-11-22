<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-183 — Verifica bounded del manifest candidato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-183 |
| Tipo | Evidenza di correzione e verifica mirata |
| Versione | 1.0.0 |
| Stato | Superato nativamente nel perimetro dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-183; RQ-043; RQ-044; RQ-063 |
| Riferimenti | GS-DAT-001; GS-SEC-001 § 8; TV-051; TV-060; TV-072; CMP-183; CMP-095 |

## Perimetro e identità

I commit di importazione, Artifact, storia qualitativa e Investigation
scrivevano il manifest candidato tramite il descriptor della transazione e lo
rileggevano tramite URL con `Data(contentsOf:)`. La sola validazione strutturale
del manifest decodificato ammetteva anche un candidato diverso da quello atteso:
la discrepanza con SQLite poteva emergere dopo la sostituzione del manifest
autorevole.

L'incremento applica la [GS-DOR-183](../pianificazione/dor-manifest-candidato.md),
Ready prima del coding, mediante un helper privato comune ai quattro commit in
`GlifiProjectPackage.swift`. Il formato persistente e le API pubbliche restano
invariati. La copia di lavoro è basata su
`a86a53b512bd777f191c89692e0c573a3d37a3ff` e include gli incrementi concomitanti;
non si attestano il solo commit di base o una CI remota.

| Sorgente verificato | SHA-256 |
| --- | --- |
| `Packages/GlifiCore/Sources/GlifiCore/GlifiProjectPackage.swift` | `5f5c41369b04aa5c900d628c99c3dd1daf6d115d6385afd705b1465c62bd142a` |
| `Packages/GlifiCore/Tests/GlifiCoreTests/GlifiProjectCandidateManifestTests.swift` | `6fbbece59b2eb86d46c4084dde3cd263015d71b46248f0202dd65debbebad2db` |

## Contratto implementato

Il manifest viene serializzato una volta; il limite esistente di **1.048.576
byte** viene controllato prima della scrittura. La rilettura usa
`transactionDirectory.openFile`, che risolve il nome rispetto al descriptor già
aperto con `O_NOFOLLOW` e `O_NONBLOCK`.

Prima dell'allocazione del buffer, `fstat` richiede file regolare, singolo hard
link e dimensione esattamente uguale ai byte canonici attesi. La lettura procede
a chunk di massimo 65.536 byte, limitati ai byte rimanenti più una sentinella;
un byte eccedente viene rifiutato prima di aggiungerlo al buffer. Tipo, numero di
link e dimensione sono controllati nuovamente sul file aperto dopo la lettura.
Byte esatti, uguaglianza del manifest decodificato e invarianti di dominio devono
corrispondere al manifest atteso prima del publish.

Non vengono aggiunti hash o copie del corpus. I tempi dei test riportati sotto
sono osservazioni dell'esecuzione, senza valore di benchmark o baseline
prestazionale.

Il seam interno esistente ammette ora un observer di test che ritorna dopo la
scrittura del candidato e prima della sua verifica. I comportamenti produttivi
di failure e terminazione al checkpoint `manifestPrepared` restano dopo la
verifica, come prima; i nomi dei checkpoint e la superficie SPI del recovery
harness non cambiano. Investigation usa parametri interni opzionali per
esercitare lo stesso seam.

## Ambiente e verifica positiva

| Componente | Valore osservato |
| --- | --- |
| Sistema, `sw_vers` | `ProductName: macOS`; `ProductVersion: 27.2.1`; `BuildVersion: 26B131` |
| Xcode | Xcode 27.2, build `27B52` |
| Apple Swift | 6.4.2, `swiftlang-6.4.2.1.9`, clang `2100.4.1.1` |
| Swift target riportato | `arm64-apple-macosx27.2.0` |
| Swift Testing | Testing Library Version `2403` |
| Esecutore e data | Codex, 2026-11-21 |

I valori del sistema sono riportati esattamente come osservati, senza dedurne
equivalenza con i target Xcode. Nessun deployment target è stato abbassato.

Formattazione e lint strict Apple dei due file, con `.swift-format` versionato:
superati. `git diff --check` dei due file: superato.

```sh
swift test --package-path Packages/GlifiCore \
  --scratch-path /tmp/GlifiStudioComplementary182-cache/SwiftPM \
  --filter candidateManifest
```

**Exit 0**: due test parametrizzati, **32 casi effettivi**. I quattro casi
positivi passano in 0,159 s; i 28 casi negativi passano in 0,337 s; la corsa termina
in 0,337 s. La build incrementale riusata serialmente dopo GS-VER-182 termina in
0,79 s.

| Casi | Esito verificato su tutti i quattro commit |
| --- | --- |
| Candidato nominale, quattro casi | Nuova generazione pubblicata, snapshot del modello e riapertura concordi |
| Troncamento a un byte | Rifiuto prima del publish |
| Un byte aggiunto | Rifiuto della dimensione oltre quella attesa |
| File sparso di 1.048.577 byte | Rifiuto prima dell'allocazione del buffer; fixture creata con `ftruncate` |
| Symlink | Rifiuto anche con destinazione esterna contenente gli stessi byte del candidato |
| Hard link | Rifiuto del secondo link anche con dimensione e byte esatti |
| FIFO | Rifiuto senza blocco; test con timeout di un minuto |
| JSON valido a pari lunghezza, digest del record modificato | Rifiuto per discordanza dal manifest atteso |

Ogni caso negativo verifica failure tipizzata di corruzione senza retry,
manifest autorevole identico a quello precedente, snapshot precedente
riapribile, fonti originali invariate e destinazione esterna conservata rispetto
a una copia indipendente. Poi esegue un commit sano e verifica la nuova
generazione: staging e record prepared della prova fallita non impediscono la
prosecuzione corretta.

## Prova negativa mediante mutante

Una copia temporanea separata dei file versionabili è stata preparata con
`shutil.copy2`, senza hardlink agli originali, e riallineata dopo il completamento
dell'incremento GS-VER-182. Una prima copia, antecedente a un nuovo sorgente del
provider runtime, non compilava e non ha eseguito test; tale tentativo non è
considerato prova negativa del prodotto.

Nel solo snapshot sono stati rimossi **esclusivamente** il confronto
`observedData == expectedData` e il confronto `decodedCandidate == manifest`.
Restano lettura bounded, no-follow, controlli di tipo/dimensione/link,
decodifica e `validate`. È un mutante mirato della verifica strutturale senza
confronto col candidato atteso, non una ricostruzione integrale della revisione
storica.

Lo stesso test `candidateManifestRejectsMutation`, eseguito con scratch separato
nello snapshot, compila in 44,69 s e termina con **exit 1**: 28 casi eseguiti,
**otto issue nei quattro casi `changedDigest`**. Per ogni percorso falliscono
la conservazione del manifest precedente e la riapertura, con
`project.generation-mismatch`. Gli altri 24 casi non producono issue. Il runner
termina in 0,280 s.

Il mutante dimostra che una failure rilevata soltanto dopo il publish non
preserva il manifest precedente. Gli stessi quattro casi, insieme agli altri
28 casi della corsa positiva, passano con i confronti attivi. Nessun originale
è stato alterato dalla prova.

## Pulizia, limiti ed esito

La copia red riallineata comprendeva **764 file** e **12.144.966 byte** di
sorgenti copiati. Al termine, copia e relativa cache di build non più attiva
occupavano **509.064 KiB** secondo `du -sk`, circa **497 MiB**: sono state
eliminate dopo la conclusione del processo. La misura riguarda quei percorsi,
senza attestare una variazione equivalente dello spazio libero del volume.
La cache condivisa GS-VER-182, ancora destinata al gate del coordinatore, è
stata preservata. Le fixture dei test vengono eliminate dai rispettivi `defer`.

L'evidenza conserva contratto, comandi, identità dei sorgenti, risultati e limiti.
I log di verifica restano disponibili durante il coordinamento finale;
snapshot, mutante e build red rigenerabili sono stati rimossi.

**Superato nel perimetro mirato**. `make verify` resta in carico al coordinatore:
questo esito non attesta il gate completo o i checkpoint kill/recovery.
CMP-095 resta **blocked**: replacement finale e cleanup tramite URL, SQLite,
identità globale della radice, corse dopo l'ultima verifica, ACL, file provider e
durabilità ai power loss restano fuori perimetro. Non si attesta contenimento
dell'intera transazione, protezione degli antenati o chiusura di TV-060/G4.

## Chiusura del coordinatore

`make verify` finale termina con exit 0: 347 test Core, 52 Kit, 36 macOS,
152 riscontri degli oracoli, 51 controlli CLI, parità QueryAST, 22 checkpoint
di process-kill recovery, due PDF/A-2u e build Debug/Release macOS/iPadOS.
La verifica include il sorgente e il test con i checksum sopra. Il preflight
macOS su snapshot identico termina con exit 0 e archivio unsigned valido;
[GS-VER-182](GS-VER-182-runtime-eventi-macos.md) e il relativo allegato
registrano il confronto byte per byte degli input. CMP-183 è verificato nel
confine specifico del candidato; CMP-095 resta blocked per i residui elencati.

## Pulizia conclusiva

Terminati i processi, il coordinatore ha rimosso la sola cache dedicata del
lotto, il probe Release e il log red temporaneo: 2.984.760 KiB
allocati prima della rimozione. Con i 509.064 KiB della copia red già rimossa,
sono circa **3,33 GiB di artefatti non più attivi eliminati**. La misura è
`du -sk` sui percorsi interessati, non un delta garantito dello spazio libero
del volume. Il [riepilogo della pulizia](allegati/GS-VER-182-pulizia.json) conserva
i conteggi; sorgenti, test, evidenze utili e toolchain esistenti sono preservati.
Snapshot e cache dell'altra attività non sono stati modificati. I riferimenti
precedenti alla cache attiva descrivono il riuso durante il lavoro, non un
residuo lasciato alla consegna.
