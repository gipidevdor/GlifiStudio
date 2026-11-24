<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Oracoli per valori molto piccoli

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-316 |
| Tipo | Correzione della verifica numerica |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di iterazione |
| Riferimenti | RQ-008; RQ-027; RQ-062; RQ-063; GS-STD-001-16; GS-VER-316; CMP-316 |

## Problema e confini

Il floor assoluto generale 1e-15 del verificatore accetta sette sostituzioni
con zero nei riferimenti NB/SOM/JS e corruzioni relative di 1e-7 in quattordici
valori piccoli. Il linkage esclude indistintamente le magnitudini sotto 1e-9.
Lo spike in memoria riproduce i difetti e conferma che la correzione proposta
passa tutte le 244 righe correnti senza cambiare riferimenti o codice numerico.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Confronto relativo finito senza floor generale e linkage dei valori piccoli significativi; soli checker e suite Python |
| requisiti | RQ-008/027: riferimenti scientifici non azzerabili dal controllo; RQ-062/063: tracciabilità e Ready prima del codice |
| dominio/API | Politica del verificatore, non della numerica di prodotto; Core/Kit/CLI, expected.txt, script R/Python e test scientifici Swift invariati |
| failure semantics | NaN/infinito rifiutati; zero e uguaglianza gestiti prima della divisione; minimi subnormali distinti da zero e fra loro; mismatch produce exit nonzero |
| esperienza prevista | Nessuna GUI nuova; diagnostica chiara per chiave; messaggio finale delimita il linkage lessicale senza presentarlo come prova dell'uso del valore in un assert |
| verifica | RED/GREEN per zero/corruzione relativa e literal mancanti; estremi finiti e subnormali; sei eccezioni esatte e soglia preservata; oracoli reali require, 244 righe e make verify macOS; GS-VER-316 |
| dati e migrazione | Nessun formato o dato persistente; nessuna riscrittura dei riferimenti per far passare il controllo |
| sicurezza/privacy | Nessuna dipendenza, rete, entitlement o diagnostica di contenuti; fixture numeriche sintetiche |
| prestazioni/sistema | Stessa complessità del confronto e ricerca letterali, con più valori realmente controllati; nessun vantaggio prestazionale dichiarato |
| tracciabilità | CMP-316 inizialmente specified; prove del 312 restano storiche; nuova evidenza e indici nel lotto |
| decisioni e recupero | Nessuna ADR nuova: si corregge un controllo; revert dei soli checker/test preservando la finitezza introdotta dal 312 |

## Eccezioni limitate

Il solo floor storico 1e-15 resta per `lexical_distributions:HEAPS`, posizioni
zero-based 3–7 (RMSE/residui del fit teoricamente esatto), e
`lexical_laws:LAWS_ZIPF_INFO_RESIDUAL_SUM`, posizione 0 (somma dei residui OLS
con intercetta). Nessuna tolleranza cresce: il residuo ZIPF attuale resta
distinto da zero. Il linkage esenta queste sole posizioni soltanto sotto
1e-9, mantenendo il vecchio controllo sopra soglia; gli altri tiny devono
possedere un letterale Swift relativamente corrispondente.

**Ready**. Le eccezioni non devono essere generalizzate per far passare un caso.
