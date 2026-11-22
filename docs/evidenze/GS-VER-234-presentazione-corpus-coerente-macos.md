<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-234 — Presentazione corpus coerente su macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-234 |
| Tipo | Evidenza di verifica della presentazione applicativa macOS |
| Versione | 1.2.4 |
| Stato | Superato nel perimetro automatico macOS sul checkpoint ea48ba88 |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | GS-DOR-234; GS-DOR-223; ADR-0041; RF-046; RQ-013/047/058/060/063 |

## Perimetro

Sono verificate sul checkpoint ea48ba88 l'invalidazione sincrona dei derivati al cambio di tabella
e l'indipendenza dei task di filtro e proiezione del modello corpus macOS.
Righe, indici, conteggio, pagina e asse devono riferirsi alla presentazione
corrente; ricerca e tabella più recenti vanno applicate alla proiezione finale.
I risultati Core/Kit, i formati e la persistenza non cambiano.
Durante pending il modello espone isPreparingPresentation e la vista mostra
ProgressView localizzato cm.presentation.updating; conteggio e nessun risultato
sono nascosti, le pagine disabilitate, asse/tabella/ricerca ancora modificabili.

La revisione individua un possibile accesso fuori limite con indici della
tabella precedente e un'incoerenza asse/dati quando la ricerca invalida il
token della proiezione. Le prove seguenti riproducono l'invalidazione mancante
senza provocare un trap volontario; non sono osservazioni di una GUI reale.

## RED iniziale e RED corretto

La prima corsa termina con una failure di preparazione: la tabella iniziale
scelta dalla fixture non consente di trovare la tabella più corta richiesta.
Non raggiunge l'asserzione del difetto e non viene presentata come RED valido.
Dati in `234-red-results.json` e `234-red.log`.

Dopo la sola correzione della scelta della tabella nella fixture, la corsa
prima della patch produttiva termina con **una definizione fallita**, zero
superate/saltate e `runtimeWarnings: []`. Il test
`StudioCorpusPresentationTests.switchingTablesInvalidatesPreviousRowsBeforeFiltering`
raggiunge `model.visibleRows.isEmpty`, falsa con le righe precedenti ancora
presenti. Non viene provocato l'accesso fuori limite. Riepilogo, input e log
sono `234-red-corrected-results.json`, `234-red-corrected-inputs.json` e
`234-red-corrected.log` nel dossier storico `/tmp/MacStudio233Evidence/`.

## Strategia e modifica del candidato

La suite StudioCorpusPresentationTests è registrata nel target macOS. Usa
fixture correspondence reale, cambio a tabella più corta nello stesso turno,
richiesta di pagina durante pending, asse+ricerca+tabella, latest-axis-wins e
reset. L'attesa della presentazione usa withObservationTracking dello stato
observable, senza API await aggiunte al prodotto, hook o attese temporali
arbitrarie. Il candidato invalida sincronicamente i derivati e separa i token
per applicare l'ultimo intento alla proiezione corrente; il risultato Core/Kit
non viene ricalcolato per filtrare o cambiare pagina.

## GREEN congiunto del candidato

Il test nativo congiunto termina con **exit 0**, **99 definizioni e 319
esecuzioni**, zero fallite/saltate e `runtimeWarnings: []`. Sono tredici test
parametrizzati con **233 run** più 86 non parametrizzati: quel 233 è un
conteggio e non viene rinumerato. Gli ingressi congelati del lotto risultano
invariati durante la corsa (`frozenLotInputsUnchanged: true`).

Riepilogo `235-234-green-results.json`, log storico `233-234-green.log` e hash
sorgenti `green-inputs.json` nel dossier `/tmp/MacStudio233Evidence/`.
Questa è una prova del candidato isolato, non un nuovo RED con ID rinumerato,
un gate completo o un'attestazione dell'intero checkout originale. In quella
fase iniziale non è attribuita un'applicazione runtime del Root all'originale; i
contributi concomitanti eventualmente già presenti mantengono la loro
attribuzione. Gli esiti della nuova integrazione identificata non sono
attribuiti a questa fase legacy e sono registrati separatamente sotto.

Nella fase legacy CMP-234 passa da specified a **implemented nel candidato**. Restano da
acquisire gate e preflight del contenuto finale; nessun esito precedente è
trasferito al nuovo codice. lifecycleNonce del lavoro 223 e il lotto di reset
235 mantengono i propri limiti e la propria attribuzione.

## Checkpoint allineato verificato (ea48ba88)

