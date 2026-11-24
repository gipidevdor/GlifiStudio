<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Riverifica e rifinitura dei profili KH

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-305 |
| Tipo | Correzione e verifica analitica |
| Versione | 1.0.2 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita: ricontrollare e perfezionare ogni aspetto |
| Riferimenti | RF-087; RQ-025; RQ-058; RQ-060; RQ-063; ADR-0043; GS-VER-300; GS-VER-305 |

## Esito e confini

Riesaminare i profili KH pubblicati in d368285, correggendo difetti numerici,
non determinismo e ammissioni incomplete dimostrati dalla revisione avversariale.
Le prime riproduzioni riguardano rappresentanti Unicode dei composti,
normalizzazione NB con conteggi grandi, quadrati subnormali Ward.D2 e budget
MDS/NB/SOM. Ulteriori rilievi dello stesso audit sono registrati come tali,
senza retrodatare il loro esame. L’audit della composizione include anche il
planner: il costo del bundle keyness deve ridurre il budget disponibile per le
capability successive. Questo rilievo è aggiunto dopo la revisione iniziale. La GUI e i lavori concorrenti restano preservati.

## Criteri di uscita

- Riproduzione discriminante per ogni correzione, con oracolo indipendente
  dove serve; non modificare tolleranze o controlli per nascondere un errore.
- Stesse formule dichiarate, API e trasporto CLI/Kit; modifiche dei risultati
  numerici o delle ammissioni sono documentate esplicitamente.
- Budget cumulativi e cancellazione prima dei buffer/calcoli non ammessi;
  nessun risultato plausibile ottenuto perdendo informazione necessaria.
- Verifiche mirate, make verify macOS e controlli coerenti con i percorsi toccati;
  nessuna promozione V6, promessa prestazionale o nuova dipendenza.
- Prove conservate e artefatti rigenerabili del solo lotto eliminati a chiusura.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Correzioni dimostrate nei profili KH, nel trasporto e nel budget planner; GUI e WIP concorrenti esclusi |
| failure semantics | Input incoerenti, risorse esaurite e range non preservabile generano failure tipizzate; nessun output parziale o riscrittura degli Artifact storici |
| tracciabilità | RF-087, RQ-025/RQ-058/RQ-060/RQ-063; ADR-0043, GS-MET-001-23 e GS-VER-305; test discriminanti e gate macOS |

**Ready** nel perimetro della richiesta. La verifica è registrata in GS-VER-305.
