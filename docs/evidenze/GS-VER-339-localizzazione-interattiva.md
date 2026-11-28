<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-339 — Localizzazione verificata nell'interfaccia macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-339 |
| Tipo | Evidenza di correttezza della presentazione |
| Versione | 1.0.0 |
| Stato | RED/GREEN interattivo e gate automatici macOS superati |
| Responsabile | Codex con revisione separata del ponte e del rendering |
| Ultima modifica | 2026-11-28 |
| Approvazione | Ripresa della verifica dopo lo sblocco del Mac |
| Riferimenti | GS-DOR-339; GS-I18N-002; GS-VER-335; GS-VER-336; CMP-339 |

## Difetto e correzione circoscritta

L'app Release con fingerprint `91ee8fd5…` mostra nel selettore Welch,
nell'istruzione dei dati, nell'alternativa e nel titolo del risultato le chiavi
tecniche anziché le etichette italiane. Catalogo e risorse it/en compilate
contengono già le traduzioni: la sola verifica della loro presenza non rileva
il difetto. Il costruttore interpolato tratta il suffisso come argomento di
un template, invece che parte dell'identificatore completo.

`StudioLocalization.key/value` impone la costruzione del `String` prima del
ponte SwiftUI/Foundation. Sono corrette **37 occorrenze SwiftUI e due
Foundation** in statistiche, operatori, analisi avanzate, corpus, linguistica,
piani, evidenze ed etichette accessibili dell'export. I messaggi con numeri interpolati conservano la loro forma
localizzabile; non sono risolti tramite concatenazione. Non cambiano Core,
Kit, CLI, cataloghi, valori scientifici, digest o formati persistenti.

Il controllo statico riproduce prima le 36 occorrenze vere, poi le due
Foundation; dopo la correzione passa. La review finale individua inoltre
`Text("export.format.\(format)")` nell'etichetta accessibile dei formati:
anche il costruttore diretto interpola un template. La guardia estesa rileva
questa sola occorrenza reale (RED exit 1), poi passa dopo il ponte (GREEN
exit 0). Diciotto esempi positivi e negativi verificano stringhe complete,
righe multiple, testo verbatim e argomenti legittimi. La scansione di
`Text`, `Label` e `Picker` non trova altri prefissi semantici diretti nello
stesso pattern; non pretende di analizzare tutta la grammatica Swift.
I documenti Apple citati in GS-I18N-002 sono usati come riferimento API;
ponte, fixture e attese sono originali.

## Prove native e limiti del metodo

La versione iniziale dei due test è eseguita realmente in italiano e inglese: **due
definizioni, quattro esecuzioni**, senza failure o skip. Il primo risolve
alternative e livelli con Foundation e bundle lproj espliciti. Il secondo
confronta la dimensione nativa di otto testi con attese verbatim indipendenti,
font e locale uguali; due controlli negativi per lingua distinguono i vecchi
costruttori interpolati. Questo confronto dimensionale non prova da solo
identità di testo o semantica accessibile: risoluzione Foundation e osservazione
GUI completano la prova circoscritta. Le stesse due definizioni sono poi
estese ai quattro formati JSON, Markdown, CSV e PDF/A-2u: risoluzione esatta
Foundation, dodici testi renderizzati complessivi e sei controlli negativi
per lingua, inclusi i quattro vecchi `Text` diretti. Questa estensione passa
nel nuovo risultato nativo finale: 146 definizioni e 439 esecuzioni totali,
senza failure o skip; le due definizioni estese hanno quattro esecuzioni
it/en effettive. Il gate integrato resta distinto dal solo GREEN statico. I log JSON `dynamic-text-key-red.json` e
`dynamic-text-key-green.json` nel dossier registrano comandi, hash e scansione.

