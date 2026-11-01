<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Ricerca e linguaggio di query

| Campo | Valore |
| --- | --- |
| Identificatore | GS-QRY-001 |
| Tipo | Specifica di design della ricerca |
| Versione | 1.3.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-10-06 |
| Approvazione | Baseline proposta; parser e usability test richiesti |
| Riferimenti | GS-DOM-001; GS-DAT-001; GS-LNG-001; GS-UX-001-11; ADR-0016 |

## Stato implementativo 0.1

La prima slice verificata rende disponibili `QueryAST v1`, parser testuale
bounded, digest canonico e valutazione sulla generazione `.glifi` autorevole. Sono
operative ricerca per forma esatta, forma normalizzata e testo tokenizzato,
phrase/slop, `NOT`/`AND`/`OR`, prossimità ordinata o simmetrica, scope di
SourceRevision, regex sul singolo token in un sottoinsieme NFA senza backtracking e
concordanze KWIC con offset UTF-8. GlifiKit e GlifiCLI usano lo stesso percorso.

La slice esegue uno scan bounded delle fonti TXT e Markdown incorporate; per
Markdown ogni match espone coordinate `extractedUTF8` e intervalli `sourceBytes`
risolti da `md-extract-v1`. Non costituisce
l'indice persistente target. Lemmi, POS, entità, metadati, range tipizzati, scope
Project/Corpus, cursor firmati, ranking e spiegazioni estese restano fail-closed.
L'ordine provvisorio è SourceRevisionID/offset finché il modello DocumentID non è
persistito. Fuzz corpus, benchmark avversari e usability test restano necessari
prima di stabilizzare il protocollo.

## Scopo e principio canonico

Ogni ricerca è rappresentata da un `QueryAST` tipizzato e versionato. Testo
inserito, builder visuale, API, CLI e futura interpretazione naturale compilano
nello stesso AST; nessun percorso esegue direttamente testo generato da un modello.

La serializzazione canonica `query-ast-v1` è il confine riproducibile. Il testo
della query è una sintassi pubblica stabile per la major, non l'identità della
ricerca.

## Algebra `QueryAST v1`

```text
Query := matchAll
       | term(field, value, matchMode)
       | phrase(field, [value], slop)
       | regex(field, pattern, flags)
       | range(field, lower?, upper?, inclusivity)
       | exists(field)
       | proximity(left, right, distance, unit, ordered)
       | not(Query)
       | and([Query])
       | or([Query])
       | within(Query, Scope)
```

Campi MVP: `text`, `form`, `normalized`, `lemma`, `document.title`,
`document.id`, `source.id`, `corpus.id` e `metadata.<field-id>`. `pos` ed `entity`
sono disponibili solo quando il profilo linguistico possiede annotazioni conformi.
Il campo non specificato equivale a `form` nel corpus selezionato, mai a una
ricerca indiscriminata su metadati.

## Grammatica testuale `glifi-query-v1`

La grammatica EBNF elimina ricorsione sinistra e assegna alla prossimità precedenza
maggiore di AND e OR:

```ebnf
query       = orExpr, EOF ;
orExpr      = andExpr, { OR, andExpr } ;
andExpr     = nearExpr, { [ AND ], nearExpr } ;
nearExpr    = unaryExpr, { ( NEAR | BEFORE ), "/", uint, unaryExpr } ;
unaryExpr   = [ NOT ], primary ;
primary     = clause | "(", orExpr, ")" ;
clause      = [ field, ":" ], ( phrase | regex | range | word )
            ;
phrase      = '"', { escaped | ? Unicode scalar except quote ? }, '"', [ "~", uint ] ;
regex       = "/", { escaped | ? scalar except slash ? }, "/", { flag } ;
range       = ( "[" | "{" ), bound, TO, bound, ( "]" | "}" ) ;
field       = identifier, { ".", identifier } ;
word        = { escaped | ? non-space non-reserved scalar ? } ;
bound       = word | phrase | "*" ;
```

Parole chiave `AND`, `OR`, `NOT`, `TO`, `NEAR` e `BEFORE` sono riconosciute ASCII
case-insensitive soltanto fuori da virgolette. `NOT` precede `AND`, che precede
`OR`; l'AND implicito ha la stessa precedenza dell'esplicito. Parenthesi prevalgono.
Backslash effettua escaping del successivo scalar; escape Unicode numerici non
sono supportati in v1 per evitare equivalenze sorprendenti.

## Semantica

- `term` confronta un valore intero nell'indice dichiarato; substring richiede un
  `matchMode` esplicito.
- `phrase` conserva ordine e, con `slop = 0`, adiacenza dei token nello stesso
  segmento. Non attraversa documenti.
- `proximity` misura distanza in token di superficie per default; altre unità sono
  enum versionate.
- `range` è tipizzato dallo schema dei metadati. Date incomplete e stringhe non
  sono convertite implicitamente.
