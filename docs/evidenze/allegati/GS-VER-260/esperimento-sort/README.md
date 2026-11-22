<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Esperimento di ordinamento descrittivo con Accelerate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-260-EXP-SORT-001 |
| Tipo | Allegato riproducibile dell’evidenza GS-VER-260 |
| Versione | 1.0.0 |
| Stato | Candidato scartato; produzione Swift conservata |
| Responsabile | Iniziatore del progetto, con supporto Codex |
| Ultima modifica | 2026-11-22 |
| Approvazione | Scelta tecnica di non adottare il candidato senza beneficio end-to-end robusto |
| Riferimenti | GS-DOR-260; ADR-0040; GS-APL-011; [GS-VER-260](../../../GS-VER-260-integrazioni-native-apple.md) |

## Domanda e candidato

L’esperimento valuta `vDSP_vsortD` nel solo fallback descrittivo ad alta cardinalità.
Il riferimento conserva la baseline Swift: probe dell’inversione iniziale, counted
sort fino a 256 valori distinti, sort Swift per gli altri casi. La soglia candidata
provvisoria di 32.768 osservazioni non è stata promossa a politica del prodotto.

Il candidato ammette soltanto buffer grandi interamente `Double.isNormal`, dopo
una scansione completa che intercetta anche zeri e subnormali tardivi. Formule,
quantili Q7, ordine delle riduzioni, precisione binary64 e struttura del risultato
restano invariati. La scansione dei fallback rientra nel tempo misurato.

La [patch candidata](candidate.patch) comprende esclusivamente quattro file:
`GlifiDescriptiveStatistics.swift`, il blocco di dispatch di `GlifiBenchmark/main.swift`,
il nuovo harness e i quattro test numerici. Non contiene le modifiche parallele
Foundation, Runtime o GUI. La patch è stata riapplicata in una copia separata della
baseline `02c1c66`: `git apply --check` ha restituito exit 0 e i quattro file risultanti
corrispondono ai rispettivi SHA congelati in [patch-validation.json](patch-validation.json).
La patch non è applicata al sorgente di produzione consegnato.

## Eseguibili e protocollo

Gli SHA identificano gli eseguibili effettivamente misurati, senza includerli negli
allegati. Un rebuild in un’altra directory può cambiare il binario, per esempio a
causa di `#filePath`; non viene promessa identità byte per byte dell’eseguibile
ricostruito. Gli inventari completi delle fonti compilate sono conservati in
[binary-comparison-source-inventories.json](binary-comparison-source-inventories.json).

| Eseguibile congelato | SHA-256 |
| --- | --- |
| Candidato vDSP | `d7abcdf14045aa244e61b446883cc8e08d8c03de1983c94329ecf5d24745f530` |
| Riferimento Swift | `d81acfec3e818750dd7a663a87427f6e339b25b1abadadd1066d3eaa129559be` |
| Patch dei quattro file | `07d78f31d972ed7f6c42fbbaa9b0f10af07706bb99daf7614741f50a55dabd8d` |

Entrambi gli eseguibili invocano la stessa API pubblica
`GlifiDescriptiveStatistics.summarize`. L’argomento `--candidate-only` del runner
significa «misura la chiamata API pubblica» in entrambi gli eseguibili; il campo
`binaryRole` negli assessment distingue Swift da vDSP. Non significa che il binario
di riferimento usi un acceleratore. La sola aggiunta al suo file originale è una
costante `package` per i metadati della soglia candidata; i corpi della descrittiva
e del sort originale sono stati verificati immutati.

Ogni processo esegue 15 casi, un warm-up e sette campioni per caso. Ogni risultato,
compresi i warm-up, è confrontato interamente dopo lo stop del timer: identità,
unità, missing policy, convenzione di varianza, conteggi, sei scalari opzionali e
probabilità/valori dei quantili, tutti confrontati tramite i bit dei Double.
Il timer include validazione, compaction e copie, eligibility, sort, Q7 e riduzioni.
Generatori, digest e confronto completo restano fuori timer; il loro costo in
memoria è invece compreso nel picco del processo.

I generatori sono sintetici e deterministici, con seed e ricette nei JSON. Nessuna
fonte o corpus dell’utente è stato letto. Gli input vanno da 4.096 a 1.000.000
osservazioni, includendo missing, bassa cardinalità, quasi ordinamento, cardinalità
tardiva, zeri e subnormali in coda. Non sono misurati energia, UI o I/O fisico.