Un primo filtro seleziona zero test: non è un GREEN. Un tentativo di leggere
sincronicamente l'albero AX dal solo NSHostingView hostless restituisce un
albero vuoto e fallisce (exit 65); non è un RED del prodotto. Il tentativo
non attuabile è sostituito dal confronto di rendering con API pubbliche,
conservando log e confine della prova; nessun controllo precedente è rimosso,
nessun accesso privato, sleep, skip o permesso AX aggiuntivo è introdotto.
L'albero accessibile dell'app reale è ispezionato tramite CUA, separatamente.

## Osservazioni interattive

Sul progetto sintetico salvato dall'interfaccia sono osservati:

- ricerca senza progetto con azione Salva funzionante; progetto senza fonti
  con azioni Importa e Fonti;
- catalogo da Cmd-K: `media` dà sette risultati e Invio conserva il catalogo;
  `Confrontare due medie` dà un solo risultato e Invio apre Welch;
- import TXT e Markdown, conteggi coerenti, query `mare` con tre e poi quattro
  occorrenze; query `vento` con due risultati e selezione della seconda fonte
  coerente con il Markdown originale;
- bozza modificata distinta dalla ricerca eseguita; `vento AND` produce
  `query.unexpected-token`, categoria invalidInput, retry afterCorrection e
  stato unchanged, conservando risultati e fonte; retry riuscito e Cmd-S;
- riapertura del progetto nella build Debug corretta con due fonti;
  selettore Welch, istruzioni, alternativa Bilaterale e titolo del risultato
  tradotti correttamente. I tre valori numerici e il digest della richiesta
  restano identici prima e dopo la correzione.

Le etichette delle metriche sono visibili nello screenshot (statistica del
test, gradi di libertà, p-value). L'omissione nel riepilogo AX ridotto non è
interpretata come difetto distinto senza esaminare le relazioni accessibili.
Il difetto dimensionale della finestra è riprodotto e corretto separatamente
in GS-VER-340. La misura reale e l'apertura del triangolo distinguono quel
difetto dal targeting del click automatico; non è attribuito al ponte delle chiavi.

## Gate finale e riscontro Release

`make verify` termina con exit 0 in 753,97 s; analisi statica e archivio
macOS senza firma terminano con exit 0 in 494,93 s. I due componenti del
preflight sono eseguiti separatamente sugli stessi **630 input immutati**,
con fingerprint SHA256
`937093c223abe644d0fba2c85e19057c5a015f44287f65544f5b1cc6a6628981`.
I documenti controllati sono ricontrollati dopo l'aggiornamento delle prove.

Passano 782 definizioni Core, 171 Kit e 107 BDD; il report completo conferma
16 feature, 744 scenari e 3092 passaggi. I nativi hanno 146 definizioni e
439 esecuzioni, zero failure e skip. Parità CLI/Kit: 132 operazioni e 264
confronti completi; 63 fixture testuali, 196 controlli CLI e 22 checkpoint
recovery. Due PDF/A-2u sono conformi e gli avvisi di licenza del bundle
coincidono byte per byte con gli originali.

La Release finale, senza sonda, riapre il progetto sintetico; selezione
Welch, esempio, Calcola e triangolo dei dettagli funzionano. Otto osservazioni,
Bilaterale e Nominale sono esposte nell'albero AX; i tre valori e il digest
restano invariati. La cattura dopo l'apertura è 2560 × 1600 pixel. L'app
verificata è conservata come anteprima locale `Previews/937093c2`.

## Confini della verifica

È una verifica interattiva circoscritta di flussi, tastiera e albero AX, non
un audit completo VoiceOver/Voice Control, contrasto, pseudo-lingua, RTL o
usabilità con persone. Non promuove G4/G5 e non qualifica iPadOS. Le limitazioni
storiche di GS-VER-335/336 restano vere per i rispettivi lotti; questo record
aggiunge prove successive e non riscrive quegli esiti.

Dossier locale: `macOS-2026-11-27-ui-audit`. Log, risultati mirati, fixture
originali e osservazioni sono conservati; gate e input finali sono
nell'[allegato](allegati/GS-VER-339-verifica.json).
