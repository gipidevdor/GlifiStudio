<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-138 — Corpus gold italiano su prosa reale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-138 |
| Tipo | Evidenza di verifica linguistica |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | ADR-0030 accettato dall'iniziatore, fonte autorizzata esplicitamente |

## Ambito

Sostituisce il gold sintetico di quattro casi con prosa italiana reale, come deciso in ADR-0030.

- **Fonte**: Carlo Collodi (1826-1890), «Le avventure di Pinocchio», capitolo 1, trascrizione di
  it.wikisource.org recuperata il 2026-09-20 con autorizzazione esplicita. L'autore è morto nel
  1890, quindi l'opera è in pubblico dominio senza ambiguità. `Scripts/build-italian-gold.py`
  documenta la derivazione dalla pagina wiki alla fixture, marcatura compresa.
- **Contenuto**: 15 paragrafi narrativi, 434 token lessicali, 19 frasi. Contiene apostrofi
  tipografici ed elisioni (`C’era`, `d’inverno`, `mastr’Antonio`, `l’ascia`, `un’occhiata`,
  `tutt’e`, `po’`), clitici (`servirmene`, `levargli`, `sbatacchiarlo`, `grattandosi`), ellissi
  (`O dunque?...`) e forme ottocentesche (`perchè`, `cogli`, `colla`).
- **Annotazione indipendente**: prodotta da una seconda implementazione del contratto
  `it-token-v1` scritta in Python a partire dalla specifica, non dal codice Swift. È la condizione
  perché l'oracolo non sia una copia dell'implementazione che deve verificare.

## Procedura e risultato

1. Annotazione indipendente e tokenizzatore del prodotto confrontati su tutti i 15 casi:
   **accordo completo** su 434 token lessicali, sulle 8 elisioni con le loro componenti e sulle 19
   frasi. Nessuna divergenza da dirimere: `adjudications.json` resta vuoto, pronto a registrare le
   decisioni quando ce ne saranno.
2. L'unica differenza sistematica riguarda la punteggiatura, che il prodotto emette come token di
   classe `punctuation` mentre l'annotazione la tratta come gap: non è una divergenza ma la
   distinzione prevista da GS-LNG-001, quindi la misura confronta le forme lessicali, come fa il
   conteggio del profilo di corpus.
3. Linee di base registrate per entrambi i corpora, legate al digest: il test verifica sia
   `it-gold-v0` (13 token lessicali, casi limite sintetici) sia `it-gold-v1` (434 token, prosa
   reale);
4. `check-fixtures.py` valida manifest, provenienza, licenza, split disgiunti, intervalli UTF-8 e
   coerenza delle linee di base; `make verify` completo verde.

## Limiti

**L'accordo pieno non dimostra che entrambe le implementazioni siano corrette**: dimostra che due
letture indipendenti dello stesso contratto coincidono su questo testo. Un errore presente nella
specifica si ritroverebbe in entrambe.

Il corpus è un capitolo di un solo autore ottocentesco: non copre registri contemporanei, cifre,
date, valute, URL, email, hashtag né testo misto, che restano nelle fixture sintetiche. Le righe
di dialogo aperte da lineetta sono escluse perché il contratto non specifica dove finisca una
frase dentro un turno di dialogo: è una lacuna della specifica da colmare, non una scelta di
comodo. Nessuna annotazione di lemma, POS o NER. Nessuna soglia assoluta di accettazione: resta
in G4.

## Esito

**Superato localmente: la tokenizzazione italiana è ora misurata su prosa reale contro
un'annotazione indipendente, con linea di base che blocca le regressioni.**
