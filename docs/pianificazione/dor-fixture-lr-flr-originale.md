<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Fixture originale per LR e FLR

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-323 |
| Tipo | Sostituzione delimitata dei dati di verifica |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di controllo delle fonti algoritmiche |
| Riferimenti | GS-LIC-002; GS-STD-001-13; GS-MET-001-23; GS-VER-323 |

## Definition of Ready

L'oracolo Python dichiara una fixture adattata dall'esempio sui trigrammi del
paper LR/FLR; il test Swift ripete quei candidati e frequenze. La citazione
scientifica resta valida per le formule, ma la verifica deve usare dati
originali del progetto, senza dipendere dal riuso dell'esempio editoriale.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Sostituire candidati, grafo delle adiacenze, frequenze e attese dell'esempio con una fixture sintetica originale; soli test Swift, oracolo Python e tre righe attese correlate |
| struttura | Nove candidati su cinque simboli artificiali; lunghezze da uno a quattro, ciclo, auto-adiacenza, componente ripetuto, componente isolato e frequenze indipendenti non uniformi |
| formule e discriminanti | Conservare LR/FLR token/type, smoothing +1, esponente 1/(2L), F indipendente, statistiche delle adiacenze, classifica e determinismo all'inversione degli input |
| failure semantics | Nessuna modifica runtime, alle failure o ai risultati utente; controlli di limiti e cancellazione preesistenti conservati |
| verifica | Calcolo scalare indipendente Python Decimal a 80 cifre con prodotti interi esatti; confronto con le nuove attese Swift, test mirati e check-oracles; il coordinatore esegue il gate integrato macOS |
| compatibilità | API, identificatori dei metodi pubblici, DTO, descriptor e parità Kit/CLI invariati; cambiano soltanto i dati di sviluppo e il relativo identificatore di preprocessing sintetico |
| provenienza | Simboli, struttura e frequenze creati per questo lotto; nessun testo, esempio numerico, codice o tabella del paper incorporati nella nuova fixture |
| tracciabilità | GS-VER-323 e registri di provenienza nello stesso lotto; aggiornamento limitato alle righe term LR/FLR di kh_lexical_profiles in expected.txt |

**Ready** prima di modificare fixture e attese. Gli altri esempi numerici del
medesimo oracolo e le nuove righe statistiche del lotto 319 restano distinti.
