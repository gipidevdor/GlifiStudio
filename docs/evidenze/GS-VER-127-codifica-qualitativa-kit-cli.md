<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-127 — Codifica qualitativa e accordo dalle codifiche in GlifiKit e CLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-127 |
| Tipo | Evidenza di integrazione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task C3 e C4 di GS-DOR-007 |

## Ambito

- **Motore**: `appendQualitativeEvent` aggancia ogni cambiamento alla testa corrente; una codifica
  deve riferirsi a una revisione della generazione corrente con un intervallo del testo estratto
  che inizia e finisce su confini di carattere (`qualitative.invalid-range` altrimenti);
  `qualitativeState` proietta la storia; `assessStoredCodingAgreement` deriva la tabella dalle
  codifiche attive di una revisione del codebook e calcola l'accordo con `coding-agreement-v2`,
  persistito e riusato.
- **GlifiKit**: `appendQualitativeChange`, `qualitativeState`, `assessStoredCodingAgreement` con
  mirror codificabili in JSON (`GlifiStudioQualitativeChange`, `GlifiStudioQualitativeState`) e
  nessun tipo di GlifiCore esposto.
- **CLI**: `glifi qualitative state|append|agreement` con envelope JSON v1.
- **Correzione**: `sourceText` di GlifiKit decodificava i byte con `String(data:encoding:)`, che
  rimuove un BOM iniziale; con un BOM il testo risultava spostato di tre byte rispetto agli
  intervalli sorgente dell'evidenza. Ora usa la decodifica stretta.

## Procedura e risultato

1. `qualitativeServiceCodesAndMeasuresAgreement`: codebook, otto codifiche di due codificatori su
   quattro frasi, memo; un intervallo che taglia «è» è rifiutato; l'accordo dalle codifiche e
   quello dalla tabella esplicita equivalente producono lo stesso nodo e lo stesso Artifact;
   riapertura con stato identico;
2. `sourceTextKeepsByteOrderMarkAligned`: con un BOM il testo sorgente ha tanti byte quanti la
   fonte;
3. contract test CLI in `verify.sh`: revisione del codebook da file JSON, stato con codebook e
   testa, ripetizione della stessa revisione rifiutata con `qualitative.revision-not-consecutive`.

## Limiti

L'interfaccia di codifica nelle app è un incremento successivo (ADR-0027). L'accordo usa la variante
nominale; i livelli ordinali e a intervalli restano disponibili solo dalla tabella esplicita.

## Esito

**Superato localmente: RF-043 ha codebook, codifiche, ritrattazioni e memo persistiti con identità,
versione, codificatore e lineage, e RF-044 calcola l'accordo direttamente dalle codifiche.**
