<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Analisi temporale e principio metadata-first

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-17 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.2 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-21 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Metadati come dimensioni analitiche

Autore, anno, categoria, provenienza e campi utente non sono soltanto filtri: possono
definire unità, strati, gruppi, assi di matrice e popolazioni di confronto. Ogni
campo **DEVE** avere identità, tipo (`nominale`, `ordinale`, `quantitativo`,
`temporale`, `testo libero`), cardinalità, dominio, unità, provenienza e politica dei
mancanti. Un testo libero **NON DEVE** diventare categoria senza trasformazione
esplicita.

Raggruppamenti derivati conservano espressione, versione dello schema, ordine delle
categorie, appartenenze multiple e unità escluse. La modifica di un metadato invalida
soltanto i discendenti del DAG che lo usano.

## Semantica temporale

Un valore temporale **DEVE** distinguere istante, data civile, intervallo o periodo
incerto. Precisione, calendario, fuso orario e sorgente sono obbligatori quando
applicabili. L'anno bibliografico non deve essere convertito implicitamente in un
istante.

La discretizzazione dichiara:

- origine e ampiezza degli intervalli;
- calendario/fuso e bordi chiusi o aperti;
- finestre fisse, mobili, cumulative o event-based;
- assegnazione di intervalli o documenti con più date;
- politica per date mancanti, incerte o fuori dominio;
- denominatore per frequenze relative e correzione per esposizione.

## Analisi

Frequenze, tassi, dispersione, diversità, keyness, associazioni e rappresentazioni
possono essere calcolate per intervallo come serie di artefatti comparabili. Una
variazione deve distinguere differenza assoluta, relativa, log ratio, trend stimato e
test inferenziale. Composizione mutevole del corpus e differenti quantità di testo
**DEVONO** essere visibili; un aumento dei conteggi grezzi non è automaticamente un
trend lessicale.

Il documento senza data è escluso, assegnato a una categoria `mancante` o imputato
soltanto secondo una policy persistita. L'imputazione produce un artefatto stimato e
non sovrascrive il metadato osservato.

## Verifica

Fixture coprono anni bisestili, cambi di fuso/ora legale quando applicabili, bordi,
precisioni diverse, intervalli sovrapposti e mancanti. Si verificano partizioni,
denominatori, invariance dell'ordine di importazione, lineage del punto temporale e
invalidazione selettiva dopo una modifica di metadato.

## Variante headless implementata

`Temporal-calendar-token-rates-v1` aggrega conteggi osservati in GlifiCore;
`GlifiStudioTextAnalytics.temporalFrequencies` ne espone la facciata GlifiKit
`@concurrent`. È una variante candidata in memoria: non introduce uno schema
persistito, non aggiunge nodi al planner e non dichiara completati gli studi su
dispositivo o la review scientifica esterna.

### Input e partizione

Ogni documento dichiara revisione sorgente univoca, provenienza non vuota del
metadato, valore temporale osservato, numero totale dei token e conteggi dei
termini selezionati. I conteggi sono interi non negativi; la loro somma non supera
l'esposizione in token. Zero token implica conteggi nulli. Non si normalizzano o
fondono forme lessicali nel raggruppamento temporale.

La configurazione risolve esplicitamente:

- base `civilDates` oppure `instants(timeZoneIdentifier:)`;
- calendario gregoriano, date civili nell'intervallo `1…9999`;
- unità giorno, mese o anno, origine, larghezza positiva e numero di bucket;
- policy dei mancanti `exclude`, `separate` o `reject`;
- policy dei valori fuori dominio `exclude` o `reject`.

I confini sono `[inizio,fine)`. L'origine mensile è il primo giorno del mese;
quella annuale è il primo gennaio. La larghezza è espressa in unità di calendario,
non in secondi. I bucket vuoti restano nella serie e mantengono gli stessi termini
degli altri bucket.

Nella base civile i confini e i confronti usano aritmetica gregoriana, senza
convertire le date in istanti. Un mese osservato può alimentare bucket mensili o
annuali; un anno osservato solo bucket annuali. Il confronto con l'inizio del
periodo serve esclusivamente ad assegnare il periodo al bucket che lo contiene,
senza dichiarare osservato un giorno. I confini allineati assicurano che il periodo
non venga diviso fra bucket.

