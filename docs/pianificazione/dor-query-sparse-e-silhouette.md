<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Query sparse e qualità del clustering

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-172 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Iterazione esplicita successiva al commit e push |
| Riferimenti | GS-VER-171; GS-MET-001-07; GS-MET-001-14; GS-STD-001-17; RQ-008; RQ-009; RQ-063 |

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Ridurre lookup BM25 per query grandi e filtri ripetuti silhouette; preservare API e formati |
| requisiti | Somme ordinarie e risultati bitwise invariati; conteggi DF esatti; ordine colonne, righe, membri e cluster conservato |
| contratto di dominio/API | Nessuna nuova API pubblica, dipendenza o backend; metodi e Artifact esistenti invariati |
| failure semantics | Posting BM25 bounded con stima conservativa 32 MiB e fallback diretto al superamento, senza nuovi rifiuti; silhouette valida forma/finiti e applica budget standard celle/lavoro con calcolo overflow-safe; cancellazione propagata dal chiamante |
| esperienza prevista | Nessuna modifica UI; calcoli headless fuori dal Main Actor |
| verifica | Baseline Release archiviata prima delle modifiche ai kernel, generatori sintetici, cinque campioni dopo warm-up, confronti completi, riferimenti diretti e make verify |
| dati e migrazione | Nessuna migrazione o corpus reale |
| sicurezza/privacy | Nessuna rete di prodotto o telemetria |
| prestazioni/sistema | Confronto quiet prima/dopo, RSS separato; selezione adattiva non è una soglia di rilascio |
| tracciabilità | GS-VER-172, benchmark, specifiche, matrice e CHANGELOG aggiornati insieme |
| decisioni | Silhouette usa recupero numerico solo su overflow/underflow intermedi; conserva medie scalate fino al rapporto negli estremi; distanze realmente non rappresentabili falliscono tipizzate, mai NaN o zero fittizio |

**Ready** per i cambi implementativi successivi al push GS-VER-171.

## Esito

[GS-VER-172](../evidenze/GS-VER-172-query-sparse-e-silhouette.md) registra
20 confronti finali con controlli identici, 21 test mirati e gate completo
con 440 test e 185 righe di oracoli. Primo tentativo e piccoli costi residui
conservati; nessuna nuova soglia di rilascio o promozione scientifica.
