# GS-VER-001 — Bootstrap dell'ambiente Xcode

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-001 |
| Tipo | Evidenza di verifica |
| Versione | 0.4.0 |
| Stato | Sostituito |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Sostituito da | [GS-VER-002](GS-VER-002-baseline-linguistica-italiana.md) per la baseline corrente |

## Ambito

- Requisiti coperti: CV-001, CV-002, CV-003; RF-023 e RF-024 soltanto a livello di scaffold.
- Verifiche coperte: TV-011 preliminare e TV-013 build baseline.
- Revisione del software: working tree iniziale, precedente al primo commit.
- Ambiente: macOS; Xcode 27.0 (`27A266a`); Swift 6.4; SDK macOS/iOS 27.0; deployment target macOS/iPadOS 27.0.
- Dataset o fixture: non applicabile; test deterministici del bootstrap.

## Procedura

Esecuzione della revisione iniziale di `Scripts/verify.sh`, precedente alla calibrazione italiana. La procedura controllava documentazione e confini architetturali, applicava il lint Swift, eseguiva i test del package e lo smoke test headless, quindi compilava senza firma entrambi gli schemi applicativi in configurazione Debug.

## Risultato atteso

- nessun errore di formattazione o dipendenza UI in `GlifiCore`;
- test `GlifiCoreTests` e `GlifiKitTests` superati;
- `GlifiCLI` avviata con risposta attesa `GlifiCore ready`;
- build `GlifiStudio-macOS` superata;
- build `GlifiStudio-iPadOS` per simulatore superata.

## Risultato osservato

Tutti i controlli hanno terminato con codice di uscita zero. Sono stati superati due test Swift; entrambi gli schemi applicativi sono stati compilati. Gli artefatti temporanei sono stati eliminati al termine della verifica.

## Limiti

La verifica non include firma, provisioning, distribuzione, dispositivi fisici, test UI, coverage di dominio o flussi funzionali di importazione e analisi, non ancora implementati.

## Esito

- Esecutore e data: automazione locale di progetto, 2026-09-15.
- Esito: **Superato**.
