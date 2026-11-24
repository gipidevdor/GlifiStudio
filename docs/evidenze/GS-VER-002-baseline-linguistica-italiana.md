# GS-VER-002 — Baseline linguistica italiana

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-002 |
| Tipo | Evidenza di verifica |
| Versione | 0.2.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Sostituito da | [GS-VER-003](GS-VER-003-interfaccia-internazionalizzabile.md) per l'interfaccia |

## Ambito

- Requisiti coperti: RF-025, CV-005 e CV-006.
- Verifica coperta: TV-014 per la configurazione iniziale; non per la qualità linguistica.
- Revisione del software: working tree iniziale, precedente al primo commit.
- Ambiente: Xcode 27.0 (`27A266a`), Swift 6.4, deployment target macOS/iPadOS 27.0.
- Risorse: catalogo condiviso `Localizable.xcstrings`, lingua sorgente `it`.

## Procedura

Esecuzione di `Scripts/verify.sh` e ispezione delle impostazioni effettive dei due schemi Xcode. Il gate valida il catalogo, la regione di sviluppo, i confini architetturali, la formattazione, i test Swift, lo smoke test CLI e le build macOS/iPadOS.

## Risultato atteso

- `DEVELOPMENT_LANGUAGE` e `CFBundleDevelopmentRegion` impostati a `it`;
- catalogo italiano condiviso incluso in entrambe le app;
- configurazione predefinita del motore con lingua `it` e locale `it_IT`;
- contratto di GlifiKit indipendente dalle stringhe localizzate;
- build macOS 27 e iPadOS 27 superate.

## Risultato osservato

Tutti i controlli hanno terminato con codice di uscita zero. Xcode espone `DEVELOPMENT_LANGUAGE = it` e `INFOPLIST_KEY_CFBundleDevelopmentRegion = it` per entrambi gli schemi. Sono stati superati tre test Swift, compreso il test della configurazione linguistica italiana, lo smoke test CLI e le due build applicative.

## Limiti

L'evidenza non misura accuratezza di tokenizzazione, lemmatizzazione, parti del discorso o riconoscimento di entità. Corpora italiani, metriche e soglie qualitative restano da definire in DA-008.

## Esito

- Esecutore e data: automazione locale di progetto, 2026-09-15.
- Esito: **Superato**.
