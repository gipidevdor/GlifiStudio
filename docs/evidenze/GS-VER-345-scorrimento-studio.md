<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-345 — Scorrimento e dimensioni dello Studio

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-345 |
| Tipo | Evidenza di regressione e integrazione GUI macOS |
| Versione | 1.0.0 |
| Stato | Regressioni e prova interattiva superate; gate integrato in corso |
| Responsabile | Codex, coordinamento della copia condivisa |
| Ultima modifica | 2026-11-28 |
| Approvazione | Correzione richiesta dello scorrimento e dell'usabilità, preservando stile e contenuti |
| Riferimenti | GS-VER-344; GS-UX-001-18; GS-APL-002; GS-APL-003; GS-STD-001-15; GS-STD-001-29; RF-089; ADR-0048 |

## Difetti e confini

Il riesame della finestra reale ha riprodotto la guida Studio coperta dal
contesto del progetto e l'azione Raccogli collocata dopo il lettore. Il primo
spostamento del contesto in una safe area non ha risolto interamente la
composizione con l'inspector. Contesto e contenuto Studio condividono ora
l'inspector, e la raccolta precede il documento.

La prova con una finestra bassa ha poi riprodotto una crescita automatica:
la cattura della destinazione Esporta misura 4.480 × 1.180 pixel; entrando in
Studio misura 4.480 × 3.018 pixel, con taccuino aperto, due passaggi e due note.
Questo è un RED della finestra reale. Non viene attribuito al lettore isolato:
il test di 3.000 paragrafi passa anche con la factory AppKit precedente.
La misura dell'intestazione fuori dal contenitore flessibile presenta lo stesso
schema già descritto in GS-VER-340; il riscontro decisivo resta la finestra del
prodotto, distinta da una NSHostingView di test.

Il primo run nativo usa la vista Valutazione originale di `4f2d828`, insieme
al workspace Studio prima della correzione della misura: 21 definizioni,
19 superate e 2 fallite. È RED qualificante per il workspace parametrizzato
Studio, con otto issue nei due casi con/senza taccuino; il frame cresce da
642 a 702 punti e il minimo del contenuto raggiunge 650 contro i 590 richiesti.
Il lookup Metodo nella Valutazione soffre anche dei limiti AX del runner
hostless e non viene usato da solo come prova causale di clipping.
Questi run sono distinti dai tentativi iniziali con errore di compilazione,
selettore senza test o attraversamento AX incompleto, che non valgono come RED
funzionale. Il ritorno booleano del proxy nativo di una tab non attesta da solo
l'azione: il test verifica la selezione effettiva e il contenuto raggiunto.

Il RED geometrico successivo della Valutazione usa la vista originale con il
solo observer passivo del pulsante export, identico a quello del candidato:
la tabella ha viewport `(517, 237, 487, 260)`, oltre il workspace
`(20, 71, 1000, 420)`. Il suo bordo superiore raggiunge 497 contro 491,
fallendo anche la tolleranza di un punto. Il run esegue 11 definizioni, con
10 superate e una fallita; l'issue geometrica qualifica il RED, il lookup AX
non lo qualifica. Il primo avvio fermato dalla conformità Hashable isolata
al Main Actor non è contato. Il candidato è ripristinato byte per byte prima
del GREEN; test e criterio geometrico rimangono identici.

Gli observer interni, senza callback nell'app ordinaria, leggono il frame del
vero export e le stesse azioni inviate a `focusedSceneValue`. Consentono al
runner hostless di osservare elementi SwiftUI che non espone nell'albero AX;
non sostituiscono i controlli e non provano l'uso esterno con VoiceOver. La prova
interattiva aziona separatamente i menu e l'esportazione del prodotto.

Il primo GREEN combinato dopo i fix di misura e navigazione comprende
24 definizioni e 38 esecuzioni native, tutte superate. Verifica tabella con
viewport positivo e contenuto, selezione del Metodo, duecentésima osservazione,
export visibile, quattro combinazioni Studio, raccolta dal lettore compatto,
conservazione del foglio e del titolo, Annulla con sblocco e ownership della
protezione. Il successivo fix della selezione nativa richiede un nuovo gate
finale e non è attestato da questo checkpoint intermedio.

