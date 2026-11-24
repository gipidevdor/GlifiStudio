<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-109 — Benchmark di scala in release per SVD troncata, cammini pesati e Louvain

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-109 |
| Tipo | Evidenza prestazionale osservata |
| Versione | 1.0.0 |
| Stato | Osservato localmente; soglie non vincolanti |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Linea di base prestazionale da confermare in G4 (ADR-0024) |

## Ambito

Supera il limite di GS-VER-108 (nessun benchmark in release oltre il milione di celle) con
l'eseguibile `GlifiBenchmark`, conforme ai campi richiesti da `Benchmarks/README.md`.

## Osservazione

Mac16,3, macOS 27.0 (26A428), stato termico iniziale `nominal`, `swift run -c release`, un warm-up e
cinque campioni:

| Misura | Mediana | Min–max | Controllo |
| --- | --- | --- | --- |
| SVD troncata 2 000×2 500 (5 milioni di celle), rango 10 | 1,63 s | 1,57–1,72 s | residuo relativo `2,3·10⁻¹⁷` |
| Betweenness pesata, 2 000 nodi, 8 000 archi | 2,75 s | 2,44–2,93 s | somma 15 242 884 |
| Louvain, 20 000 nodi, 80 000 archi | 0,90 s | 0,87–0,94 s | modularità 0,871 (struttura generata ≈ 0,89) |

## Limiti

Una sola macchina e una sola sessione: le soglie restano da fissare su hardware di riferimento
(G4). Energia, memoria di picco e throughput di I/O non sono ancora misurati.

## Esito

**Osservato: le implementazioni scalabili di GS-VER-108 operano su milioni di celle e decine di
migliaia di nodi in tempi di secondi, con controlli di correttezza soddisfatti.**
