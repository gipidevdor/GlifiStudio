<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0035 — Completamento nativo delle varianti KH Coder

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0035 |
| Tipo | Decisione di ambito e architettura |
| Versione | 1.0.0 |
| Stato | Accettato per ambito e architettura; gate locale superato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita corrente di realizzare tutti gli algoritmi mancanti, con implementazione nativa Apple; GUI assegnata separatamente |
| Riferimenti | RF-087; ADR-0002; ADR-0008; ADR-0031; ADR-0032; GS-MET-001-23; GS-API-002; GS-DOR-233 |

## Contesto

Le famiglie introdotte da ADR-0032 non equivalevano a tutte le varianti esposte
dal manuale pubblico KH Coder 3 e dal sorgente pubblico ufficiale. Il confronto
ha identificato comunità/layout/Prim, dissimilarità Simpson, SMACOF ordinale e
multi-start, SOM esagonale e diagnostiche, selezione del numero di topic e una
pipeline linguistica opzionale. Naive Bayes e regole di codifica erano già presenti.
Il riferimento pubblico non permette di attestare la parità con l’edizione
chiusa corrente; né la disponibilità di una famiglia prova equivalenza numerica.

L’iniziatore autorizza esplicitamente il completamento nel motore e nelle
facciate headless, mantenendo il lavoro GUI separato. Questo record e la DoR
sono consolidati dopo l’avvio implementativo autorizzato: non attestano una
registrazione preventiva inesistente.

## Decisione

Aggiungere primitive in memoria con varianti e politiche esplicite in
[GS-MET-001-23](../metodi-analitici/23-operatori-kh-coder.md). GlifiCore possiede
calcolo e limiti; GlifiKit espone operazioni `@concurrent`, errori tipizzati e DTO
indipendenti dal Core. Le nove operazioni aggiuntive riusano il JSON piatto e
lo schema/versione 1 di [GS-API-002](../api/02-richieste-analitiche.md), con nuovi
valori `ordinal` e `simpson` nei metodi esistenti. Le richieste precedenti
conservano protocollo e default.

Usare implementazioni Swift originali e API di sistema, inclusi LAPACK/vDSP già
adottati e Natural Language opzionale per l’italiano. Lo stemmer implementa la
specifica Snowball italiana 3.1.0; non incorpora sorgente GPL di KH Coder.
Non introdurre dipendenze esterne, runtime R/Python, rete, telemetria, download di
asset, entitlement, persistenza o integrazione GUI in questo incremento.

I risultati espongono semantica dei pesi, obiettivi, tie, inizializzazione,
convergenza, seed e provenienza applicabili. Le richieste oltre budget e i casi
numerici non definiti falliscono oppure conservano assenza e motivo dichiarati;
non producono un risultato apparentemente completo. La pipeline linguistica
mantiene superficie come default, distingue lemma/stem e unknown/notRequested,
conserva offset e OS senza inventare una versione del modello Apple.

## Verifica e conseguenze

Oracoli analitici, formule indipendenti, proprietà, fixture di trasporto e test
di input ostili/cancellazione verificano i contratti. Il benchmark è informativo
finché non esiste una soglia approvata; nessun incremento di velocità è dedotto
dal solo uso di un’API nativa. Accelerazioni successive richiedono confronto
misurato e parità scalare sulla stessa semantica.

I nuovi identificatori restano `candidate` secondo ADR-0031; non ereditano
manifest o approvazione V6 da varianti precedenti. Il gate locale completo è superato nel perimetro dichiarato in [GS-VER-233](../evidenze/GS-VER-233-completamento-kh-coder.md).
Il rollback è un revert dei nuovi operatori e del relativo trasporto, senza
migrazione dei progetti. L’italiano resta la sola baseline linguistica del lotto.

## Alternative considerate

Delegare a KH Coder/R avrebbe introdotto runtime e vincoli non richiesti.
Rinominare le sole famiglie esistenti avrebbe nascosto differenze di obiettivo,
topologia e algoritmo. L’implementazione nativa mantiene tali differenze
esplicite, senza promettere identità con tutti i parametri di un altro prodotto.
