<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Analysis Planner e applicabilità metodologica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-04 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Principio approvato; policy MVP da decidere |
| Documento padre | [GS-UX-001](README.md) |

## Responsabilità

L'Analysis Planner trasforma intenzione, oggetti selezionati, profilo della
raccolta, capacità disponibili e policy approvate in un `AnalysisPlan` tipizzato e
riproducibile. Decide **che cosa** sia metodologicamente applicabile; l'Analysis DAG
decide le dipendenze effettive necessarie a eseguirlo.

```text
Question + AnalyticalIntent + CollectionProfile + CapabilitySnapshot + Policy
                              ↓
              AnalysisPlan + rationale + esclusioni
                              ↓
                         AnalysisDAG
```

## Dichiarazione di capacità analitica

Ogni famiglia o variante candidata **DEVE** dichiarare:

- oggetti e intenzioni che può sostenere;
- dati, unità, metadati e rappresentazioni richiesti;
- precondizioni matematiche e statistiche definite in GS-MET;
- qualità minima dell'input e assunzioni verificabili;
- dimensione minima/massima applicabile e casi degeneri;
- costo stimabile di CPU, memoria, I/O, energia e tempo;
- dipendenze del DAG, backend e fallback disponibili;
- prodotti informativi, limiti interpretativi e possibili approfondimenti;
- versione della regola di applicabilità.

## Stati di applicabilità

| Stato | Conseguenza |
| --- | --- |
| `applicable` | precondizioni soddisfatte; il nodo può entrare nel piano |
| `conditional` | eseguibile con caveat o decisione esplicita documentata |
| `notApplicable` | precondizione metodologica non soddisfatta; non eseguibile |
| `unavailable` | metodo applicabile, ma capacità o backend approvato assente |
| `deferred` | applicabile ma rinviato da costo, priorità o budget esplicito |

`notApplicable` e `unavailable` **NON DEVONO** essere confusi. Una persona esperta
può modificare parametri o selezioni e chiedere una nuova pianificazione, ma non può
forzare il sistema a dichiarare valido un metodo con precondizioni violate.

## Procedura di pianificazione

Il planner **DEVE**, in ordine:

1. risolvere oggetti, ambito e intenzioni;
2. derivare le famiglie candidate dalla tassonomia, non dalla disponibilità casuale;
3. valutare precondizioni e qualità sul profilo versionato;
4. eliminare duplicazioni informative secondo una policy esplicita;
5. stimare costo e scegliere strategie streaming, sparse o a blocchi;
6. risolvere varianti e parametri in descrittori completi;
7. costruire e validare il sottografo necessario;
8. registrare inclusioni, esclusioni, caveat, fallback e motivazioni.

Una pianificazione `review.completely` include tutte le famiglie applicabili,
informativamente non ridondanti e sostenibili entro la policy di risorse. Non
esegue una tecnica soltanto perché implementata.

## Spiegabilità e controllo

L'utente deve poter chiedere:

- che cosa verrà o è stato analizzato;
- perché una famiglia è inclusa, esclusa o rinviata;
- quali dati o metadati mancano;
- quale variante, costo e fallback sono stati risolti;
- quale modifica renderebbe applicabile un approfondimento.

La vista ordinaria usa linguaggio comprensibile; il dettaglio espone identificatori
GS-MET, precondizioni e descriptor. Ogni modifica manuale del piano crea una nuova
revisione e resta nella cronologia dell'indagine.

## Determinismo e verifica

A parità di input canonici, capability snapshot e policy, il planner **DEVE**
produrre lo stesso piano ordinato. Tie-break e stime di costo sono versionati. Test
di decision table coprono presenza/assenza di date, gruppi, testo affidabile,
dimensione sufficiente, memoria limitata, backend indisponibile e assunzioni violate.

## Slice implementata

`planner-mvp-v1` valuta profilo corpus e keyness per tutti gli intenti stabili.
Produce `applicable`, `conditional`, `notApplicable` o `deferred`, risolve lo scope,
espande i due profili di popolazione richiesti da keyness, ordina gli step e
registra ragioni, caveat, backend e assenza di fallback. Il budget usa modelli
versionati basati su byte e overhead per fonte, soltanto interi e rifiuto
dell'overflow e non ammette selezioni oltre i limiti dell'esecutore. Piano e
rationale sono Artifact versionati riusabili; la slice profilo/keyness è eseguita
con admission runtime, progresso e cancellazione condivisi da Core, Kit e CLI.
Restano aperti capability assenti, profilo qualitativo completo, override esperti,
UI e progresso intra-nodo.
