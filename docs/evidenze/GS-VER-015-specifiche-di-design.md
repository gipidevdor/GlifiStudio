<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-015 — Specifiche di design implementativo

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-015 |
| Tipo | Evidenza di verifica documentale e architetturale |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata della baseline ADR-0016 |

## Ambito

- richiesta: trasformare la revisione progettuale in una famiglia compatta e
  autorevole di specifiche implementative;
- verifiche documentali coperte: predisposizione TV-050–TV-061;
- decisione: ADR-0016;
- documenti: GS-DOM-001, GS-DAT-001, GS-LNG-001, GS-QRY-001, GS-ANA-001,
  GS-RUN-001, GS-UI-001, GS-VIZ-001, GS-VAL-001 e GS-PROD-001.

## Procedura

1. validare metadati, ID univoci, link e copertura obbligatoria delle dieci
   specifiche;
2. verificare integrazione in requisiti, architettura, tracciabilità, standard,
   profilo Apple, ADR e baseline prodotto;
3. verificare sequenze RF/RQ/TV e assenza di duplicati;
4. eseguire `make verify` e `make verify-app-store` con la toolchain locale;
5. riesaminare il diff e lo stato del repository.

## Risultato osservato

- 169 file documentali e 168 identificatori controllati risultano validi;
- tutti i collegamenti locali si risolvono;
- sono indicizzate 22 specifiche GS-MET, 14 GS-UX e 10 GS-DSG;
- le sequenze RF-001–RF-086, RQ-001–RQ-048 e TV-001–TV-061 sono continue e prive
  di duplicati nelle rispettive tabelle normative;
- `make verify` è terminato con esito positivo: toolchain, repository, segreti,
  configurazione GitHub, naming, architettura, localizzazione, profilo Apple,
  baseline App Store, test Swift e build applicative sono superati;
- `make verify-app-store` è terminato con esito positivo, inclusi analisi statica e
  archivi macOS/iPadOS senza firma.
- dopo il push di `6df92ca`, GitHub ha creato i run `34965002983` e `34965002861`
  ma non ha avviato step o runner perché il budget Actions impedisce ulteriore uso;
  la deroga temporanea GS-WVR-002 registra rischio, mitigazione e rientro.

## Limiti

La verifica può provare completezza strutturale e coerenza della baseline, non
implementazione del dominio, correttezza scientifica, performance, UX su persone,
dispositivi fisici, firma o approvazione App Store. Le verifiche TV-050–TV-061
restano pianificate finché non esistono codice, fixture ed evidenze specifiche.
La CI remota non costituisce evidenza positiva finché GS-WVR-002 non è chiusa con
entrambi i workflow verdi.

## Esito

**Superato localmente per struttura e coerenza.** Le verifiche implementative
TV-050–TV-061 restano aperte secondo i limiti dichiarati.
