<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Barriera di reset dei laboratori macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-273 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.3.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta di proseguire correzioni e completamenti macOS con soli test automatici |
| Riferimenti | RQ-011; RQ-013; RQ-047; RQ-058; RQ-060; RQ-063; GS-DOR-223; ADR-0041; GS-UX-001-17 |

## Problema e criterio di stop

Il contratto di GS-DOR-223 vieta la pubblicazione tardiva dopo un reset.
La revisione del modello avanzato individua un'operazione che attraversa un
await e può poi pubblicare senza verificare che il modello appartenga ancora
alla stessa generazione di reset. La cancellazione del Task non equivale a un
reset del modello. I modelli statistico e operatori sono già presidiati; il
lavoro 223 ha nel frattempo corretto corpus con lifecycleNonce e valutazione
linguistica/temporale con lifecycleID. Questi controlli sono preservati e
rientrano nelle regressioni senza attribuire a questo lotto le loro correzioni.

Il problema è un contratto del modello: il coordinatore Home attuale attende
la fine dello stato occupato prima del cambio documento. Non si dichiara quindi
una riproduzione del difetto attraverso un gesto dell'interfaccia reale.
Il lotto termina quando il reset durante un'operazione sospesa impedisce la
pubblicazione precedente, senza dipendere da Task.cancel, e il retry è valido.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Barriera privata di reset per StudioAdvancedAnalysisModel.execute; regressioni per StudioEvaluationModel.executeLinguistic/executeTemporal e StudioCorpusMethodsModel.execute già corretti dal lavoro 223. Nessuna nuova famiglia analitica, formula, UI o funzionalità iPadOS |
| requisiti | RQ-011/013/047/058/060/063; proprietà già richiesta da GS-DOR-223 e ADR-0041. Il risultato appartiene all'input catturato e non può ripopolare un modello resettato |
| contratto di dominio/API | Identità privata UUID della generazione del modello, rinnovata da reset; cattura prima del primo await e verifica dopo l'ultimo await, immediatamente prima del blocco di pubblicazione MainActor senza ulteriori await. Output e presentazione derivata appartengono alla medesima generazione. Nessuna API pubblica Kit/Core o identità di dominio cambia |
| failure semantics | Un'operazione superata dal reset termina con GlifiStudioFailure: code operation.cancelled, category cancelled, operation analyze, retryDisposition newRequest, retainedState unchanged. Rimane valido lo stato corrente imposto dal reset o da un retry successivo. Failure e cancellazione ordinarie conservano il comportamento e l'output precedente previsti; ownership, admission e busy del coordinatore non cambiano |
| esperienza prevista | Nessun nuovo testo o controllo; si riusa la failure cancellata localizzata. Risultati, righe, filtri e pagine resettati non ricompaiono per il completamento precedente. Compilazione e test non sono audit della GUI o dell'accessibilità |
| verifica | Prova deterministica sui quattro percorsi con fixture numeriche reali: RED atteso soltanto Advanced, tre GREEN attesi per i controlli già presenti di valutazione linguistica/temporale e corpus. Non rimuovere guard preesistenti per costruire un falso RED. Task.immediate sul Main Actor esegue inline fino al primo hop del calcolo concurrent; il chiamante esegue reset nello stesso turno prima che il completamento possa riprendere sul Main Actor. API SDK disponibile da macOS 26, target macOS 27. Nessun hook o iniezione in produzione, sleep, polling o yield arbitrario. Assert di mancata pubblicazione dopo reset senza Task.cancel, metadata della failure, stato derivato, failure ordinaria e retry; i test esistenti restano attivi. GS-VER-273 registra risultati effettivi; gate e preflight macOS sul sorgente finale identificato |
| dati e migrazione | Il reset invalida soltanto la pubblicazione applicativa. Non annulla un Artifact Core già committato né modifica snapshot persistenti, formati o migrazioni. UUID esclusivamente di sessione, non esportati |
| sicurezza/privacy | Fixture sintetiche e temporanee; nessun corpus reale, segreto, log di contenuto/path, rete, dipendenza, entitlement o telemetria nuova. Nessun confine di iniezione è aggiunto al prodotto |
| prestazioni/sistema | Costo O(1) per reset/esecuzione, senza scansioni o lavoro aggiuntivo per elemento. Calcolo e preparazione restano fuori Main Actor; guard e pubblicazione restano sul Main Actor. Nessuna attività di polling o promessa di latenza/energia |
| tracciabilità | CMP-233 inizialmente specified; GS-VER-273 candidata, test nativi dei tre modelli e verifica macOS. Aggiornare nello stesso incremento codice, prove, registri e stato pertinente; nessuna promozione di CMP-223 o G4/G5 |
| decisioni e recupero | Correzione locale coerente con ADR-0041 e GS-STD-001-07/29; nessuna nuova decisione architetturale. Revert del solo incremento se il guard modifica risultati, ownership o stato valido. Il WIP altrui resta preservato |

## Casi di accettazione

1. Calcolare un risultato numerico valido e conservarne l'identità come prova
   della fixture; avviare la nuova esecuzione mediante Task.immediate MainActor.
2. Dopo il primo hop concurrent, eseguire reset nello stesso turno del chiamante
   senza cancellare il Task e poi attenderne il terminale: deve fallire come
   cancellato e lasciare output e presentazione nello stato del reset.
3. Un'esecuzione ammessa dopo il reset può pubblicare il nuovo risultato;
   un vecchio completamento eventualmente ancora in corso non lo sostituisce.
4. Failure ordinaria e cancellazione senza reset non cancellano l'output valido
   precedente. Nessun risultato o parametro scientifico viene alterato.
5. Le prove non attestano un race osservato nella GUI, nuove proprietà della
   persistenza, VoiceOver, iPadOS, energia o CI remota.

**Ready** prima del primo cambiamento implementativo o test RED del lotto.
La revisione 1.1 sostituisce l'ipotesi di seam della 1.0 con la strategia SDK
nativa: nessun hook di test entra nel prodotto. La 1.2, prima della patch,
restringe la produzione ad Advanced in base ai guard arrivati dal lavoro 223:
nessun falso RED e nessuna attribuzione delle correzioni corpus/valutazione.
Il requisito e l'ordine deterministico della prova sono definiti, senza
modifica dell'API pubblica.

## Rinumerazione e provenienza delle esecuzioni

Questa unità di reset era stata registrata localmente come 233. Il controllo
successivo di origin/main `137595026cf1aa416094fc3bf82aa8b0dfe04027` rileva
l'identificatore 233 già assegnato al completamento KH Coder; l'identificatore
235 risulta libero nella revisione verificata e viene adottato per questo
stesso incremento. Le revisioni Ready 1.0–1.2 precedono codice e test con il
nome iniziale; la 1.3 cambia l'identità documentale, senza retrodatare readiness
o creare una nuova esecuzione.

Directory MacStudio233, file e log con prefisso 233 restano nomi storici della
stessa prova sul modello di reset. Non si rinominano campioni, conteggi o log
grezzi e non si attribuiscono queste prove al completamento KH Coder upstream.
