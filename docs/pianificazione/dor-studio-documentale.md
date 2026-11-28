<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Leggere, raccogliere e concludere

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-344 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready per implementazione e verifica |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita corrente di procedere con lo studio documentale, mantenendo stile Glifi Studio e focus su contenuto e conclusioni |
| Riferimenti | ADR-0048; GS-API-003; GS-API-007; GS-UX-001-18; GS-STD-001-11; GS-STD-001-29; RQ-028; RQ-030; RQ-032; RQ-033; RQ-037; RQ-043; RQ-047; CMP-344 |

## Perimetro e criteri osservabili

| Voce | Contratto |
| --- | --- |
| outcome e confini | Aprire un documento, raccogliere un passaggio senza creare categorie, scrivere una conclusione collegando più passaggi e ritrovare le fonti dopo riapertura |
| esperienza | Una lettura dominante; confronto e taccuino su richiesta; azioni «Raccogli passaggio», «Vai alla fonte», «Scrivi una conclusione»; dettagli tecnici secondari |
| dominio | Stato revisionato con estratti immutabili, note modificabili, gruppi e ordine; due pin di confronto; indagine opzionale verificata; annotazioni manuali distinte dalle evidenze scientifiche |
| provenienza | Revisione e digest originali, rappresentazione estratta e digest, intervallo UTF-8 e quote; locatori reali; nessuna ricostruzione da nome file o testo somigliante |
| API/parità | Sei varianti `study-call`: state, save-state, collect, resolve, export, original; tutti i parametri/risultati/failure nel dispatcher Kit e test CLI nativi |
| compatibilità | ADR-0048 definita prima del formato; reader 4 lazy, lettura 1/2/3 senza riscrittura, Artifact append-only, versioni sconosciute rifiutate; nessun nuovo schema SQLite |
| failure semantics | Limiti espliciti prima di materializzare; cancellazione e conflitto non modificano il package; fallimenti di caricamento conservano il contesto valido |
| piattaforma | Foundation, AppKit/NSTextView e PDFKit già Apple; verifica SDK corrente e build macOS; nessuna dipendenza nuova, rete, entitlement o lingua di analisi aggiuntiva |
| accessibilità | Selezione nativa e alternativa per frasi/caratteri; etichette localizzate, tastiera, colori semantici, layout compatto; audit assistivi e studio con utenti distinti dai test di modello |
| verifica | BDD italiana prima del dominio, RED osservabile e GREEN; test Core/Kit/CLI, compatibilità e corruzione; test native di selezione e lifecycle; `make verify` macOS |
| tracciabilità | GS-VER-344 e CMP-344 con esiti realmente osservati e lacune; pulizia dei soli temporanei posseduti; fonti e lavoro preesistente conservati |

**Ready** per l'implementazione e la verifica del perimetro registrato.

Non sono autorizzati implicitamente una lavagna infinita, cloud o scrittura a
mano. L'usabilità deve essere valutata sul compito di lettura e conclusione;
il superamento dei test automatici non certifica comprensione o audit VoiceOver.
