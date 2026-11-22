# 13. Dipendenze e supply chain

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-13 |
| Tipo | Capitolo normativo |
| Versione | 0.3.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 13.1 Adozione

Una nuova dipendenza **DEVE** avere:

- requisito o problema che la giustifica;
- confronto con framework di sistema e implementazione interna;
- valutazione di manutenzione, licenza, sicurezza, dimensione e stabilità API;
- proprietario interno;
- strategia di aggiornamento o sostituzione.

Un framework Apple appropriato e supportato **DEVE** essere valutato prima di introdurre una dipendenza esterna o una soluzione proprietaria equivalente. La preferenza non sostituisce la verifica di adeguatezza, disponibilità SDK, prestazioni, privacy e possibilità di fallback.

La somiglianza nominale con Glifi Studio **NON DEVE** costituire una giustificazione tecnica; questo vale anche per GlifiStore.

## 13.2 Risoluzione e inventario

- Le dipendenze Swift **DOVREBBERO** usare Swift Package Manager salvo requisito contrario.
- Le versioni risolte **DEVONO** essere riproducibili.
- Ogni rilascio **DEVE** poter produrre un inventario delle dipendenze e delle relative licenze.
- Dipendenze non più mantenute o vulnerabili **DEVONO** generare una valutazione e un piano.
- Codice scaricato dinamicamente **NON DEVE** essere eseguito senza una decisione di sicurezza esplicita.
- API deprecate, incluso ML Compute per nuovo codice, **NON DEVONO** essere adottate quando Apple indica un percorso sostitutivo applicabile.

## 13.3 Strumenti e automazioni di build

Azioni CI, plugin Xcode, macro, formatter, generatori, modelli e immagini runner **DEVONO** essere trattati come dipendenze eseguibili.

- Ogni azione esterna **DEVE** essere fissata a un commit SHA completo e revisionata a ogni aggiornamento.
- Tag e branch mobili **NON DEVONO** essere usati come riferimenti eseguibili in CI.
- Il token del workflow **DEVE** avere permessi minimi e le credenziali di checkout **NON DEVONO** persistere senza necessità.
- Codice proveniente da pull request non fidate **NON DEVE** essere eseguito con segreti o privilegi di scrittura.
- Runner self-hosted **NON DEVONO** essere adottati senza isolamento, aggiornamento, reset e risposta agli incidenti.
- Gli aggiornamenti automatici **DEVONO** aprire modifiche revisionabili; non costituiscono approvazione all'integrazione.

## 13.4 Licenza del progetto

Il progetto adotta la BSD 3-Clause con identificatore SPDX `BSD-3-Clause`, secondo [GS-LIC-001](../licenza.md).

- Ogni distribuzione sorgente **DEVE** conservare copyright, condizioni e disclaimer.
- Ogni distribuzione binaria **DEVE** riprodurli nella documentazione o negli altri materiali forniti.
- Il nome del titolare e dei contributori **NON DEVE** essere usato per approvare o promuovere prodotti derivati senza permesso scritto.
- Materiali e dipendenze di terzi **DEVONO** mantenere licenze e avvisi applicabili.
- Un cambiamento futuro di licenza **NON DEVE** essere presentato come revoca delle licenze già concesse sulle versioni distribuite.
