# 21. Rilascio e distribuzione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-21 |
| Tipo | Capitolo normativo |
| Versione | 0.4.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 21.1 Versione

Il prodotto usa versionamento semantico quando esiste un contratto pubblico stabile. Prima di `1.0.0`, ogni modifica incompatibile **DEVE** essere dichiarata nelle note di rilascio.

Versioni del prodotto, del formato progetto, degli indici e delle API **NON DEVONO** essere confuse: ciascun contratto ha il proprio identificatore.

## 21.2 Candidato di rilascio

Ogni candidato **DEVE** essere costruito da una revisione identificabile e produrre:

- artefatto riproducibile per quanto tecnicamente possibile;
- risultati dei test e dei benchmark richiesti;
- inventario di dipendenze e licenze;
- note di rilascio e incompatibilità;
- istruzioni di migrazione e rollback;
- firma e notarizzazione quando applicabili.

## 21.3 Approvazione

Un rilascio **NON DEVE** essere pubblicato con requisiti `Must` non verificati, vulnerabilità non valutate, migrazioni non provate o dati di test non autorizzati.

Per 0.1, Must, Should, esclusioni e gate G1–G5 sono governati da GS-PROD-001.
Catalogo GS-MET e specifiche di design non costituiscono da soli funzioni
pubblicabili. Una capacità post-MVP **NON DEVE** apparire stabile nel binario,
metadati, screenshot o API.

## 21.4 Separazione e protezione

Verifica non firmata, creazione dell'artefatto, firma/notarizzazione e pubblicazione **DEVONO** essere fasi distinguibili. Gli ambienti di firma **DEVONO** richiedere approvazione, applicare minimo privilegio e impedire accesso da pull request.

Il materiale di firma **NON DEVE** essere conservato nel repository. Ogni credenziale **DEVE** avere titolare, scopo, scadenza o riesame, rotazione e procedura di revoca. Gli artefatti trasferiti fra fasi **DEVONO** essere identificati mediante hash o attestazione equivalente.

La distribuzione App Store non in elenco è stabilita da ADR-0011. Finché DA-018
non assegna team, certificati e profili, workflow di firma o pubblicazione e segreti
Apple **NON DEVONO** essere attivati. La build senza firma costituisce evidenza di
compilazione e packaging, non candidato distribuibile.

## 21.5 App Store non in elenco

Il prodotto **DEVE** superare la normale App Review prima che la distribuzione non
in elenco possa essere richiesta. La richiesta **NON DEVE** essere usata per beta o
prerelease. Il link diretto **NON DEVE** essere considerato un controllo degli
accessi. Metadati, screenshot, privacy, accessibilità, informazioni di revisione e
supporto **DEVONO** riferirsi alla stessa build candidata.

## 21.6 Provenienza e recupero

Ogni rilascio **DEVE** essere riconducibile a commit, toolchain, dipendenze risolte, configurazione e approvazioni. Il rollback **DEVE** considerare compatibilità dei dati e migrazioni, non soltanto la sostituzione del binario.
