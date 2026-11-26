<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Distribuzioni statistiche e provenienza indipendente

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-319 |
| Tipo | Correzione numerica e provenienza implementativa |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di perfezionamento e controllo licenze |
| Riferimenti | RQ-008; RQ-027; RQ-062; RQ-063; GS-MET-001-21; GS-VER-319; CMP-319 |

## Problema e confini

Il quantile normale usa coefficienti attribuiti ad Acklam e una correzione che
può traboccare per probabilità positive subnormali. Il nucleo beta cita
`Numerical Recipes` senza evidenza di una licenza per quel codice. Anche il nucleo gamma cita `Numerical Recipes` e il logaritmo gamma incorpora
coefficienti Lanczos senza provenienza verificata. Le routine interessate
vengono sostituite con implementazioni originali delle identità matematiche,
confrontate con R come processo esterno: nessun codice R, Numerical Recipes,
Acklam o contenuto editoriale DLMF viene incorporato.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Inversione normale finita per ogni probabilità binary64 in (0,1), frazioni beta/gamma indipendenti, log-gamma nativo Apple e controllo di finitezza del quantile t; nessun nuovo metodo pubblico; rapporto t/F calcolato in logaritmi per preservare code piccole e statistiche vicine a zero |
| requisiti | RQ-008/027: risultati numerici e casi degeneri verificati; RQ-062/063: Ready, evidenza e tracciabilità |
| dominio/API | Firme pubbliche, identità delle varianti, DTO e parità Kit/CLI conservati; cambiano il calcolo interno e propagazione degli errori numerici già tipizzati |
| failure semantics | Probabilità e gradi di libertà non finiti rifiutati prima delle scorciatoie; frazione non valida fallisce chiusa senza risultato numerico inventato |
| esperienza prevista | Nessuna nuova GUI; i risultati esistenti guadagnano robustezza nelle code |
| verifica | RED/GREEN subnormali e df infinito, oracoli R esistenti più griglia t/F/chi-quadrato e qnorm, simmetria/monotonia; gate macOS a cura dell'integratore |
| dati e migrazione | Nessun formato persistente o migrazione; revisione algoritmo 2 per keyness e cinque famiglie derivate coinvolte, storici leggibili e altri nodi invariati; riferimenti precedenti conservati |
| sicurezza/privacy | Nessuna dipendenza o rete nel prodotto; sole fixture numeriche sintetiche |
| prestazioni/sistema | Calcolo bounded; misura isolata del kernel e dei consumatori pertinenti, senza promesse di accelerazione |
| tracciabilità | CMP-319, GS-VER-319, specifica GS-MET-001-21 e indici aggiornati nel lotto |
| decisioni e recupero | Nessuna architettura nuova; ripristino dei file del lotto senza alterare dati utente |

**Ready**. Le fonti sono riferimenti matematici, non licenze per copiare codice o
contenuti editoriali; le condizioni DLMF restano distinte dalla licenza BSD del
nuovo Swift originale.
