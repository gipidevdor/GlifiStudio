<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Codifica dei digest degli export visuali

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-178 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta di ottimizzare evitando sovrapposizioni alle altre chat |
| Riferimenti | GS-VIZ-001; GS-MET-001-22; GS-STD-001-12; GS-STD-001-17; GS-STD-001-29; GS-VER-175; GS-VER-207; RF-084; RQ-028; RQ-044; RQ-063 |

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Ridurre formatter e allocazioni della codifica SHA-256 privata degli export; CryptoKit e tutti i controlli di integrità restano applicati. |
| contratto | Identici byte sha256: più 64 cifre ASCII minuscole; bundle, manifest, ricevute, JSON e CSV invariati. Nessuna cache o nuovo helper pubblico. |
| failure semantics | Tutti i rifiuti tipizzati e l'ordine delle validazioni invariati; API Kit/CLI e formato v1 invariati. |
| verifica | Vettori noti e confronto completo con formatter precedente, dati sintetici binari/Unicode; bundle completo e verifica; regressioni di integrità esistenti. |
| prestazioni | Harness Kit opt-in Release con supporto già esistente, senza modifiche alle dipendenze; baseline prima della patch; un warmup e sette campioni, uguaglianza e SHA fuori timer. Digest isolato, bundle piccolo, verifica tabella grande; contesa dichiarata, nessuna soglia nuova. |
| ownership | Agente export: test dedicato e helper privato in GlifiVisualizationExport; coordinatore: baseline, documenti e gate. Presentation, GUI, servizio, CLI e sessioni delle altre chat esclusi. |
| tracciabilità | CMP-186; GS-VER-178; codice, test e registri nello stesso incremento. |
| uscita | Revisione indipendente, make verify completo e pulizia; nessuna attestazione G4. |

**Ready** sulla base pubblicata `38bba29`, prima del coding. Eventuali ulteriori
copie CSV possono essere valutate soltanto in una misura separata successiva,
con identità dei byte e beneficio ripetuto; non fanno parte della patch minima.