- `regex` opera sulla forma di superficie di un singolo token in MVP. Ricerca
  arbitraria sull'intero corpus richiede una futura variante con budget proprio.
- `not` è complemento rispetto allo Scope risolto, non rispetto all'intero progetto.
- Campi o annotazioni assenti producono `unsupportedField`, non zero risultati.

La normalizzazione Unicode e linguistica è quella della vista indicizzata
GS-LNG-001. Case e diacritici sono sensibili per default; flag espliciti possono
selezionare viste insensibili già materializzate.

## Scope, risultato e ordinamento

Lo Scope congela ProjectID, CorpusVersionID, eventuale selezione di documenti e
policy di accesso. Un risultato restituisce QueryAST canonico, scope, versione
dell'indice, match con SourceReference, score opzionale, spiegazione del match e
Caveat.

Senza ranking richiesto, l'ordine è `DocumentID`, posizione UTF-8, match ID. Con
ranking, la variante di score e il tie-break sono dichiarati. Paginazione usa un
cursor firmato localmente con identità di query e indice; offset numerici instabili
non sono un contratto API.

## Diagnostica

Ogni errore contiene codice stabile, intervallo UTF-8 nel testo della query,
argomenti localizzabili e correzioni strutturate. Codici minimi:
`unexpectedToken`, `unterminatedPhrase`, `invalidEscape`, `unknownField`,
`typeMismatch`, `invalidRange`, `unsupportedAnnotation`, `regexRejected`,
`budgetExceeded` e `staleCursor`.

La UI localizza il messaggio senza localizzare i codici, i nomi canonici dei campi
o la grammatica. Alias italiani possono essere offerti dal builder e compilati nel
nome canonico, ma non entrano nella serializzazione.

## Sicurezza e limiti computazionali

Il parser è iterativo o limita profondità e nodi. La baseline impone massimi
configurabili: 64 KiB di query, profondità 32, 1.024 nodi AST, phrase 256 token,
prossimità 10.000 token, pattern regex 256 byte, token regex 4 KiB, 1.000 fonti,
256 MiB letti e 1.000 righe materializzate. Superare un limite produce errore
prima dell'esecuzione o della successiva unità bounded.

Il motore regex deve garantire tempo lineare per il sottoinsieme accettato oppure
eseguire con deadline, cancellation e budget di passi. Backreference, lookbehind
illimitati e costrutti non dimostrati sicuri sono rifiutati. Ogni ricerca rispetta
budget GS-RUN per tempo, memoria, risultati e I/O; risultati parziali sono marcati
e non riusati come completi.

## API comune

GlifiKit espone operazioni asincrone concettualmente equivalenti a:

```swift
parse(text, grammarVersion) -> QueryAST | QueryDiagnostics
validate(ast, capabilitySnapshot) -> ValidatedQuery
execute(validatedQuery, scope, budget) -> AsyncSequence<SearchBatch>
explain(matchID) -> MatchExplanation
```

Il comando `glifi query <progetto.glifi> (--text <query> | --ast <query.json>)`
accetta due ingressi esclusivi e produce righe tabulate oppure un envelope JSON v1.
`--ast` legge al massimo 64 KiB da un file regolare, senza seguire il collegamento
simbolico del componente finale e senza attendere un writer su FIFO. Il Core
applica i budget di nodi e profondità durante la decodifica e valida schema,
versioni, campi, operatori e regex prima della scansione delle fonti. La radice ha
profondità zero; ogni arco verso un nodo figlio incrementa la profondità di uno.
Gli spazi e l'ordine delle chiavi del JSON d'ingresso non partecipano al digest,
calcolato dalla ricodifica canonica dell'albero validato.

`GlifiStudioProjectSession.query(canonicalAST:)` riceve `Data`, senza esporre tipi
Core. L'esecuzione è condivisa con `query(_:)`: stesso digest, ordine, KWIC e
troncatura, senza modifica della generazione. JSON malformato o struttura non
decodificabile producono `query.invalid-ast`; schema/versioni incompatibili
`query.incompatible-ast`. Le failure di budget mantengono i codici esistenti;
I/O e file non regolari producono `query.ast-unreadable` e
`query.ast-not-regular-file`. Le diagnostiche AST non includono contenuto, path o
dettagli del decoder e non inventano span del testo della query.

Verifiche e limiti dell'incremento sono in [GS-VER-143](../evidenze/GS-VER-143-ingresso-queryast.md).
Progress strutturato, CSV e streaming restano superficie target non ancora
esposta. GUI e CLI non possono aggiungere semantiche private al motore.

## Conformità

- test di precedenza, escaping, Unicode, tipi e diagnostica con span esatti;
- round-trip AST canonico e identità stabile tra GUI, CLI e API;
- property/fuzz test del parser senza crash o crescita non limitata;
- test metamorfici per parentesi, commutatività applicabile e normalizzazione;
- benchmark di query avverse e cancellazione entro il budget approvato.
