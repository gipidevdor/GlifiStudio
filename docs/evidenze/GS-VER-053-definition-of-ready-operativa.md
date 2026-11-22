<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-053 — Definition of Ready operativa

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-053 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-STD-001-07; RQ-063; TV-076; CMP-014 |

## Ambito

Rendere operativa la Definition of Ready: scheda Ready per il percorso
produttivo 0.1, template PR obbligatorio e controllo automatico in
`check-docs.py`; promuovere CMP-014 a `implemented`.

## Controlli

1. `docs/pianificazione/dor-percorso-produttivita-0-1.md` con Stato `Ready` e
   voci GS-STD-001-07.
2. `.github/PULL_REQUEST_TEMPLATE.md` espone sezione Definition of Ready.
3. `Scripts/check-docs.py` rifiuta assenza di schede Ready o template DoR.
4. CMP-014 → `implemented`; `make quality-static` sul tip.

## Risultato

**Superato** per processo e automazione. Non sostituisce review umana del
contenuto di ogni futura scheda DoR.

## Limiti

Budget Actions: GS-WVR-004.
