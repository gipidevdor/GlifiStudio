# Piano di documentazione e profilo degli standard

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DMP-001 |
| Tipo | Documentation management plan |
| Versione | 0.15.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## 1. Scopo

Questo piano definisce struttura, identificazione, controllo, revisione e qualità degli information item di Glifi Studio. Si applica alla documentazione progettuale mantenuta nel repository in formato Markdown.

Il piano attua lo standard dedicato alla [documentazione](standard/19-documentazione.md), parte dello [Standard di progetto Glifi Studio](standard-di-progetto.md). In caso di conflitto, dopo l'approvazione prevale lo standard di progetto.

## 2. Profilo adottato

Il progetto adotta una conformità **tailored**, proporzionata alla fase iniziale e alle dimensioni attuali del progetto:

| Riferimento | Applicazione nel progetto |
| --- | --- |
| [ISO/IEC/IEEE 15289:2019](https://www.iso.org/standard/74909.html) | Tipi di information item, identificazione, stato, controllo e relazione con il ciclo di vita |
| [ISO/IEC/IEEE 29148:2018](https://www.iso.org/standard/72089.html) | Necessità degli stakeholder, requisiti ben formati, attributi, verifica, validazione e tracciabilità |
| [ISO/IEC/IEEE 42010:2022](https://www.iso.org/standard/74393.html) | Entità di interesse, stakeholder, concern, viewpoint, view, model, corrispondenze e rationale |
| [ISO/IEC 25010:2023](https://www.iso.org/standard/78176.html) | Classificazione delle caratteristiche di qualità del prodotto software |
| [ISO 9241-11:2018](https://www.iso.org/standard/63500.html) | Concetti di usabilità, utenti, obiettivi, contesto d'uso, efficacia, efficienza e soddisfazione |
| [ISO 9241-210:2019](https://www.iso.org/standard/77520.html) | Processo di progettazione human-centred, comprensione del contesto, valutazione e iterazione |

ISO/IEC/IEEE 12207:2026 costituisce il riferimento generale per i processi del ciclo di vita, ma questo piano non dichiara la conformità dell'intero processo di sviluppo.

### 2.1 Dichiarazione di conformità

La documentazione è **allineata mediante tailoring** ai riferimenti elencati. Non viene dichiarata conformità piena o certificata perché:

- il progetto è ancora in fase di definizione;
- responsabili e autorità di approvazione non sono stati assegnati;
- criteri quantitativi e baseline di rilascio sono incompleti;
- il repository è inizializzato, ma non esiste ancora una baseline approvata e identificata da tag;
- il testo integrale degli standard deve essere verificato dal responsabile qualità prima di un'eventuale attestazione formale.

Il formato Markdown è un mezzo di registrazione e non modifica gli obblighi informativi del profilo.

## 3. Information item controllati

| Tipo | Identificatore | Contenuto minimo |
| --- | --- | --- |
| Standard interno | `GS-STD-*` | Indice normativo e un documento autonomo per ogni argomento regolato |
| Piano documentale | `GS-DMP-*` | Scopo, riferimenti, tailoring, struttura, controllo e criteri di qualità |
| Identità di progetto | `GS-ID-*` | Nome canonico, identificatori tecnici, regole d'uso ed eccezioni di provenienza |
| Visione e stakeholder needs | `GS-VIS-*` | Contesto, obiettivi, stakeholder, necessità, confini, assunzioni |
| Specifica requisiti software | `GS-SRS-*` | Contesto, interfacce, vincoli, requisiti e attributi di verifica |
| Specifica dei metodi analitici | `GS-MET-*` | Semantica, formule, input/output, precondizioni, determinismo, provenienza e verifica dei metodi scientifici |
| Specifica dell'esperienza utente | `GS-UX-*` | Modello mentale, intenzioni, indagine, planner, catena epistemica, navigazione, accessibilità e validazione human-centred |
| Specifica di design implementativo | `GS-DOM-*`, `GS-DAT-*`, `GS-LNG-*`, `GS-QRY-*`, `GS-ANA-*`, `GS-RUN-*`, `GS-UI-*`, `GS-VIZ-*`, `GS-VAL-*`, `GS-PROD-*` | Contratto eseguibile di un solo sottosistema o baseline, con invarianti, stati, interfacce e criteri di conformità |
| Specifica di sicurezza | `GS-SEC-*` | Asset, assunzioni, trust boundary, minacce, controlli, rischio residuo e verifiche |
| Specifica API | `GS-API-*` | Superficie, lifecycle, concorrenza, failure, versionamento e protocollo headless |
| Matrice di tracciabilità | `GS-TRC-*` | Collegamenti bidirezionali tra fonti, necessità, requisiti, design e verifica |
| Descrizione architetturale | `GS-AD-*` | Entità, stakeholder, concern, viewpoint, view, corrispondenze e rationale |
| Glossario | `GS-GLO-*` | Termini, definizioni e abbreviazioni condivise |
| Politica di licenza | `GS-LIC-*` | Licenza applicabile, copyright, contributi e materiali di terzi |
| Piano | `GS-PLAN-*` | Obiettivi, attività, risultati attesi, dipendenze e criteri di uscita |
| Governo repository | `GS-REP-*` | Accessi, integrazione, configurazione del provider, CI, segreti, backup e visibilità |
| Piano App Store | `GS-AS-*` | Distribuzione, identità, metadati, privacy, accessibilità, TestFlight, qualità, review e rilascio |
| Registro problemi | `GS-ISS-*` | Questione, motivazione, evidenza richiesta, responsabile e stato |
| Decisione architetturale | `GS-ADR-*` | Contesto, decisione, stato, alternative e conseguenze |
| Evidenza di verifica | `GS-VER-*` | Revisione, ambiente, procedura, risultato osservato, esito ed esecutore |
| Deroga controllata | `GS-WVR-*` | Regola, ambito, durata, rischio, mitigazione, verifica compensativa e rientro |

### 3.1 Granularità documentale

Ogni documento controllato **DEVE** trattare un solo argomento principale. Le sottosezioni sono ammesse soltanto quando specificano aspetti inseparabili dello stesso argomento. Un documento che acquisisce una seconda responsabilità indipendente **DEVE** essere separato e l'indice applicabile deve essere aggiornato nello stesso cambiamento.

Gli indici non duplicano il contenuto normativo: forniscono identità, stato, ordine di lettura e collegamenti ai documenti che governano.

Una famiglia scientifica **DEVE** mantenere un documento per ciascun argomento
analitico autonomo. L'indice della famiglia definisce contratto comune, autorità e
relazioni, ma non duplica le formule dei documenti specialistici.

La famiglia UX **DEVE** separare responsabilità cognitive e d'interazione autonome.
Non duplica formule GS-MET, regole Apple o requisiti: li collega dichiarando
rispettivamente significato scientifico, comportamento di piattaforma e obblighi
verificabili.

La famiglia di design **DEVE** contenere un documento autorevole per ciascuno dei
dieci concern registrati in GS-DSG-IDX-001. L'indice mantiene confini e dipendenze,
non requisiti o norme duplicati. Una nuova specifica richiede ADR che dimostri che
il concern non appartiene già a un documento esistente.

Sicurezza e API sono concern trasversali autonomi governati rispettivamente da
GS-SEC-001 e GS-API-001. Nuovi documenti di design sono scoraggiati finché la
lacuna può essere chiusa rafforzando un contratto esistente o producendo evidenza.
Fixture, benchmark e la matrice JSON di conformità sono artefatti verificabili, non
nuove specifiche di prodotto.

## 4. Metadati obbligatori

Ogni information item controllato deve riportare:

- identificatore univoco e stabile;
- tipo di documento;
- versione;
- stato;
- responsabile;
- data dell'ultima modifica in formato ISO 8601 (`YYYY-MM-DD`);
- stato dell'approvazione.

Se un dato non è noto, viene indicato esplicitamente come `Da assegnare` o `Da definire`; il campo non viene omesso.

## 5. Stati e approvazione

Il ciclo di stato è:

```text
Bozza → In revisione → Approvato → Sostituito
```

`Respinto` può essere usato per proposte e ADR che non entrano in vigore. Soltanto un'autorità nominata può approvare una baseline. Fino a quel momento, i contenuti derivati dagli appunti sono **baseline candidate**.

## 6. Versionamento

I documenti usano `MAJOR.MINOR.PATCH`:

- `MAJOR`: modifica incompatibile a scopo, contratto o baseline approvata;
- `MINOR`: aggiunta o modifica sostanziale compatibile;
- `PATCH`: correzione editoriale senza cambiamento normativo.

La storia dettagliata dovrà essere affidata al controllo versione. A ogni baseline approvata deve corrispondere un tag o altro identificatore immutabile.

Le versioni riportate nei documenti sono identificatori logici; la storia Git ne
registra le modifiche, ma non costituisce da sola approvazione di una baseline.

## 7. Linguaggio normativo

Nei documenti controllati:

- **DEVE** indica un obbligo verificabile;
- **NON DEVE** indica un divieto verificabile;
- **DOVREBBE** indica una raccomandazione dalla quale ci si può discostare motivando la scelta;
- **PUÒ** indica una possibilità, non un requisito.

Formulazioni descrittive, aspirazionali o contenenti “idealmente”, “quando utile” e “ragionevolmente” non costituiscono requisiti verificabili finché non vengono precisate.

## 8. Regole per i requisiti

Ogni requisito deve:

1. avere un identificatore permanente;
2. esprimere una sola obbligazione principale;
3. identificare il soggetto e usare linguaggio normativo;
4. essere necessario, privo di ambiguità, fattibile e verificabile;
5. dichiarare fonte, rationale, stato, priorità e metodo di verifica;
6. avere un criterio di accettazione misurabile o una questione aperta associata;
7. essere tracciato verso una necessità e, quando disponibili, design e prova.

Modificare il testo di un requisito approvato richiede una revisione d'impatto. Il suo identificatore non viene riutilizzato per un significato differente.

## 9. Regole per la descrizione architetturale

La descrizione deve identificare:

- entità di interesse e finalità della descrizione;
- stakeholder e concern pertinenti;
- viewpoint adottati e convenzioni di ciascuno;
- view e model che rispondono ai concern;
- corrispondenze e invarianti tra le view;
- decisioni, alternative, rationale e questioni aperte.

Ogni decisione significativa viene collegata a un ADR. Ogni viewpoint deve dichiarare stakeholder, concern, notazione e criteri di coerenza.

### 9.1 Regole per le specifiche scientifiche

Ogni metodo analitico deve dichiarare almeno significato, dominio, input, output,
parametri risolti, precondizioni, formula o procedura versionata, casi degeneri,
proprietà, determinismo, provenienza e confronto indipendente. Una citazione
bibliografica supporta il rationale ma non sostituisce la variante eseguibile.

### 9.2 Regole per le specifiche UX

Ogni elemento UX deve dichiarare modello mentale, oggetti, stati, azioni, errori,
progressive disclosure, accessibilità, localizzazione e verifica applicabili. Un
wireframe supporta la valutazione, ma non sostituisce semantica, requisiti o prova
con persone rappresentative. Il linguaggio dell'esperienza non deve alterare la
terminologia normativa dei metodi.

### 9.3 Regole per le specifiche di design

Ogni specifica di design deve indicare scopo, confine di autorità, invarianti,
stati o flussi, contratti tra componenti, comportamento di errore e criteri di
conformità. Scelte irreversibili o costose devono rinviare a un ADR; valori
quantitativi non validati devono essere marcati come baseline da calibrare.

## 10. Tracciabilità

La tracciabilità minima è:

```text
fonte → necessità stakeholder → requisito software
      → elemento/decisione architetturale → verifica
```

La matrice deve consentire anche la lettura inversa. Un requisito senza fonte o verifica è incompleto; un elemento architetturale senza requisito o concern associato deve avere una motivazione esplicita.

## 11. Revisione e quality gate

Prima dell'approvazione di un documento devono essere verificati:

- presenza e coerenza dei metadati;
- assenza di collegamenti interni interrotti;
- identificatori univoci;
- termini definiti e uso coerente del linguaggio normativo;
- copertura di stakeholder e concern applicabili;
- verificabilità e tracciabilità dei requisiti;
- risoluzione o registrazione esplicita delle ambiguità;
- coerenza con ADR vigenti e altri documenti approvati;
- correttezza dimensionale e matematica di formule, casi nulli e precondizioni;
- distinzione tra dati osservati, trasformazioni, stime, inferenze e generazione;
- presenza di oracoli, fixture o proprietà verificabili indipendentemente;
- tracciabilità fra necessità, intenzioni, flussi, modello del dominio e studi UX;
- comprensibilità di findings, incertezza e caveat con tecnologie assistive.

## 12. Gestione delle fonti iniziali

`appunti-1.txt` e `appunti 2.txt` sono record di input non controllati. Vengono preservati senza modifiche, ma non costituiscono una baseline. I contenuti importati nella documentazione controllata mantengono il riferimento alla fonte e restano candidati finché non approvati.
