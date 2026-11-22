<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-302 — Robustezza trasversale della baseline

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-302 |
| Tipo | Evidenza di correttezza, risorse e lifecycle |
| Versione | 1.0.0 |
| Stato | In verifica della composizione con GS-VER-304 |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di massima qualità ingegneristica; GS-DOR-302 |
| Riferimenti | GS-STD-001-29; GS-QRY-001; GS-DEV-002; GS-API-003 |

## Perimetro

La baseline è `8901f4ad3f17a27f02fc7628221641d66346b38c`. La revisione
distribuita esamina limiti e cancellazione del Core, ingressi Kit/CLI, ownership
delle attività macOS e strumenti di verifica. Le correzioni sono guidate da
difetti riprodotti, senza refactoring cosmetici o accelerazioni non misurate.
Durante l'audit l'altra sessione pubblica `d368285`, con il completamento KH:
quel commit viene integrato prima del gate conclusivo. Le ulteriori modifiche
KH non pubblicate rimangono nella copia separata e non entrano nella verifica.

## Regressioni osservate

- KWIC e frase con slop: parametri `Int.max` causano overflow; entrambe le
  regressioni terminano il processo di test prima della correzione.
- Prossimità e unione booleana: il limite dell'output viene applicato troppo
  presto agli operandi, alterando corrispondenze e ordine canonico.
- Richiesta CLI assente: `plan` produce `transientIO` / exit 6 invece di
  `invalidInput` / exit 3. Il lettore legacy controlla e riapre il percorso;
  nessuna race o exploit è dichiarata riprodotta.
- Chiusura finestra: un'apertura sospesa non viene cancellata e può applicare
  successivamente un allegato alla sessione non più visibile.
- Cache: la baseline adotta directory sconosciute e non esclude esecuzioni
  concorrenti; accetta symlink e configurazioni invalide, arrotonda il cap e
  cancella temporanei altrui. Anche la morte del proprietario può lasciare
  un compilatore attivo: la nuova preparazione deve conservare la cache.

## Verifica conclusiva

Una prima esecuzione di `make verify` e
`Scripts/check-app-store-packaging.sh --macos-only` termina con **exit 0**.
Il confronto conclusivo rileva otto file modificati nel frattempo dall'arrivo
del lotto GUI GS-VER-304, verificato separatamente: gli esiti non vengono
attribuiti automaticamente alla nuova composizione. Il gate viene ripetuto
sulla fotografia completa. Il precedente insieme aveva **530 input**,
base `d368285`, SHA-256
`19ca13a9a7147210a6582fd0fdaf62740557a79061ca239ddfbaa7d9ccd4a038`:
path relativo UTF-8 ordinato, NUL, contenuto, NUL. Il
[riepilogo strutturato](allegati/GS-VER-302/verifica.json) conserva l'inventario
per file, i risultati e gli hash dei log delle regressioni.

La verifica comprende **642 definizioni Core,
141 Kit**, 2.816 dichiarazioni pubbliche, 40 tag compilati, 63 fixture e 189
controlli CLI testuali. Sono superati 130 operazioni standalone e 260 confronti
integrali CLI/Kit, 51 rifiuti, 64 controlli dei file legacy, due formati
d'importazione e 22 checkpoint di recupero.

La suite nativa macOS supera **117 definizioni e 349 esecuzioni**, zero failure
e zero skip. Build Debug/test e Release, analisi statica Release e archivio
macOS senza firma sono completati. Oracoli: **236 righe indipendenti più 64
casi Fraction binary64**. Ambiente: Xcode 27.2, Apple Swift 6.4.2,
macOS 27.2.1 e Python 3.14.10 nei controlli.

L'evidenza conclusiva della composizione richiede fingerprint invariati dopo
entrambe le esecuzioni. I successivi aggiornamenti documentali e della matrice
sono ricontrollati separatamente prima della pubblicazione.

La parità query aggiunge due casi Core/Kit, con 1.002 e 100.001 ripetizioni:
match tardivo, offset, testo/AST, troncatura, failure tipizzata e generazione
invariata. Il controllo CLI esegue 31 invocazioni query e quattro preparazioni;
dopo la failure dimostra la riutilizzabilità del progetto. L'invariabilità
della generazione è attestata dal test Kit, non dedotta dalla sola usabilità.

## Query, misure e compatibilità

Le regressioni dimostrano i due crash prima della correzione, i falsi negativi
e il prefisso canonico errato. Sono superati **36 test Query**, 1.432 confronti
con enumerazione indipendente, compresi 1.176 con intervalli annidati, e il
fuzz esistente da 3.000 input. La query selettiva con 1.001 ancore per operando
termina correttamente entro **16.000 passi**, evitando il prodotto cartesiano.

I budget sono distinti dal limite delle righe, globali alla singola valutazione
Core e applicati prima di emissioni o passi. Le ricerche per finestre e gli
ordinamenti sono limitati e cancellabili. I byte aggregati della singola phrase
sono ammessi prima della normalizzazione. Il costruttore Core originale a
undici argomenti resta disponibile anche come valore funzione; la regressione
di compilazione ha prima riprodotto la perdita della firma.

