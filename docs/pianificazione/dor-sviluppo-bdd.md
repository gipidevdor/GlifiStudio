<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Sviluppo guidato dai comportamenti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-334 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di usare Cucumber anche durante lo sviluppo |
| Riferimenti | GS-DEV-002; GS-BDD-001; ADR-0046; GS-STD-001-16 |

## Comportamento e confini

Il ciclo quotidiano parte da un comportamento osservabile in Gherkin italiano,
con attese indipendenti e failure definite. Il comando mirato deve elencare le
feature e gli esempi espansi e consentire di eseguire una feature o una riga
senza ridurre il gate completo. Un report parziale è accettabile soltanto se
corrisponde esattamente alla selezione esplicita; selezioni vuote, scenari
omessi o aggiunti e passaggi non superati sono errori.

La selezione usa l'inventario generato dal parser upstream già bloccato. Non
introduce un parser Gherkin, nuove dipendenze o codice nei prodotti. Argomenti
non validi falliscono prima di allocare cache. Il comando di elenco non richiede
build. Filtri ambientali incompatibili non possono creare falsi verdi.

## Verifica e integrazione

| Voce | Contratto |
| --- | --- |
| outcome e confini | Esempi osservabili prima del coding e selezione esplicita esatta durante l'iterazione; suite completa prima della consegna |
| failure semantics | Argomenti e selezioni non validi falliscono prima della cache; report vuoti, incompleti, inattesi o non superati sono respinti |
| tracciabilità | CMP-334, GS-BDD-001 e GS-VER-334 collegano comandi, regressioni e run reali |

**Ready** per il loop Cucumber di sviluppo; nessun ampliamento del prodotto.

Prima della consegna servono regressioni del verificatore e degli ingressi
shell, un'esecuzione reale mirata con conteggi esatti, una prova RED/GREEN e
`make verify` macOS con tutti gli scenari. Documentazione, istruzioni agenti e
loop Makefile devono descrivere lo stesso contratto. I test UI e gli oracoli
scientifici rimangono verifiche dedicate: una feature headless non dimostra
interazione visuale o accessibilità assistiva.

Nessuna migrazione, entitlement, rete di prodotto o nuova API pubblica.
Rollback tramite revert del cambiamento; nessun effetto sui progetti salvati.
