<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-122 — SpanMap componibili con classe contributive

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-122 |
| Tipo | Evidenza di lineage |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task L1 di GS-DOR-005 |

## Ambito

RF-078 richiede SpanMap componibili con classi exact, contributive, synthetic e derivational
(GS-DAT-001):

- `GlifiSpanMappingKind.contributive`, valido solo con almeno due intervalli di input;
- spazio `normalizedUTF8` e spazi di ingresso e uscita dichiarati nel costruttore;
- `GlifiSpanMap.composed(after:)`: composizione `C→B ∘ B→A` con controllo di spazi, lunghezze e
  revisione (`text.incompatible-span-maps` altrimenti) e regole di classe di GS-DOR-005.

## Procedura e risultato

1. `spanMapCompositionPreservesEveryOrigin`: 500 coppie di trasformazioni casuali a seed fisso,
   costruite byte per byte con segmenti exact, synthetic, derivational e contributive:
   - la mappa composta supera la validazione strutturale e dichiara `sourceBytes → normalizedUTF8`;
   - per ogni segmento l'insieme dei byte d'origine coincide esattamente con quello raggiungibile
     risolvendo le due mappe in sequenza: nessuna origine persa né aggiunta;
   - ogni segmento composto `exact` riproduce byte per byte la fonte;
   - synthetic resta synthetic e derivational non diventa mai exact;
   - ogni classe composta compare più di 20 volte;
2. `spanMapCompositionRejectsIncompatibleMaps`: spazi non collegabili e contributive con un solo
   intervallo sono rifiutati.

## Limiti

La pipeline di importazione produce ancora un solo passo (`sourceBytes → extractedUTF8`); la
composizione è pronta per normalizzazione e trasformazioni future, che dovranno dichiarare il
proprio SpanMap. Il fuzz di GS-VER-120 resta valido: il nuovo caso dell'enum è additivo.

## Esito

**Superato localmente: RF-078 ha SpanMap componibili che conservano tutte le origini.**
