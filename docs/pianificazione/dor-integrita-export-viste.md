<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Integrità degli export delle viste scientifiche

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-175 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di implementare più milestone complementari |
| Riferimenti | RF-084; RQ-028; RQ-044; GS-VIZ-001; GS-MET-001-22; GS-STD-001-12; GS-STD-001-16 |

| Voce | Accettazione |
| --- | --- |
| tracciabilità | GS-VER-175; CMP-179; specifiche, test e registri nello stesso incremento. |
| outcome e confini | Milestone e file definiti nelle righe seguenti; esclusioni e contratti restano espliciti |
| milestone strutturale | Manifest v1 con inventario esatto dei due payload canonici, senza duplicati, percorsi alternativi o media type incoerenti; dimensioni e digest verificati |
| milestone provenance | Identità, conteggi, layout, riduzione e caveat del manifest corrispondenti alla VisualizationSpec |
| milestone CSV | Tabella equivalente alla rigenerazione deterministica della stessa vista, con controlli strutturali compatibili con ogni famiglia |
| RED | Dimostrare che il verificatore precedente accetta manifest manomessi lasciando invariati i payload e CSV alterati con digest aggiornato |
| compatibilità | Stessi formati v1, API e bundle validi dei builder esistenti; identità opache non vincolate a UUID e nessun vincolo sulla versione software corrente |
| semantiche per famiglia | Non confondere numero di foglie con righe di fusione del dendrogramma; esclusioni dichiarate e riduzione restano concetti distinti |
| failure semantics | Rifiuto fail-closed tramite la failure tipizzata di integrità esistente; nessun risultato parziale |
| confini di fiducia | Consistenza interna del bundle, non autenticazione dell'origine: progetto/generazione non vengono attestati contro un progetto esterno e tutti i payload coerentemente riscritti non sono distinguibili senza un digest atteso fidato |
| ownership | Produzione: GlifiVisualizationExport; verifica: nuovo GlifiVisualExportIntegrityTests; coordinatore: contratti, registri e gate; file GUI/nuovi operatori analitici/Apple esclusi |
| dati e migrazioni | Fixture sintetiche e bundle generati dai builder attuali; nessun formato, dipendenza, privilegio o migrazione nuova |
| uscita | RED/verde, compatibilità delle quattro famiglie, revisione indipendente e make verify sulla composizione con GS-DOR-174; nessuna attestazione di audit GUI o G4 |

**Ready** registrata prima delle modifiche implementative. Le milestone si
aggiungono al recupero numerico di Brandes già verificato in modo mirato;
il gate finale coprirà l'intero lotto isolato.

## Esito del lotto

Implementazione e verifiche funzionali concluse nel gate congiunto di
[GS-VER-174](../evidenze/GS-VER-174-betweenness-cammini-estremi.md), con 637 test
e tutte le build previste. Le misure sotto contesa non attestano prestazioni
isolate; i limiti specifici restano nelle rispettive evidenze. Nessuna promozione
scientifica, audit grafico o gate su dispositivo viene chiuso da questo lotto.
