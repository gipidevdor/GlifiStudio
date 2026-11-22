<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0024 — Barra di eccellenza ingegneristica di classe Apple

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0024 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-18 |
| Data decisione | 2026-09-18 |
| Approvazione | Rafforzamento della qualità senza indebolire i gate esistenti |
| Integra | ADR-0006, ADR-0015, ADR-0017, ADR-0019, ADR-0020 |
| Sostituisce | Nessuno |

## Contesto

Lo standard GS-STD-001 e i profili GS-APL coprono già linguaggio, concorrenza,
sicurezza, accessibilità, test, prestazioni, osservabilità e rilascio. Restano
lacune misurabili rispetto al livello di mestiere atteso da un'app Apple di prima
qualità: nessun test plan con sanitizer, nessun audit di accessibilità
automatizzato, nessuna metrica XCTest di avvio/hitch/hang, nessun catalogo DocC né
analisi delle rotture di API, nessuna soglia quantitativa di piattaforma, nessuna
politica su typed throws, memory safety rigorosa, tipi non copiabili, Data
Protection, Enhanced Security, Voice Control e rilascio a fasi.

Introdurre subito tutti questi controlli come gate romperebbe `make verify` sulla
baseline corrente; lasciarli impliciti li renderebbe non verificabili.

## Decisione

1. Si adotta il capitolo [GS-STD-001-29](../standard/29-eccellenza-ingegneristica-apple.md)
   come barra normativa di eccellenza ingegneristica di classe Apple.
2. Il capitolo non duplica i capitoli esistenti: ne indicizza la copertura e aggiunge
   soltanto i criteri `EA-*` mancanti, con verifica e stato di adozione dichiarati.
3. Le soglie quantitative del capitolo sono iniziali e vanno confermate su hardware
   di riferimento in G4; una soglia confermata non si peggiora senza deroga.
4. Nessun criterio diventa gate finché non esistono codice conforme e un controllo
   che lo verifichi; fino ad allora è "Da introdurre" e non può essere presentato
   come verificato.
5. Il capitolo prevale, in caso di sovrapposizione, soltanto quando è più
   restrittivo; non indebolisce alcuna clausola vigente.
6. La Definition of Done e lo stato di adozione richiamano il capitolo.

## Alternative considerate

- Distribuire le nuove clausole nei singoli capitoli: respinta perché disperde la
  barra complessiva e rende difficile vedere cosa manca.
- Adottare una checklist esterna o una certificazione: respinta perché non è
  specifica di Swift, Xcode e delle piattaforme Apple e non è verificabile dal
  repository.
- Introdurre subito i gate automatici: respinta perché farebbe fallire la baseline
  e spingerebbe a indebolire i controlli.
- Non fare nulla: respinta perché lascia implicite e non misurabili le lacune.

## Conseguenze

- ogni nuova funzione è misurata su una barra unica, con evidenza per criterio;
- le lacune (test plan, audit di accessibilità, metriche XCTest, DocC, diff API)
  diventano lavoro pianificato per fase, non intenzioni;
- gli agenti e le persone non possono dichiarare conformi criteri privi di
  evidenza;
- l'onere di manutenzione cresce: ogni criterio attuato aggiorna capitolo 28 e
  tracciabilità nello stesso cambiamento.

## Verifica

`make check-docs` e `make check-compliance` devono continuare a passare. L'adozione
di ciascun criterio è registrata come evidenza in `docs/evidenze` quando attuato.

## Riferimenti

- [GS-STD-001-29](../standard/29-eccellenza-ingegneristica-apple.md)
- [GS-STD-001-25](../standard/25-definition-of-done.md)
- [GS-STD-001-28](../standard/28-stato-di-adozione.md)
- [ADR-0020](0020-loop-di-qualita-e-dialetto-swift.md)
