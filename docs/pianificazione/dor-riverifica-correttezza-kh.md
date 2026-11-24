<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Riverifica di correttezza e completezza KH

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-234 |
| Tipo | Scheda di riverifica del lotto GS-DOR-233 |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di riverificare tutto con correttezza e completezza estreme |
| Riferimenti | GS-DOR-233; RF-087; RQ-025; RQ-058; RQ-060; RQ-063; GS-MET-001-23; GS-API-002; GS-VER-234 |

## Ambito e registrazione

Riverifica indipendente e correzione delle regressioni del lotto autorizzato
GS-DOR-233, sulla revisione pubblicata `c6fd88e`. La scheda aggiuntiva consolida
il programma dopo il primo giro di audit/RED, senza inventare una registrazione
preventiva. Non introduce un nuovo algoritmo KH, formato persistente, dipendenza
o integrazione GUI. Le varianti ancora assenti sono dichiarate, non simulate.

## Criteri di uscita

- Controesempi numerici, Unicode, grammatica e risorse verificabili, con regressioni
  discriminanti e controlli su input ordinari, estremi e già cancellati.
- Politica GN binary64 v2 e ammissione cumulativa documentate; nessun epsilon
  arbitrario per fondere cammini distinti, nessun valore non finito pubblicato.
- Copertura KH separata fra operatori disponibili, composizioni e varianti assenti;
  correzione dell’asserzione errata sulla matrice parola-contesto.
- Suite Debug/Release, controlli sanitizzati pertinenti e `make verify` sul contenuto
  finale, con inventario/digest ed esiti effettivi in GS-VER-234.
- Conservazione delle prove e rimozione delle scratch del lotto; lavoro GUI,
  toolchain, dipendenze e worktree concorrenti preservati.

La verifica tecnica non è una promozione scientifica V6 e non dimostra la qualità
linguistica su corpora reali o la parità con un’edizione chiusa di KH.

## Scheda Definition of Ready

| Voce | Contratto della riverifica |
| --- | --- |
| outcome e confini | Regressioni corrette in Core/Kit/CLI e copertura KH esplicita; esclusi GUI, nuove varianti KH e nuovi formati |
| failure semantics | Input non validi, overflow e budget falliscono con errori di dominio; nessun risultato parziale o zero numerico plausibile fuori dominio; cancellazione propagata |
| tracciabilità | RF-087 e requisiti di correttezza/risorse, GS-MET-001-23 e GS-API-002; esiti RED/finali in GS-VER-234, senza alterare i risultati storici GS-VER-233 |

**Ready** per completare la verifica delle correzioni nel perimetro autorizzato.
