<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Codifica qualitativa

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-16 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-20 |
| Approvazione | ADR-0029; validazione con utenti non ancora eseguita |
| Documento padre | [GS-UX-001](README.md) |

## Scopo

La codifica permette a una o più persone di assegnare categorie di un codebook a passaggi delle
fonti, di motivare le scelte con memo e di misurare l'accordo fra codificatori. L'interfaccia
rende visibile ciò che il modello garantisce: nessuna codifica storica viene riscritta, ogni
cambiamento resta nella storia e l'accordo nasce dalle codifiche registrate (ADR-0027).

## Oggetti e vocabolario

| Oggetto | Nome nell'interfaccia | Regola |
| --- | --- | --- |
| Codebook | «Codebook» | Ha revisioni numerate; la revisione attiva è l'ultima |
| Categoria | «Categoria» | Etichetta, definizione, istruzioni; identità stabile mostrata nel dettaglio |
| Codifica | «Codifica» | Passaggio, categoria, codificatore, origine; mai modificata, solo ritirata |
| Ritiro | «Ritira» | Conserva la codifica nella storia con il motivo |
| Memo | «Nota» | Testo libero legato a una codifica, una categoria o una fonte |
| Codificatore | «Codificatore» | Etichetta pseudonima scelta dall'utente, non un'identità personale |
| Accordo | «Accordo fra codificatori» | Alfa di Krippendorff e, con due codificatori completi, kappa di Cohen |

Il termine «tag» non si usa: suggerisce etichette modificabili, mentre la codifica è un fatto
registrato.

## Flussi

1. **Preparare il codebook**: creare il codebook con almeno una categoria, oppure registrarne una
   nuova revisione completa. Le fusioni, divisioni e rinomine si dichiarano come mapping; le
   codifiche già registrate non cambiano.
2. **Codificare**: scegliere la fonte, selezionare il passaggio nel testo, scegliere la categoria
   e il codificatore corrente. Il passaggio si sceglie in due modi equivalenti e senza
   trascinamento: per frasi, indicando la prima e l'ultima frase di un intervallo consecutivo,
   oppure per caratteri, indicando il carattere iniziale e quello finale escluso. In entrambi i
   casi il passaggio risolto viene mostrato prima di essere registrato, si allinea ai confini di
   carattere e deve contenere almeno un carattere visibile; il passaggio codificato resta
   evidenziato.
3. **Rivedere**: l'elenco delle codifiche mostra passaggio, categoria, codificatore e stato
   (attiva o ritirata); il testo di ogni passaggio è risolto dagli intervalli registrati, anche
   quando non coincide con una frase. Ritirare chiede un motivo da un elenco chiuso.
4. **Annotare**: aggiungere una nota a una codifica.
5. **Misurare l'accordo**: scegliere revisione e codificatori; il risultato mostra le misure, il
   numero di unità e il numero di unità escluse perché ambigue, con la spiegazione dell'esclusione.

## Stati e errori

Un cambiamento rifiutato non modifica nulla e spiega la causa con la chiave localizzata della
failure (categoria assente, passaggio non valido, selezione che non individua un passaggio valido,
storia cambiata nel frattempo). In caso di storia cambiata l'interfaccia ricarica lo stato e invita
a ripetere. Una storia vuota mostra un invito a creare il codebook.

## Accessibilità

Ogni azione disponibile con il puntatore è disponibile da tastiera e da VoiceOver. La selezione
del passaggio non richiede mai il trascinamento: entrambe le modalità, per frasi e per intervallo
di caratteri, si governano con elenchi e campi numerici, e il testo risolto è leggibile prima
della registrazione. Le categorie non si distinguono solo per colore. Gli annunci confermano ogni
codifica registrata o rifiutata.

## Verifica

Test del modello di presentazione (flussi, errori, ricarica dopo storia cambiata), build macOS e
iPadOS, stringhe in italiano e inglese nel catalogo; audit VoiceOver, tastiera e Dynamic Type su
dispositivo nel gate G4 (GS-UX-001-15).
