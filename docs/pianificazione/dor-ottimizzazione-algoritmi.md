<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Ottimizzazione misurata degli algoritmi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-169 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita: ottimizzare gli algoritmi con massima correttezza ed efficienza |
| Riferimenti | GS-DOR-168; GS-VER-168; GS-STD-001-17; GS-MET-001-03; ADR-0032; RQ-008; RQ-009; RQ-063 |

## Contratto dell'incremento

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Ridurre tempo e allocazioni dei colli di bottiglia analitici misurati; conservare formule, varianti, ordine, seed e tolleranze |
| requisiti | Correttezza prima della velocità; nessuna approssimazione, esclusione di dati o indebolimento dei gate |
| contratto di dominio/API | Stesse API Core/Kit, nessun nuovo backend, dipendenza o formato persistente |
| failure semantics | Budget, overflow, dominio, dati insufficienti e cancellazione restano fail-closed e tipizzati |
| esperienza prevista | Calcolo fuori dal Main Actor; nessuna nuova interfaccia |
| verifica | Misure Release prima/dopo sullo stesso generatore; warm-up e cinque campioni, mediane e dispersione, checksum; oracoli e regressioni; `make verify` |
| dati e migrazione | Nessuna migrazione; artefatti già persistiti conservano i contratti esistenti |
| sicurezza/privacy | Solo dati sintetici deterministici, nessuna rete o telemetria |
| prestazioni/sistema | Riduzioni di allocazioni e lavoro ridondante dopo baseline; hardware, ambiente, memoria e stato termico registrati; nessun nuovo gate numerico senza baseline approvata |
| tracciabilità | GS-VER-169, matrice, requisiti pertinenti, benchmark e CHANGELOG aggiornati nello stesso cambiamento |
| decisioni | Ambito autorizzato da richiesta e ADR-0032; promozione scientifica separata |

**Ready** prima delle modifiche implementative.

## Esito

Implementazione e confronto completati in
[GS-VER-169](../evidenze/GS-VER-169-ottimizzazione-algoritmi.md): tredici casi
misurati in Release con controlli input/output invariati, 447 test e gate
completo superati. Le misure restano informative, con compromessi di memoria
e tempo dichiarati; nessuna soglia o variante scientifica è promossa.
