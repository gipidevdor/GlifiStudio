<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0047 — Dataset, preparazione e lavoro di ricerca persistenti

| Campo | Valore |
| --- | --- |
| Identificatore | ADR-0047 |
| Versione | 1.0.0 |
| Stato | Accettata per il perimetro autorizzato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Iniziatore del progetto, richiesta esplicita corrente |
| Data | 2026-11-28 |
| Decisore | Iniziatore del progetto, richiesta esplicita corrente |
| Riferimenti | RF-013; RF-015; RF-016; RF-040; RF-087; GS-STD-001-11; ADR-0028; ADR-0041; ADR-0043 |

## Contesto

La richiesta corrente autorizza importazione CSV/Excel, variabili tipizzate,
preparazione italiana condivisa e salvataggio delle analisi avanzate, mantenendo
il design nativo esistente. Le restrizioni precedenti ai risultati di sessione
di ADR-0041 sono superate esclusivamente per questo incremento.

## Decisione

Si riusano il package `.glifi` v1, il commit generazionale, il DAG e gli oggetti
immutabili verificati con SHA-256. I nuovi payload hanno schema e versione propri;
non si aggiungono sidecar autorevoli né si cambia lo schema SQLite o lo schema
del manifest. Il campo esistente `minimumReaderVersion` diventa 3 al primo commit
di dati di ricerca, per impedire a lettori precedenti di ignorarne la semantica.
Le impostazioni di progetto sono revisioni immutabili concatenate con controllo
ottimistico della revisione attesa. Dichiarano selezione vuota nel descriptor v2:
sono dati autorevoli indipendenti dall'aggiunta di fonti, non cache del corpus.
Le analisi dichiarano invece tutte le revisioni effettive, la preparazione,
la richiesta canonica e il risultato prodotto dal dispatcher condiviso.

L'importazione tabellare conserva i byte originali e il digest, le scelte di
mapping e la provenienza uno-based di foglio, riga e colonna. Le fonti testuali
derivate non vengono presentate come byte originali del foglio. Le formule non
vengono eseguite e i collegamenti esterni non sono risolti. Excel significa XLSX;
il formato binario XLS è rifiutato esplicitamente. I limiti precedono decodifica,
espansione ZIP, materializzazione delle righe e calcolo.

Forma normalizzata, lemma Apple e stemming italiano mantengono identità diverse.
Una preparazione aggiornata produce un digest diverso; i risultati precedenti
conservano la configurazione originale e sono riconoscibili come storici.
Nessuna lingua aggiuntiva, rete, entitlement o dipendenza di prodotto è introdotta.

## Compatibilità, migrazione e recupero

L'estensione è additiva. I progetti esistenti senza i nuovi payload hanno stato
vuoto e preparazione standard equivalente al comportamento precedente. Nessuna
migrazione distruttiva viene eseguita all'apertura. Il lettore corrente verifica
schema, versione, invarianti e catena delle revisioni prima dell'uso; versioni
sconosciute e corruzione falliscono in modo esplicito. I progetti ordinari conservano il requisito 1 e quelli PDF/EPUB il requisito 2;
solo i nuovi dati di ricerca richiedono il lettore 3. I lettori precedenti
rifiutano esplicitamente questi ultimi progetti, evitando analisi involontarie
con una preparazione diversa. Il lettore corrente apre le revisioni precedenti
senza migrazione distruttiva. Il recupero generazionale resta quello del
package esistente. Una modifica incompatibile futura richiederà una nuova ADR e
migrazione su copia verificata.

## Verifica e limiti

Sono richiesti test di parsing ostile, provenienza, tipi/mancanti, concorrenza,
riapertura senza ricalcolo, conservazione attraverso importazioni successive,
invalidazione semantica e parità Kit/CLI. La verifica macOS finale e gli audit
manuali sono registrati separatamente: la decisione non ne anticipa l'esito.

## Cattura dei laboratori espliciti

L'autorizzazione comprende anche Statistica, Operatori, Valutazione e
Linguistica. I primi tre conservano i DTO dei dispatcher esistenti tramite
buste discriminate di cattura, senza convertirli falsamente in richieste
analitiche testuali. I dati numerici manuali non acquisiscono un'associazione
implicita alle fonti né una preparazione linguistica. La struttura delle buste,
i limiti e il trasporto CLI sono governati da GS-API-006.
