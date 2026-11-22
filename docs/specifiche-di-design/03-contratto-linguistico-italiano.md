<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Contratto linguistico italiano

| Campo | Valore |
| --- | --- |
| Identificatore | GS-LNG-001 |
| Tipo | Specifica di design linguistico |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline proposta; corpus gold e soglie da approvare |
| Riferimenti | ADR-0004; GS-I18N-001; GS-DAT-001; GS-MET-001-18; GS-VAL-001 |

## Scopo

Questo contratto stabilisce quando due esecuzioni possono dichiarare la stessa
analisi linguistica italiana. Governa rappresentazione, segmentazione, token,
normalizzazione e annotazioni; non seleziona un fornitore né confonde lingua del
corpus e lingua dell'interfaccia.

Ogni pipeline registra `languageTag`, `locale`, ID e versione delle regole,
backend, versione del modello, risorse e soglie. Un cambio che può alterare token,
offset o annotazioni crea una nuova versione semantica.

## Rappresentazioni

1. I byte importati e il testo estratto restano immutabili.
2. La rappresentazione analitica italiana usa Unicode NFC e newline LF, con
   SpanMap GS-DAT per ogni trasformazione.
3. Case folding, rimozione diacritici, stemming e stopword non modificano la
   rappresentazione canonica: sono viste o filtri versionati.
4. La UI mostra per default la forma di superficie della fonte. Una forma
   normalizzata o un lemma è etichettato come tale.
5. Caratteri malformati in UTF-8 causano errore localizzato; non sono sostituiti
   silenziosamente da U+FFFD nel percorso MVP.

## Unità linguistiche

| Unità | Contratto |
| --- | --- |
| `TextSegment` | Blocco strutturale proveniente dal document model |
| `Sentence` | Intervallo contiguo nella rappresentazione analitica, con regola di boundary versionata |
| `SurfaceToken` | Intervallo contiguo non vuoto; preserva ortografia e punteggiatura associabile |
| `TokenComponent` | Sottointervallo o contributo esplicito per elisioni, clitici o composti |
| `LexicalForm` | Vista normalizzata, non nuova posizione |
| `LemmaAnnotation` | Candidato con lemma, POS, feature, confidenza e backend |
| `EntityAnnotation` | Tipo, intervallo, confidenza, modello e policy di sovrapposizione |

Un `SurfaceToken` è l'unità primaria di conteggio. I componenti non incrementano
automaticamente il conteggio: il metodo dichiara se usa superficie, componenti o
annotazioni. Nessun token ricostruisce offset tramite ricerca della stringa.

## Regole italiane baseline `it-token-v1`

### Apostrofi ed elisioni

U+0027 APOSTROPHE e U+2019 RIGHT SINGLE QUOTATION MARK sono equivalenti soltanto
per il riconoscimento della regola, non nei byte o nella forma visualizzata.
Sequenze come `l'acqua`, `un'amica`, `quest'anno`, `po'` e `dell’arte` restano un
SurfaceToken e possono esporre componenti (`l'` + `acqua`) con span esatti.
Apostrofi iniziali/finali non riconosciuti e virgolette sono punteggiatura separata.

### Clitici

Forme unite come `dimmelo`, `portarglielo` e `andarsene` restano SurfaceToken. La
scomposizione morfologica è un'annotazione del backend con componenti e confidenza,
mai una riscrittura irreversibile. La ricerca per lemma può espandere i componenti
solo quando il profilo linguistico lo autorizza e lo mostra nel piano.

### Trattini

Il trattino interno tra lettere o cifre (`italo-francese`, `COVID-19`) conserva un
SurfaceToken e componenti interrogabili. Line break hyphenation proveniente da PDF
è una trasformazione documentale distinta. Dash tipografici separano token, salvo
regola lessicale versionata.

### Abbreviazioni e sentence boundary

Un inventario versionato distingue abbreviazioni (`dott.`, `prof.`, `ecc.`), sigle,
iniziali e ordinali. Il punto non chiude una frase se una regola più specifica
riconosce l'abbreviazione nel contesto. Ellissi, virgolette di chiusura, elenchi e
titoli hanno fixture dedicate. Le euristiche non dichiarano certezza assoluta.

### Classi speciali

- URL ed email validati sono singoli token speciali, senza case folding del path o
  della local part.
- Interi, decimali, percentuali, valute e date conservano superficie; una
  interpretazione numerica/temporale è un'annotazione tipizzata con locale.
- Emoji seguono extended grapheme cluster per presentazione, ma gli offset
  persistiti restano UTF-8 GS-DAT.
