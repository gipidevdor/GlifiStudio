<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Identità delle chiavi localizzate dinamiche

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-339 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Ripresa dell'audit interattivo dopo lo sblocco del Mac; correttezza e UX richieste |
| Riferimenti | GS-I18N-002; GS-STD-001-29; GS-BDD-001; CMP-335; CMP-336; CMP-339; GS-VER-339 |

## Definition of Ready

| Voce | Contratto |
| --- | --- |
| difetto riprodotto | Il catalogo apre Welch con Invio sul risultato unico, ma selettore, istruzioni e alternativa mostrano le chiavi statistics.operation.welchT, statistics.input.pairedSeries e statistics.alternative.twoSided. Le traduzioni it/en sono presenti anche nel bundle validato |
| outcome e confini | Risolvere l'identificatore completo costruito a runtime prima di passarlo a SwiftUI; conservare la distinzione dalle interpolazioni di argomenti nelle frasi localizzate |
| superficie | Occorrenze dello stesso costruttore in laboratorio statistico, operatori, analisi avanzate, corpus, linguistica e viste condivise di piani/evidenze |
| failure semantics | Nessun fallback che nasconda chiavi mancanti; catalogo e guardia controllano risorse e costruzione. Eventuali metriche senza etichetta osservate richiedono indagine separata prima di dichiararle corrette |
| API e dati | Nessuna modifica di Core, Kit, CLI, algoritmi, risultati scientifici o formati persistenti; solo presentazione e regressioni applicative |
| verifica | RED interattivo osservato; controllo statico negativo sulle occorrenze reali, test nativi del ponte con API pubbliche quando affidabili, nuova build e confronto visivo/AX, quindi make verify macOS |
| accessibilità e locale | Identificatori completi e nomi comprensibili per italiano e inglese, tastiera e AX; audit VoiceOver, Voice Control, pseudo-lingua e RTL restano distinti finché non eseguiti |
| tracciabilità e rollback | CMP-339 e GS-VER-339, con sorgente compilata e limiti espliciti; revert senza migrazioni |

**Ready** prima della correzione. La prova GUI è indipendente dalle verifiche
headless già superate; una risorsa presente non prova che la vista usi la chiave
corretta. La documentazione Apple dei costruttori distingue stringhe complete e
interpolazioni di testo. Gli esempi di regressione sono originali.
