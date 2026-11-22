<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-233 — Barriera di reset dei laboratori macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-233 |
| Tipo | Evidenza di verifica del lifecycle applicativo macOS |
| Versione | 1.2.0 |
| Stato | Preparata; esecuzioni da acquisire |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | GS-DOR-233; GS-DOR-223; ADR-0035; RQ-011/013/047/058/060/063 |

## Perimetro

La proprietà da verificare è il mancato ripopolamento di un modello resettato
quando una precedente operazione termina. Sono interessati il laboratorio
avanzato per la nuova correzione; valutazione linguistica/temporale e corpus
sono regressioni dei guard lifecycleID/lifecycleNonce già arrivati dal lavoro
223, preservati senza attribuzione a questo lotto. Il controllo è una
generazione privata del modello, indipendente dalla cancellazione del Task.

La revisione del codice individua il confine async da presidiare; non costituisce
ancora una riproduzione RED. L'ownership Home attuale attende lo stato occupato
prima di cambiare documento: non si attribuisce il difetto a un percorso GUI
osservato. La correzione non annulla Artifact Core già validamente committati.

## Prove richieste

Fixture numeriche reali e Task.immediate sul Main Actor devono forzare reset
dopo l'avvio inline e il primo hop concurrent, prima della pubblicazione, senza
Task.cancel, hook produttivi, sleep o yield arbitrari. Si confrontano output,
righe, filtri e pagina dopo il completamento tardivo; si asseriscono la failure
operation.cancelled/cancelled/newRequest/unchanged e il retry. Gli esiti RED,
GREEN e gli hash dei sorgenti devono essere registrati separatamente, senza
inferire l'esito dalla sola presenza dei test. La strategia della Ready 1.1
sostituisce l'ipotesi di seam della prima revisione, prima dell'implementazione.
La Ready 1.2 restringe il producer ad Advanced: si attende un RED per quel
percorso e tre GREEN preesistenti per gli altri; sono esiti da acquisire, non
test già eseguiti. Nessun guard del lavoro 223 viene rimosso per ottenere RED.

Il gate e il packaging macOS sul contenuto finale identificato restano da
acquisire. Le evidenze 223, 230–232 e 270 mantengono i propri perimetri; nessuna
prova storica viene estesa automaticamente al nuovo incremento. CMP-233 parte
specified, senza promozione di CMP-223, G4/G5 o dei metodi scientifici.

## Limiti

Soltanto test automatici macOS. Nessuna attestazione della GUI reale,
VoiceOver, Voice Control, iPadOS, energia, CI remota o rollback di persistenza.
Il contenuto preesistente e i contributi concorrenti restano preservati.
