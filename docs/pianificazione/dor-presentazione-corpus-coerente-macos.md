<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Presentazione corpus coerente su macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-274 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.1.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta di proseguire correzioni e completamenti macOS con soli test automatici |
| Riferimenti | RF-046; RQ-013; RQ-047; RQ-058; RQ-060; RQ-063; GS-DOR-223; ADR-0041; GS-UX-001-17 |

## Problema e criterio di stop

Nel modello corpus il cambio di tableID può rendere corrente una tabella più
corta mentre gli indici filtrati e le righe appartengono ancora alla precedente.
Una richiesta di pagina in tale intervallo può accedere fuori dai limiti.
Inoltre il token condiviso fra filtro e proiezione può scartare la proiezione
di un nuovo asse quando cambia la ricerca, lasciando etichetta e dati riferiti
ad assi differenti. Sono difetti candidati individuati dal codice, non esiti
già riprodotti o osservazioni di una GUI reale.

L'incremento termina quando tabella, asse, indici, conteggio, pagina e righe
sono coerenti dopo ogni transizione ammessa e il filtro più recente viene
applicato alla proiezione più recente senza accessi obsoleti.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Correggere soltanto la presentazione di StudioCorpusMethodsModel e i suoi controlli macOS. Nessun algoritmo, risultato Core/Kit, schema persistente o funzionalità iPadOS cambia |
| requisiti | RF-046 e RQ-013/047/058/060/063; tabelle complete e identità dell'output catturato di GS-UX-001-17/ADR-0041. Asse dichiarato e valori mostrati devono riferirsi alla stessa proiezione |
| contratto di dominio/API | Su cambio tabella, ricerca o asse che richiede lavoro async, invalidare sincronicamente righe, indici, conteggio e pagina derivati. Indici pubblicati appartengono sempre alle righe della tabella corrente. Separare identità e ownership di filtro e proiezione; ricerca o tableID più recenti non annullano la proiezione dell'asse richiesto. Al suo completamento applicare tabella corrente se disponibile, altrimenti il fallback esistente, e ricerca corrente. Reset e nuovo output invalidano entrambi i percorsi; lifecycleNonce del lavoro 223 è preservato |
| failure semantics | Completamenti superati o cancellati sono scartati senza sostituire la presentazione corrente o azzerare lo stato pending di una richiesta più recente. Durante pending nessuna pagina può accedere a indici precedenti. Le failure scientifiche e di calcolo restano tipizzate e conservano l'output valido secondo il contratto esistente; nessun parziale è marcato pronto |
| esperienza prevista | Stato observable read-only isPreparingPresentation; ProgressView con chiave cm.presentation.updating, italiano «Aggiornamento dei risultati…» e inglese «Updating results…». Durante pending conteggio e stato nessun risultato sono nascosti, paginazione disabilitata; asse, tabella e ricerca restano attivi per registrare l’ultimo intento. Nessuna vecchia coordinata è presentata come riferita all’asse nuovo e nessun vuoto transitorio è dichiarato risultato definitivo. Ricerca e scelta tabella dell’utente sono conservate, senza reset implicito al completamento della proiezione |
| verifica | Nuova suite nativa StudioCorpusPresentationTests, registrata nel target test macOS prima dell’esecuzione. RED/GREEN deterministici con risultato reale correspondence e tabella B più corta di A: immediatamente dopo tableID=B asserire righe/indici/conteggio vuoti e pagina zero prima di qualsiasi sospensione. Fermare il RED sull'asserzione, senza provocare un trap volontario; nel GREEN showPage(0) durante pending non accede fuori limite. Provare asse+ricerca+tabella nello stesso turno MainActor, latest-axis-wins e reset, poi attendere la presentazione tramite withObservationTracking dello stato observable, senza aggiungere API await al prodotto, hook, sleep, polling o yield arbitrari. Dopo il terminale verificare asse, filtro, tabella, completezza/paginazione e identità dell'output; GS-VER-274, gate e preflight macOS sul sorgente finale identificato |
| dati e migrazione | Output scientifico catturato e JSON esistente invariati; cambia soltanto la presentazione derivata di sessione. Nessuna migrazione, Artifact, dato gold o metadato persistente nuovo |
| sicurezza/privacy | Fixture sintetiche locali, nessun corpus reale, logging di contenuto/path, rete, dipendenza, entitlement o telemetria nuova. Nessun nuovo input non fidato o privilegio |
| prestazioni/sistema | Proiezione e filtro restano fuori Main Actor; invalidazione sincrona O(1) senza scansioni sul Main Actor. Stato aggiornato a eventi con task cancellabili owned, nessun timer o lavoro speculativo. Pagine bounded esistenti conservate; nessuna nuova promessa di latenza o energia |
| tracciabilità | CMP-234 inizialmente specified, GS-VER-274 candidata e test nativi corpus. Codice, test, localizzazione, evidenza e registri aggiornati nello stesso incremento; nessuna promozione di CMP-223, G4/G5 o stati scientifici |
| decisioni e recupero | Correzione locale conforme ad ADR-0041 e GS-STD-001-07/29; nessun backend o API pubblica Kit/Core nuovo. Revert limitato al lotto se altera output o ownership. Preservare le correzioni concomitanti del lavoro 223 e la barriera del lotto 233 |

## Casi di accettazione

1. Il cambio da una tabella lunga a una più corta invalida i derivati nello
   stesso turno. Una pagina chiesta prima del terminale è innocua; dopo il
   terminale tutti gli indici appartengono alla tabella breve e le righe non
   sono perse o duplicate.
2. Cambiare asse e digitare una ricerca nello stesso turno non scarta la nuova
   proiezione. Dati e indicazione dell'asse coincidono; si usa l'ultima ricerca.
3. Cambiare tableID mentre la proiezione è in corso conserva tale scelta se
   disponibile. Un completamento vecchio non ripristina query o tabella vecchie.
4. Reset e sostituzione dell'output invalidano tutti i derivati pendenti;
   nessun terminale vecchio cancella il progresso di un lavoro più recente.
5. Calcoli e payload scientifici restano identici. Localizzazione e verifica
   strutturale non sono un audit VoiceOver, una misura GUI o una prova iPadOS.

**Ready** prima del primo cambiamento implementativo o test RED del lotto.
La revisione 1.1 sceglie l'osservazione test-only dello stato già esposto alla
vista: nessuna API async di attesa viene introdotta nel modello di produzione.
