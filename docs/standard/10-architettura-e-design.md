# 10. Architettura e design

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-10 |
| Tipo | Capitolo normativo |
| Versione | 0.6.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 10.1 Descrizione architetturale

La descrizione **DEVE** identificare entità di interesse, finalità, stakeholder, concern, viewpoint, view, model, corrispondenze, decisioni e rationale. Ogni view **DEVE** dichiarare quali concern tratta.

## 10.2 Decisioni architetturali

Un ADR è obbligatorio quando una scelta:

- modifica confini o dipendenze tra moduli;
- introduce o sostituisce persistenza, formato, protocollo o dipendenza principale;
- influenza sicurezza, privacy, compatibilità o migrazione;
- impone un vincolo difficilmente reversibile;
- sceglie un compromesso rilevante fra qualità concorrenti.

Un ADR **DEVE** riportare stato, contesto, decisione, alternative, conseguenze, decisore e collegamenti. Un ADR accettato non viene riscritto per cambiare la storia: viene sostituito da un nuovo ADR.

## 10.3 Invarianti Glifi Studio

- Glifi Studio è il prodotto interattivo; GlifiCore è il motore.
- GlifiCore **NON DEVE** importare SwiftUI, AppKit o UIKit.
- Le dipendenze tra moduli **DEVONO** essere acicliche.
- Il dominio **NON DEVE** essere modellato sulla struttura di un database specifico.
- La visualizzazione **NON DEVE** determinare il formato dei risultati analitici.
- Nessun algoritmo fondamentale **DEVE** richiedere l'intero corpus in memoria.
- L'ottimizzazione **DEVE** seguire una baseline corretta e una misura riproducibile.
- Ogni dipendenza da acceleratori o modelli di sistema **DEVE** avere rilevamento delle capacità e fallback esplicito.
- Risultati probabilistici o generativi **NON DEVONO** sostituire implicitamente fonti o risultati deterministici.
- Ogni artefatto analitico persistibile **DEVE** avere un descrittore conforme a GS-MET-001-01.
- Le dipendenze analitiche **DEVONO** formare un DAG con invalidazione transitiva selettiva.
- La semantica di un metodo **NON DEVE** dipendere dalla GUI, dallo storage o dal backend Apple scelto.
- Il primo livello dell'esperienza **NON DEVE** essere un catalogo di algoritmi.
- Project, Corpus e Investigation **DEVONO** avere identità indipendenti da scene,
  finestre e formulazioni localizzate.
- Applicabilità e findings **DEVONO** essere prodotti da planner e rule set
  verificabili fuori dalla GUI.
- Un finding **NON DEVE** essere persistito come risultato senza evidenza e caveat
  applicabili risolvibili.
- macOS e iPadOS **DEVONO** condividere semantica del dominio senza imporre layout
  identici.

## 10.4 API e confini

Le API pubbliche **DEVONO** essere minime, documentate e orientate al dominio. Tipi interni **NON DEVONO** diventare pubblici per aggirare un confine architetturale. Dipendenze verso framework e servizi sostituibili **DEVONO** attraversare contratti espliciti.

GlifiKit e GlifiCLI seguono [GS-API-001](../api/README.md). Una dichiarazione Swift
`public` non implica da sola SDK stabile, ABI, library evolution o distribuzione
separata. Lifecycle, isolation, progressi, cancellazione, failure e compatibilità
devono essere stabilizzati insieme ai contract test applicabili.

Ogni trust boundary e input non fidato segue
[GS-SEC-001](../sicurezza/README.md). Il sandbox e un framework di sistema sono
controlli di difesa in profondità, non prove di validazione o contenimento completo.

I backend Apple sono governati da [ADR-0008](../adr/0008-portafoglio-tecnologico-apple-silicon.md) e dal [profilo tecnologico Apple](../apple/README.md).

La semantica dell'interazione è governata da [GS-UX-001](../esperienza-utente/README.md)
e [ADR-0014](../adr/0014-esperienza-guidata-da-indagini.md). I suoi concetti non
impongono automaticamente nuovi target Swift; i confini si stabilizzano mediante
vertical slice e test di dipendenza.

La fondazione scientifica è governata da [GS-MET-001](../metodi-analitici/README.md)
e [ADR-0013](../adr/0013-semantica-analitica-e-analysis-dag.md). `GlifiMath` è un
confine concettuale; la sua eventuale separazione in target richiede evidenza sulle
dipendenze e non può modificare i contratti matematici.

Il design implementativo è governato da
[GS-DSG-IDX-001](../specifiche-di-design/README.md) e ADR-0016. Domain model,
package, QueryAST, DAG, runtime, route e VisualizationSpec **NON DEVONO** emergere
come convenzioni private di una singola feature. I confini di autorità della
famiglia impediscono duplicazioni con GS-MET e GS-UX.

Ogni implementazione sostanziale deve entrare nella matrice di conformità
machine-readable al gate Definition of Ready; una clausola senza codice/test/evidenza
non può essere dichiarata verificata.
