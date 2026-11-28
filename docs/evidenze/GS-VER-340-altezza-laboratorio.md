<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Verifica — Osservazione dell'altezza del laboratorio statistico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-340 |
| Tipo | Evidenza di correttezza del layout macOS |
| Versione | 1.0.0 |
| Stato | RED/GREEN interattivo e gate automatici macOS superati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Verifica mirata richiesta dopo l'osservazione GUI GS-VER-339 |
| Riferimenti | [GS-DOR-340](../pianificazione/dor-altezza-laboratorio.md); GS-VER-339; GS-APL-002; GS-APL-003; CMP-340 |

## Esito

**Il difetto è reale e riprodotto nel contenitore DocumentGroup dell'app.**
Una sonda passiva, compilata in un worktree separato con le stesse risorse e
viste, misura il frame della finestra documento da 1280 × 800 a 1280 × 2265
punti, contro 1179 punti disponibili nello schermo. Con scala backing 2,
la cattura di 2560 × 4530 pixel coincide esattamente con il frame nativo.
La selezione Welch dal catalogo basta a riprodurlo, prima del calcolo.

L'ipotesi iniziale riguardava il minimo verticale trasmesso da HSplitView ai
pannelli. Il primo candidato, quattro frame verticali flessibili su split,
tab e Form, non modifica il risultato: 2265 punti anche in una nuova sessione.
È scartato. Il secondo candidato sposta GeometryReader attorno all'intera
VStack: intestazione, Divider e pannelli ricevono così il viewport effettivo.
È verificato nella finestra reale e applicato, identico byte per byte, al
sorgente produttivo. Nessun numero fisso limita l'altezza.
Form grouped dispone già di scorrimento secondo la
[documentazione Apple](https://developer.apple.com/documentation/SwiftUI/GroupedFormStyle):
non è stato aggiunto uno ScrollView annidato né un limite fisso d'altezza.

## Probe hostless iniziali e loro limiti

Il probe usa NSHostingController con `sizingOptions = [.minSize]` in una
NSWindow posseduta, viewport richiesto 1280 × 800 punti, layout e letture
pubbliche di `contentMinSize` e `contentRect(forFrameRect:)`. Non usa sleep,
Mirror, selettori privati o interfacce AX interne. La finestra viene chiusa
in `defer`. Le combinazioni sono italiano/inglese e Dynamic Type large/accessibility3;
questi parametri non attestano la localizzazione effettiva dell'app nel runner.

| Tentativo | Esito del runner | Misure osservate | Interpretazione |
| --- | --- | --- | --- |
| Isolato iniziale | EXIT65; 1 definizione, 4 esecuzioni fallite, 8 issue | L'assegnazione del controller sostituisce il viewport iniziale con 1 × 0; dopo l'await del calcolo il minimo è 32 × 409; il resize esplicito accetta 1280 × 800 | Errore di setup del probe, non RED del prodotto |
| Isolato con viewport assegnato dopo il controller | EXIT0; 1 definizione, 4 esecuzioni superate | Contenuto 1280 × 800 in tutte le fasi; minimo verticale 0 durante alcune prime letture, 409 dopo il calcolo | Nessuna riproduzione dell'altezza segnalata |
| Isolato e wrapper del workspace | EXIT65; 2 definizioni, 8 esecuzioni, 4 superate e 4 fallite, 12 issue | Isolato invariato; il wrapper restituisce contenuto alto 832 punti e minimo alto 433; dopo resize il contenuto torna a 800 | Scarto di 32 punti nel contenitore di navigazione, non riproduzione di un minimo smisurato |

Le fasi osservate sono vista iniziale, selezione Welch con esempio sintetico,
risultato e ridimensionamento. Il wrapper riproduce sidebar, contesto adattivo
del progetto e VStack di dettaglio di Home con identificatori sintetici;
**non include DocumentGroup, ripristino della scena o finestra del prodotto reale**.

Il runner hostless emette diagnostiche CoreUI riferite al bundle dell'agente
Xcode e geometrie transitorie. I Text del laboratorio usano il bundle predefinito:
la sola variabile `locale` non prova l'uso delle traduzioni dell'app. Questo
limite impedisce di qualificare il layout localizzato o di interpretare lo
scarto del wrapper come regressione del prodotto. Nessuna modifica alle attese
nasconde questi esiti.

## Misure nella finestra documento reale

La sonda aggiunge soltanto observer di notifiche NSWindow e un monitor locale
del click che restituisce l'evento invariato. Legge frame, contentLayoutRect,
contentMinSize, backingScaleFactor, screen.frame/visibleFrame e geometrie
pubbliche dei contenitori di scorrimento. Non modifica il layout, non usa
timer, API private o automazione UI alternativa; tutte le interazioni passano
da CUA. Il nuovo avvio e il digest del binario distinguono ogni candidato.

| Fase | Frame finestra (punti) | Minimo verticale osservato | Spazio verticale disponibile |
| --- | --- | --- | --- |
| Documento aperto, Panoramica | 1280 × 800 | 0 nella prima notifica | 1179 |
| Transizione alla statistica | 1280 × 1179 | 128 nella notifica transitoria | 1179 |
| Welch selezionato, prima del calcolo | 1280 × 2265, origine y = −1035 | 2265 | 1179 |
| Primo candidato, nuova sessione | 1280 × 2265, origine y = −1035 | 2265 | 1179 |
| Secondo candidato, Welch e dettagli | 1280 × 800 | 128 | 1179 |
| Secondo candidato, finestra affiancata compatta | 1120 × 1179 | 128 | 1179 |

Min/max possono essere sentinel o ignorati con Auto Layout: il RED si fonda
sul frame effettivo confrontato con visibleFrame, non sulla sola proprietà
minSize. Il click automatico al centro dell'etichetta non aziona il disclosure:
il triangolo visibile viene poi cliccato direttamente e cambia a `on`,
mostrando le otto osservazioni e i parametri localizzati. Questo limite del
targeting automatico è distinto dal difetto dimensionale reale.
Il dossier conserva i log grezzi localmente; la sintesi sanificata esclude
titoli, percorsi, PID e identificatori di sessione. La visita parziale delle
view e l'I/O diagnostico sincrono non costituiscono benchmark né inventario
esaustivo di contenitori. La sonda non entra nel codice da consegnare.

## Correzione e GREEN interattivo

Il cambiamento contiene soltanto il riordino di GeometryReader e VStack;
Form grouped, split, tab compatte, binding, azioni e larghezze restano gli
stessi. Il sorgente verificato ha SHA256
`33d7a048a27ecc1abe384c799c93464c15638fd7f06f079a6d0dd90f8bf33524`.
La causa è circoscritta alla misura dell'intestazione fuori dal contenitore
flessibile; l'esatta proposta di larghezza che produceva l'andata a capo
durante il calcolo del minimo resta un'inferenza, non una misura acquisita.

Con finestra 1280 × 800, il contentLayoutRect resta 1280 × 748 e i Form
dispongono di 635,5 punti verticali. Il documento dei risultati aperti arriva
a 1743 punti, conservando lo stesso viewport: lo scroll è effettivo. La cattura
torna a 2560 × 1600 pixel. Sono eseguiti caricamento dell'esempio sintetico,
Calcola, apertura del triangolo, scorrimento dei parametri e apertura del
pannello nativo Export, poi annullato senza scrivere un file.

Il comando nativo Finestra → Sposta e ridimensiona → A sinistra porta a
1120 × 1179 punti, dentro visibleFrame. Il layout passa alle tab compatte;
Impostazioni conserva i dati e Cmd-Invio esegue Calcola e apre Risultati.
Dettagli, scorrimento ed Export funzionano anche qui. Il documento lungo
1515 punti scorre in 936,5 punti; la cattura è 2240 × 2358 pixel.

I tre risultati Welch restano `0,593390829097`, `5,74363843524` e
`0,575523078328`; il digest della richiesta resta
`23e77fae2b418886875596520ecc34f6b379100c00a860aa0a7a868d3334f90c`.
Le letture geometriche non provano da sole questi comportamenti: sono
completate dalle azioni e dagli stati AX osservati tramite CUA.

## Artefatti e confini

Il dossier locale `macOS-2026-11-27-ui-audit` conserva:

- `statistics-layout-340-probe.swift`, SHA256 `2e0dcbaef1c79b6b9c2aeb5f892efe4e6edd47178dfa0b439477807c1434c567`;
- `native-layout-340-isolated`, `native-layout-340-isolated-2` e `native-layout-340-final`, ciascuno con log chiuso, xcresult e JSON summary/tests;
- `native-layout-340-observations.json`, con misure e digest dei log.
- log della finestra documento prima e dopo, due patch candidate e sorgente
  diagnostico separato, con sintesi geometriche sanificate. Le misure decisive,
  i digest e le osservazioni manuali sono nell'[allegato](allegati/GS-VER-340-layout.json).

Il probe e i suoi soli collegamenti temporanei Xcode sono rimossi dal gate
permanente dopo aver conservato gli artefatti. **Nessun controllo preesistente
è rimosso.** Restano il bridge di localizzazione e i due test GS-VER-339 già
verificati in quattro esecuzioni effettive; la formattazione del laboratorio
richiesta nello stesso lotto è preservata.

I soli esperimenti hostless non attestano raggiungibilità delle azioni, scorrimento reale,
VoiceOver, Voice Control, interazione da tastiera, iPadOS, prestazioni o
qualificazione del rilascio. Il GREEN successivo copre la finestra italiana
nelle due geometrie dichiarate, senza qualificare altre lingue, tutti i
laboratori o gli estremi Dynamic Type. L'introduzione conserva fixedSize
verticale: il testo grande e i viewport inferiori richiedono un audit dedicato.
La clausola resta implemented; G4/G5, VoiceOver e Voice Control restano aperti.

Il riscontro conclusivo nella Release produttiva priva della sonda conferma
selezione Welch, calcolo e dettagli aperti, senza crescita della cattura
oltre 2560 × 1600 pixel. Gate finale, fingerprint e conteggi sono registrati
in [GS-VER-339](GS-VER-339-localizzazione-interattiva.md).
