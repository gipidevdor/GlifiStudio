# GS-VER-005 — Ridenominazione Glifi Studio

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-005 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Ambito

- Decisione coperta: ADR-0007.
- Specifica coperta: GS-ID-001.
- Revisione del software: working tree iniziale, precedente al primo commit.
- Ambiente: Xcode 27.0 (`27A266a`), Swift 6.4, deployment target macOS/iPadOS 27.0.

## Procedura

Esecuzione di `Scripts/verify.sh` dalla cartella `/Users/gpicchiarelli/Documents/GlifiStudio`. La procedura comprende controllo automatico della denominazione, validazione documentale, architetturale, linguistica e Apple, lint Swift, tre test, smoke test headless e build Debug/Release di entrambe le app.

Il controllo della denominazione esamina percorsi e contenuti controllati, escludendo esclusivamente i due file di appunti preservati come fonti di provenienza.

## Risultato atteso

- nome visibile `Glifi Studio` nel catalogo italiano e inglese;
- workspace, progetto, schemi, target e tipi applicativi basati su `GlifiStudio`;
- package e moduli `GlifiCore`, `GlifiKit` e `GlifiCLI`;
- bundle identifier nel namespace provvisorio `studio.glifi.GlifiStudio`;
- nessun riferimento alla denominazione precedente in percorsi o artefatti controllati;
- tre test e quattro build Xcode superati.

## Risultato osservato

`Scripts/verify.sh` ha terminato con codice di uscita zero. Il controllo di denominazione, i quattro controlli strutturali, i tre test Swift, lo smoke test di `GlifiCLI` e le build Debug/Release per `GlifiStudio-macOS` e `GlifiStudio-iPadOS` sono stati superati dalla nuova posizione del repository.

## Limiti

La verifica copre gli artefatti locali. La disponibilità legale del nome, gli identificatori definitivi dell'account Apple Developer e la propagazione verso servizi esterni restano verifiche distinte.

## Esito

- Esecutore e data: automazione locale di progetto, 2026-09-15.
- Esito: **Superato**.
