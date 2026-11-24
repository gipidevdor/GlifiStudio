<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-129 — Selezione libera del passaggio da codificare

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-129 |
| Tipo | Evidenza di integrazione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | GS-DOR-009 (GS-UX-001-16 § Accessibilità, ADR-0029) |

## Ambito

Il passaggio da codificare non coincide più necessariamente con una frase. Una selezione
strutturata, espressa senza trascinamento, viene risolta in un intervallo del testo estratto:

- **Motore**: `GlifiPassageSelection` ha tre forme — `sentences(first:last:)` per uno o più
  periodi consecutivi, `characters(start:end:)` per un intervallo di caratteri (cluster di grafemi
  estesi) e `bytes(start:end:)` per l'intervallo UTF-8 che una codifica registra;
  `passages(sourceRevisionID:selections:in:)` legge il testo estratto una sola volta e risolve
  l'elenco, `passage(...)` è il caso singolo. Ogni passaggio risolto inizia e finisce su un confine
  di carattere — lo stesso vincolo che `appendQualitativeEvent` impone a una codifica — e contiene
  almeno un carattere visibile; altrimenti la chiamata fallisce con `qualitative.invalid-selection`
  (`invalidInput`, `unchanged`). La forma multipla fallisce per intero: nessuna lista parziale.
- **GlifiKit**: `passage`, `passages` ed `extractedCharacterCount` con il mirror
  `GlifiStudioPassageSelection`; nessun tipo di GlifiCore esposto.
- **CLI**: `glifi qualitative segments --source <id>` elenca le frasi con i loro intervalli e
  `glifi qualitative passage --source <id> --sentences|--characters|--bytes <a>-<b>` risolve la
  selezione, con envelope JSON v1.
- **App**: la sezione «Codifica» sceglie la modalità («Per frasi» o «Per caratteri»), mostra il
  passaggio risolto prima di registrarlo e risolve il testo di ogni codifica già registrata sulla
  fonte caricata, anche quando non coincide con una frase.

## Procedura e risultato

1. `passageSelectionResolvesFreeFormIntervals`: su un testo con accenti e una sequenza emoji
   composta, un passaggio copre due frasi consecutive (estremi uguali a quelli dei segmenti), uno
   è più piccolo di una frase (`caratteri 3–15` = «mare è calmo»), uno coincide con la sola
   sequenza `👨‍👩‍👧`, che resta indivisa e vale un carattere e undici byte; i tre passaggi sono
   accettati come intervalli di codifica; sei selezioni non valide — invertita, oltre l'ultima
   frase, negativa, vuota, oltre la fine del testo e su un solo spazio — sono rifiutate con
   `qualitative.invalid-selection`;
2. contract test CLI in `verify.sh`: i segmenti sono ordinati e non vuoti; la selezione per frase
   `0-0` e quella per byte sugli estremi del primo segmento descrivono lo stesso passaggio; un
   intervallo vuoto è rifiutato con `qualitative.invalid-selection` e `retainedState = unchanged`;
3. build Xcode macOS e iPadOS verdi dentro `make verify`; 13 nuove stringhe in italiano e inglese
   nel catalogo, controllato da `check-localization.py`.

## Limiti

La selezione per caratteri si esprime con due campi numerici: è accessibile e priva di
trascinamento, ma non è ancora una selezione diretta sul testo con il puntatore. Gli audit
VoiceOver, tastiera e Dynamic Type su dispositivo restano nel gate G4 (GS-UX-001-15); nessuna
validazione con utenti.

## Esito

**Superato localmente: il passaggio da codificare può essere più piccolo o più grande di una frase,
con gli stessi vincoli di allineamento che la storia qualitativa impone alle codifiche.**
