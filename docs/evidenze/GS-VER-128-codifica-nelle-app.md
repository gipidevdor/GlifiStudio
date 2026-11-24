<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-128 — Codifica qualitativa nelle app macOS e iPadOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-128 |
| Tipo | Evidenza di integrazione UI |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | GS-DOR-008 (ADR-0029) |

## Ambito

Sezione «Codifica» delle app secondo GS-UX-001-16, costruita solo su operazioni GlifiKit:

- **Codebook**: categorie correnti e revisione; nuove categorie con etichetta e definizione, la
  cui identità stabile deriva dall'etichetta (`GlifiStudioCodebookCategory.identifier(forLabel:)`);
  registrazione della revisione successiva completa;
- **Codifica**: scelta della fonte, frasi del testo estratto come selezione strutturata
  (`textSegments(sourceRevisionID:)`, alternativa accessibile al trascinamento), categoria e
  codificatore pseudonimo;
- **Revisione**: codifiche attive e ritirate, ritiro con motivo da elenco chiuso, note sulle
  codifiche;
- **Accordo**: scelta dei codificatori; unità confrontate, unità ambigue escluse con spiegazione,
  alfa di Krippendorff e kappa di Cohen;
- storia cambiata nel frattempo: lo stato viene ricaricato e la failure localizzata chiede di
  ripetere.

## Procedura e risultato

1. `textSegmentsAreCodableSentences`: le frasi di una fonte Markdown sono ordinate e ognuna è
   accettata come intervallo di codifica;
2. `categoryIdentifierFromLabel`: identità ASCII stabili da etichette con accenti, punteggiatura,
   solo emoji e oltre 64 caratteri;
3. build Xcode macOS e iPadOS verdi dentro `make verify`; 40 nuove stringhe in italiano e inglese
   nel catalogo, controllato da `check-localization.py`.

## Limiti

Nessuna selezione libera di passaggi più piccoli o più grandi di una frase; audit VoiceOver,
tastiera e Dynamic Type su dispositivo nel gate G4 (GS-UX-001-15); nessuna validazione con utenti.

## Esito

**Superato localmente: la codifica qualitativa è raggiungibile dalle app con le stesse garanzie di
GlifiKit.**
