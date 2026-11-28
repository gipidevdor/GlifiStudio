<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0048 — Studio documentale e taccuino verificabile

| Campo | Valore |
| --- | --- |
| Identificatore | ADR-0048 |
| Versione | 1.0.0 |
| Stato | Accettata per il perimetro autorizzato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di procedere con lo studio dei documenti, ponendo al centro contenuto e conclusioni |
| Data | 2026-11-28 |
| Decisore | Iniziatore del progetto, richiesta esplicita corrente |
| Riferimenti | GS-DOR-344; GS-API-007; GS-UX-001-18; GS-STD-001-11; ADR-0027; ADR-0028; ADR-0047 |

## Contesto

La codifica qualitativa conserva categorie, codifiche e memo, ma non rappresenta
un taccuino di passaggi indipendenti dalle categorie. Il primo incremento di
studio autorizzato collega lettura, raccolta di passaggi e conclusioni personali.
Il contenuto del documento deve dominare l'interfaccia; confronto e organizzazione
sono strumenti progressivi. Le funzioni statistiche esistenti restano distinte.

## Decisione

Si aggiunge uno stato autorevole di studio con estratti, note/conclusioni, gruppi,
ordine, al massimo due estratti di confronto e associazione opzionale a un'indagine.
Una conclusione può collegare più estratti. È contenuto scritto dalla persona:
non diventa automaticamente Evidence, Finding o risultato di un algoritmo.

Gli estratti conservano revisione immutabile, digest originale, identità e digest
della rappresentazione estratta, intervallo UTF-8 half-open e citazione esatta.
Il ritorno alla fonte usa la revisione archiviata e i locatori reali, senza OCR o
analisi nuovi. Per PDF si usa PDFKit sul byte originale verificato; il salto di
pagina non implica una geometria di evidenziazione assente. La raccolta avviene
dal testo estratto verificabile. Nessuna fonte originale viene modificata.

Lo stato usa Artifact immutabili concatenati nel package esistente, descriptor v2
con scope vuoto e controllo ottimistico della revisione. Le dipendenze alle fonti
sono riferimenti verificati nel payload: l'aggiunta di altre fonti non elimina
il lavoro. Nessun nuovo contenitore, schema SQLite, backend o dipendenza.
GS-API-007 governa sei operazioni condivise Core/Kit/CLI e i limiti.

## Compatibilità, migrazione e recupero

Il lettore corrente diventa 4. `minimumReaderVersion` sale a 4 soltanto al primo
commit di studio e non viene successivamente abbassato. Progetti testo, documenti
ricchi e ricerca senza studio mantengono rispettivamente i requisiti 1, 2 e 3.
Aprire un progetto precedente non ne riscrive i byte né crea uno stato persistente.
Un lettore precedente rifiuta esplicitamente lo studio invece di ignorarlo.

Il payload `studio.glifi.artifact.study-state.v1` identifica schema e versione,
nodo, predecessore e revisione. Letture e scritture verificano catena, digest,
identità, riferimenti e limiti prima dell'uso. Versioni sconosciute, corruzione e
anchor incoerenti sono errori tipizzati; non si corregge silenziosamente una citazione.
Un errore o una cancellazione non pubblicano una revisione parziale. Resta il
recupero generazionale verificato del package; una futura migrazione incompatibile
richiede ADR e copia transazionale verificata. L'export JSON canonico conserva
progetto e stato; il ripristino riguarda lo stesso progetto con revisioni presenti,
senza importare fonti assenti o ricalcolare analisi. Markdown è un'esportazione
leggibile, non il formato autorevole di ripristino.

## Conseguenze e verifica

Nessuna rete, sincronizzazione, entitlement o lingua di analisi aggiuntiva.
Lavagna libera, collegamenti spaziali, scrittura a mano e collaborazione sono
fuori da questo primo incremento. Test BDD RED/GREEN precedono il dominio;
suite Core/Kit/CLI e native verificano provenienza, conflitti, ripristino, selezione
Unicode e lifecycle. La verifica macOS e gli audit di usabilità/assistivi sono
registrati separatamente, senza anticiparne l'esito.
