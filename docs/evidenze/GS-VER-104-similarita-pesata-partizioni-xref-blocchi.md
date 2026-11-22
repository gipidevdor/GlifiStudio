<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-104 — Similarità pesata e smoothing dichiarato, partizioni dichiarate, validazione xref e bootstrap a blocchi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-104 |
| Tipo | Evidenza di verifica, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-029, TV-031, TV-032, TV-054, TV-056, TV-073 e RQ-061 |

## Ambito

Supera i limiti di GS-VER-085 (altre partizioni), GS-VER-086 (smoothing come trasformazione
separata, varianti pesate o multinsieme, disuguaglianza triangolare solo su una terna),
GS-VER-093 (nessuna validazione strutturale del PDF) e GS-VER-097 (nessun bootstrap per dati
dipendenti):

- `WeightedJaccard-v1` (Ruzicka, `Σmin/Σmax`), `MultisetDice-v1` (`2Σmin/(Σx+Σy)`) e smoothing
  `Lidstone-v1` come trasformazione esplicita; `corpus-term-similarity-v3` aggiunge Jaccard pesato
  sulle frequenze relative, Dice multinsieme sui conteggi e KL simmetriche dopo Lidstone `α = ½`
  (sempre definite, accanto alla KL non levigata che resta `nil` quando indefinita);
- `corpus-term-dispersion-v2`: partizione dichiarata (`declared-partition-v1`) come gruppi di
  documenti che coprono il corpus esattamente una volta, con dimensioni e frequenze sommate per
  parte; la partizione per documento resta il default; parità GlifiKit e flag CLI
  `dispersion --part …` ripetibile;
- validazione strutturale della xref dopo il rendering PDF: `startxref` deve puntare a `xref` e
  ogni voce in uso all'intestazione `k 0 obj`; un PDF incoerente non viene esportato
  (`export.pdf-invalid-xref`);
- `MovingBlockBootstrap-v1`: blocchi di `L` osservazioni consecutive con inizio uniforme, per
  sequenze dipendenti.

## Procedura e risultato

1. valori a mano: Ruzicka `1/5`, Dice multinsieme `1/3`, Lidstone `(c+½)/(N+3/2)` e KL in bit sulle
   distribuzioni levigate; input nulli o `α ≤ 0` rifiutati; la similarità v3 sul corpus di
   riferimento riproduce gli stessi valori;
2. disuguaglianza triangolare verificata su tutte le 220 terne di 12 distribuzioni con zeri
   generate da `SplitMix64` (seed 17) per Euclidea, Manhattan, Hellinger e JS-distanza (880 terne,
   ciascuna nelle tre permutazioni);
3. partizione dichiarata `{d1,d2}`/`{d3}`: dimensioni `[4,3]` e `GriesDP` di «casa» identico alla
   primitiva di GS-VER-085 sulle parti sommate; frequenza documentale sempre per documento;
   partizioni incomplete o con una sola parte rifiutate;
4. validatore xref: accetta un documento con offset corretti e rifiuta lo stesso documento con un
   offset spostato di un byte (il difetto di GS-VER-093); ogni export PDF dei test esistenti lo
   supera;
5. bootstrap a blocchi con `L = 1` identico, a parità di seed, al bootstrap i.i.d.; `L = 3` con
   intervallo che contiene la stima; `L > n` rifiutato;
6. `Scripts/verify.sh` verifica partizione per documento e campi della similarità v3; gate
   completo `make verify`.

## Limiti

Il validatore PDF controlla la struttura della xref, non la conformità PDF/A completa (per cui
servirebbe un validatore esterno come veraPDF, non disponibile nell'ambiente). Il bootstrap a
blocchi è una primitiva GlifiCore: nel modello attuale le unità analitiche persistite (documenti)
sono indipendenti e nessuna operazione espone ancora sequenze dipendenti.

## Esito

**Superato localmente per similarità pesate e smoothing dichiarato, partizioni di dispersione
dichiarate, validazione della xref e bootstrap a blocchi, con parità GlifiCore/Kit/CLI dove
persistiti.**
