<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Robustezza trasversale della baseline

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-302 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di ottimizzare l'intera base e applicare la massima qualità ingegneristica |
| Riferimenti | GS-STD-001-29; GS-QRY-001; GS-DEV-002; GS-API-003; RF-001; RF-015; RF-016; RF-018; RQ-058; RQ-063 |

## Perimetro e criterio di arresto

La revisione parte dalla baseline `8901f4a` e applica i requisiti esistenti a
Core, Kit, CLI, app macOS e strumenti di verifica. La scheda consolida durante
l'audit i difetti riprodotti: overflow e troncamento delle query, ammissione
dei file CLI, chiusura delle operazioni della finestra e proprietà delle cache.
Ogni correzione deve avere una regressione osservata prima e dopo.

Il completamento richiede gate macOS, parità CLI/Kit, documentazione dei budget,
misure Release delle query e prove mirate di sanitizer ove eseguibili. Nessun
voto assoluto di qualità, conformità universale o chiusura G4 deriva dall'audit.
Il completamento KH pubblicato nel frattempo in `d368285` entra nella baseline
del gate; le ulteriori modifiche non pubblicate restano nella copia separata.

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Correggere i difetti riprodotti senza cambiare formule scientifiche, backend o formati di prodotto |
| failure semantics | Budget esaurito e input non ammesso falliscono prima di pubblicare risultati; cancellazione e stato conservato seguono la tassonomia |
| tracciabilità | CMP-302 e GS-VER-302 collegano requisiti, sorgenti, regressioni ed esito del gate |
| Query | Il limite delle righe governa l'output; operandi completi entro budget separati e globali alla valutazione; superamento con failure tipizzata |
| API | Nessuna nuova operazione Kit/CLI; limiti Core opzionali e parità ricontrollati; identità AST e formati persistenti invariati |
| CLI | Un descrittore controllato e lettura incrementale bounded; categorie e retry coerenti per errori del filesystem |
| Lifecycle | Chiusura finestra con cancellazione e attesa delle attività prima del rilascio di sessione e accesso alla fonte |
| Strumenti | Cache rimovibile solo con proprietà riconosciuta e lock esclusivo; nessuna bonifica globale per nome o anzianità |
| Verifica | Regressioni avversarie, suite mirate, misure prima/dopo e gate macOS; limiti effettivi in GS-VER-302 |
| Recupero | Nessuna migrazione di prodotto; directory non riconosciute conservate; modifiche sorgente reversibili |
| Esclusioni | Nessuna dipendenza, rete, entitlement o backend nuovo; nessuna promozione scientifica, audit assistivo o soglia di rilascio |

**Ready** consolidata durante la revisione delle correzioni ai requisiti già
esistenti; nessuna nuova vertical slice o approvazione scientifica è dedotta.
