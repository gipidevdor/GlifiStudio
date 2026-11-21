<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-171 — Integrazione e pubblicazione degli algoritmi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-171 |
| Tipo | Evidenza di integrazione |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Codex, con quattro agenti concorrenti |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita: commit, push e successiva iterazione |
| Riferimenti | GS-DOR-171; GS-VER-168; GS-VER-169; GS-VER-170; RQ-008; RQ-063 |

## Perimetro

Proiezione dei soli algoritmi e delle relative verifiche/documentazione su
`origin/main` alla revisione `fe6f654`, in un worktree separato dal working tree
condiviso. Esclusi i cambiamenti paralleli di interfaccia macOS, runtime,
package, query, SpanMap, tokenizer ed export. I sette commit upstream successivi
alla vecchia base `a86a53b` sono preservati, inclusi i loro test, oracoli,
ValidationManifest e stati di conformità.

## Compatibilità

`LexRankSentence-v1` e `TextRankSentence-v1` conservano semantica, default,
limiti e failure già pubblicati. La variante locale configurabile usa
`TextRankSentence-configurable-v1`; le varianti LexRank locale restano
`LexRankSentence-continuous-v1` e `LexRankSentence-threshold-v1`. Configurazione
esplicita e diagnostica dei nuovi metodi non reinterpretano Artifact legacy.
Il budget `Budget-characters-v1` conta scalari Unicode e resta compatibile.

Le evidenze GS-VER-168/169/170 descrivono snapshot storici del working tree
sorgente; i loro numeri di test comprendono altre attività allora presenti.
Non vengono attribuiti automaticamente alla proiezione integrata. Il nuovo gate
qui registrato verifica invece esattamente l'insieme candidato al commit.

## Correzione numerica prima della pubblicazione

La review ha rilevato che la traslazione comune di Welch non protegge la
varianza interna di un gruppo con offset elevato rispetto agli altri. Sul caso
`[[0,1,2],[1e15,1e15,1e15+1]]`, il percorso precedente produce una varianza
secondaria circa 0,33594 anziché 1/3 e un errore relativo di circa 0,2% su F.
Una regressione sul codice precedente ha prodotto 72 assertion fallite;
la correzione sottrae un anchor locale per la varianza di ogni gruppo,
conservando scale comuni e medie ricostruite per i contrasti. Dieci test mirati
passano, inclusi 54 combinazioni di segno, traslazione, scala 2^±900 e inversione,
oltre al fallback per sottrazioni locali in overflow. Il riferimento Decimal
indipendente a 80 cifre conferma F≈2,25×10³⁰ e df2=3,2. Review matematica separata
con frazioni esatte e review del patch superate; nessuna tolleranza allargata.

## Verifica

Il primo gate provvisorio ha superato 370 test Core, 46 test Kit, 175 righe di
oracoli, PDF/A, CLI e recovery; interrotto intenzionalmente durante la build
Release per applicare la correzione Welch, senza presentarlo come superato.
Il nuovo `make verify` sul codice corretto è terminato con exit 0 il
2026-11-21 alle 22:10 CET: **371 test Core, 46 test Kit e 8 test nativi macOS**
(425 complessivi), **177 righe di oracoli**, due PDF/A-2u conformi, 51 controlli
CLI, QueryAST e 22 checkpoint recovery superati. Le build Debug/Release macOS e iPadOS tramite workspace
sono passate. Il riepilogo nativo è confermato con `xcresulttool`.

Restano gli avvisi dell'host sul CoreSimulator 1171.7.0 inferiore a 1174.21.0 e
sulla dichiarazione di apertura in-place iPadOS. Nessuna esecuzione su
dispositivo/simulatore iPad attribuita a questa verifica. Nessuna soglia
prestazionale, deroga ai controlli o promozione scientifica introdotta.
