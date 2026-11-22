<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Runtime macOS guidato dagli eventi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-182 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di realizzare il programma complementare con attenzione massima alle prestazioni |
| Riferimenti | GS-STD-001-07; GS-APL-015; ADR-0018; RQ-052; RQ-053; RQ-054; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Collegare eventi energia, termica, memoria e attività macOS al runtime delle sessioni; admission delle operazioni lunghe e rivalutazione del piano fra nodi, senza polling |
| requisiti | RQ-052–RQ-054, RQ-063; TV-065–TV-067 nel perimetro automatico; hardware, energia, Instruments e G4 restano distinti |
| dominio/API | DTO Sendable e provider Kit iniettati Service→Session; store Mutex con snapshot sincrono O(1); Core riceve provider compatibile con snapshot espliciti esistenti; App dipende soltanto da Kit |
| failure semantics | Pressione critica rifiuta nuovo lavoro con failure runtime tipizzata e ultima generazione valida conservata; rivalutazione ai confini fra nodi, nessun risultato incompleto dichiarato completo; snapshot, close e recovery restano disponibili |
| esperienza prevista | Azioni esistenti conservano risultati e localizzazione delle failure; nessun controllo UI nuovo; iniezione del servizio al modello e owner del monitor nell'app macOS, senza singleton mutabile |
| verifica | Segnali finti, snapshot concorrenti, start/stop idempotenti, rilascio observer/source, admission critica sulle azioni dirette e variazione fra nodi con riapertura valida; test del workspace e `make verify`; GS-VER-182 candidata |
| dati e migrazione | Nessun formato, schema o migrazione; un nodo già committato rimane valido; nessuna promessa di checkpoint intra-nodo o recovery power-loss nuova |
| sicurezza/privacy | Soli segnali nativi senza contenuto, rete, privilegi o dipendenze; termica sconosciuta e memoria non ancora osservata sono trattate conservativamente |
| prestazioni/sistema | Eventi senza timer, snapshot O(1) protetto da Mutex e nessun actor-hop per nodo; source/observer owned e cancellabili; memoria iniziale warning dichiarata fino al primo evento; termica letta prima della registrazione; nessuna assertion App Nap o sleep |
| tracciabilità | CMP-182 inizialmente specified, GS-VER-182, RQ-052–054 e registri aggiornati dopo prove; nessun criterio EA non verificato promosso |
| decisioni e recupero | ADR-0018 applicata senza backend o scelta scientifica nuova; Task del piano userInitiated, altre chiamate async ereditano priorità strutturata; rollback per revert senza migrazione |

**Ready** registrata prima del coding. Il default headless esplicito conserva la
compatibilità dei client privi di lifecycle AppKit. Le analisi indivisibili hanno
admission iniziale e cancellazione esistente; la rivalutazione dinamica è limitata
ai confini sicuri del piano. I profili non cambiano parametri scientifici e il
parallelismo esistente non viene ampliato. Nessuna nuova attestazione energetica
o prestazionale di rilascio deriva dai soli test automatici.
