# 22. Manutenzione e compatibilità

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-22 |
| Tipo | Capitolo normativo |
| Versione | 0.2.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

- Ogni versione supportata **DEVE** avere politica e termine di supporto dichiarati.
- Un difetto **DEVE** essere riprodotto e classificato prima della correzione quando possibile.
- Correzioni su versioni mantenute **DEVONO** minimizzare cambiamenti estranei.
- La rimozione di API o formati **DEVE** prevedere deprecazione o decisione motivata.
- La compatibilità all'indietro **DEVE** essere verificata sulle fixture delle versioni dichiarate.
- Debito tecnico noto **DEVE** avere identificatore, conseguenza e criterio di risoluzione; un commento `TODO` isolato non è un registro sufficiente.
- Il formato `.glifi` corrente **DEVE** leggere e scrivere N e, quando esiste,
  leggere N-1 prima della migrazione. Una versione futura sconosciuta **DEVE**
  aprirsi read-only soltanto se sicuro oppure essere rifiutata senza mutazioni.
- La migrazione **DEVE** operare su copia transazionale, verificare il risultato e
  mantenere un backup recuperabile. Il downgrade non è promesso; l'export
  interoperabile è la via di uscita supportata.
- Versione prodotto, formato progetto, schema database, QueryAST, algoritmo,
  InterpretationRule e VisualizationSpec sono assi distinti e **NON DEVONO** essere
  avanzati come un singolo numero.
- Findings e Artifact storici conservano la versione originaria. Un ricalcolo crea
  una nuova revisione e non riscrive il passato.