## Tentativi distinti

1. `paired-exploratory-attempt1*`: confronto esplorativo tra copia privata del
   riferimento e API pubblica del candidato nello stesso eseguibile. Compilazioni
   concorrenti osservate; risultati numerici identici, ma nessuna conclusione di
   adozione. La differenza di contesto di compilazione del riferimento è un limite
   aggiuntivo, superato dal confronto successivo tra due eseguibili.
2. `full-api-pass*` e [full-api-abba-comparison.json](full-api-abba-comparison.json):
   primo confronto A/B e B/A dei due binari. Il probe iniziale era quieto, ma un
   nuovo `swift-test` con compilazioni è comparso durante la misura. Tutti e quattro
   i processi sono marcati contesi; non sono evidenza di promozione.
3. `full-api-attempt2-*`: due passate A/B e B/A senza processi concorrenti di
   compilazione, test o benchmark osservati. Il probe comprende 11 snapshot in
   5,5 secondi; il monitor prosegue ogni 0,5 secondi durante i quattro processi.
   L’assenza è osservazionale entro tale intervallo, non una prova di assenza di
   ogni possibile attività del sistema.

La passata finale usa Mac16,3, memoria fisica 16 GiB, macOS 27.2.1, Apple Swift 6.4.2.
**Low Power Mode è true all’inizio e alla fine di tutti i quattro run**, con stato
termico nominale (`rawValue: 0`). Non sono stati cambiati impostazioni di energia,
priorità, servizi o attività delle altre chat. Queste misure locali non rappresentano
la matrice Mac/iPad o un profilo a risparmio energetico disattivato.

Tutti i 480 risultati API della passata finale (warm-up inclusi), i digest completi
dei 15 casi e gli input coincidono tra i due binari. Il riepilogo completo è in
[full-api-attempt2-abba-comparison.json](full-api-attempt2-abba-comparison.json);
[full-api-attempt2-summary.txt](full-api-attempt2-summary.txt) riporta le mediane.

| Caso | Swift / vDSP, prima passata (ms) | Swift / vDSP, seconda passata (ms) |
| --- | ---: | ---: |
| Continuo 32.768 | 4,062 / 4,216 | 4,339 / 4,227 |
| Continuo 500.000 | 83,320 / 82,944 | 85,606 / 82,916 |
| Continuo 1.000.000 | 175,637 / 175,209 | 179,305 / 175,400 |
| Ripetuto 500.000 | 15,101 / 16,166 | 15,390 / 15,805 |
| Zeri in coda | 10,044 / 10,629 | 10,082 / 10,623 |
| Subnormali in coda | 8,613 / 9,227 | 8,750 / 9,215 |

I casi grandi mostrano vantaggi piccoli e variabili: circa 0,45–3,24% su 500.000 e
0,24–2,23% su un milione. I fallback con zeri e subnormali peggiorano di circa
5–7%; anche il controllo ripetuto è più lento nelle due passate. Non viene attribuita
ogni differenza a una sola causa: versione del codice compilato, allocatore e stato
del sistema incidono anche senza compilazioni concorrenti. Il confronto non
dimostra un beneficio end-to-end robusto e non giustifica l’adozione.

## Memoria

Due ulteriori processi separati misurano il caso continuo da 500.000 osservazioni,
con input/output identici e senza concorrenza rilevata. I raw sono
`rss-continuous500k-reference*` e `rss-continuous500k-native*`.

`/usr/bin/time -l` osserva 36.306.944 byte di RSS massimo nel riferimento e
36.323.328 nel candidato: +16 KiB, sostanziale parità in questa osservazione.
I campi `getrusage` nel JSON sono letti prima della serializzazione finale e possono
essere diversi dal massimo rilevato dal processo supervisore. Non vengono usati
per dichiarare un risparmio di memoria del kernel.

Entrambe le misure comprendono allocatore, generatori, buffer dei digest e controlli
untimed; non isolano il workspace del sort. Non sono riportati limiti universali
RSS o miglioramenti energetici.

## Ricetta di riproduzione

Usare la toolchain richiesta dal repository. Non eseguire build o test in parallelo
alle misure. Il checkout di esempio ricostruisce soltanto questo esperimento dalla
baseline della patch; per l’identità delle altre fonti compilate confrontare gli
inventari. Gli SHA dei binari storici identificano i run registrati, non un risultato
che ogni rebuild deve riprodurre.

