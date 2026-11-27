<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Catalogo da tastiera e stato accessibile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-336 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di perfezionare UX e UI |
| Riferimenti | GS-UI-001; GS-APL-003; GS-STD-001-15; GS-STD-001-29 |

## Comportamento e confini

Invio nel campo di ricerca del catalogo apre una destinazione soltanto quando
esiste un unico risultato complessivo tra strumenti e metodi visibili. Con
risultati ambigui la persona sceglie un elemento esplicito; nessuna famiglia ha
precedenza nascosta. La ricerca non modifica corpus, parametri o risultati
finché non viene scelta una destinazione.

Il riepilogo localizzato rende percepibili il numero di risultati e il
comportamento di Invio. I controlli restano SwiftUI nativi, con testo semantico,
nomi localizzati e ordine coerente anche con layout da destra a sinistra. Non
si introducono controlli disegnati, colori rigidi o nuove gerarchie scientifiche.

Nella barra di stato, nome e valore rimangono distinguibili: sovrascrivere il
nome accessibile non deve eliminare lo stato del motore o il valore di un
argomento diagnostico. Una nuova failure produce un annuncio localizzato di
sistema, senza spostare il focus, leggere payload diagnostici o annunciare ogni
aggiornamento di progresso. La ricreazione della vista non riannuncia lo stato
iniziale.

## Verifica e integrazione

| Voce | Contratto |
| --- | --- |
| outcome e confini | Invio apre una sola destinazione complessiva; nome e valore di stato restano accessibili; nuovi errori annunciati senza spostare il focus |
| failure semantics | Ambiguità o zero risultati non modificano la destinazione; l'annuncio non include contenuto diagnostico né certifica un recupero |
| tracciabilità | CMP-336 e GS-VER-336 distinguono regressioni native, revisione AX e audit interattivi |

**Ready** per le correzioni di presentazione e semantica applicativa.

Regressioni sullo stesso resolver usato dalla UI coprono zero, uno e più
risultati di entrambe le famiglie e il caso concreto PageRank. Una prova RED deve
mostrare la precedenza errata corrente. Servono test nativi, localizzazione,
build macOS e `make verify`; l'ispezione interattiva resta distinta dai test
del resolver e non attesta un audit VoiceOver completo.

Nessuna API di prodotto, formato, migrazione o dipendenza nuova. Rollback
tramite revert, senza modifica dei dati persistenti.
