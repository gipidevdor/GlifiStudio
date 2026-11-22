<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-199 — Identità e limiti del riuso keyness

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-199 |
| Tipo | Evidenza di correzione dei metadati e dell'admission al riuso |
| Versione | 1.2.0 |
| Stato | Superato nel perimetro automatico macOS |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-199; RF-011; RF-031; RQ-003; RQ-024; RQ-058 |

## Difetto e perimetro

Il descrittore keyness omette il livello di confidenza dai parametri risolti;
la validazione della cache non confronta il livello e non applica il limite
richiesto della famiglia. Il difetto consente un riuso con intervalli del
livello precedente o con una famiglia oltre il nuovo budget.

La correzione include il livello nell'identità e controlla livello e limite
anche sul riuso. Il limite resta fuori dal nodo, così un budget diverso ma
sufficiente non causa ricalcoli. Gli Artifact keyness v2 con il descrittore
precedente privo del parametro rimangono leggibili;
i nuovi descrittori possono richiedere un nodo nuovo, senza migrazione,
modifiche al formato o alle formule.

## Verifica da acquisire

La DoR Ready precede la patch. Due regressioni Core devono mostrare RED prima
del fix e GREEN dopo: livello 0,95 seguito da 0,80 con nodo corretto e riuso
della ripetizione; famiglia già materializzata oltre il successivo cap ridotto
rifiutata con `keyness.hypothesis-limit-exceeded`, budget maggiore compatibile
riusabile senza commit estraneo. Le identità e le generazioni osservate vanno
registrate con gli esiti effettivi, senza presumere successo dai soli test scritti.

CMP-199 è `verified` nel perimetro automatico macOS del nuovo lotto. L'evidenza è dipendenza di
[GS-VER-198](GS-VER-198-keyness-macos.md); il nuovo gate identifica il
contenuto effettivamente verificato e non riutilizza lo snapshot 196/197.

## RED osservato

La suite mirata `GlifiKeynessCacheContractTests` termina con **exit 1, due test
falliti e sei issue** sul codice non corretto. La richiesta di livello 0,80
restituisce 0,95, riusando Artifact, nodo e digest; manca inoltre il parametro
del livello nel descrittore. Nel secondo caso una famiglia cached di tre
termini viene restituita con limite richiesto due, senza la failure prevista.
Log: `199-red.log` nel dossier del lotto.

La patch della factory e della validazione viene applicata soltanto dopo questo
RED.

## GREEN mirato osservato

La suite mirata termina con **exit 0, due test superati, zero falliti**, in
0,111 secondi. Il cap due rifiuta la famiglia cached di tre termini con la
failure prevista; il budget sufficiente tre riusa lo stesso Artifact. Il livello
0,80 produce Artifact, nodo e digest distinti; tornare a 0,95 riusa il nodo
precedente senza nuova generazione. Log:
`199-green.log` nel dossier.

L'esito dimostra i due contratti corretti, senza misure di prestazione dedotte
dal tempo della suite. Il gate/preflight del nuovo snapshot è registrato sotto.

## Prove aggiuntive del guard e del legacy

L'estensione Ready 1.1 precede l'aggiunta di due ulteriori test Core. La corsa
conclusiva `--filter keyness` termina con **exit 0: otto test Core superati**, di
cui quattro esistenti e **quattro di GS-DOR-199**, più quattro definizioni Kit
con sette esecuzioni. Log:
`198-199-keyness-final-retry.log` nel dossier.

Il primo test aggiuntivo usa la vera factory e `storeArtifact`: un payload 0,95
associato al nodo richiesto 0,80 è rifiutato con
`keyness.descriptor-result-mismatch`, senza nuova generazione. Questo esercita
il guard sul risultato riusato, distinto dal test dell'identità del descrittore.
Il secondo memorizza un Artifact **keyness v2, con livello già presente nel
payload**, e un descrittore precedente reale ottenuto da JSON senza il parametro
del livello; riapre il package e legge i byte conservati. La nuova richiesta
usa il descrittore attuale senza riscrivere il legacy. Questa prova non riguarda
il payload keyness v1 precedente a Fisher e agli intervalli.

Queste sono prove controllate sui confini reali del package, senza nuova
versione di schema o API speciale di test. I due RED storici restano soltanto
quelli documentati sopra; le due prove aggiunte non vengono presentate come
regressioni osservate fallire prima del fix.

## Gate e identità della revisione

`make verify-macos` e il packaging `--macos-only` sono entrambi superati con
exit 0 sullo snapshot di **854 file**, manifest SHA-256
`0ed9b459878fbc6922245faac4ef5ce4c1b9b15804aa7ec6fdc4d4eb7e0add91`,
base `a86a53b512bd777f191c89692e0c573a3d37a3ff`.
[GS-VER-198](GS-VER-198-keyness-macos.md) registra il gate comune: 448 test
Core/Kit, 153 righe di oracoli, due PDF/A-2u, CLI/recovery/QueryAST e 195
esecuzioni native; build Debug/Release, analisi e archivio macOS validi.

Il dossier è
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-21-0ed9b459/`;
l'archivio di 7 957 734 byte ha SHA-256
`1122fb4261eb1c7e640c2046af43327e5965dbcaaf9fc3d1cbe9f97aa6c13985`.
Sono prove locali sul contenuto congelato, senza attribuzione a un nuovo
commit/CI remota o a sorgenti successivi. Nessuna build iPadOS è inclusa.

Il confronto conclusivo conferma invariati i sorgenti posseduti da questo lotto,
ma esclude quattro percorsi Core/test modificati successivamente da altre
sessioni: `GlifiAnalysisGraph.swift`, `GlifiIdentifiers.swift`,
`GlifiDigestEncoding.swift` e `GlifiDigestEncodingTests.swift`.
[GS-VER-198](GS-VER-198-keyness-macos.md) elenca i percorsi completi e conserva
la distinzione dallo snapshot verificato; nessuna compatibilità con tali
ottimizzazioni viene inferita. La pulizia completata del solo lotto libera
circa 2,92 GiB, conservando dossier, archivio e toolchain attive.

## Limiti

La correzione riguarda identità e admission di questa analisi, non un audit
universale degli Artifact o una nuova validazione scientifica degli intervalli.
Nessuna prova GUI, iPadOS, VoiceOver, G4 o CI remota è attribuita ai test locali.
Le modifiche parallele degli altri programmi rimangono preservate e distinte.
