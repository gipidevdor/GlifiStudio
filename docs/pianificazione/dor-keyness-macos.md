<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Confronto keyness completo nel client macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-198 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.1.1 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Nuova richiesta di miglioramenti e completamenti; estensione E di ADR-0033 e ponte Kit del livello di confidenza approvato |
| Riferimenti | RF-031; RF-045; RQ-003; RQ-011; RQ-013; RQ-026; RQ-028; RQ-058; GS-MET-001-08; GS-UX-001-07/17; GS-VER-118 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Completare il confronto diretto nell'Indagine macOS: tutta la famiglia keyness v2 in pagine, popolazioni e richiesta effettiva, test selezionato e intervalli già prodotti da Kit; sostituire l'anteprima di venti righe, senza nuova destinazione, algoritmo o formato |
| requisiti | RF-031/RF-045 e RQ-003/011/013/026/028/058; conteggi, denominatori, test, effect size, correzione, intervalli e diagnostica distinti; nessuna selezione di significatività o nuova inferenza nel client |
| dominio/API | `compareKeyness` persistente, gruppi target/riferimento espliciti, non vuoti e disgiunti; corpus options standard. Ponte Kit del `confidenceLevel` Core esistente: proprietà pubblica, init pubblico a due argomenti conservato esattamente e inoltrato con 0,95, nuovo init a tre argomenti senza default; compatibilità anche dei riferimenti a funzione a due argomenti |
| failure semantics | Opzioni non valide e limiti rifiutati dalle failure Kit esistenti senza clamp; gruppi mancanti/sovrapposti falliscono come già previsto. Il contenimento app prima della presentazione usa `ui.keyness.invalid-result`, categoria `corruption`, operazione `analyze`, retry `never`, stato `lastCommittedGeneration` e chiave `failure.keyness.invalid-result`; risultato, richiesta effettiva, pagina e snapshot precedenti conservati; `runAnalysis` mantiene cancellazione, ownership e cleanup terminale; commit valido non convertito in falsa failure |
| esperienza prevista | GS-UX-001-17 E nel Form dell'Indagine esistente, sezioni native macOS e testo it/en; tre parametri configurabili con default dichiarati, dettagli metodologici progressivi, tutta la famiglia paginata; iPadOS conserva il flusso esistente |
| verifica | Nuovo `Apps/macOS/Tests/StudioKeynessTests.swift`: parità completa Kit e riuso, popolazioni e opzioni effettive immutabili, selezione Fisher/G-test e intervalli, tutte le pagine oltre venti termini, pagina diretta/ultima/invalida, failure e stato precedente, cancellazione con retry e reset progetto. `StudioKeynessValidationTests.swift` contiene DTO mutati per il helper, distinti da prove end-to-end sul package. `GlifiKeynessOptionsTests.swift` verifica la facciata: init a due/tre argomenti, riferimento a funzione con due argomenti, confidence default/modificata/non valida. Nuovo freeze e gate/preflight macOS, GS-VER-198 candidata |
| dati e migrazione | Profilo `keyness-gtest-fisher-ha-ci-bh-v2`, Artifact v2 e digest già includono il livello Core; nessuna migrazione, nuova formula o schema. Draft, richiesta UI e pagina sono effimeri e ripuliti al cambio progetto |
| sicurezza/privacy | Solo revisioni già autorizzate del progetto; nessuna rete, dipendenza, entitlement o contenuto nei log; la UI non inventa occorrenze, metadati o intervalli sorgente |
| prestazioni/sistema | Calcolo e I/O restano nei confini Kit; validazione bounded della presentazione in helper nonisolated `@concurrent` prima di pubblicare lo stato; rendering di cinquanta termini per pagina, nessun ricalcolo numerico, ordinamento globale o scansione fonte×termine sul Main Actor; nessuna attesa attiva o matrice densa |
| tracciabilità | CMP-198 inizialmente `specified`; RF-031/RF-045 e TV-031/TV-058/TV-071; ADR-0033, UX17, programma, evidenza e CHANGELOG nello stesso incremento; nessuna promozione prima del gate |
| decisioni e recupero | Estensione E e addizione compatibile Kit registrate prima del codice; rollback del client senza migrazione; preservati i lotti 196/197 e gli altri programmi. Nessuna riapertura dei kernel scientifici o delle loro attestazioni |

## Parametri e regole separate

I controlli iniziali usano `maximumHypothesisCount = 100 000`,
`lowExpectedCountThreshold = 5` e `confidenceLevel = 0,95`. Il primo è un Int
non negativo, il secondo è finito e non negativo, il livello è finito e
strettamente compreso fra zero e uno. I valori non vengono corretti
silenziosamente né ridotti ai soli valori dell'interfaccia precedente.
L'ammissione formale del parametro non promette che ogni Double rappresentabile
consenta il successivo calcolo: livelli estremamente prossimi a uno possono
produrre la failure numerica tipizzata esistente `statistics.invalid-probability`.
Il client la conserva senza clamp o intervalli inventati.

