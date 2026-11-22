<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Integrazioni native Apple coordinate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-260 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita: valutare Accelerate, Metal e le altre tecnologie Apple e integrare le adozioni pertinenti rispettando le altre chat |
| Riferimenti | ADR-0008; ADR-0018; ADR-0024; ADR-0032; GS-APL-005/011/015; GS-STD-001-17; RF-002/003; RQ-002/007/011/013/053/054/058/063 |

## Confini e coordinamento

Checkout dedicato dalla baseline `02c1c66`. Restano di competenza delle altre chat:
GUI e laboratorio avanzato, KH/Natural Language/MDS/SOM/LDA/reti, NMF e visite
analitiche GS-VER-173, selezioni e lookup macOS GS-VER-230/231/232. Nessuna modifica
non committata di quei checkout viene incorporata implicitamente.

## Criteri di accettazione

| Area | Contratto |
| --- | --- |
| outcome e confini | Valutare le quattro aree delimitate sotto su baseline isolata e attuare le adozioni giustificate; nessun nuovo metodo scientifico, formato, rete o lavoro GUI altrui |
| failure semantics | Conservare failure Glifi tipizzate, budget fail-closed e byte immutati; rifiutare tipi non regolari prima del coordinatore e sul descriptor; rilasciare attività su successo/failure/cancellazione senza alterarne l’esito |
| tracciabilità | ADR-0040, GS-APL-016, CMP-261/262/264 e GS-VER-260 nello stesso cambiamento; risultati e limiti distinti per area |
| Valutazione | Inventario di tecnologie Apple già adottate, in corso, adottabili e rinviate con motivazione, requisito e verifica; nessuna adozione per il solo nome del framework |
| Accelerate | Valutare `vDSP_vsortD` per il fallback ad alta cardinalità della descrittiva; riferimento Swift invariato per zeri, subnormali, piccoli array e casi già economici. Promuovere soltanto con confronto end-to-end misurato e identità bitwise del risultato completo; non cambiare formule, riduzioni, quantili, precisione, payload o backend scientifici |
| Metal/MPS | Verificare disponibilità e precisione rispetto alla baseline Double; nessun passaggio implicito a Float32, shader o GPU aggiunti senza equivalenza, vantaggio end-to-end, bounds e fallback |
| File | Lettura Foundation coordinata e incrementale di sorgenti esterne, limitata prima di accumulare oltre il budget; file non regolari/link e cancellazione trattati con failure di dominio; byte e SpanMap invariati, nessun nuovo formato |
| Runtime | Attività ProcessInfo macOS finita soltanto nel piano esplicitamente richiesto, reason statica, idle sleep consentito, rilascio su successo/failure/cancellazione; nessun opt-out globale App Nap, timer o incremento QoS |
| App | Comandi nativi della piattaforma per la navigazione già presente, senza controlli personalizzati o modifiche ai file GUI occupati |
| Privacy | Nessun corpus, path o query nei log; nessuna rete, telemetria, download modelli, entitlement o servizio nuovo |
| Verifica | Test di dominio e regressione, confronti completi numerici, benchmark Release e risorse misurate quando cambia un hot path, gate statici e `make verify`; limiti non eseguibili dichiarati |
| Recupero | Patch separate per area; revert senza migrazione o perdita dei documenti, baseline Swift mantenuta; preservare stash, checkout e toolchain altrui |

## Stato scientifico e limiti

Questa attuazione non promuove automaticamente capacità candidate, non attesta audit
manuali VoiceOver o benchmark energetici e non introduce nuovi gate per criteri
ancora da attuare. Le adozioni condizionali restano tali finché non esiste la prova
richiesta. Gli identificatori GS-DOR/VER/CMP-260…269 sono riservati a questo lotto.

**Ready** prima del coding per il perimetro e le prove dichiarati.

Il candidato sort vDSP è stato valutato e scartato: nessuna soglia o percorso
Accelerate aggiuntivo viene promosso nel prodotto; la prova resta in GS-VER-260.
