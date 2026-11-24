<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Ammissione documentale per gruppi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-314 |
| Tipo | Ottimizzazione misurata interna |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di proseguire ottimizzazioni e correzioni |
| Riferimenti | RF-004; RF-006; RQ-011; RQ-013; RQ-044; RQ-058; RQ-060; RQ-062; RQ-063; GS-STD-001-17; ADR-0044; CMP-314; GS-VER-314 |

## Opportunità misurata e confini

La base `741da2e` ripete la scansione di tutti gli Artifact per ogni fonte ricca
durante l'ammissione delle analisi. Uno spike standalone Swift ottimizzato, con
helper copiati e soli metadati sintetici, misura mediane su sette ripetizioni: 125 fonti ricche
su 250 fonti e 2000 Artifact richiedono circa 11,04 ms contro 0,360 ms usando
bucket locali; 500 fonti ricche su 1000 e 5000 Artifact circa 152,05 contro
1,50 ms. Sono costi isolati, senza I/O e senza attestazione di latenza dell'app.
Il riuso dell'indice riguarda una sola ammissione, non una cache persistente.
Lo spike è indicativo: la compilazione nativa concorrente è stata rilevata.
Il caso massimo 10000/10000 non ha completato la finestra bounded e non possiede
una mediana. La verifica finale deve usare helper di prodotto compilati Release,
campioni realistici e una finestra senza i compilatori del lotto attivi.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Ridurre le scansioni ripetute nelle ammissioni di più fonti; indice locale per soli candidati riservati con una revisione richiesta esatta; nessuna modifica a estrattori, formule, snapshot o reopen già indicizzato |
| requisiti | RQ-013 e GS-STD-001-17: lavoro proporzionato e misurato; RQ-044/058/060: limiti e failure invariati; RF-004/006: provenienza documentale conservata |
| dominio/API | Helper interno e chiamanti Core in gruppo; conservare il metodo singolo come riferimento e per i casi singoli; API pubbliche Core/Kit/CLI invariate |
| failure semantics | Stesso ordine dei record e stesse failure per byte negativi, snapshot assente/ambiguo o descriptor incoerente; duplicati richiesti conservati; candidati foreign/multi-revision prima ignorati restano ignorati; nessun bindings globale che allarghi la validazione |
| esperienza prevista | Stessi esiti e budget delle operazioni utente; nessuna modifica GUI, lingua, accessibilità o risultato |
| verifica | Confronto differenziale con il percorso singolo su plain/rich/misti e casi avversi, cancellazione e duplicati; benchmark con dataset/checksum, ambiente, ripetizioni, dispersione e limiti espliciti; test e make verify macOS; GS-VER-314 |
| dati e migrazione | Nessun formato o dato persistente cambia; indice temporaneo eliminato al ritorno e snapshot immutabile della stessa ammissione |
| sicurezza/privacy | Nessuna nuova dipendenza, rete, entitlement o diagnosi di contenuti; sole fixture sintetiche; fail-closed preservato |
| prestazioni/sistema | Una scansione degli Artifact e lookup sui bucket; memoria proporzionale ai candidati selezionati; controlli plain e piccoli; nessun vantaggio end-to-end o energetico inferito dallo spike |
| tracciabilità | CMP-314 inizialmente specified; questa Ready precede il codice; prove, indici e tracciabilità in GS-VER-314 |
| decisioni e recupero | Indice locale Swift nell'architettura esistente, ADR-0044 conservata; nessun backend nuovo o ADR aggiuntiva; revert dei soli helper/chiamanti senza migrazione |

**Ready** per il candidato batch. Scartare il candidato se le verifiche
differenziali falliscono o la misura finale non conferma un beneficio utile.
