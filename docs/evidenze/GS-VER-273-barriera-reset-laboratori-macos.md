<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-273 — Barriera di reset dei laboratori macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-273 |
| Tipo | Evidenza di verifica del lifecycle applicativo macOS |
| Versione | 1.3.4 |
| Stato | Superato nel perimetro automatico macOS sul checkpoint ea48ba88 |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | GS-DOR-273; GS-DOR-223; ADR-0041; RQ-011/013/047/058/060/063 |

## Perimetro

La proprietà verificata sul checkpoint ea48ba88 è il mancato ripopolamento di un modello resettato
quando una precedente operazione termina. Sono interessati il laboratorio
avanzato per la nuova correzione; valutazione linguistica/temporale e corpus
sono regressioni dei guard lifecycleID/lifecycleNonce già arrivati dal lavoro
223, preservati senza attribuzione a questo lotto. Il controllo è una
generazione privata del modello, indipendente dalla cancellazione del Task.

La revisione del codice individua il confine async da presidiare; la
riproduzione RED successiva è registrata separatamente sotto. L'ownership Home attuale attende lo stato occupato
prima di cambiare documento: non si attribuisce il difetto a un percorso GUI
osservato. La correzione non annulla Artifact Core già validamente committati.

## Riproduzione RED e attribuzione

La corsa originariamente nominata reset 233 termina con **exit 65**: quattro
definizioni, tre superate e una fallita, zero saltate e `runtimeWarnings: []`.
Il solo RED è `StudioAdvancedAnalysisTests.resetDuringImmediateExecutionPreventsPublicationAndAllowsRetry`,
che raggiunge l'asserzione pertinente sulla pubblicazione invalidata dal reset.
Valutazione linguistica/temporale e corpus sono tre GREEN dei guard già
arrivati dal lavoro 223: non sono tre difetti riprodotti o nuove correzioni
attribuite a questo incremento. Nessun guard è rimosso per costruire RED.

Fixture numeriche reali e Task.immediate sul Main Actor forzano il reset dopo
l'avvio inline e il primo hop concurrent, prima della pubblicazione, senza
Task.cancel, hook produttivi, sleep o yield arbitrari. Riepilogo e sorgenti
sono `233-red-results.json`, `233-red-source-hashes.json` e `233-red.log` nel
dossier storico. La rinumerazione a 235 non crea un'altra esecuzione.

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

Nella fase legacy CMP-233 passa da specified a **implemented nel candidato**. La nuova patch
è limitata ad Advanced; i guard preesistenti di Evaluation e Corpus restano
preservati. Le evidenze 223, 230–232, 234 e 270 mantengono i propri perimetri;
nessuna prova storica, promozione scientifica o chiusura G4/G5 è trasferita.

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

CMP-234 e CMP-233 sono **verified nel solo perimetro automatico del checkpoint
ea48ba88 sulla base 1375950**. Nell'originale legacy 02c1c66 i fix sono applicati
preservando la GUI diversa e gli aggiornamenti concomitanti; il gate appartiene
al checkpoint allineato, non è una certificazione dell'intero checkout condiviso
corrente o di una completezza universale della GUI. Il guard peer più forte
rimane preservato. iPadOS, verifiche manuali e G4 restano esclusi. Dossier finale:
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-ea48ba88/`.


## Limiti

Soltanto test automatici macOS. Nessuna attestazione della GUI reale,
VoiceOver, Voice Control, iPadOS, energia, CI remota o rollback di persistenza.
Il contenuto preesistente e i contributi concorrenti restano preservati.

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