Il coordinatore ha composto una copia isolata della tree di integrazione GUI
sulla base origin/main `137595026cf1aa416094fc3bf82aa8b0dfe04027`, conservando
le nove nuove capacità Core e i contributi preesistenti. Il nuovo checkpoint
congelato contiene **1 072 file**, manifest SHA-256
`ea48ba88522af182d3fe9e87924ebd3f5c1a2875387fb2c56950c0f41040c235`.
Il percorso di preparazione è `/tmp/MacStudio235Aligned`; nessuna copia peer
è modificata. In questo allineamento l'ADR GUI è 0041; il riferimento 0035
nelle sezioni legacy di questo documento mantiene la motivazione storica
originale e non viene sovrascritto con l'ADR upstream del completamento KH Coder.

Il modello Advanced allineato contiene già il guard executionRevision della
peer, rinnovato a ogni avvio e reset. È preservato perché protegge anche la
supersession, senza sostituirlo con il guard lifecycleID della patch legacy.
Il contributo reset 235 comprende quindi il fix sulla vecchia base e la
regressione sulla base nuova, senza attribuirsi il controllo più forte peer.
La correzione 234 e i test sono composti sulla nuova base; il checkout legacy
02c1c66 e il checkpoint latest 1375950 mantengono esiti e provenienze distinti.

La prima build allineata non avvia i test per una cattura non ancora coerente
di vista operatori e modello GraphPreview. La coppia completata dall'owner è
poi acquisita senza proxy o modifiche alla peer; prova in aligned-operators-sync.json.
La successiva esecuzione nativa allineata termina con **exit 0**, **104
definizioni e 327 esecuzioni**, zero fallite/saltate e runtimeWarnings: [].
Sono tredici test parametrizzati con **236 run** più 91 non parametrizzati;
sono comprese quattro regressioni di reset e quattro di presentazione.
Riepilogo 235-234-aligned-native-results.json e log 235-234-aligned-native.log
nel dossier di lavoro. Non si trasferisce a questa base il precedente GREEN
legacy di 99 definizioni/319 esecuzioni.

Il primo freeze allineato d3ef5fbb non supera il gate: 129 problemi di formato
nei soli file peer StudioLinguisticModel/StudioLinguisticView fanno terminare
la verifica prima dei test Core. Il packaging di quella generazione è
interrotto dal coordinatore con exit 143 e non riceve un esito positivo.
Manifest, sorgenti e log della generazione d3ef sono conservati separatamente;
non si presenta quel tentativo come verificato.

Il nuovo freeze ea48ba88 segue soltanto la formattazione canonica Swift dei due
file nel clone isolato, con prova del delta e senza modificare la peer o
indebolire i controlli. Il precedente GREEN nativo non diventa un nuovo test
post-formattazione per rinomina.

Il nuovo `make verify-macos` del checkpoint ea48ba88 termina con **exit 0**.
Passano **592 test Core/Kit** (491 Core e 101 Kit), 194 righe di oracoli, due
PDF/A-2u, **90 controlli CLI su 30 fixture condivise** con parità entro 1e-12,
22 checkpoint recovery e QueryAST. I test nativi Debug contano nuovamente
**104 definizioni e 327 esecuzioni**, tredici parametrizzate con 236 run più
91 non parametrizzate, zero fallite/saltate e `runtimeWarnings: []`;
anche la build Release macOS è superata. Sono esiti di una nuova esecuzione
sul fingerprint congelato dopo la formattazione, non il trasferimento dei
risultati precedenti. Log `verify-macos.log` e riepilogo `final-native-results.json`
nel dossier del checkpoint.

Anche `Scripts/check-app-store-packaging.sh --macos-only` del medesimo
ea48ba88 termina con **exit 0**: analisi Release, archivio macOS senza firma,
metadati Info.plist, privacy manifest e asset sono conformi. Il log
`packaging-macos.log` ha SHA-256
`01d845cadb6e0415c41e8976aa67ab094bf8fd77bf09ce00860270f81b103058`.
La corrispondenza di hash e mode dei 1 072 ingressi è verificata prima e dopo
le corse, senza modificare il checkpoint congelato.

CMP-234 e CMP-235 sono **verified nel solo perimetro automatico del checkpoint
ea48ba88 sulla base 1375950**. Nell'originale legacy 02c1c66 i fix sono applicati
preservando la GUI diversa e gli aggiornamenti concomitanti; il gate appartiene
al checkpoint allineato, non è una certificazione dell'intero checkout condiviso
corrente o di una completezza universale della GUI. Il guard peer più forte
rimane preservato. iPadOS, verifiche manuali e G4 restano esclusi. Dossier finale:
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-ea48ba88/`.


## Limiti

Soli test automatici macOS: nessuna attestazione della GUI reale, VoiceOver,
Voice Control, iPadOS, energia, CI remota o promozione scientifica. I contributi
concorrenti e i dati preesistenti rimangono preservati.
