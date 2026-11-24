<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0029 — Codifica qualitativa nelle app (estensione post-0.1)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0029 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-19 |
| Data decisione | 2026-09-19 |
| Approvazione | Estensione documentata scelta esplicitamente dall'iniziatore |
| Integra | ADR-0025, ADR-0027, GS-PROD-001, GS-UX-001-16 |
| Sostituisce | Nessuno |

## Contesto

GS-PROD-001 dichiara fuori dal prodotto 0.1 la content analysis multi-codificatore. ADR-0027 ha
introdotto la storia qualitativa persistita, raggiungibile da GlifiKit e CLI (GS-VER-126,
GS-VER-127), e prevede l'interfaccia di codifica in un incremento successivo.

## Decisione

1. La codifica qualitativa entra nelle app macOS e iPadOS come parte dell'incremento post-0.1
   aperto da ADR-0025; la baseline 0.1 non cambia e la release 0.1 può essere distribuita senza di
   essa.
2. L'interfaccia segue la nuova specifica GS-UX-001-16, scritta prima del codice.
3. Le app usano soltanto le operazioni di GlifiKit già verificate; nessuna logica di dominio vive
   nell'interfaccia.

## Conseguenze

- Nuova sezione di navigazione per la codifica, stringhe localizzate e verifica di accessibilità;
  la validazione su dispositivo resta nel gate G4.
- La tracciabilità registra l'estensione in DA-034.
