<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-284 — Regia del piano e input numerico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-284 |
| Tipo | Evidenza di refactoring interno |
| Versione | 1.1.0 |
| Stato | Superato nel perimetro macOS dichiarato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di razionalizzazione organica |
| Riferimenti | [Issue #43](https://github.com/gipidevdor/GlifiStudio/issues/43); GS-DOR-284; CMP-284/285; GS-AD-001 |

## Perimetro e invarianti

La baseline `d368285` è stata compilata prima delle modifiche. Dopo la
pubblicazione concorrente delle correzioni KH, il confronto è ripetuto contro
`a2716ef`, preservato integralmente nel merge. Il refactoring
resta nei moduli esistenti: un helper privato dello stesso actor esegue il passo
e restituisce il record dell’artefatto; il chiamante costruisce una sola volta
il risultato. Corpus mantiene il record diretto senza snapshot aggiuntivi;
keyness e capability estese condividono la verifica dell’artefatto persistito.
Admission, dipendenze, schema, progressi, cancellazione e finalizzazione restano
nella regia, con la stessa sequenza di chiamate esterne asincrone.

Un helper interno Kit conserva la grammatica decimale già identica nei due
editor, inclusi virgola, punto, esponenti e rifiuto di separatori misti e valori
non finiti. I chiamanti conservano i propri errori e la semantica delle righe.
Nessun kernel, API, schema, identità o formato persistente è modificato.

## Verifica

L’[allegato di verifica](allegati/GS-VER-284-verifica.json) registra baseline,
digest delle sorgenti interessate, confronto API e CLI, conteggi ed esiti.

- `executeAnalysisPlan`: 341 → 277 righe; costruzioni del risultato 3 → 1,
  controlli dell’artefatto mancante 2 → 1. I quattro file di produzione,
  incluso il nuovo helper, passano complessivamente da 3.993 a 3.985 righe.
- Superficie pubblica Core e Kit identica con `swift-api-digester`: si ordina
  soltanto l’elenco delle dichiarazioni di primo livello; membri, parametri,
  attributi e disponibilità restano integralmente nel confronto. Nessuna
  certificazione ABI o library evolution implicita.
- 164 casi CLI: stdout, stderr e codici di uscita identici, senza rimozione o
  normalizzazione di campi. Confronto limitato a richieste sintetiche
  deterministiche e operazioni di progetto read-only o fallite; scritture e
  stream posseduti sono coperti dai test del gate.
- Mirati superati: 5 definizioni Core e 15 Kit in 3 suite. I due nuovi test
  parametrizzati coprono 12 numeri ammessi e 8 token rifiutati attraverso le
  API pubbliche; confrontano i bit dei valori e l’intera failure di famiglia.
  Non attestano la conservazione dello zero con segno durante calcoli o JSON.
- Gate originario su `53cf248`, `make verify` macOS superato: 631 test Core e 142 Kit; 113 test nativi,
  345 esecuzioni, zero failure o skip; build Debug/Release. Superati anche
  189 controlli su 63 fixture testuali, 260 confronti completi di parità sulle
  130 operazioni Kit/CLI, 51 rifiuti, 22 checkpoint process-kill e 2 PDF/A-2u.
- Revisione indipendente di isolamento, sequenza delle chiamate esterne,
  identità, grammatica e failure: nessun rilievo azionabile. La revisione dei
  documenti ha corretto i riferimenti normativi e distinto i requisiti del
  parser da quelli dell’esecuzione prima della consegna.

Le misure strutturali descrivono duplicazione e responsabilità; non dimostrano
un’accelerazione. CMP-284/285 restano `implemented`, senza promuovere criteri
scientifici o l’intera architettura. iPadOS è rinviato su richiesta
dell’iniziatore. Xcode emette gli avvisi preesistenti CoreSimulator/device anche
con destinazioni macOS; non impediscono il superamento di test e build Mac.
Le modifiche delle altre chat e il checkout Root sono preservati.

## Riproduzione

Compilare la baseline finale `a2716ef` in uno snapshot temporaneo separato e conservare
l’eseguibile CLI prima delle patch. Per entrambe le revisioni estrarre le API
con `swift-api-digester -dump-sdk -module GlifiCore` e `GlifiKit`, usando SDK
macOS, target `arm64-apple-macosx27.0`, Swift 6, `-avoid-location` e
`-avoid-tool-args`; confrontare i JSON dopo il solo ordinamento delle
dichiarazioni di primo livello. Gli include puntano alla directory restituita
da `swift build --show-bin-path` e alla sua sottodirectory `Modules`.

Il programma di confronto CLI è condiviso con il lotto precedente, senza
duplicarne il codice:

```sh
python3 docs/evidenze/allegati/GS-VER-280/compare-cli.py \
  --reference "$reference_cli" --candidate "$candidate_cli" \
  --workspace . --output "$comparison_json"
swift test --package-path Packages/GlifiCore \
  --filter 'analysisPlanExecution|extendedCapabilitiesExecuteEndToEnd|runtimePressure|GlifiEditorDecimalContractTests|GlifiStatisticsWorkbenchTests|GlifiCoreOperatorsTests'
make verify
```

Usare Python 3.12 o successivo compatibile, la toolchain prevista dal repository
e veraPDF configurato per il gate. Log, dump API compressi e confronto CLI
completo sono conservati nelle prove locali del lotto; cache di build,
eseguibili temporanei e risultati rigenerabili sono rimossi alla chiusura.

## Integrazione finale

I gate locali e remoti del primo refactoring sono superati su `53cf248`.
Dopo l’avanzamento concorrente di main, un merge preserva 454 file di
produzione/test/controllo upstream e tutte le 165 voci della sua matrice;
i cinque file sorgente del lotto restano identici. La revisione indipendente
conferma la conservazione completa dei tre documenti in conflitto, con una
sola riga Versione e le aggiunte del lotto. API e 164 confronti CLI restano
identici rispetto alla nuova baseline `a2716ef`.

I conteggi del gate originario nell’allegato sono esplicitamente associati a
`53cf248`; non descrivono i test aggiunti dal lotto KH. Gli esiti finali del
gate sul codice unito e del preflight macOS sono registrati separatamente nella
[PR #44](https://github.com/gipidevdor/GlifiStudio/pull/44), sul suo head finale.
