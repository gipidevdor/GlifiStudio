<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Paradigma e intenzioni analitiche

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-01 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da validare con utenti |
| Documento padre | [GS-UX-001](README.md) |

## Modello mentale

Glifi Studio è un ambiente di esplorazione guidata di documenti e corpus. La persona
formula una domanda, seleziona ciò che studia, osserva risultati comprensibili e può
verificarli fino alle fonti e al metodo. L'esperienza **NON DEVE** presupporre la
conoscenza di TF-IDF, BM25, PMI, logDice, test statistici o tecniche multivariate.

L'algoritmo è subordinato all'intenzione. Le varianti scientifiche restano
selezionabili e ispezionabili per il lavoro specialistico, ma **NON DEVONO** formare
da sole la navigazione primaria o il vocabolario obbligatorio per iniziare.

## Tassonomia canonica delle intenzioni

Un'`AnalyticalIntent` è un concetto localizzabile e versionato. Il suo identificatore
non coincide con la frase mostrata nell'interfaccia.

| ID stabile | Domanda concettuale | Oggetti compatibili |
| --- | --- | --- |
| `understand.collection` | Che cosa sto studiando? | progetto, corpus, selezione |
| `discover.contents` | Che cosa contiene la raccolta? | corpus, selezione |
| `identify.themes` | Quali temi emergono? | corpus, gruppo, periodo |
| `characterize.group` | Che cosa caratterizza questo insieme? | gruppo, autore, categoria, periodo |
| `compare.objects` | In che cosa differiscono o si somigliano? | corpus, gruppi, autori, categorie, periodi |
| `trace.change` | Come cambia il linguaggio nel tempo? | concetto, corpus, gruppi temporali |
| `explore.relationships` | Quali concetti sono collegati? | termine, concetto, corpus |
| `find.similar` | Quali elementi sono simili? | documento, segmento, corpus |
| `explore.object` | Che cosa sappiamo di questo oggetto? | termine, concetto, autore, categoria, periodo, documento |
| `search.sources` | Dove compare ciò che cerco? | progetto, corpus, documento |
| `review.completely` | Qual è la panoramica più completa applicabile? | corpus, selezione, indagine |

La tassonomia **DEVE** poter essere estesa senza modificare i dati scientifici già
persistiti. Ogni intenzione dichiara almeno versione, tipi di oggetto, slot
richiesti, famiglie analitiche candidate, dimensioni del profilo necessarie,
possibili approfondimenti e chiavi di localizzazione.

## Primo avvio e avvio di un'indagine

La domanda guida è «Che cosa vuoi studiare?». Il sistema **DEVE** permettere di:

1. creare o aprire un progetto;
2. aggiungere fonti con controlli di sistema;
3. comprendere progressivamente che cosa contiene la raccolta;
4. conservare una domanda oppure scegliere un'intenzione;
5. ottenere un piano spiegabile e risultati applicabili.

La configurazione del motore, la matrice o il test statistico **NON DEVONO** essere
prerequisiti del primo percorso. Opzioni metodologiche avanzate restano disponibili
nel contesto del piano, dell'evidenza o del metodo che influenzano.

## Criteri di coerenza

- Due formulazioni localizzate della stessa intenzione mantengono lo stesso ID.
- Una nuova variante algoritmica non crea automaticamente una nuova intenzione.
- Un'intenzione non garantisce un risultato: il planner può dichiararla non
  soddisfacibile con i dati correnti.
- L'accesso diretto a un metodo per utenti esperti produce comunque un piano,
  descrittori, evidenze e caveat conformi alla stessa esperienza.
- “Analizza tutto” significa tutto ciò che è applicabile e utile, non ogni algoritmo
  installato.
