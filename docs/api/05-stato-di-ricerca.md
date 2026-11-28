<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Stato di ricerca, variabili e preparazione italiana

| Campo | Valore |
| --- | --- |
| Identificatore | GS-API-005 |
| Tipo | Contratto applicativo e persistente |
| Versione | 1.0.0 |
| Stato | Implementazione in verifica |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di completamento funzionale KH Coder; ADR-0047 |
| Riferimenti | RF-013; RF-016; RF-040; GS-STD-001-11; GS-API-003 |

## Contratto e tipi

`researchState()` restituisce una revisione composta da `revision`, definizioni
`fields`, osservazioni `records`, selezioni `subsets` e `preparation`.
`saveResearchState(_:expectedRevision:)` richiede la revisione corrente anche nel
payload e restituisce la successiva. Una revisione superata produce
`research.stale-revision`; non viene sovrascritta la modifica dell'altra finestra.

Ogni campo ha identità ASCII stabile `[a-z0-9._-]{1,64}`, etichetta e tipo:
testo, numero binary64 finito, booleano o data civile gregoriana `yyyy-MM-dd`.
`missing` è distinto da stringa vuota, zero e falso. Un'osservazione appartiene
alla revisione immutabile della fonte; i nomi dei file non sono identità.
Un campo sconosciuto, tipo errato, data impossibile o fonte inesistente impedisce
il commit. I valori derivati possono dichiarare l'Artifact che li ha prodotti;
questo deve esistere nella generazione verificata.

La definizione di un campo derivato può conservare `derivation`, con
`artifactID`, `operationIdentifier` e `parameters` stringa chiave/valore. Per
un taglio gerarchico sono registrati il produttore dell'albero, il nome della
trasformazione e il numero di gruppi effettivamente scelto. La provenienza di
creazione del campo resta distinta dalle eventuali modifiche manuali dei
singoli record. Massimi: 64 parametri, chiavi ASCII di 64 byte, 4.096 byte per
valore e 65.536 byte complessivi. Una derivazione con Artifact inesistente o
parametri non conformi impedisce il commit; la stessa verifica vale alla
rilettura. Le definizioni precedenti prive di `derivation` restano leggibili.

Il valore JSON ha un tag `type` con `text`, `number`, `boolean` o `date` e
un membro `value` primitivo del tipo corrispondente, per esempio
`{"type":"text","value":"Nord"}`. Un mancante è `{"type":"missing"}` e
non ammette un membro `value`. Il numero zero viene serializzato con segno
positivo. `derivationArtifactIDs` associa ciascun campo derivato al proprio
Artifact senza sovrascrivere la provenienza degli altri campi dello stesso record.

`origins` conserva per ogni campo il digest dell'input, il foglio eventuale e
riga/colonna originali con base uno. `$text` e `$id` identificano le colonne del
testo e dell'identificativo esterno. Il digest non contiene path o segreti.
La provenienza di una cella importata non viene sostituita da quella della vista.
Le origini richiedono un originale tabellare verificato, già nel progetto o
incluso nella stessa transazione: digest dei byte, schema/nodo dell'archivio,
foglio/riga/colonna mappati e identità del testo derivato devono concordare.
Un riferimento a un archivio inesistente o a una cella estranea viene rifiutato
prima del commit. Non si ripete l'estrazione del foglio a ogni lettura dello stato.

## Selezione combinata

`selectResearchSources(_:)` riceve una congiunzione di `subsetID`, uguaglianza
tipizzata `fieldID`/`value` e `query` facoltativi. Campo e valore devono comparire
insieme. Un confronto con `missing` comprende anche le fonti senza osservazione.
La query usa il predicato completo per fonte, compreso `NOT`: non ricostruisce la
selezione da un'anteprima KWIC troncata. L'ordine restituito è quello delle fonti
nella generazione. Le selezioni nominate conservano identità esplicite e restano
riutilizzabili nelle analisi che ricevono le revisioni selezionate.

## Preparazione condivisa

La preparazione sceglie forme normalizzate, lemmi Apple italiani oppure stemming
Snowball italiano. Lemmi e categorie grammaticali richiedono asset già presenti;
indisponibilità o annotazioni ignote producono failure esplicita, senza download
o sostituzioni. Il digest comprende le liste canoniche e il runtime Apple quando
si usano previsioni linguistiche. Una lista riordinata o duplicata conserva
l'identità semantica; una scelta lessicale diversa la modifica.

