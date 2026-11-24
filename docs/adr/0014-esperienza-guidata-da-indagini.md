<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0014 — Esperienza guidata da indagini, intenzioni ed evidenze

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0014 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Direzione UX esplicita dell'iniziatore del progetto |
| Fonte | Richiesta di revisione sistematica UX del 2026-09-15 |
| Sostituisce | Nessuno |

## Contesto

La baseline definisce metodi scientifici, progetto persistente, AnalysisDescriptor
e Analysis DAG, ma non stabilisce ancora il modello mentale del prodotto. Una
navigazione costruita direttamente sulle famiglie algoritmiche costringerebbe la
persona a conoscere il metodo prima di formulare la domanda e trasformerebbe Glifi
Studio nel frontend di una libreria statistica.

La semplicità non può però derivare dalla rimozione di formule, parametri, caveat o
fonti. Serve un confine esplicito tra semantica scientifica, pianificazione,
interpretazione strutturata e presentazione progressiva.

## Decisione

1. GS-UX-001 diventa la specifica normativa dell'esperienza utente.
2. Il progetto resta il contenitore persistente; l'indagine diventa l'unità
   cognitiva del percorso di ricerca e può avere cronologia ramificata.
3. Il primo livello è organizzato per domanda, intenzione e oggetto studiato, non
   per algoritmo. Le intenzioni hanno tassonomia e ID indipendenti dalla lingua.
4. Un CollectionProfile versionato alimenta un Analysis Planner deterministico che
   seleziona tutte e sole le analisi applicabili, informative e sostenibili.
5. Evidence, Finding e Caveat sono concetti distinti. Un motore interpretativo
   deterministico produce findings mediante rule set verificabili.
6. La catena `Conclusione → Evidenza → Fonti → Metodo` governa la progressive
   disclosure; ogni numero dichiara lineage esatto, contributivo o derivazionale.
7. Un confidence score universale è vietato. Eventuali categorie di solidità
   derivano da policy scientifiche specifiche e versionate.
8. macOS e iPadOS condividono semantica e identità, adottando navigazione e
   interazioni native differenti quando appropriato.
9. Un livello generativo può assistere domanda e prosa sopra strutture valide, ma
   non decide significatività, crea evidenze o altera lineage e caveat.

I concetti stabiliscono responsabilità e invarianti, non nomi definitivi di tipi
Swift, target, storage o layout.

## Alternative considerate

- catalogo di strumenti scientifici come home: respinto perché espone la struttura
  interna prima dell'obiettivo della persona;
- modalità semplice ed esperta separate: respinta perché rischia semantiche e
  risultati divergenti;
- interpretazione libera affidata a un LLM: respinta per riproducibilità, lineage e
  rischio di conclusioni non sostenute;
- esecuzione indiscriminata di ogni algoritmo: respinta perché applicabilità,
  qualità e costo dipendono dai dati;
- sola cronologia Undo/Redo: respinta perché non rappresenta il percorso analitico
  persistente e ramificabile.

## Conseguenze positive

- persone non specialiste possono formulare domande senza perdere rigore;
- esperti mantengono accesso immediato a metodo e parametri;
- planner, findings e caveat diventano verificabili senza GUI;
- accessibilità, localizzazione e comportamento cross-platform derivano da oggetti
  semantici stabili;
- il prodotto può dichiarare in modo strutturato quando non è possibile concludere.

## Conseguenze negative e rischi

- aumentano i contratti di dominio e la persistenza da progettare;
- tassonomia, regole interpretative e policy di solidità richiedono review
  scientifica e studi con utenti;
- una sintesi editoriale progressiva è più complessa di un elenco di output;
- cronologia ramificata, più finestre e invalidazione richiedono gestione coerente
  delle versioni;
- una microcopy semplice ma scientificamente precisa richiede validazione dedicata.

## Verifica della decisione

- GS-UX-001 mantiene un documento per ogni responsabilità autonoma;
- requisiti RF-047–RF-074 e RQ-030–RQ-040 sono tracciati;
- VA-07 e CR-13–CR-20 separano interazione, dominio e semantica analitica;
- i primi prototipi superano decision table, test di lineage e studi di comprensione
  prima di stabilizzare API o navigazione;
- nessun claim presenta lo scaffold corrente come implementazione della specifica.
