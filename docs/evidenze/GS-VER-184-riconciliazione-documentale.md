<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-184 — Riconciliazione documentale dello stato del prodotto

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-184 |
| Tipo | Evidenza di ricognizione e verifica documentale |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro documentale |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | Prosecuzione del programma complementare richiesta dall'iniziatore; nessuna promozione scientifica o di gate |
| Riferimenti | GS-PLAN-180; GS-PLAN-001; GS-DOR-168; GS-STD-001-07; RQ-062; RQ-063 |

## Perimetro

La ricognizione confronta roadmap, requisiti e stato di adozione con evidenze
già registrate e sorgenti presenti. Gli interventi di questo incremento sono
limitati alla [roadmap](../roadmap.md) e all'appendice del
[DoR algoritmico](../pianificazione/dor-completamento-algoritmi.md). Requisiti,
stato di adozione e registri comuni sono oggetto di proposte puntuali consegnate
all'integratore, senza riscrittura concorrente da parte di questo incremento.

La roadmap passa a 1.1.0, conserva gli stati storici e distingue la
riconciliazione del 2026-11-21 dalle revisioni effettivamente verificate nelle
evidenze precedenti. La presenza di codice concomitante non attesta una nuova
esecuzione del gate o il completamento di una capacità scientifica.

## Riscontri e correzioni

| Dichiarazione precedente | Riscontro esistente | Correzione documentale |
| --- | --- | --- |
| Gold italiano interamente da realizzare | GS-VER-138 documenta prosa reale, 434 token lessicali e 19 frasi, con limiti di copertura | Registrare il gold disponibile e mantenere aperti rappresentatività, annotazioni avanzate e soglie assolute |
| UI nativa fra le capacità assenti della Fase 1 | GS-VER-057 registra il percorso Must e la candidatura funzionale G3; GS-VER-150 verifica l'interfaccia essenziale | Riferire la UI alla Fase 2, preservando G3 formale, audit GUI, G4 e G5 aperti |
| Presentazione dedicata delle analisi estese ancora assente | GS-VER-113/114 documentano intenzioni e viste da Artifact con tabelle equivalenti | Registrare le viste disponibili senza dichiarare copertura di ogni operazione o parametro diretto |
| Codebook e selezione dei passaggi ancora interamente futuri | GS-VER-126…129 documentano persistenza, accordo, app e selezione strutturata per frasi o caratteri | Registrare le capacità esistenti mantenendo separati selezione diretta con puntatore e audit su dispositivo |
| Topic model probabilistici interamente futuri | GS-VER-160…162 documentano le varianti native di libreria, fra cui LDA, e il trasporto Kit/CLI | Separare libreria e stato scientifico per variante da integrazione persistente, planner e UI |
| GS-DOR-168 non esplicita tutti i campi obbligatori della scheda | GS-STD-001-07 richiede i campi della Definition of Ready; le specifiche GS-MET e GS-API fissano già i contratti applicabili | Aggiungere una scheda completa per la prosecuzione delimitata, con requisiti, confini, failure, verifica, dati, sicurezza, prestazioni, tracciabilità e decisioni |

Il riscontro in sola lettura dei sorgenti conferma la presenza delle viste
`StudioVisualizationView` e `StudioCodingView`, della selezione per caratteri,
del salto alle coordinate di fonte, dell'anteprima export e dei client CLI
corrispondenti. È una conferma di presenza e collegamento del codice, non una
nuova prova di esecuzione, correttezza numerica o accessibilità.

## Verifiche osservate

Il 2026-11-21, dopo gli aggiornamenti a roadmap e DoR:

- `Scripts/check-docs.py` è terminato con exit 0: 378 file documentali,
  377 identificatori univoci, link locali validi e 27 schede DoR;
- `git diff --check -- docs/roadmap.md
  docs/pianificazione/dor-completamento-algoritmi.md` è terminato senza errori
  di whitespace sui cambiamenti tracciati;
- la rilettura del DoR conferma tutti i campi della scheda e una dichiarazione
  `**Ready**` circoscritta alla prosecuzione già normata, con esclusioni e
  criterio di arresto per varianti prive di contratto.

La distinzione temporale è esplicita: il DoR completo è ricostruito dopo
l'avvio nell'altra chat. Questa evidenza non dimostra registrazione preventiva,
non sana retroattivamente il relativo requisito di processo e non dichiara
verificati gli algoritmi di GS-DOR-168.

La ripetizione del controllo documentale dopo l'aggiunta di questa evidenza
termina con exit 0: 381 file, 380 identificatori univoci, link validi e 29 DoR.
La crescita del conteggio comprende documenti concomitanti della copia condivisa
e non è attribuita interamente a questo incremento. Il controllo di whitespace
dei file nuovi con `git diff --no-index --check /dev/null <file>` non emette
diagnostica; l'exit 1 segnala la presenza del diff rispetto al file vuoto.

## Limiti

Nessuna build, test Swift, oracolo numerico, benchmark o prova GUI viene eseguito
da questo incremento documentale. `make verify` resta a carico della verifica
integrata; i controlli documentali non ne sostituiscono l'esecuzione né attestano
lo stato corrente della CI remota. I lavori dell'altra chat restano distinti.

Le famiglie algoritmiche nuove e il laboratorio macOS richiedono le proprie
evidenze, livelli di validazione e tracciabilità. GUI, VoiceOver, dispositivi,
Instruments, review scientifica esterna V6 e G4/G5 restano aperti.

Non sono stati creati snapshot, download, build o altri artefatti temporanei
per questa ricognizione; si conservano soltanto i documenti consegnati.

## Integrazione del coordinatore

Applicate anche le proposte puntuali in GS-SRS-001: stati di RQ-012, RQ-020 e
RQ-038, oracoli RF-022 e selezione strutturata RF-043. La tabella GS-STD-001-28
riporta la data documentata corrente e corregge API/CLI, CI storica e benchmark
già disponibili, mantenendo aperti audit su dispositivo, soglie e hardware.
Le colonne normative dei requisiti e i criteri di accettazione non cambiano.
Il controllo statico completo ha superato anche questi inserimenti prima della
verifica nativa globale; nessuna promozione dei nuovi metodi dell'altra chat
deriva da questa riconciliazione.

La verifica integrata finale del coordinatore è terminata con exit 0, incluso
il controllo documentale globale. GS-VER-182 ne registra gli esiti nativi e
il preflight macOS su snapshot identico; questa evidenza conserva il proprio
perimetro documentale e non promuove le nuove varianti scientifiche.
