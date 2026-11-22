<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0042 — Invarianti degli intervalli UTF-8 decodificati

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0042 |
| Tipo | Decisione di correttezza del confine di decodifica |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di riverifica estrema; correzione fail-closed nel perimetro autorizzato |
| Riferimenti | RQ-025; RQ-058; RQ-060; GS-STD-001-18; GS-DOR-234; GS-VER-234; GS-VER-202 |

## Contesto

GlifiUTF8Range dichiara un intervallo non vuoto con start non negativo e end
strettamente maggiore di start. Il costruttore applica queste condizioni, il
precedente decoder sintetizzato le aggirava. count e text(in:) potevano quindi
eseguire aritmetica o indicizzazione su uno stato impossibile. Il raffinamento
storico GS-VER-202 conservava intenzionalmente anche range invalidi decodificati
nel suo test di compatibilità del percorso lineare. La riverifica richiede di
risolvere questa divergenza, non di eliminare una regressione perché è rossa.

## Decisione

Il decoder usa lo stesso costruttore validante. Intervalli negativi, vuoti o
invertiti sono rifiutati con text.invalid-range prima del consumo; non si
correggono, non si troncano e non si reinterpretano automaticamente i dati.
Il comportamento di compatibilità per mappe disordinate, sovrapposte o con gap
resta verificato quando tutti gli intervalli sono validi. Le annotazioni esterne
possono essere respinte già durante la decodifica, prima della conversione.

Il decoder della span map richiede identificatore di contratto non vuoto e
lunghezze input/output non negative; verifica inoltre i vincoli locali di ciascun
segmento: limiti delle coordinate, cardinalità delle origini per kind e lunghezza coerente
per exact. Una mappa decodificata non può quindi indicizzare un’origine assente
o effettuare traslazioni oltre un range coerente. La validazione locale non
impone ordinamento globale, copertura contigua o un numero di segmenti derivato
dalla lunghezza: geometrie legacy sovrapposte/disordinate/con gap restano valide
quando ogni segmento è internamente coerente.

La rappresentazione JSON, i sette campi della span map e i valori degli input
validi restano invariati. È una restrizione intenzionale degli input malformati,
non un nuovo formato persistente o una migrazione. Dati preesistenti con range
non conformi richiedono correzione/reimportazione esplicita; l’originale resta
intatto e non viene inventata una riparazione automatica.

## Verifica e conseguenze

I test mantengono confronto con il percorso lineare e composizione per geometrie
legacy valide. Le fixture con range vuoti/invertiti diventano test di rifiuto
esplicito, inclusi i range annidati. NFC/NFD, limiti Int, round-trip valido e
assenza di risultati parziali restano verificati in GS-VER-234. I risultati storici
GS-VER-202 sono conservati con un rimando alla nuova decisione.

Il controllo a ogni singolo chiamante è respinto: lascerebbe ancora accessibile
un valore pubblico il cui count può andare in overflow. Conservare il decoder
permissivo sarebbe incompatibile con l’invariante del tipo e con il fail-closed.
