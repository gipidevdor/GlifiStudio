<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Campi CSV con CRLF

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-338 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Correzione della regressione osservata durante gli scenari completi richiesti |
| Riferimenti | GS-DOR-337; GS-LIC-003; GS-VIZ-001; RFC 4180 § 2.6 |

## Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Quotare ogni campo CSV che contiene virgola, virgolette, CR o LF, anche quando CRLF forma un unico Character Swift; intestazioni, identità e celle usano lo stesso serializzatore |
| difetto riprodotto | Lo scenario Cucumber originale con etichetta sponda+CRLF+chiara fallisce nel confronto esatto dei byte; la scansione per Character non riconosce CRLF come CR o LF singoli |
| failure semantics | I bundle con CSV non canonico restano rifiutati anche con dimensioni e digest aggiornati; nessun recupero silenzioso o alterazione dei valori |
| verifica | RED Cucumber già osservato; regressioni Kit per CRLF, CR, LF e testo ordinario, quindi stesso caso GREEN e gate macOS completo |
| API e dati | Nessun parametro, DTO, formato di progetto o algoritmo scientifico nuovo; il CSV corretto soddisfa il contratto già dichiarato. Un precedente export con CRLF non quotato è un documento malformato, non un formato storico da perpetuare |
| sicurezza e privacy | Fixture sintetiche originali, nessun corpus reale o dipendenza nuova; RFC consultato soltanto come riferimento normativo |
| tracciabilità | CMP-338 e GS-VER-338 distinguono difetto produttivo, riproduzione e verifica, separati dagli errori di authoring degli altri scenari |

**Ready** prima della correzione del serializzatore. Si rilevano i delimitatori
sui valori scalari Unicode, conservando invariati i byte del contenuto e il
raddoppio delle virgolette. Nessuna ottimizzazione viene rivendicata.