La regressione sulla ricreazione del lettore è un RED nativo distinto:
una selezione con emoji viene conservata dal modello e risolta correttamente
nell'anteprima, ma il nuovo NSTextView mostra `{0, 0}` invece di `{9, 16}`
in coordinate UTF-16. Un primo filtro Xcode senza parentesi non esegue test e
non è contato. Il fix trasmette la selezione corrente al vero lettore, la
convalida senza overflow e la ripristina soltanto alla nuova navigazione;
non introduce salvataggio globale dello scorrimento o nuovi dati nel progetto.
Il GREEN della suite Workspace esegue 14 definizioni e 20 esecuzioni, tutte
superate, senza skip o runtime warning. Conserva l'oracolo del RED e verifica
anche aggiornamento ordinario, caret vuoto, range estremi rifiutati e nuova fonte.

Il seguito interessa layout e comandi applicativi privati. I contratti pubblici
Core/Kit/CLI, il formato persistente e la lingua di analisi italiana seguono
GS-API-007 e ADR-0048 senza nuove operazioni o migrazioni.

## Prove interattive acquisite

Con fixture sintetica italiana sono completati: selezione nativa, anteprima,
raccolta di un secondo passaggio, conclusione sostenuta da due passaggi,
salvataggio e riapertura di entrambe le conclusioni. «Vai alla fonte» seleziona
il passaggio originale. Il dettaglio frasi/caratteri apre l'anteprima, annullata
senza aggiungere un estratto. L'esportazione GUI della valutazione linguistica
scrive un JSON completo, poi controllato come file.

Queste prime azioni non attestavano ancora il GREEN dimensionale. La versione
precedente di GS-VER-344 dichiarava esplicitamente incompleta la prova visiva;
il nuovo riesame ne ha confermato la necessità.

Il GREEN interattivo successivo, con GeometryReader esterno, misura 4.480 ×
1.180 pixel in Esporta, 4.480 × 1.178 dopo Cmd-8 in Studio e ancora 4.480 ×
1.178 con il taccuino aperto tramite Cmd-Maiuscole-B. Lo scorrimento del taccuino
raggiunge il fondo e rende visibile la seconda conclusione con entrambi i
collegamenti. L'anteprima per caratteri passa dal popover al foglio senza
aggiungere un estratto se annullata. Questo copre la finestra italiana reale,
distinta dal test nativo con quattro combinazioni di taccuino e Dynamic Type.

La prova dei menu ha riprodotto un altro difetto: Cmd-1 poteva cambiare
destinazione con il foglio Studio aperto. La raccolta tornava dal modello,
mentre l'editor locale della conclusione non veniva ripristinato. Il rimedio
deve impedire la navigazione durante la decisione modale, senza salvare
automaticamente il testo digitato. Il confronto compatto deve inoltre riferire
il comando Raccogli al tab visibile, anche dopo il ridimensionamento da due
lettori affiancati.

Il riesame finale del prodotto verifica titolo e testo della bozza prima di
Cmd-1 e Cmd-K: entrambi lasciano il foglio invariato; tutti gli ingressi del menu
Area di lavoro risultano disabilitati. Annulla sblocca la successiva navigazione.
Un intervallo caratteri `9999..<1` produce una failure leggibile e conserva i
valori nel popover; la correzione a `0..<8` apre l'anteprima «Studiare», poi
annullata. Nel confronto ampio sono selezionate due citazioni diverse; aprendo
il taccuino la vista passa alle tab compatte. Cmd-Maiuscole-E raccoglie la
citazione di A quando A è visibile e quella di B dopo il cambio di tab.

Nella Valutazione italiana il ridimensionamento nativo In alto conserva una
tabella con più righe visibili, i controlli di pagina e l'export in alto.
Metodo e provenienza espone le cinque osservazioni sintetiche con intestazioni
distinte nell'albero AX; lo scorrimento raggiunge il fondo e l'export rimane
azionabile. Il file finale JSON di 1.538 byte è letto e verificato: cinque
osservazioni, due corrispondenze, accuracy 0,4, metodo
`LinguisticClassification-exact-v1`. L'app della prova è chiusa normalmente.

## Limiti

Nel runner hostless Evaluation restano due avvisi «Invalid view geometry:
width is negative.» durante il layout, anche inizializzando un host vuoto con
frame valido prima della vista reale. Non sono soppressi e la causa non è
qualificata come esclusivamente esterna al prodotto. Le geometrie finali
asserite rispettano il viewport; questo esito non equivale ad assenza di
diagnostiche o a qualifica completa dell'interfaccia.

VoiceOver, Voice Control, Full Keyboard Access completo, contrasto, pseudo-lingua
e destra-sinistra richiedono audit dedicati. La presenza di controlli AppKit e
test di geometria non li certifica. L'intuitività richiede valutazione con
persone rappresentative; non è dedotta dal numero di test automatici.
