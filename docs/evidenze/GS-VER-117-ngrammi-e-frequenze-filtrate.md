<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-117 — N-grammi di caratteri e frequenze filtrate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-117 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task Q4 e Q5 di GS-DOR-003 |

## Ambito

Completa RF-019 e RF-020 con le definizioni normative aggiunte a GS-MET-001-04 (versione 1.2.0,
§ Frequenze filtrate e n-grammi):

- unità `Form-v1`, `WordNGram-v1` (`n` in 1…5), `CharNGram-graphemes-v1` e
  `CharNGram-graphemes-padded-v1` (`n` in 1…10, extended grapheme cluster dentro la forma,
  marcatori di confine `_` alla Cavnar e Trenkle);
- filtri `TermFilter-v1` dichiarati nella richiesta e nel descrittore: stopword esplicite
  normalizzate come i token, lunghezza minima, conteggio e document frequency minimi, proporzione
  massima di documenti; nessuna lista di stopword implicita;
- `stopword-policy.exclude-containing-v1`: un n-gramma di parole con una stopword è escluso,
  senza rimuovere la stopword prima del conteggio, così da non creare adiacenze inesistenti;
- frequenze relative sul denominatore prima dei filtri, esclusioni per filtro attribuite al primo
  filtro che esclude, troncatura dichiarata;
- Artifact `corpus-ngram-frequencies-v1`, `analyzeNGramFrequencies` in GlifiKit e `glifi ngrams`.

## Procedura e risultato

1. `ngramCountsMatchR`: trigrammi di caratteri con marcatori (denominatore 44, conteggi, document
   frequency e frequenze relative di `_ca`, `cas`, `asa`, `sa_`, `_è_`) e bigrammi di parole
   coincidono con `Tests/Oracles/R/ngrams.R`; nessun n-gramma di caratteri attraversa il confine
   fra forme;
2. `ngramFiltersMatchR`: stopword `{la, è}` escludono 7 dei 9 bigrammi distinti senza creare il
   bigramma `casa casa`; il denominatore resta 10; filtri su lunghezza, conteggio e proporzione di
   documenti escludono 3, 2 e 2 forme come in R; troncatura dichiarata; filtri, dimensioni e
   soglie non valide rifiutati con codici tipizzati;
3. `ngramFrequenciesArePersistedFromText`: dal testo importato, con maiuscole e punteggiatura, gli
   stessi valori; riuso per get-or-store; varianti con e senza marcatori sono nodi distinti;
4. contract test CLI in `verify.sh` per `glifi ngrams` con stopword in maiuscolo normalizzata.

## Limiti

Il profilo corpus 0.1 conserva i propri n-grammi di parole senza filtri; le frequenze filtrate sono
un nodo separato che non ne cambia l'identità.

## Esito

**Superato localmente: RF-019 e RF-020 sono completi per le definizioni di GS-MET-001-04.**
