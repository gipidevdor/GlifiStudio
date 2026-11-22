<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-120 — Fuzz deterministico di importer TXT/Markdown e query

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-120 |
| Tipo | Evidenza di sicurezza e robustezza |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task S2 di GS-DOR-004 |

## Ambito

Fuzz deterministico, eseguito a ogni `make verify`, delle superfici che elaborano input non fidato
(GS-SEC-001 THR-001 e THR-009, RQ-044):

- **TXT**: 2.000 input da frammenti di byte che mescolano testo italiano, combinanti, emoji,
  controlli, NUL, CR/LF, BOM UTF-8 e UTF-16, sequenze UTF-8 troncate, surrogati e code point oltre
  U+10FFFF (seed `0x5EED0001`);
- **Markdown**: 2.000 documenti da frammenti di heading, enfasi, fence, blockquote profondi, liste,
  link, immagini, HTML, commenti, entità valide e invalide, escape, tabelle e annidamenti di 64
  delimitatori (seed `0x5EED0002`);
- **query `glifi-query-v1`**: 3.000 query, il 70 % generate dalla grammatica con annidamento
  limitato e regex annidate `(a+)+b`, il 30 % da frammenti malformati; valutazione su un testo che
  esercita il backtracking (seed `0x5EED0003`).

## Invarianti verificati

1. ogni input produce un risultato oppure una `GlifiFailure` tipizzata, mai un altro errore o un
   crash;
2. se accettato: SpanMap totale e contigua sull'output, intervalli sorgente dentro i byte
   originali, e per ogni segmento `exact` byte estratti identici ai byte sorgente mappati;
3. token ordinati, non sovrapposti, dentro il testo e risolvibili;
4. determinismo: la stessa importazione o lo stesso parsing danno lo stesso valore;
5. corrispondenze della query dentro il testo e tempo totale delle 3.000 query sotto 60 s;
6. il generatore esercita davvero entrambi gli esiti (soglie minime di input accettati).

## Difetto trovato e corretto

Il fuzz TXT ha trovato un input con due BOM UTF-8 consecutivi: l'importer rimuoveva il primo, poi
`String(data:encoding:)` di Foundation scartava in silenzio anche il secondo U+FEFF, che è
contenuto. Il testo risultava vuoto mentre la SpanMap dichiarava tre byte di output. L'importer e
l'estrattore Markdown usano ora la decodifica stretta `String(validating:as:)`, che rifiuta
l'UTF-8 invalido senza alterare i caratteri validi. Il test di regressione
`secondByteOrderMarkIsPreservedAsContent` copre TXT e Markdown.

## Limiti

È fuzz generativo a seed fisso, non guidato da copertura (libFuzzer non è disponibile per Swift
Testing nel gate). PDF e OCR restano fuori baseline (THR-002). Package ed export sono coperti dai
test avversari esistenti, non da questo fuzz.

## Esito

**Superato localmente: gli importer TXT/Markdown e il linguaggio di query resistono al fuzz
deterministico; un difetto di perdita di contenuto è stato corretto.**