Nella base istante il fuso è obbligatorio, esplicito e valido per Foundation;
il calendario non usa il fuso o la locale correnti. I confini corrispondono alla
mezzanotte locale e possono distare 23 o 25 ore. Una mezzanotte ripetuta sceglie la
prima occorrenza; una data locale senza mezzanotte valida è rifiutata. Date civili
e istanti non possono essere mescolati nella stessa serie.

Intervalli e periodi incerti hanno tipi distinti ma sono rifiutati da questa
variante: nessun punto medio, frazionamento del conteggio o imputazione è implicito.
La loro eventuale assegnazione richiederà una variante scientifica separata.

### Output, denominatori e provenienza

Ogni bucket restituisce confini tipizzati, numero di documenti, esposizione totale
in token e, per ciascun termine `w`:

```text
frequenza(w,b) = somma dei conteggi osservati nei documenti assegnati a b
DF(w,b) = numero dei documenti assegnati a b con conteggio(w) > 0
tasso-per-mille(w,b) = 1000 × frequenza(w,b) / token(b)
```

Con esposizione nulla il tasso è non definito (`nil`), anche se il conteggio è
zero. L'esposizione comprende tutti i token dichiarati, non soltanto i termini
selezionati. Non si divide per la durata del bucket e non si chiama il risultato
tasso per unità di tempo. I risultati sono descrittivi, senza inferenza di trend,
correzione causale o assunzione di composizione costante del corpus.

L'aggregato `missing`, quando richiesto, conserva gli stessi denominatori e
lineage dei bucket. Le esclusioni distinguono data mancante, prima del dominio e
dopo il dominio, conservando revisione e provenienza del metadato. Ogni termine
elenca inoltre le revisioni con contributo positivo. Revisioni e lineage hanno
ordine canonico; termini in ordine lessicografico, bucket cronologici. L'ordine
di importazione non cambia il risultato.

L'implementazione materializza la chiave canonica una sola volta per revisione
prima dell'ordinamento. La posizione dei termini nel vocabolario ordinato è
condivisa fra gli aggregati: frequenze e liste dei contribuenti usano accumuli
indicizzati, senza ricostruire dizionari per bucket. Le somme restano intere con
controllo dell'overflow; contribuenti, lineage, termini nulli e tassi conservano
lo stesso ordine e significato. Le modifiche di struttura e le misure Release
prima/dopo su input sintetico deterministico sono tracciate in GS-VER-169;
non costituiscono una nuova variante scientifica né una promozione di stato.

Il successivo affinamento conserva l'ordinamento come indici dell'input originale.
Le chiavi canoniche temporanee vengono rilasciate al termine del helper di
ordinamento; validazione e partizione non richiedono una copia ordinata dei
documenti. Anche bucket e categoria dei mancanti conservano indici, risolti
soltanto durante la sintesi. Le visite seguono lo stesso ordine canonico e le
stesse riduzioni controllate, incluse validazione dei documenti poi esclusi,
esposizioni nulle e provenienza. I confronti su casi sparsi, densi e senza termini
con mancanti, con checksum completi dell'input e del risultato, sono registrati
in GS-VER-170. La rappresentazione interna non modifica il contratto pubblico,
le policy o la cancellazione.

### Limiti, errori e verifica della variante

Massimo 100.000 documenti, 10.000 bucket e larghezza massima 10.000 unità; massimo
10.000 termini e 1.000.000 celle in ingresso e in uscita (compresa la categoria
mancante). Termini e provenienza sono bounded a 4.096 byte ciascuno e 64 MiB
aggregati, contando le ripetizioni fra documenti. I limiti sono
controllati prima delle allocazioni principali e l'overflow dei conteggi è
rifiutato. La cancellazione è osservata durante validazione e aggregazione.

Date non valide, esposizioni incoerenti, revisioni duplicate, tipo o precisione
incompatibili e assegnazioni non supportate producono `GlifiFailure` tipizzata;
la facciata conserva la tassonomia in `GlifiStudioFailure`. Nessun risultato
parziale viene pubblicato.

`GlifiTemporalAnalysisTests` verifica calcoli a mano, anno bisestile 2024,
eccezioni secolari 1900/2000, bordi, mesi/anni, bucket vuoti, mancanti, overflow,
ordine invertito, cambio d'ora di Roma e giorno locale soppresso in Pacific/Apia.
`GlifiTemporalAnalysisPresentationTests` verifica conteggi e lineage attraverso
GlifiKit. La tracciabilità dell'incremento è in GS-VER-168.
