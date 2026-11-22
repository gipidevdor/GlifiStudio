<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-176 — Cancellazione nelle repliche bootstrap

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-176 |
| Tipo | Evidenza di cancellazione cooperativa e parità numerica |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con agenti concorrenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Più milestone complementari richieste dall'iniziatore |
| Riferimenti | GS-DOR-176; GS-STD-001-12; GS-RUN-001; GS-MET-001-21; GS-VER-173; RQ-011; RQ-041; RQ-063 |

## Contratto

Checkpoint cumulativi per osservazioni ricampionate nel bootstrap indipendente
e moving-block, con riuso del kernel indipendente anche in BCa. Il limite riguarda il lavoro del kernel, non una deadline;
validazione, stima finale e sort rimangono distinti. Non si cambiano API pubbliche,
generatori, somme, quantili, metadati, formati o backend.

## Verifica

DoR Ready prima del codice. Cinque test iniziali sono passati nell'esecuzione
congiunta, insieme ai riferimenti legacy del moving-block e all'oracolo R di BCa.
Un sesto test pubblico BCa è passato separatamente con exit 0: `CancellationError`
su task già cancellato con input valido e priorità della failure di dominio con
input non finito. Non sono state cambiate le formule di BCa.

I test deterministici iniettano un errore nel checkpoint dopo 8192 osservazioni,
con una sola replica da 10001 osservazioni. La traccia è `[0,4096,8192]` per
bootstrap indipendente, blocchi unitari, blocchi da 9000 e blocchi da 10001.
Un'altra prova concatena 3000 repliche da tre osservazioni e verifica budget
cumulativo e distanza fra checkpoint non superiore a 4096.

Dieci combinazioni con due seed confrontano tutti i campi dell'intervallo
bit per bit con i cicli precedenti, oltrepassando il confine del chunk. I
confronti preesistenti di GS-VER-173 restano attivi. Le guard pubbliche restano
prima dei checkpoint; il nuovo contatore diagnostico satura a `Int.max`, mentre
il countdown del lavoro rimane distinto e limitato a 4096.

## Controllo negativo

Su una copia isolata senza hardlink è stato soppresso soltanto il checkpoint
interno al chunk, conservando entry, checkpoint fra repliche e controlli prima
e dopo il sort. **Exit 1, otto issue e un test fallito**, in 0,020 s. In tutti
e quattro i casi la traccia degrada a `[0,10001,10001]`: manca il punto 8192 e
l'errore atteso non arriva. Il test distingue quindi la cancellazione dentro
la replica da un controllo tardivo al termine. Il codice attivo non è stato mutato.

Il controllo negativo usa l'hook interno aggiunto per osservare il lavoro in
modo deterministico; il vecchio kernel non offriva tale osservabilità senza
ricorrere a tempi o scheduling. Le API pubbliche restano identiche.

## Gate e costi

Il gate sulla composizione aggiornata è condiviso con
[GS-VER-174](GS-VER-174-betweenness-cammini-estremi.md): exit 0 e 637 test,
incluse tutte le build previste. Due passate Release dei tre workload moving-block
coincidono per input e ultimo output, ma sono marcate con contesa; nessuna
conclusione prestazionale è attribuita a quei tempi. Il sort mantiene il
backend precedente e non diventa
interrompibile; validazione, stima finale e fasi specifiche di BCa non ricevono
una garanzia di latenza dai checkpoint del kernel.

I [riscontri portabili del lotto](allegati/GS-VER-174-176-riscontri.json) conservano
conteggi, digest, controlli negativi e osservazioni con contesa, senza dati personali.