Le esclusioni esplicite prevalgono. Le inclusioni conservano parole osservate
anche se stopword o escluse dal filtro grammaticale; non inventano occorrenze.
Una parola contemporaneamente inclusa ed esplicitamente esclusa è un errore di
configurazione. I composti sono espressioni osservate di 2–16 parole, con
preferenza per la più lunga, all'interno della stessa frase e dello stesso
paragrafo. I gap tra componenti devono contenere soltanto spazi Unicode:
`città, di Roma` non diventa `città di Roma`. L'intervallo unito resta UTF-8
half-open nel testo estratto originale. Le categorie non concordi dei componenti
non vengono trasformate in una categoria grammaticale inventata del composto.
Se una query richiede `pos` per una rappresentazione contenente un composto
senza categoria univoca, la ricerca restituisce `query.unsupported-annotation`;
non interpreta l'annotazione assente come zero occorrenze. Una dichiarazione
di composto contenente punteggiatura tra componenti è rifiutata già durante
la validazione della configurazione.

Il codice di preparazione restituisce `GlifiCodingDocument` con i valori
stringa delle variabili presenti e la provenienza linguistica effettiva.
L'integrazione nelle analisi registra digest e configurazione effettivi;
gli artefatti calcolati con una preparazione precedente restano identificabili
come storici e non possono essere riusati come risultati della nuova scelta.

## Persistenza, compatibilità e recupero

Lo schema del payload è `studio.glifi.artifact.research-state.v1`, versione 1.
Ogni revisione è un Artifact content-addressed con descrittore v2, identità del
progetto, digest del contenuto e dipendenza dall'Artifact precedente. Il
descrittore dichiara `sourceRevisionIDs: []`: la configurazione è autorevole e
un nuovo import non la invalida. I riferimenti alle fonti sono verificati nel
payload contro la generazione corrente. La catena richiede revisioni contigue e
un solo predecessore, senza fork silenziosi. La rilettura ricontrolla digest,
schema, nodo produttore e revisione; corruzione e schema ignoto falliscono chiusi.

Non cambia lo schema del manifest o di SQLite. Un progetto precedente senza
questi Artifact restituisce revisione zero con configurazione vuota; scrivere
la prima revisione è additivo e non richiede migrazione distruttiva. Le revisioni
precedenti e le fonti restano immutabili. Il commit point e il recupero sono
quelli transazionali del package `.glifi`, inclusa l'importazione congiunta di
righe e variabili quando richiesta dall'importatore tabellare.

Il requisito minimo del lettore sale a 3 soltanto al primo salvataggio di stato,
archivio tabellare o risultato di ricerca. I progetti ordinari mantengono il
requisito 1; quelli contenenti soltanto documenti ricchi e analisi precedenti
mantengono il requisito 2. Il lettore corrente apre entrambi senza cambiare i
byte del manifest o del database. Un lettore precedente rifiuta i progetti che
richiedono 3, anziché ignorarne la preparazione autorevole. Il requisito resta
nei commit successivi e il lettore corrente rifiuta requisiti futuri sconosciuti
o un requisito artificiosamente abbassato in presenza di dati di ricerca.

## Limiti e verifica

Massimi: 256 campi, 100.000 osservazioni, 500.000 celle, 1.000 sottoinsiemi,
200.000 riferimenti complessivi nei sottoinsiemi, 16 MiB per stato e
10.000 revisioni. Le liste lessicali hanno massimo 10.000 termini e 1 MiB per
lista; massimo 1.000 composti. La preparazione ammette 8 MiB di testo, 100.000
token e 20 milioni di confronti dei componenti. La selezione testuale applica
un budget cumulativo di 64 MiB di testo letto. Cancellazione e limiti precedono
la pubblicazione di uno stato nuovo.
La verifica della provenienza ammette 1.000 dataset distinti e un budget
cumulativo di 256 MiB di archivi letti per operazione.

Le suite dedicate verificano riapertura, import successivo, concorrenza delle
revisioni, tipi e date, mancanti, corruzione, composizione dei filtri con `NOT`,
precedenza lessicale, confini dei composti, digest canonico e coordinate Unicode.
Gli esiti effettivamente eseguiti e i limiti dell'integrazione sono registrati
nell'evidenza del lotto; questo documento non anticipa il risultato del gate.
