<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Checklist G4 — accessibilità e dispositivi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-15 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Checklist operativa per G4; prove su dispositivo ancora aperte |
| Documento padre | [GS-UX-001](README.md) |
| Riferimenti | GS-UX-001-13; GS-PROD-001 G4; GS-VER-037; GS-VER-046; GS-VER-049 |

## Strutturale (completato nel codice Must)

- [x] Titoli e header accessibili sulle sezioni principali
- [x] Controlli toolbar con `accessibilityLabel`
- [x] Elementi metriche/KWIC combinati per VoiceOver
- [x] Cataloghi `it`/`en` senza stringhe hardcoded di prodotto
- [x] Preview Dynamic Type e RTL presenti
- [x] Progresso percorso Must in Overview con `accessibilityValue`
- [x] Azioni `analyze-corpus` e `compare-keyness` etichettate
- [x] Salto Evidence→fonte con etichette e selezione VoiceOver

## Su dispositivo (obbligatorio per chiudere G4)

- [ ] VoiceOver macOS sul percorso Must completo
- [ ] VoiceOver iPadOS + tastiera esterna
- [ ] Dynamic Type XXL senza troncamenti critici
- [ ] Contrasto e Reduce Motion
- [ ] Pseudolocalizzazione su build Release
- [ ] Matrice dispositivi minimi (DA-001) con ResourceBudget osservato

## Note

Questa checklist non abbassa i gate: le voci dispositivo restano bloccanti per G4
e per la validazione UX reale (CMP-019).
