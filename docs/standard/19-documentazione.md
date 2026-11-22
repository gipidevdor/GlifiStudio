# 19. Documentazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-19 |
| Tipo | Capitolo normativo |
| Versione | 0.4.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 19.1 Information item

La documentazione **DEVE** rispettare [GS-DMP-001](../piano-documentazione.md). Ogni documento controllato deve avere identificatore, versione, stato, responsabile, data e approvazione.

## 19.2 Markdown

- I file **DEVONO** usare UTF-8 e Markdown leggibile senza renderer proprietario.
- Titoli, tabelle, elenchi e blocchi di codice **DEVONO** essere sintatticamente validi.
- Collegamenti relativi **DEVONO** risolversi nel repository.
- Diagrammi testuali **DEVONO** avere una descrizione comprensibile anche senza resa grafica.
- Contenuti generati **DEVONO** dichiarare origine e modalità di rigenerazione.

## 19.3 Specifiche scientifiche

I metodi **DEVONO** rispettare GS-MET-001 e avere un argomento autonomo per
documento. Formula, variante, casi nulli, smoothing, logaritmi, determinismo e
tolleranze **NON DEVONO** essere lasciati a convenzioni implicite o alla sola
citazione bibliografica.

## 19.4 Specifiche dell'esperienza

La UX **DEVE** rispettare GS-UX-001 e mantenere separati modello mentale, dominio,
presentazione Apple e semantica GS-MET. Tassonomie, stati, journey e microcopy
devono essere versionabili e verificabili; mockup e screenshot non costituiscono da
soli specifica o validazione.

## 19.5 Specifiche di design implementativo

La famiglia GS-DSG **DEVE** mantenere esattamente i dieci concern autorizzati dal
suo indice finché un ADR non ne modifica il perimetro. Ogni documento dichiara un
solo argomento, confine, invarianti, stati o flussi, errori e criteri di conformità;
non duplica requisiti, formule GS-MET o modello mentale GS-UX.

## 19.6 Documentazione API

Le API pubbliche **DEVONO** essere documentate con DocC. La documentazione deve descrivere contratto, parametri, risultato, errori, precondizioni, effetti collaterali, thread-safety e complessità quando non ovvi.

## 19.7 Aggiornamento con il codice

Una modifica **NON È** completa se rende inesatti requisiti, architettura, ADR, esempi, guide o note di migrazione. Codice e documentazione applicabile **DEVONO** essere aggiornati nella stessa unità di cambiamento.