```sh
sort_experiment="$(pwd)/docs/evidenze/allegati/GS-VER-260/esperimento-sort"
sort_capture_root="$(mktemp -d "${TMPDIR:-/tmp}/GlifiAppleSort260.XXXXXX")"
export GLIFI_SORT_EVIDENCE_DIRECTORY="$sort_capture_root"
export GLIFI_SORT_WORKTREE="$sort_capture_root/work"
mkdir -p "$GLIFI_SORT_WORKTREE" "$sort_capture_root/binaries"
git archive 02c1c66 | tar -x -C "$GLIFI_SORT_WORKTREE"
cp "$GLIFI_SORT_WORKTREE/Packages/GlifiCore/Sources/GlifiCore/GlifiDescriptiveStatistics.swift" \
  "$sort_capture_root/original-descriptive.swift"
(cd "$GLIFI_SORT_WORKTREE" && git apply --check "$sort_experiment/candidate.patch" \
  && git apply "$sort_experiment/candidate.patch")
cp -R "$GLIFI_SORT_WORKTREE/Packages/GlifiCore" "$sort_capture_root/reference-package"
python3 - "$sort_capture_root" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
source = (root / "original-descriptive.swift").read_text()
needle = "    public static let maximumObservationCount = 1_000_000"
source = source.replace(needle, needle + "\n\n    // Benchmark metadata only.\n"
    + "    package static let minimumAcceleratedSortCount = 32_768", 1)
(root / "reference-package/Sources/GlifiCore/GlifiDescriptiveStatistics.swift").write_text(source)
PY
swift build -c release --package-path "$GLIFI_SORT_WORKTREE/Packages/GlifiCore" \
  --scratch-path "$sort_capture_root/build-native" --product GlifiBenchmark
swift build -c release --package-path "$sort_capture_root/reference-package" \
  --scratch-path "$sort_capture_root/build-reference" --product GlifiBenchmark
cp "$sort_capture_root/build-native/release/GlifiBenchmark" \
  "$sort_capture_root/binaries/GlifiBenchmark-native"
cp "$sort_capture_root/build-reference/release/GlifiBenchmark" \
  "$sort_capture_root/binaries/GlifiBenchmark-reference"
python3 "$sort_experiment/observe-benchmark.py" probe
# Proseguire solo dopo un probe quieto; i monitor di ogni run restano vincolanti.
python3 "$sort_experiment/observe-benchmark.py" reference pass1-A-reference
python3 "$sort_experiment/observe-benchmark.py" native pass1-B-native
python3 "$sort_experiment/observe-benchmark.py" native pass2-B-native
python3 "$sort_experiment/observe-benchmark.py" reference pass2-A-reference
python3 "$sort_experiment/observe-benchmark.py" reference rss-reference \
  --case=continuous-500000
python3 "$sort_experiment/observe-benchmark.py" native rss-native \
  --case=continuous-500000
```

Il runner misura sette campioni della stessa API in entrambi i binari. Confrontare
anche input/output SHA e tutti i campi `contentionObserved`; un probe quieto non
sostituisce il monitor durante la misura. I risultati contesi devono essere tenuti
separati e non promossi.

## Provenienza e riservatezza

I JSON del harness, gli assessment, i tempi e gli inventari senza dati personali
sono copiati byte per byte dalla cache locale. I monitor sono **derivati redatti**:
conservano soltanto `processName`, `PID` e `CPU` dei processi rilevanti, oltre ai
timestamp dei campioni. Percorsi degli eseguibili, command line, dettagli estranei
e liste di altre applicazioni sono rimossi. La sanitizzazione è dichiarata nei
monitor e in [artifact-provenance.json](artifact-provenance.json), con SHA originale
e SHA pubblicato. I runner log duplicativi non sono versionati.

Non sono inclusi binari, cache di compilazione, directory di lavoro o output con
percorsi privati. Gli originali restano nella cache locale fino alla verifica della
copia; [artifact-sha256.json](artifact-sha256.json) elenca gli allegati consegnati.
Il programma di osservazione allegato usa directory ricevute tramite variabili
esplicite e registra soltanto i dati di processo ammessi sopra.

## Decisione

Il candidato non entra nel prodotto. Non vengono aggiunti import Accelerate,
threshold, flag benchmark o nuovi test di adozione al tree compilato. La patch e le
misure restano come provenienza di un esperimento scartato; nessuna clausola viene
promossa per il solo fatto che l’API Apple è disponibile.
