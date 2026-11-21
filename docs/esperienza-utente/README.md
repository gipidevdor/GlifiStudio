<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Specifica dell'esperienza utente

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-21 |
| Approvazione | Paradigma richiesto dall'iniziatore; baseline da validare con utenti |
| Riferimenti | ISO 9241-210:2019; ISO 9241-11:2018; ISO/IEC 25010:2023; Apple Human Interface Guidelines; GS-MET-001 |

## Scopo e autorità

GS-UX-001 definisce il paradigma d'interazione dal quale devono derivare requisiti,
architettura applicativa, navigazione, presentazione dei risultati, accessibilità e
test di Glifi Studio. Non è un catalogo di schermate e non impone tipi Swift,
componenti grafici o una disposizione visiva definitiva.

La [specifica scientifica](../metodi-analitici/README.md) governa formule,
precondizioni e significato dei metodi. Questa specifica governa il modello mentale,
la progressione informativa e le azioni offerte alle persone. I
[profili Apple](../apple/README.md) governano il comportamento nativo di piattaforma.
Nessuno dei tre livelli può ridefinire implicitamente gli altri.

GS-UI-001 rende concreti route, scene, comandi e componenti; GS-ANA-001 rende
concreti planner, interpretation e ranking. Questi documenti implementano il
modello mentale GS-UX senza diventarne una fonte alternativa.

## Principio costituzionale

Glifi Studio organizza l'interazione intorno a ciò che la persona studia, a ciò che
vuole comprendere, a ciò che il sistema ha trovato e alle evidenze che sostengono
ogni affermazione. Algoritmi e parametri restano verificabili, ma la complessità
metodologica cresce verso l'interno del sistema mediante progressive disclosure.

```text
domanda → intenzione → piano applicabile → evidenze → findings → approfondimento
                                      ↘ caveat ↙
```

Una vista primaria **NON DEVE** essere un catalogo di algoritmi. Una formulazione
comprensibile **NON DEVE** eliminare precisione, lineage o possibilità di verifica.

## Relazione con l'implementazione corrente

Le app condividono il percorso Must SwiftUI (progetto `.glifi`, import, indagine,
piano/esecuzione, KWIC, findings ed export) come client di GlifiKit. Restano aperte
navigazione adattiva avanzata, audit VoiceOver su dispositivo e studi UX. I nomi
concettuali della specifica non costituiscono automaticamente API pubbliche.

## Information item

| ID | Responsabilità | Documento |
| --- | --- | --- |
| GS-UX-001-01 | Paradigma e tassonomia | [Paradigma e intenzioni analitiche](01-paradigma-e-intenti-analitici.md) |
| GS-UX-001-02 | Modello cognitivo persistente | [Progetto, corpus e indagine](02-progetto-corpus-e-indagine.md) |
| GS-UX-001-03 | Conoscenza preliminare dei dati | [Profilo della raccolta e preparazione](03-profilo-della-raccolta-e-preparazione.md) |
| GS-UX-001-04 | Pianificazione spiegabile | [Analysis Planner e applicabilità](04-analysis-planner-e-applicabilita.md) |
| GS-UX-001-05 | Semantica di ciò che viene affermato | [Evidence, Finding e Caveat](05-evidence-finding-e-caveat.md) |
| GS-UX-001-06 | Profondità informativa | [Progressive disclosure e solidità](06-progressive-disclosure-e-solidita.md) |
| GS-UX-001-07 | Architettura dell'informazione | [Navigazione per oggetti e confronto](07-navigazione-per-oggetti-e-confronto.md) |
| GS-UX-001-08 | Presentazione dei risultati | [Sintesi editoriale e approfondimenti](08-sintesi-editoriale-e-approfondimenti.md) |
| GS-UX-001-09 | Interrogabilità dei risultati | [Lineage interattivo e numeri](09-lineage-interattivo-e-numeri.md) |
| GS-UX-001-10 | Memoria del lavoro | [Cronologia, persistenza e relazione](10-cronologia-persistenza-e-relazione.md) |
| GS-UX-001-11 | Domande in linguaggio naturale | [Ingresso naturale e interpretazione canonica](11-ingresso-naturale-e-interpretazione-canonica.md) |
| GS-UX-001-12 | Comportamento di piattaforma | [Esperienza adattiva macOS e iPadOS](12-esperienza-adattiva-macos-ipados.md) |
| GS-UX-001-13 | Inclusione e prova | [Accessibilità e validazione UX](13-accessibilita-e-validazione-ux.md) |
| GS-UX-001-14 | Linguaggio dell'interfaccia | [Vocabolario e localizzazione semantica](14-vocabolario-e-localizzazione-semantica.md) |
| GS-UX-001-15 | Checklist G4 accessibilità | [Checklist G4 accessibilità e dispositivi](15-checklist-g4-accessibilita.md) |
| GS-UX-001-16 | Codifica qualitativa | [Codifica qualitativa](16-codifica-qualitativa.md) |
| GS-UX-001-17 | Completamento analitico macOS | [Laboratorio di analisi testuale](17-laboratorio-analisi-testuale.md) |

## Evoluzione

Una modifica al modello mentale, alla semantica di un'intenzione, alla catena
epistemica o al comportamento di navigazione richiede analisi d'impatto su
requisiti, architettura, localizzazione, persistenza e test. Wireframe e prototipi
sono evidenze di design: non sostituiscono questa specifica né la validazione con
persone rappresentative.