La soglia diagnostica configurabile determina `hasLowExpectedCount` e non
modifica `FisherSelection-min-expected-5-v1`: la scelta del test usa sempre il
minimo atteso minore di cinque. G-test e Fisher non sono alternative selezionate
a posteriori dall'utente. Il livello configura gli intervalli Katz/Woolf già
definiti, non un nuovo metodo statistico.

## Popolazioni, famiglia e presentazione

E usa i due gruppi del confronto esistente, distinti dall'ambito tutte/selezionate
di A–D. L'assegnazione normale a un gruppo rimuove la revisione dall'altro;
controlli di dominio continuano a rifiutare sovrapposizioni e gruppi mancanti.
Etichetta Fonte N e identità della revisione sostituiscono il nome originale
quando questo non è disponibile. Modificare i draft dopo un successo non
modifica popolazioni, opzioni o lineage effettivi del risultato precedente.

Sono accessibili tutti i termini, cinquanta per pagina, nell'ordine Kit:
valore assoluto del log ratio decrescente e termine crescente come tie-break.
Pagina diretta, precedente/successiva e ultima non ricalcolano l'analisi;
pagina non valida non cambia lo stato. La paginazione non tronca il risultato,
non filtra i p-value e non riduce la famiglia Benjamini–Hochberg.

Per termine si conservano conteggi e tassi, direzione, G e gradi di libertà,
test selezionato, p selezionato, p del G-test, q BH, log ratio e odds ratio HA,
entrambi gli intervalli e diagnostica delle attese. Metodi, livello, correzione,
ordinamento e lineage restano ispezionabili. Valori piccoli positivi non sono
presentati come zero per semplice arrotondamento a un numero fisso di decimali.
Nessun badge universale di affidabilità o dichiarazione automatica di
significatività viene introdotto.

## Contenimento applicativo

Prima di pubblicare risultato, richiesta effettiva, pagina o snapshot, un helper
app asincrono fuori dal Main Actor verifica i bounds della presentazione,
popolazioni e opzioni rispetto alla richiesta, identità non ambigue dei termini
e domini dei valori necessari alla UI. Una failure non pubblica stato parziale
né attribuisce read-only recovery al package. I guard non ricalcolano test,
correzione BH o intervalli e non certificano la semantica universale degli
Artifact. I test del helper su DTO alterati restano distinti da una prova di
apertura del package corrotto.

I controlli strutturali dichiarati sono:

- popolazioni uguali alla richiesta, non vuote, uniche e disgiunte; livello e
  soglia diagnostica uguali alle opzioni effettive, cardinalità entro il limite
  di ipotesi e totali di token positivi;
- termini non vuoti e unici nell'ordine dichiarato; frequenze comprese fra zero
  e il totale del gruppo, almeno una positiva per termine, somme uguali ai
  totali con aritmetica che rileva overflow;
- tassi, p selezionato, p del G-test e q finiti in `[0, 1]`; G finito non
  negativo, un grado di libertà e minimo atteso finito positivo;
- odds ratio e relativi estremi positivi finiti; log ratio ed estremi finiti;
  per entrambi estremi ordinati che contengono la stima puntuale entro la
  tolleranza D1 dichiarata, fino a otto ULP o 1e-12 per gli arrotondamenti,
  calcolata separatamente per ciascun lato usando soltanto stima ed estremo
  di quel lato, senza amplificarla con l'estremo opposto;
- direzione nel dominio chiuso target/riferimento/uguale e test selezionato
  G-test oppure Fisher; identità del profilo v2, selezione Fisher, Katz, Woolf,
  BH e altre policy dichiarate corrispondenti al contratto corrente, senza
  interpretare in anticipo eventuali versioni future.

Questi controlli non ricalcolano rapporti, test, p/q-value o intervalli. I numeri
non finiti non vengono introdotti tramite strategie JSON speciali: i relativi
guard sono revisionati distintamente dai DTO mutati decodificabili normalmente.
Il contenimento non ammette una stima 0,04 sotto un limite inferiore 1 solo
perché l'estremo superiore è 1e308: la tolleranza dell'altro lato non si propaga.

## Dipendenza di correttezza

GS-DOR-199 corregge identità del descrittore e admission della cache keyness:
il livello deve essere risolto nel nodo e corrispondere al risultato; il limite
della famiglia si applica anche al riuso. Il lavoro applicativo 198 può
proseguire, ma non è chiuso senza la verifica di tale dipendenza. Si tratta di
metadati/validazione, non di un nuovo kernel o formato persistente.

**Ready** prima di modello, UI, test e ponte Kit. L'unità usa prove automatiche
e un nuovo snapshot; non estende retroattivamente il gate del lotto precedente.
Finestre reali, VoiceOver, autosave, file provider, iPadOS e G4 restano distinti.
