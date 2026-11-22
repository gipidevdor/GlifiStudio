# 9. Ingegneria dei requisiti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-09 |
| Tipo | Capitolo normativo |
| Versione | 0.2.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 9.1 Gerarchia

La catena minima è:

```text
fonte → necessità stakeholder → requisito software
      → design/ADR → implementazione → verifica → evidenza
```

## 9.2 Qualità del requisito

Ogni requisito **DEVE**:

1. possedere un identificatore stabile;
2. esprimere una sola obbligazione principale;
3. avere soggetto e oggetto espliciti;
4. usare linguaggio normativo;
5. essere necessario, fattibile, non ambiguo e verificabile;
6. indicare fonte, rationale, priorità, stato e metodo di verifica;
7. includere un criterio di accettazione misurabile;
8. essere tracciato in entrambe le direzioni.

Parole quali “veloce”, “intuitivo”, “grande”, “appropriato” o “quando utile” **NON DEVONO** comparire in un requisito approvato senza metrica o condizione che ne elimini l'ambiguità.

Un requisito di esperienza **DEVE** derivare da contesto d'uso, bisogno o rischio
epistemico identificato e specificare compito, persone, piattaforma, stato e metodo
di valutazione applicabili. Preferenza dichiarata, telemetria, test di usabilità e
accessibilità sono evidenze differenti e non intercambiabili.

## 9.3 Identificatori e stati

- `NS-*`: necessità stakeholder.
- `RF-*`: requisito funzionale.
- `RQ-*`: requisito di qualità.
- `CV-*`: vincolo.
- `IE-*`: interfaccia esterna.
- `TV-*`: verifica pianificata.
- `GS-UX-*`: contratto dell'esperienza da cui possono derivare necessità e requisiti.

Gli stati ammessi sono `Bozza`, `In revisione`, `Approvato`, `Sospeso`, `Sostituito` e `Respinto`. `Incompleto` **PUÒ** essere usato prima della revisione, mai in una baseline.

## 9.4 Modifiche

Una modifica a un requisito approvato **DEVE** includere analisi d'impatto su architettura, dati persistenti, compatibilità, test, documentazione e piano di rilascio. Un identificatore **NON DEVE** essere riutilizzato con significato diverso.
