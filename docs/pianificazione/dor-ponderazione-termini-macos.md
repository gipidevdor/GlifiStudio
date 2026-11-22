<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Ponderazione TF/TF-IDF nel laboratorio macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-197 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.1.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Nuova richiesta di miglioramenti/completamenti; estensione D di ADR-0033 |
| Riferimenti | RF-029; RF-030; RQ-003; RQ-011; RQ-013; RQ-058; GS-MET-001-07; GS-UX-001-17; GS-VER-115 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Client diretto macOS di `analyzeTermWeighting` nello stesso laboratorio; sei TF × tre IDF × tre normalizzazioni, matrice sparsa completa entro i budget Kit; nessun kernel, planner, API o formato nuovo |
| requisiti | RF-029/RF-030 e RQ-003/011/013/058; parità con Kit, tutte le celle osservate comprese quelle a peso zero, fonti vuote e vocabolario/DF espliciti, richiesta effettiva e lineage invariati dai draft |
| dominio/API | Scope condiviso tutte/selezionate, `GlifiStudioTermWeightingScheme` e `corpusOptions.standard`; default UI raw/smooth/none dichiarato, non un default Kit inesistente; payload persistito `corpus-term-weighting-v1` invariato |
| failure semantics | Errori Kit per progetto/scope/varianti/limiti preservati senza clamp; shape incoerente al confine app produce `ui.weighting.invalid-result`, categoria `corruption`, operazione `analyze`, retry `never`, stato `lastCommittedGeneration`; risultato, metadati, pagine e snapshot UI precedenti conservati; `runAnalysis` gestisce cancellazione e cleanup, un commit valido non diventa falsa failure; pagine non valide non mutano la pagina corrente |
| esperienza prevista | GS-UX-001-17 D: controlli nativi it/en, azione comprensibile e dettagli progressivi; label generica Metodo per BM25/MTLD/ponderazione, picker summary invariato; Fonte N se nome non disponibile, nessun metadato persistente inventato |
| verifica | Nuovo `Apps/macOS/Tests/StudioTermWeightingTests.swift`: default e varianti, parità Kit, scope, righe vuote, count positivo/peso zero, celle implicite, vocabolario/DF, pagine/ultima/diretta, richieste immutabili, reuse/failure/cancel/reset; DTO decodificati da JSON mutato con indici negativi/fuori range/Int.max, DF corta, celle duplicate/fuori ordine, count non positivo e peso negativo; non finiti rifiutati dal decoder standard e distinti dalla verifica del helper; copertura delle combinazioni proporzionata dopo timing; gate/preflight macOS su nuovo snapshot, GS-VER-197 candidata |
| dati e migrazione | Artifact, descriptor e identità scientifiche esistenti; richiesta/pagine/metadati UI effimeri e ripuliti al cambio progetto; nessuna migrazione |
| sicurezza/privacy | Soltanto fonti del progetto e Kit; nessuna rete, dipendenza, entitlement, annotazione o nuovo dato nei log; nessun intervallo di occorrenza inventato |
| prestazioni/sistema | Standard Kit: 1 000 fonti, 256 MiB, 100 000 termini, 500 000 celle; pagine da 50 per celle e vocabolario con accesso diretto/ultima, fino a 10 000 pagine; validazione shape bounded e precomputazione fuori Main Actor dei conteggi per fonte prima di qualsiasi subscript UI, nessuna scansione Nfonti×Ncelle nella view o matrice densa |
| tracciabilità | CMP-197 inizialmente `specified`; RF-029/RF-030 e TV-029/TV-030/TV-058/TV-071, nuova evidenza, programma e CHANGELOG nello stesso incremento |
| decisioni e recupero | Estensione D registrata in ADR-0033 prima del codice; formule GS-MET-001-07 e validazione GS-VER-115 invariati; rollback UI locale senza migrazione, preservando gli altri programmi |

## Celle osservate e zeri

Il risultato conserva celle con `count>0` anche se `weight=0`. I commenti DocC
imprecisi “non-zero weighted cell” in Core e Kit vengono corretti nel medesimo
incremento, senza cambiare codice numerico o dati. Le coppie assenti hanno zeri
impliciti; una fonte senza celle rimane una riga del risultato. Ordine celle
riga/colonna e vocabolario lessicografico non vengono reinterpretati dalla UI.

## Estensione di contenimento al confine app

La lettura di un Artifact riusabile verifica nodo, hash e schema, mentre la
semplice decodifica del valore non dimostra la coerenza di tutti gli indici.
Prima di preparare metadati o pubblicare il risultato, il confine app valida fuori
dal Main Actor identità delle fonti e schema di ponderazione rispetto alla richiesta effettiva,
dimensioni entro il budget, allineamento vocabolario/DF, DF nel dominio dei
documenti e coerente con le celle osservate, indici di riga/colonna nel range,
count positivo, conteggi di celle per fonte derivati soltanto dai dati validati,
peso finito non negativo e
ordine riga/colonna strettamente senza duplicati. La UI
non usa `precondition` per questi dati e non esegue subscript prima della verifica.

La failure tipizzata usa la chiave `failure.weighting.invalid-result` e non
pubblica stato parziale né azzera risultati/metadati/pagine/snapshot precedenti.
Non attiva read-only recovery, non modifica il package e non verifica nuovamente
formule o la semantica universale degli altri Artifact.

I test di contenimento costruiscono DTO tramite JSON valido mutato. Numeri come
`1e999`, non rappresentabili come Double finito, sono rifiutati dal JSONDecoder
standard prima del helper: quel rifiuto non è rivendicato come esecuzione del
controllo di finitezza nel helper. Le verifiche di finitezza nel codice restano
esplicite e soggette a review; nessuna coercizione o strategia JSON non finita è
aggiunta al prodotto.

L'estensione Ready 1.1 precede la patch di contenimento e le prove relative.

**Ready** prima di modello, view, test e correzione dei soli commenti DocC.
iPadOS resta invariato e rimandato; il nuovo turno non estende retroattivamente
l'attestazione dello snapshot precedente. Nessuna prova GUI manuale, VoiceOver,
autosave, G4 o compatibilità con ottimizzazioni concomitanti è inferita.
