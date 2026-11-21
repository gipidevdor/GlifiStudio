<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-197 — Ponderazione TF/TF-IDF nel laboratorio macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-197 |
| Tipo | Evidenza di correzione e verifica applicativa macOS |
| Versione | 1.2.0 |
| Stato | Superato nel perimetro automatico macOS |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-197; RF-029; RF-030; RQ-003; RQ-011; RQ-013; RQ-058 |

## Perimetro e identità

L'incremento D del laboratorio macOS usa `analyzeTermWeighting` con sei TF,
tre IDF e tre normalizzazioni esistenti. Default UI esplicito raw/smooth/none,
ambito condiviso, `corpusOptions.standard`, nessun kernel o formato nuovo.

La matrice è sparsa e conserva le celle osservate con count positivo anche
quando il peso è zero. Fonti/righe vuote, vocabolario e DF restano espliciti;
le coppie assenti rappresentano zeri impliciti. Celle e termini hanno pagine da
50 con accesso diretto e ultima pagina. Metadati di presentazione preparati fuori
dal Main Actor; nessuna matrice densa o scansione fonti×celle nella view.
La richiesta effettiva è separata dai draft e usa ownership `runAnalysis`.
Sono corretti soltanto i commenti DocC imprecisi in Core/Kit, senza formule nuove.

Questo turno è distinto dallo snapshot `07673ac2…70b5f` del lotto precedente.
Il nuovo freeze include i contributi concomitanti presenti in quel momento,
senza promuovere loro clausole scientifiche né attestare modifiche successive.

## Verifica

`make test-macos` è superato sul lotto 196–197: **47 definizioni e 128
esecuzioni, 0 fallite, 0 saltate**, con `runtimeWarnings: []` nel riepilogo
xcresult. Cinque test parametrizzati producono 86 esecuzioni, a cui si aggiungono
42 test non parametrizzati. La suite specifica della ponderazione comprende
**6 definizioni e 78 esecuzioni**: 54 combinazioni TF/IDF/normalizzazione,
20 matrici incoerenti e quattro ulteriori test di comportamento.
Riepilogo sanificato `validated-macos-results.json` e log
`196-197-validated-green.log` sono conservati nel dossier del nuovo lotto.

Sono provati parità del risultato completo con Kit, richiesta effettiva e riuso,
scope selezionato, righe vuote, celle osservate a peso zero e zeri impliciti,
pagine complete di celle/vocabolario e accesso diretto/ultima, stato conservato
dopo failure, reset al cambio progetto e cancellazione ripetuta con retry.
Il risultato precedentemente osservato di 46 definizioni/108 esecuzioni era
anteriore ai venti casi di contenimento; non viene usato come prova di quei casi.

CMP-197 è `verified` nel perimetro automatico macOS sul nuovo snapshot.
La DoR Ready precede il codice applicativo; la sua estensione 1.1 precede la
patch e i test del contenimento. Il log contiene avvisi host CoreSimulator e
diagnostici Xcode, distinti dai runtime warning dei test.

## Gate e identità del contenuto verificato

Il lotto di **830 file**, basato su
`a86a53b512bd777f191c89692e0c573a3d37a3ff`, ha manifest SHA-256
`58d18024b9029075bdad8ffd6c8bb41ad2f1d1d4196b6fbc26aab729dfe80e8b`.
`make verify-macos` e `Scripts/check-app-store-packaging.sh --macos-only`
sono entrambi superati con exit 0: 433 test Core/Kit, 153 righe di oracoli,
due PDF/A-2u, CLI/recovery/QueryAST, 128 esecuzioni native macOS e build
Debug/Release, analisi e archivio macOS senza firma.

[GS-VER-196](GS-VER-196-collegamento-documenti-macos.md) registra conteggi,
avvisi non fatali, manifest e archivio riproducibile del medesimo gate.
Il dossier è
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-21-58d18024/`;
l'archivio `verified-source.tar.gz` di 7 837 859 byte ha SHA-256
`6f6c28c68511348055877a442d98ddace7c84ab0409ab39cff5f0e7240279152`.
Nessun nuovo commit, CI remota, gate iPadOS o prova GUI viene attribuito
all'esecuzione locale.

## Contenimento della forma del risultato

Il confine app verifica fuori dal Main Actor identità delle fonti e schema di
ponderazione della richiesta, dimensioni e budget, vocabolario/DF, indici, ordine e unicità delle
celle, count positivi e pesi finiti non negativi. La DF è confrontata con le
celle osservate; i conteggi per fonte sono prodotti dalla stessa passata bounded.
La failure app `ui.weighting.invalid-result` usa categoria `corruption`, operazione
`analyze`, retry `never`, stato `lastCommittedGeneration` e chiave localizzata
`failure.weighting.invalid-result`; non attiva read-only recovery.

Le venti mutazioni sono DTO decodificati da JSON valido e passati al helper,
non attacchi end-to-end al package. Coprono indici negativi/Int.max, dimensione
e dominio DF, DF incoerente, celle duplicate/invertite, count nullo/negativo,
peso negativo, termini duplicati/invertiti/vuoti, fonti/schema di ponderazione difformi e termine
senza cella osservata. I test controllano la failure esatta e che la chiamata al
helper non muti risultato, metadati, pagine e snapshot precedenti. La review del
percorso di produzione verifica l'ordine: validazione prima di ogni pubblicazione
UI. Non si rivendica una nuova prova integrata di apertura di package corrotto.

Il controllo di finitezza è esplicito e revisionato. Il JSON standard rifiuta
valori non rappresentabili come `1e999` prima di raggiungere il helper; non è
stata aggiunta una strategia di decodifica per NaN o infinito. Il contenimento
non verifica nuovamente formule, non modifica Artifact/API e non certifica la
semantica universale dei risultati delle altre analisi.

## Limiti

Solo macOS e verifiche automatiche secondo il perimetro concordato. Nessuna
attestazione di finestre SwiftUI reali, autosave, file provider, VoiceOver,
validazione con utenti, iPadOS o G4. Nessuna nuova CI o commit viene attribuita
alle prove locali; la compatibilità con modifiche concomitanti richiede identità
ed esiti espliciti.
