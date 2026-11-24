<!-- SPDX-License-Identifier: BSD-3-Clause -->

## Risultato

Descrivi cosa cambia e perché.

## Definition of Ready

- Stato DoR: `Ready` / `Ready con rischio accettato` / `Non ready`
- Scheda in `docs/pianificazione/`, oppure motivo per cui non si applica
- Rischi accettati: responsabile, scadenza e rollback, se presenti

## Tracciabilità

- Issue:
- Requisiti o criteri di accettazione:
- ADR o decisioni aperte:
- Clausole CMP aggiornate:

## Verifica

- [ ] `make verify` supera tutti i controlli.
- [ ] Se `make verify` non è eseguibile, `make quality-static` supera i controlli statici.
- [ ] `make verify-app-store` supera il preflight per modifiche ad app, packaging, privacy, metadati o distribuzione.
- [ ] Ho riesaminato `make app-store-submission-check` e gli esiti reali dei gate esterni, se pertinente.
- [ ] I test pertinenti sono aggiunti o aggiornati.
- [ ] Ho eseguito benchmark se cambiano un percorso critico o l'uso delle risorse.
- [ ] Ho verificato migrazione e compatibilità per modifiche ai formati persistenti.

## Impatto

- [ ] Architettura e dipendenze rispettano gli ADR.
- [ ] Sicurezza, privacy, logging ed eventuali entitlement sono stati valutati.
- [ ] Non sono presenti segreti, dati personali, corpus reali o materiale non autorizzato.
- [ ] Ho verificato interfaccia, accessibilità, italiano iniziale e internazionalizzazione.
- [ ] Documentazione, tracciabilità e registro modifiche sono aggiornati.

## Rischio e recupero

Indica rischi residui, segnali da osservare, rollback e deroghe. Per modifiche
senza effetti operativi, scrivi `Non applicabile` e spiega perché.