- Hashtag, mention, identificatori, parole con accento, maiuscole miste e lettere
  non italiane restano recuperabili senza perdita.
- Spazi e punteggiatura sono gap indirizzabili, non token lessicali di default.

## Lemma, POS, NER e ambiguità

Le annotazioni probabilistiche conservano tutti i candidati necessari alla policy,
confidenza non calibrata come tale, tagset, mapping al tagset comune e stato
`resolved`, `ambiguous`, `unknown` o `notApplicable`. Un lemma `unknown` non viene
sostituito automaticamente dalla forma come se fosse una predizione riuscita.

Il tagset comune deve essere versionato; conversioni lossless e lossy sono
distinte. NER consente intervalli annidati solo se lo schema lo dichiara e proibisce
overlap incoerenti. Correzioni manuali sono nuove Annotation con autore e priorità,
non mutazioni del risultato automatico.

## Stopword e normalizzazione di ricerca

Una stoplist è un artefatto versionato con lingua, provenienza, licenza e digest.
Il filtro non cancella token né posizioni. Il default MVP non rimuove stopword in
importazione; ogni analisi risolve esplicitamente la lista applicata.

Ricerca sensibile a case e diacritici è sempre disponibile. Modalità insensibili
sono operatori dichiarati e non alterano il corpus. La normalizzazione della query
usa la stessa versione della vista interrogata.

## Corpus gold italiano

`Fixtures/Linguistics/it-v1` contiene un primo seed BSD-3-Clause di otto casi con
offset UTF-8 verificati automaticamente. È un avvio V1, non un corpus gold
approvato: lemma/POS/NER, soglie assolute e deriva restano da acquisire.

`Fixtures/Linguistics/it-gold-v1` è il corpus gold dei confini di token e di frase su **prosa
italiana reale** di pubblico dominio (ADR-0030), con split di validazione e test dichiarati.
L'annotazione nasce da un'implementazione del contratto indipendente dal tokenizzatore del
prodotto e le divergenze sono decise in `adjudications.json`, così l'oracolo non è una copia
dell'implementazione che deve verificare. `Fixtures/Linguistics/it-gold-v0` resta come regressione
sui casi limite sintetici. Le righe di dialogo aperte da lineetta sono fuori dalla v1: il
contratto non specifica ancora dove finisca una frase dentro un turno di dialogo. La collezione completa deve contenere esclusivamente testo sintetico,
pubblico dominio o redistribuibile, con manifest di licenza, e coprire almeno:

- apostrofi ASCII/tipografici, elisioni e citazioni;
- clitici semplici/composti e forme ambigue;
- trattini, dash, dehyphenation e a capo;
- abbreviazioni, iniziali, decimali e sentence boundary;
- accenti, combinazioni NFC/NFD, emoji e script misti;
- URL, email, date, valuta, percentuali, hashtag e rumore;
- titoli, elenchi, Markdown e frammenti documentali.

Per token e frasi l'oracolo specifica intervalli UTF-8 esatti, classe e componenti.
Lemma/POS/NER usano split bloccati, agreement annotatori e soglie per backend; una
media globale non può nascondere regressioni su classi critiche.

## Conformità

- golden test esatti per token, sentence e SpanMap;
- property test di copertura ordinata e assenza di overlap illegali;
- metamorphic test NFC/NFD, newline e apostrofo senza perdita di lineage;
- valutazione lemma/POS/NER con precision, recall, F1, accuracy e bootstrap CI;
- confronto delle versioni con rapporto di deriva prima della promozione.

`make check-fixtures` verifica integrità interna del seed e non sostituisce la
valutazione del backend o l'approvazione di DA-008.

## Stato implementativo iniziale

`GlifiItalianTokenizer` realizza il percorso bounded di `it-token-v1` con token
posizionali privi di copie permanenti della surface, componenti di elisione,
abbreviazioni iniziali, numeri italiani, URL, email, emoji, hashtag e mention. I
test prodotto leggono la fixture canonica e verificano gli otto casi seed byte per
byte. Il backend è sostituibile tramite `GlifiTokenizing`.

Questa implementazione non è ancora promossa a backend linguistico completo:
normalizzazione con SpanMap, corpus gold, sentence boundary estesi, lemma, POS, NER,
soglie e drift report restano obbligatori prima del supporto 0.1.

## Riferimenti tecnici

- [Unicode Normalization Forms, UAX #15](https://www.unicode.org/reports/tr15/)
- [Unicode Text Segmentation, UAX #29](https://www.unicode.org/reports/tr29/)
