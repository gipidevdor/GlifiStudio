<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Limiti correnti sul profilo corpus riutilizzato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-330 |
| Tipo | Correzione del contratto di ammissione |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di correttezza semantica e incarico di integrazione GS-VER-330 |
| Riferimenti | RQ-008; RQ-033; GS-API-003; GS-STD-001-11; GS-DAT-001; GS-VER-330; CMP-330 |

## Problema e confini

Il riuso del profilo corpus controlla numero delle fonti e byte ammessi, ma
non applica i limiti correnti di vocabolario, n-grammi distinti e celle non
nulle. Con gli stessi input e parametri scientifici una richiesta restrittiva
può quindi fallire a cache fredda e riuscire dopo un calcolo con limiti più
ampi. Il percorso condiviso alimenta anche le analisi derivate.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Applicare i tre limiti al profilo riutilizzato, sia nell'analisi corpus diretta sia nel caricamento del gruppo condiviso; conservare il riuso quando il risultato rientra nei limiti |
| requisiti | RQ-008/033 e GS-API-003: parametri e failure hanno lo stesso significato indipendentemente dalla storia della cache e dal client |
| dominio/API | Nessuna API pubblica, formula, dipendenza o schema persistente nuovo; i limiti operativi restano fuori dal descriptor scientifico |
| failure semantics | Stessi codici `analysis.vocabulary-limit-exceeded`, `analysis.ngram-limit-exceeded` e `analysis.matrix-limit-exceeded`, categoria `insufficientResources`, retry dopo cambiamento delle condizioni e ultima generazione conservata |
| esperienza prevista | Un limite restrittivo non viene ignorato; un limite sufficiente restituisce l'Artifact esistente senza nuova tokenizzazione o generazione |
| verifica | Regressioni parametrizzate freddo/caldo per i tre limiti, chiamata diretta e gruppo usato da analisi derivata; soglia esatta, limite più ampio, riapertura e conservazione di identità/snapshot; RED prima della modifica e GREEN sullo stesso comando |
| dati e migrazione | Lettura delle strutture persistenti correnti; nessuna invalidazione o duplicazione di Artifact scientificamente identici |
| sicurezza/privacy | Fixture sintetiche locali, directory temporanee con cleanup; nessun dato personale, rete, entitlement o libreria aggiunti |
| prestazioni/sistema | Confronti di cardinalità sul risultato già decodificato; nessuna scansione dei testi o ricalcolo; esecuzioni Swift serializzate dall'integratore |
| tracciabilità | GS-VER-330 registra esiti, comandi e limiti; matrice e indici condivisi aggiornati dall'integratore |
| decisioni e recupero | Correzione privata mirata; se emergono contratti incompatibili, segnalarli prima di ampliare lo scopo |

**Ready** prima delle modifiche a sorgenti e test. L'integratore coordina lo
scratch di compilazione e le esecuzioni RED/GREEN; questa scheda non attesta
verifiche ancora da eseguire.
