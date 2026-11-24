<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-275 — Parità continua fra GlifiKit e CLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-275 |
| Tipo | Evidenza di contratto e verifica headless |
| Versione | 1.0.0 |
| Stato | Superato localmente; limiti espliciti sotto riportati |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di mantenere sempre allineate CLI e Kit; ADR-0036; GS-DOR-275 |

## Perimetro

I comandi `statistics`, `operator`, `evaluation`, `project-call` e `profile`
chiamano gli ingressi GlifiKit condivisi e restituiscono risultati completi.
Le venti analisi di progetto conservano tutte le opzioni di corpus; la keyness
conserva anche soglie, limiti e livello di confidenza. Importazione e profilo
consentono la scelta del formato indipendente dall'estensione. `lastProfile`
serializza direttamente il DTO nativo completo.

Il contratto è [GS-API-003](../api/03-parita-continua-cli.md). L'inventario
pubblico deriva dal symbol graph del compilatore, include firme, campi e casi
degli enum e richiede mapping o motivazione per ogni callable. La baseline non
viene aggiornata dal gate. I casi operativi attesi derivano dagli enum compilati,
non da un numero fisso di fixture.

## Verifiche mirate osservate

Il primo gruppo mirato ha superato quattordici definizioni, inclusi tutti i
44 metodi statistici, 41 operatori e 13 operazioni di valutazione. Il secondo
ha superato venti definizioni in cinque suite, aggiungendo profilo, limiti JSON,
chiavi sconosciute, cancellazione, interi estremi e conservazione dei bit dei
Double, compreso lo zero con segno. Queste prove precedono il gruppo completo
di comandi di progetto e non sostituiscono la verifica conclusiva.

## Verifica conclusiva

`make verify` è terminato con **exit 0** su un worktree detached isolato con
overlay della copia condivisa. Xcode 27.2, Apple Swift 6.4.2, Python 3.14.10
selezionato nel PATH dei controlli e macOS 27.2.1. Il Python 3.9 fornito da
Xcode non soddisfa il requisito Python 3.10+ degli oracoli; nessuna dipendenza
o configurazione globale dell'host è stata modificata.

- **423 definizioni Core e 91 Kit** superate, incluse le nuove prove di JSON,
  risultati numerici, cancellazione e tutte le operazioni di progetto.
- **126 operazioni** enumerate dal compilatore: 44 statistiche, 41 operatori,
  13 valutazioni, 26 comandi di progetto e due formati di profilo; **252 confronti
  integrali CLI/Kit**, **51 rifiuti** e due importazioni con formato esplicito.
- **2.266 dichiarazioni pubbliche** censite: 81 metodi operativi associati a
  comandi, 261 costruttori/codec/helper/lifecycle motivati e 1.924 tipi, membri e
  casi. Tutti i dodici casi di `text-analysis` hanno fixture: restano superati
  anche i 51 controlli storici su quindici fixture.
- **102 definizioni native macOS, 322 esecuzioni**, zero failure e zero skip
  dal riepilogo xcresult. Build macOS Debug/test e Release e iPadOS Debug/Release
  su destinazione generica Simulator completate.
- **194 righe di oracoli indipendenti**, 22 checkpoint di process-kill recovery,
  QueryAST CLI, controlli statici e formattazione superati.

Dieci regressioni deliberate del controllo sono state rifiutate: nuova API,
campo DTO modificato, dichiarazione rimossa, fixture assente, binding CLI
mancante, esclusione immotivata e alterazioni di seed, zero con segno, numero
e membro del risultato. Il controllo dei nomi canonici è stato corretto per
leggere le chiavi italiane del catalogo JSON indipendentemente dagli spazi;
cinque regressioni dimostrano che rimangono obbligatori nome, chiave e valore,
senza modificare il catalogo condiviso.

## Identità e conservazione

La base Git è `02c1c666437a58743dba40193b9a94d4a7a3a11c`; l'overlay contiene
977 file versionabili. I **431 input di programma** hanno SHA-256
`7fba192badee5b9829c5c23816ebeddbe181f3586e2bd727988e54cf35fbe31b`:
path relativo ordinato UTF-8, NUL, contenuto e NUL. Inventario, risultati e hash
sono nell'[allegato strutturato](allegati/GS-VER-275-verifica-kit-cli.json).

Durante il gate un'altra lavorazione ha riformattato
`Apps/Shared/Resources/Localizable.xcstrings`: i 2.418 elementi JSON, tutte le
chiavi e tutti i valori coincidono esattamente con lo snapshot, ma i byte
differiscono. L'allegato distingue i due fingerprint; nessun altro input di
programma differisce. I metadati conclusivi sono ricontrollati separatamente.
Cache, copia isolata e fixture rigenerabili vengono eliminate dopo la verifica;
la misura prima della rimozione è circa **4,1 GiB**, compreso l'audit interrotto.
Restano sorgenti, toolchain attive e questa evidenza.

## Limiti dell'evidenza

La validazione PDF/A-2u indipendente è **saltata perché veraPDF è assente**.
Xcode segnala il runtime CoreSimulator 1171.7.0 precedente al 1174.21.0 richiesto
e la dichiarazione di apertura documenti in-place iPadOS mancante; le build
generiche sono comunque completate. Nessuna prova UI su simulatore o dispositivo
iPadOS è dedotta da esse.

Il confronto numerico usa tolleranza assoluta e relativa di 1e-12; interi,
identificatori, stringhe, struttura e segno dello zero sono controllati senza
tolleranza. Ogni export visuale verifica il digest del proprio manifest e i
byte di ogni payload. Fra due export indipendenti si esclude dal confronto
soltanto `createdAt`, già estraneo all'identità scientifica del contratto.
Gli UUID creati da importazioni indipendenti sono validati senza equipararli.

Questa evidenza riguarda il trasporto e la parità funzionale, non tutti i
possibili input, la promozione dei manifest scientifici, l'ergonomia delle app
o la chiusura G4/G5. Costruzione, serializzazione, presentazione e lifecycle
rimangono censiti come infrastruttura con motivazione esplicita.