Il [confronto Release finale](allegati/GS-VER-302/core-query-final-benchmark-summary.json)
usa lo stesso harness, baseline archiviata `8901f4a`, candidato integrato,
ordine ABBA e quattordici campioni per variante. Stato termico nominale e
risparmio energetico attivo, senza modificare impostazioni. **Due compilazioni
esterne sono attive**: i dati sono informativi sotto contesa, non una soglia G4.

| Carico sintetico | Mediana baseline | Mediana finale |
| --- | --- | --- |
| Unione, 1.000 token | 0,496 ms | 0,266 ms |
| Prossimità ordinata, 100 × 100 | 0,103 ms | 0,122 ms |
| Prossimità simmetrica, 100 × 100 | 0,103 ms | 0,123 ms |

Resta un costo di circa 0,02 ms per i controlli di correttezza e risorse nei due
piccoli carichi di prossimità. La
[fase intermedia con soli budget](allegati/GS-VER-302/core-query-benchmark-summary.json)
e la sua [patch](allegati/GS-VER-302/core-query-intermediate.patch) restano
distinte dal candidato finale. La
[scansione Unicode intermedia](allegati/GS-VER-302/core-validated-read-benchmark-summary.json)
su 100.000 token misura 89,98 → 92,84 ms; non viene presentata come misura
dell'ultimo binario. Nessuna accelerazione di piattaforma è introdotta.

L'harness confronta fra versioni identità della fixture e della query, range
UTF-8 attesi indipendenti, conteggio e completezza. Il DTO completo è confrontato
fra ripetizioni della stessa versione; il confronto integrale CLI/Kit rimane
una verifica separata.

## Concorrenza e sanitizer

La chiusura cancella e attende le attività possedute prima di chiudere la
sessione e rilasciare l'accesso alla fonte. Il modello si libera dopo il
completamento e l'allegato attende ogni generazione di teardown. Una revisione
indipendente ha individuato il rischio di ammissione prima della fine della
generazione successiva. Il primo test usava un timer: nella suite completa
scadeva già durante la prima chiusura, prima dell'interleaving atteso. Questo
falso positivo è conservato nell'allegato diagnostico e non è una regressione
runtime risolta aumentando il timeout.

La barriera interna effettivamente usata dall'attachment ora viene verificata
con generazioni e gate controllati, senza timer. L'ammissione e la registrazione
dell'ID avvengono nello stesso tratto sincrono Main Actor. La
[mutazione `while` → `if`](allegati/GS-VER-302/close-barrier-mutation-summary.json)
fallisce deterministicamente sull'ammissione prima di B; il codice ripristinato
supera anche la suite completa. La cancellazione al completamento di B evita
di attendere C, senza cancellare il produttore condiviso.

- [Address Sanitizer finale](allegati/GS-VER-302/core-query-final-asan-summary.json):
  **19 definizioni**, nessun diagnostico, incluso il costruttore originale;
  runtime effettivamente collegato e 96 sorgenti Core invariati durante la prova.
- [Thread Sanitizer finale](allegati/GS-VER-302/close-barrier-full-tsan-summary.json):
  **117 definizioni della suite macOS completa**, nessun failure, skip o avviso
  runtime; strumentazione effettiva verificata. Una sola riga DocC vuota viene
  aggiunta dopo la prova per il lint: il
  [delta](allegati/GS-VER-302/close-barrier-postlint-delta.json) ricostruisce
  esattamente l'hash precedente, senza cambiamenti eseguibili. Il gate finale
  compila la stesura corrente.

Queste sono prove mirate sul modulo integrato, non una dichiarazione di copertura
universale, LeakSanitizer o audit UI della finestra.

## Proprietà delle risorse e revisione

Le **dodici regressioni degli strumenti** verificano directory non riconosciute,
symlink, contesa e trap, cap senza arrotondamento, directory altrui vecchie,
SIGKILL del proprietario con figlio ancora vivo, percorsi relativi, fallimento
di `mktemp`, errori di misura `du`/`df` e sostituzione della directory.
Gli ingressi usano un'uscita esplicita sui fallimenti delle funzioni: il solo
errexit di zsh in tale contesto può saltare il trap EXIT. La preparazione
parzialmente posseduta viene rilasciata anche su errore di misura.
Il marcatore di attività impedisce
la riadozione automatica di cache interrotte. Il test senza `TMPDIR` conferma
il fallback del packaging e la pulizia dopo il comando stub fallito.

La checklist 29.6 è applicata alle aree toccate: compatibilità e mapping;
correttezza e budget; isolamento e cancellazione; stato persistente;
ammissione e diagnostica; due messaggi localizzati; API native; misure;
regressioni e sanitizer; documenti e tracciabilità. Non sono introdotti rete,
dipendenze, entitlement, backend o formati di prodotto.

## Limiti

Accessibilità manuale, dispositivi, energia e criteri ancora Da introdurre
restano aperti. Il profilo corrente rinvia iPadOS. La validazione PDF/A
indipendente è saltata perché veraPDF è assente; i test degli export non la
sostituiscono. Le build macOS segnalano il CoreSimulator precedente alla versione
richiesta da Xcode, senza dedurne prove su simulatore iPadOS. Nessun voto assoluto
di qualità è ricavato dal solo superamento dei controlli.
