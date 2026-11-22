<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Raffinamento di memoria e calcolo analitico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-170 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Prosecuzione esplicita dell'ottimizzazione con priorità alla correttezza |
| Riferimenti | GS-DOR-169; GS-VER-169; GS-STD-001-17; GS-MET-001-03; ADR-0032; RQ-008; RQ-009; RQ-063 |

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Ridurre costo delle descrittive e memoria temporale; profilare e ottimizzare NMF, TF-IDF e BM25 nei colli di bottiglia misurati |
| requisiti | Stessi risultati, ordinamenti, formule, seed, tolleranze e criteri di arresto; nessuna approssimazione |
| contratto di dominio/API | API e formati invariati; nessuna nuova dipendenza o backend |
| failure semantics | Limiti, overflow, input invalidi e cancellazione espliciti; cache DF densa di weigh limitata a 1.000.000 colonne, superiore al vocabolario standard e applicata anche alle configurazioni corpus custom; BM25 scalato solo quando gli intermedi ordinari non sono finiti; nessun risultato parziale pubblicato |
| esperienza prevista | Nessuna modifica UI; calcolo fuori dal Main Actor |
| verifica | Baseline Release prima delle modifiche, cinque campioni dopo warm-up, checksum completi, riferimento diretto/oracoli e `make verify` |
| dati e migrazione | Solo generatori sintetici e nessuna migrazione |
| sicurezza/privacy | Nessuna rete, telemetria, dati personali o corpus reale |
| prestazioni/sistema | RSS per processo isolato; setup e checksum fuori dal timer; compromessi e modifiche scartate registrati |
| tracciabilità | GS-VER-170, matrice, specifiche pertinenti e CHANGELOG aggiornati insieme |
| decisioni | Autorizzato dalla prosecuzione dell'iniziatore; promozione scientifica e hardware di riferimento separati |

**Ready** prima delle modifiche implementative.

## Esito

Implementazione, confronto e gate completati in
[GS-VER-170](../evidenze/GS-VER-170-raffinamento-algoritmi.md): quattordici
casi Release con controlli completi invariati, 480 test e `make verify`
superati. Correzioni degli estremi BM25 verificate con oracolo Decimal e
riferimenti diretti; costi dei fallback e memoria dichiarati. Nessuna
promozione scientifica o soglia di rilascio.
