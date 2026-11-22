# GS-VER-003 — Interfaccia internazionalizzabile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-003 |
| Tipo | Evidenza di verifica |
| Versione | 0.1.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Ambito

- Requisiti coperti: CV-005, CV-007 e parte strutturale di CV-008.
- Verifica coperta: TV-015 per catalogo, configurazione e build.
- Revisione del software: working tree iniziale, precedente al primo commit.
- Ambiente: Xcode 27.0 (`27A266a`), Swift 6.4, deployment target macOS/iPadOS 27.0.

## Procedura

Esecuzione di `Scripts/verify.sh`. Il controllo di localizzazione analizza il catalogo JSON, le regioni Xcode, le impostazioni condivise e l'inclusione nelle due build phase. Seguono lint, test, smoke test headless e build delle app macOS e iPadOS.

## Risultato atteso

- lingua sorgente `it` e regioni Xcode `it`/`en`;
- chiavi semantiche indipendenti dal testo tradotto;
- valori completi italiani e inglesi per tutte le stringhe iniziali;
- stesso catalogo compilato nei due target;
- nessuna dipendenza del motore dal catalogo;
- gate completo superato.

## Risultato osservato

Tutti i controlli hanno terminato con codice di uscita zero. Il catalogo contiene cinque chiavi semantiche con valori completi `it`/`en`. Sono stati superati tre test Swift, lo smoke test CLI e le build macOS/iPadOS 27.

## Limiti

Non sono ancora presenti test UI che forzino il cambio lingua a runtime, pseudolocalizzazione, plurali o layout complessi. Tali verifiche diventeranno obbligatorie con l'introduzione delle relative superfici.

## Esito

- Esecutore e data: automazione locale di progetto, 2026-09-15.
- Esito: **Superato**.
