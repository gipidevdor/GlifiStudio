<!-- SPDX-License-Identifier: BSD-3-Clause -->

# 13. Dipendenze e supply chain

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-13 |
| Tipo | Capitolo normativo |
| Versione | 0.4.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-26 |
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

## 13.5 Fonti algoritmiche e materiali senza package manager

L’inventario **DEVE** includere anche regole e tabelle implementative, frammenti
adattati, generatori pseudo-casuali, fixture, immagini e strumenti di verifica:
l’assenza di dipendenze SwiftPM esterne non basta a dimostrare la provenienza.
Per ogni materiale **DEVONO** essere registrati fonte primaria, revisione,
condizioni applicabili, relazione con l’implementazione, distribuzione e avvisi,
secondo [GS-LIC-002](../algoritmi-e-provenienza.md).

- Una citazione scientifica **NON DEVE** essere trattata come permesso di copia
  dell’implementazione o dei contenuti della pubblicazione.
- Un adattamento o port **DEVE** conservare gli obblighi della fonte; un nuovo
  identificatore SPDX del progetto **NON DEVE** nasconderne la derivazione.
- Testo originale, trascrizione e annotazioni di una fixture **DEVONO** avere
  ambiti di licenza distinti quando differiscono; le porzioni riprodotte nei
  file annotati **DEVONO** conservare attribuzione e condizioni della fonte.
- Gli avvisi necessari alla distribuzione binaria **DEVONO** essere presenti
  nel bundle e verificati sul prodotto costruito, oltre che nel repository.
- Variazioni di manifest di dipendenza, azioni CI e asset inventariati **DEVONO**
  richiedere aggiornamento dei digest revisionati, con review della provenienza.

Il controllo strutturale **NON DEVE** essere presentato come certificazione di
compatibilità legale, titolarità o assenza di diritti brevettuali e di marchio.
