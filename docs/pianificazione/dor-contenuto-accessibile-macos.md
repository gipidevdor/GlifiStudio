<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Contenuto accessibile delle fonti macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-193 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Audit macOS automatico e completamento dei difetti concreti richiesti dall'iniziatore |
| Riferimenti | RQ-012; GS-APL-003; GS-UX-001-09; GS-UX-001-13 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Solo macOS: rimuovere l'etichetta accessibile sostitutiva dai tre Text del contenuto originale in KWIC, evidence e anteprima export, lasciando heading e semantica nativa Text; nessun cambio ai testi o range scientifici |
| requisiti | RQ-012; il contenuto della fonte non riceve più soltanto l'etichetta generica `query.source`, `finding.evidence.source` o `export.preview`; nessuna nuova dichiarazione di audit completo |
| dominio/API | Correzione locale della view condivisa sotto condizione macOS; nessuna API, modello o dato persistente nuovo; ramo iPadOS invariato |
| failure semantics | Nessuna operazione fallibile o asincrona introdotta; failure e stato validi esistenti invariati |
| esperienza prevista | Fonte selezionabile e contesto nominato dalla Section esistente; label, ruoli e contenuto nativi, senza testo duplicato in un nuovo valore accessibile |
| verifica | Review dei tre siti e dei rami di piattaforma, lint e build nel profilo macOS; nessun test che replichi l'implementazione per questa modifica reversibile; GS-VER-193 candidata; prova VoiceOver non eseguita |
| dati e migrazione | Nessun dato entra, cambia o persiste; nessuna migrazione |
| sicurezza/privacy | Nessuna rete, dipendenza, entitlement, logging o nuovo accesso ai contenuti; stesse fonti già mostrate |
| prestazioni/sistema | Rimozione di tre modificatori; nessun nuovo I/O, calcolo o copia dell'intero testo |
| tracciabilità | CMP-193 inizialmente `specified`; RQ-012 e TV-017/TV-058, evidenza e registro residui nello stesso cambiamento |
| decisioni e recupero | GS-APL-003; nessuna nuova decisione architetturale; coordinamento dopo B/C e lettura del responsabile prima del codice; revert locale della view |

**Ready** per la correzione statica circoscritta, non per dichiarare VoiceOver,
GUI reale, audit automatico end-to-end, nuovi criteri EA o G4 superati. Mac bloccato
e scelta esplicita di soli test automatici restano limiti della verifica.

Il terzo sito, anteprima export, è incluso per decisione del responsabile prima
del codice; presenta lo stesso override dei due testi di fonte.

## Verifica finale del profilo macOS

Gate e preflight automatici superati sullo snapshot identificato in
[GS-VER-188](../evidenze/GS-VER-188-gate-macos.md). La clausola dell'incremento è
`verified` soltanto nel perimetro documentato; nessuna chiusura di GUI manuale,
VoiceOver, finestre reali, autosave, iPadOS o G4 è inferita.
