<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0040 — Integrazioni native Apple coordinate e misurate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0040 |
| Versione | 1.0.0 |
| Stato | Accettato per attuazione dei contratti esistenti; esiti di verifica separati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di valutare e integrare le tecnologie Apple pertinenti rispettando le altre chat |
| Riferimenti | ADR-0008; ADR-0013; ADR-0018; GS-DOR-260; GS-APL-016 |

## Contesto

Il progetto usa già molte tecnologie native. Altre chat stanno completando GUI,
algoritmi KH, Natural Language e ottimizzazioni numeriche. L’adozione generalizzata
di framework non costituirebbe un miglioramento verificabile e rischierebbe di
alterare precisione, transazioni o ownership.

## Decisione

1. Rendere esplicito in GS-APL-016 il portafoglio già adottato, in lavorazione e
   condizionale, con requisiti e prove necessari.
2. Valutare un solo kernel Accelerate libero: ordinamento descrittivo degli input
   grandi normali, preservando tutti i bit e i fallback esistenti. Non promuoverlo
   senza misura end-to-end e controllo completo dei risultati.
3. Applicare Foundation al confine delle fonti esterne con file coordination,
   letture incrementali bounded e verifica del descriptor aperto; non cambiare il
   writer autorevole del package né i formati.
4. Gestire un’attività macOS finita soltanto nel piano richiesto dall’utente,
   consentendo idle sleep e rilasciandola su ogni uscita; niente opt-out globale App Nap.
5. Aggiungere i comandi standard applicabili alla scena macOS, senza intervenire
   sulla riprogettazione GUI in corso.

Metal/MPS non sostituisce implicitamente i calcoli Double con Float32. Document API
27, Core Transferable, Audio Graph, modelli, OCR e servizi di sistema restano
condizionali ai propri contratti. Non si aggiungono rete, telemetria, entitlement,
nuovi backend scientifici, migrazioni o dipendenze.

## Alternative e conseguenze

Adottare tutto lo stack indiscriminatamente è respinto. Sostituire SVD/NMF o
riduzioni floating-point mentre le altre chat li modificano è respinto. La
baseline Swift resta disponibile e gli incrementi sono reversibili separatamente.
La disponibilità delle API non attesta accessibilità, correttezza scientifica o
beneficio energetico: queste prove restano distinte nell’evidenza GS-VER-260.

## Esito della valutazione numerica

Il confronto completo della stessa API Core in due binari Release non dimostra
un beneficio robusto per `vDSP_vsortD` e rileva regressioni nei percorsi economici.
Il candidato è scartato e la produzione Swift resta invariata; patch, ricetta e
misure restano in GS-VER-260. Nessuna soglia viene scelta per forzare l’adozione.
