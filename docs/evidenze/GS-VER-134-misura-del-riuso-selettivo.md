<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-134 — Misura del riuso selettivo e attese della fixture v1 nel gate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-134 |
| Tipo | Evidenza prestazionale osservata |
| Versione | 1.0.0 |
| Stato | Osservato localmente; soglie non vincolanti |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | Linea di base prestazionale da confermare in G4 (ADR-0024) |

## Ambito

Chiude i due limiti dichiarati da GS-VER-133: il beneficio di ADR-0028 non era misurato e le
attese della fixture di persistenza v1 erano duplicate a mano dentro `verify.sh`.

- **Benchmark del riuso**: quarta misura di `GlifiBenchmark`. Corpus sintetico da `SplitMix64-v1`
  seed 4 (40 documenti di 400 forme su un vocabolario di 200); un'analisi di associazione su un
  gruppo di 20 documenti viene calcolata a freddo, poi ripetuta dopo l'importazione di una fonte
  estranea al gruppo, con un giro di riscaldamento e cinque campioni.
- **Fixture v1 collegata**: il contract test della CLI legge generazione, numero di fonti, forme
  lessicali e tipi da `Fixtures/Persistence/v1/basic/case.json` invece di ripeterne i valori.
  Il caso dichiara anche `typeCount`, che prima nessuno verificava.

## Procedura e risultato

Esecuzione con `swift run -c release --package-path Packages/GlifiCore GlifiBenchmark` su Apple
silicon, stato termico iniziale `nominal`:

| Grandezza | Valore osservato |
| --- | --- |
| Analisi a freddo (osservazione singola) | 0,333 s |
| Ripetizione dopo importazione estranea (mediana di 5) | 0,0655 s |
| Minimo e massimo della ripetizione | 0,0592 s – 0,0772 s |
| Rapporto freddo/riuso | 5,08 |
| Artifact conservati dopo l'importazione | 2 |
| Stesso `ArtifactID` restituito | sì |

Il gate resta verde con le attese della fixture lette dal caso.

## Limiti

Il rapporto 5,08 vale **per questa scala**: 40 documenti brevi generati sinteticamente, su una
singola macchina, senza soglia vincolante. Non è una previsione per corpus reali o grandi, dove il
costo a freddo cresce con il contenuto mentre quello del riuso cresce con la dimensione
dell'Artifact letto. Il riuso non è gratuito: 65 ms sono lettura dello snapshot, del payload
persistito e sua decodifica. Nessuna misura di memoria, energia o stato termico sotto carico, e
nessun confronto su hardware di riferimento: restano in G4.

## Esito

**Osservato localmente: il riuso selettivo evita il ricalcolo e costa circa un quinto dell'analisi
a freddo su questa scala; il valore resta una linea di base, non una soglia.**
