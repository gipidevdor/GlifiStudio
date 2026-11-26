<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Distribuzione e verifica delle licenze

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-321 |
| Tipo | Correzione di distribuzione e supply chain |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di revisione delle licenze e della correttezza con tutti gli agenti |
| Riferimenti | GS-LIC-001; GS-STD-001-13; RQ-062; RQ-063; CMP-321; GS-VER-321 |

## Problema e confini

Il bundle applicativo non distribuisce il testo BSD del progetto. L'inventario
dei materiali e delle fonti algoritmiche non è verificato dal gate. Il controllo
deve rendere rilevabili licenze o avvisi mancanti e riferimenti non inventariati,
senza presentare la verifica strutturale come accertamento legale della titolarità.

## Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Includere LICENSE e THIRD_PARTY_NOTICES.txt originali nei target applicativi; verificare identità dei byte nel bundle macOS e struttura dell'inventario locale |
| dominio/API | Solo risorse legali, configurazione Xcode e strumenti di sviluppo; nessuna modifica delle API Core/Kit/CLI o dei formati utente |
| failure semantics | Inventario non valido, percorsi assenti/esterni, avvisi assenti o risorse alterate producono exit nonzero; nessun download o consenso implicito |
| verifica | Test negativi del verificatore, self-test Xcode, controlli fixture e gate make verify macOS con bundle Release reale |
| UX/accessibilità | Nessun nuovo controllo o percorso interattivo; testi legali UTF-8 distribuiti come risorse consultabili |
| sicurezza/privacy | Nessuna dipendenza o rete a runtime; preservare avvisi di terzi e separare diritti sulle fonti da licenza del codice originale |
| prestazioni | Verifiche solo durante lo sviluppo e risorse testuali nel bundle; nessuna accelerazione o variazione numerica rivendicata |
| tracciabilità | CMP-321 inizialmente specified, evidenza GS-VER-321, indici e guida aggiornati con l'integrazione |
| recupero | Revert dei soli file del lotto; nessuna migrazione o modifica di dati utente |

**Ready** per questa correzione circoscritta. Le sostituzioni numeriche e la
ricostruzione della provenienza restano documentate nelle unità GS-DOR-318/319.
