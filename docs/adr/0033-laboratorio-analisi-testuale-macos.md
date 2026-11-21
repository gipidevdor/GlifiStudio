<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0033 — Completamento del laboratorio di analisi testuale macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0033 |
| Versione | 1.2.0 |
| Stato | Accettato per programma e confini; verifiche per incremento |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-11-21 |
| Data decisione | 2026-11-21 |
| Approvazione | Richiesta esplicita di completare le caratteristiche di analisi testuale, prima macOS, con chiarezza e test automatici |
| Riferimenti | RF-019; RF-020; RF-027; RF-030; RF-031; RF-042; RF-045; ADR-0002; ADR-0025; ADR-0029; ADR-0032 |

## Contesto

Il motore e GlifiKit espongono numerose analisi persistite e verificate, raggiungibili
dalla CLI ma non dai flussi applicativi. La vecchia esclusione del riassunto dal
prodotto 0.1 non descrive il nuovo ambito richiesto dall'iniziatore. Come per la
codifica qualitativa in ADR-0029, l'estensione applicativa è post-0.1 e non riscrive
retroattivamente quella baseline.

Le nuove famiglie di ADR-0032 restano un contratto headless in memoria: il solo
fatto di esporle nella libreria non fornisce persistenza, planner e UI. Anche Zipf,
Heaps, metadati e servizi linguistici hanno lacune distinte da quelle di presentazione.

## Decisione

1. Completare su macOS tre flussi contestuali dello stesso laboratorio testuale,
   nell'ordine: **A**, riassunto estrattivo; **B**, ranking lessicale dei documenti
   con BM25; **C**, frequenze e n-grammi configurabili e diversità MTLD. Ogni
   incremento ha DoR, test ed evidenza distinti.
2. Riutilizzare esclusivamente le analisi GlifiKit già disponibili: nessuna formula,
   famiglia, backend, dipendenza o formato persistente viene introdotto dalla UI.
   Il codice applicativo non interpreta nuovamente i risultati scientifici.
3. Applicare [GS-UX-001-17](../esperienza-utente/17-laboratorio-analisi-testuale.md)
   prima del codice. Il percorso parte dalle fonti e da ciò che si vuole comprendere;
   metodo, parametri e limiti restano ispezionabili senza un catalogo iniziale di algoritmi.
4. Distinguere gli offset del testo estratto dagli intervalli dei byte originali.
   Per il riassunto, Core risolve `sourceRanges` tramite SpanMap; GlifiKit li espone
   nel DTO della frase selezionata. Gli Artifact esistenti non cambiano. Messaggi
   precedenti senza mapping decodificano con elenco vuoto, che significa mapping
   non disponibile: la UI apre la fonte intera e lo dichiara.
5. Registrare capacità e lacune nel [programma GS-PLAN-002](../pianificazione/programma-analisi-testuale-macos.md).
   Le famiglie assenti o soltanto headless non sono dichiarate completate da A–C.
6. Rimandare lo sviluppo dedicato iPadOS. Il Mac bloccato e la scelta esplicita di
   soli test automatici limitano le prove di questo turno; GUI, VoiceOver,
   dispositivi e G4 restano aperti.

## Conseguenze

La baseline storica 0.1 e il gate globale multipiattaforma restano invariati.
L'estensione macOS usa il profilo esplicito di GS-DOR-167 senza attribuirgli
equivalenza con la verifica di entrambe le piattaforme.

Il primo incremento comprende una correzione di provenienza nel risultato risolto,
con compatibilità dei DTO e prove Markdown/BOM; nessuna migrazione del package.
Le altre famiglie richiedono nuove unità Ready quando contratti, dati e verifiche
sono maturi. L'approvazione del programma non è una promozione scientifica né una
verifica UX con persone.

## Estensione successiva — Ponderazione dei termini

La nuova richiesta di proseguire miglioramenti e completamenti autorizza
l'incremento **D**, ponderazione TF/TF-IDF diretta nel laboratorio macOS, tramite
la API GlifiKit persistente già verificata. La decisione iniziale A–C resta
storica; non vengono introdotti nuovi metodi scientifici o formati. Il default
applicativo esplicito è `TF-raw-v1 / IDF-smooth-v1 / RowNorm-none-v1`, con tutte
le sei varianti TF, tre IDF e tre normalizzazioni già previste da GS-MET-001-07.

D segue GS-UX-001-17 e GS-DOR-197: matrice sparsa, celle osservate conservate
anche con peso zero, righe/fonti vuote esplicite, vocabolario e DF completi,
paginazione bounded e cancellazione posseduta. La prova del precedente lotto
rimane riferita al proprio snapshot; questa estensione richiede evidenza nuova.
iPadOS, modifiche ai kernel e promozioni scientifiche ulteriori restano esclusi.

## Estensione successiva — Confronto keyness

La nuova richiesta di miglioramenti e completamenti autorizza l'incremento
**E**, completamento della keyness diretta nell'Indagine macOS. Il client rende
accessibile l'intera famiglia già restituita da Kit, con popolazioni, test
selezionato, p del G-test, correzione BH, effect size e intervalli v2; non
introduce metodi o formule né cambia la famiglia dopo avere osservato i p-value.

È approvato il ponte applicativo del livello di confidenza già maturo in Core:
`GlifiStudioKeynessOptions` aggiunge la proprietà e un init a tre argomenti senza
default, conservando esattamente l'init pubblico a due argomenti, che inoltra
0,95. È un'addizione compatibile della facciata, anche per riferimenti a funzione
a due argomenti; Artifact e digest scientifici già comprendono il parametro.
La soglia diagnostica configurabile resta distinta dalla regola Fisher fissa
con minimo atteso minore di cinque.

E segue GS-UX-001-17 e GS-DOR-198, usa cancellazione posseduta e richiede prove
proprie sul nuovo contenuto verificato. A–D e i lotti lifecycle precedenti restano
storici, senza promozione retroattiva; lo sviluppo dedicato iPadOS è rimandato.

L'esposizione del parametro fa emergere una dipendenza di correttezza:
GS-DOR-199 aggiunge il livello ai parametri risolti del descrittore e ne verifica
la corrispondenza sul risultato riusato, insieme al budget della famiglia.
Il budget rimane fuori dall'identità semantica; nessuna formula o schema cambia.
Gli Artifact keyness v2 con il descrittore precedente restano leggibili, mentre i nuovi descrittori possono
richiedere il ricalcolo con un nuovo nodo. La chiusura di E richiede anche 199.
