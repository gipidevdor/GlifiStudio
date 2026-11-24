<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — QueryAST da file nel percorso headless

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-012 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-06 |
| Approvazione | Sviluppo autonomo richiesto dall'iniziatore; attuazione del contratto GS-QRY-001 esistente |
| Riferimenti | RF-080; RQ-042; RQ-044; RQ-046; GS-QRY-001; GS-API-001; ADR-0002; ADR-0016 |

## 1. outcome e confini

Consentire `glifi query <progetto> --ast <file.json>` in alternativa esclusiva a
`--text`, senza introdurre un formato: l'ingresso è il QueryAST v1 già canonico.
Core, Kit e CLI eseguono lo stesso albero e restituiscono digest, ordine e KWIC
identici. Nessuna nuova UI, dipendenza, rete o modifica al package persistente.

## 2. Contratto e failure semantics

- GlifiKit riceve `Data` e non espone tipi Core. Il motore conserva un unico
  percorso di esecuzione per gli ingressi testuale e AST.
- File regolare, non symlink, aperto senza bloccare su FIFO; lettura limitata a
  64 KiB più un byte sentinella. Dimensione verificata sul descrittore aperto.
- Decodifica tipizzata bounded: profondità e nodi controllati durante la
  costruzione ricorsiva; schema, grammatica e semantica validati prima del digest
  e prima di leggere le fonti. Flag regex sconosciuti rifiutati, non ignorati.
- JSON malformato → `query.invalid-ast`; versioni incompatibili →
  `query.incompatible-ast`; budget → failure `insufficientResources` esistente;
  file non regolare → `query.ast-not-regular-file`; I/O → `query.ast-unreadable`.
- La diagnostica non include contenuto, percorsi o dettagli del decoder.

## Accettazione e verifica

Test Core sui limiti esatti e oltre soglia, albero profondo, schema e flag;
test Kit di parità e lifecycle; smoke CLI con stesso risultato testuale/AST,
argomenti esclusivi, JSON ostile, symlink, directory, FIFO, file troppo grande
e canary di privacy. `make quality-static`, formattazione e `make verify`;
build e test nativi sul runner Xcode 27. Evidenza GS-VER-143, matrice CMP-081,
contratti e CHANGELOG nello stesso incremento.

## tracciabilità e stato

**Ready**: requisiti RF-080, RQ-042, RQ-044 e RQ-046, contratti GS-QRY-001 e
GS-API-001, ADR-0002/ADR-0016, verifiche TV-053/TV-060, matrice CMP-081 ed evidenza
GS-VER-143. Nessuna nuova decisione architetturale o deroga ai gate esistenti.

## Rischio e recupero

L'ingresso AST amplia la superficie di input non fidato, non le capacità del
motore. Limiti prima dell'I/O delle fonti, controlli negativi e percorso comune
mitigano il rischio. Rollback mediante revert; nessuna migrazione necessaria.
