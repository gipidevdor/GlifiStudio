<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Profilo della raccolta e preparazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-03 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da validare con corpus e utenti |
| Documento padre | [GS-UX-001](README.md) |

## CollectionProfile concettuale

Il profilo della raccolta è un artefatto versionato che caratterizza i dati
disponibili prima della pianificazione. Non è soltanto una dashboard: è un input
obbligatorio dell'Analysis Planner.

| Dimensione | Contenuto minimo |
| --- | --- |
| Consistenza | documenti, segmenti, token stimati/confermati, byte e distribuzioni dimensionali |
| Formati | tipi, versioni, leggibilità, testo digitale, immagini e necessità di OCR |
| Lingue | lingue rilevate, copertura, incertezza e scelte esplicite |
| Estrazione | copertura, errori, confidence applicabile, pagine o regioni problematiche |
| Tempo | campi disponibili, precisione, intervallo coperto, mancanti e distribuzione |
| Metadati | schema tipizzato, copertura, cardinalità, categorie, autori e valori mancanti |
| Duplicazioni | duplicati esatti, candidati quasi duplicati, criterio e stato della decisione |
| Linguistica | annotazioni disponibili, backend, versione, lingua e qualità validata |
| Rappresentatività | sbilanciamenti osservabili, insufficienze e limiti noti del campionamento |

Ogni proprietà **DEVE** distinguere dato osservato, quantità derivata, stima e valore
non disponibile. Il profilo conserva fonti, versione, tempo di calcolo, regole,
esclusioni e qualità per dimensione; **NON DEVE** sintetizzarle in un punteggio
universale privo di significato scientifico.

## Preparazione progressiva

L'importazione viene presentata come preparazione del materiale. L'esperienza
**DEVE** comunicare progressivamente ciò che è già utilizzabile e ciò che richiede
attenzione, senza attendere una pipeline completa per mostrare ogni informazione.

Stati minimi:

| Stato | Significato per la persona |
| --- | --- |
| `preparing` | il materiale viene letto e caratterizzato; sono disponibili progressi reali |
| `partiallyReady` | una parte identificata è esplorabile, mentre altro lavoro continua |
| `ready` | il profilo richiesto per il piano corrente è valido |
| `needsAttention` | una decisione o un problema limita alcune analisi |
| `cancelled` | il lavoro si è fermato senza dichiarare completi artefatti parziali |
| `failed` | la conseguenza e le azioni di recupero sono note; la causa tecnica resta ispezionabile |

Quando applicabile, la UI mostra numero di documenti, quantità di testo, lingue,
periodi, autori, categorie, duplicati e problemi di leggibilità. “OCR con confidence
bassa” può essere presentato inizialmente come materiale poco leggibile, ma
confidence, backend, lingua, coordinate e metriche **DEVONO** restare accessibili.

## Decisioni e qualità

- Una fonte non supportata o corrotta non rende implicitamente valido il resto.
- Correzioni manuali di lingua, metadati o duplicati producono eventi tracciati.
- La rilevazione automatica non sovrascrive una scelta esplicita senza conferma.
- Il sistema **DEVE** indicare come un'insufficienza cambia il piano: analisi
  escluse, degradate o da interpretare con cautela.
- Il profilo può aggiornarsi incrementalmente; ogni piano conserva la versione
  effettivamente usata.

## Lineage e verifica

Ogni aggregato del profilo deve raggiungere i documenti o la procedura che lo ha
generato. I test coprono importazioni parziali, cancellazione, errori misti,
duplicati, lingue multiple, metadati mancanti, OCR insufficiente e aggiornamento
selettivo dopo una modifica.

## Slice implementata

`collection-planning-profile-v1` espone prima dell'esecuzione revisioni, byte,
formati e lingua configurata come metadati osservati, con radice delle fonti e
ordine canonico. È persistito dentro `analysis-plan.v1`. Token, qualità
linguistica, tempo, metadati tipizzati, duplicazioni, OCR e rappresentatività
restano non disponibili e non vengono simulati con valori zero.
