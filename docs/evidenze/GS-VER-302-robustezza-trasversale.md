<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-302 — Robustezza trasversale della baseline

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-302 |
| Tipo | Evidenza di correttezza, risorse e lifecycle |
| Versione | 1.0.0 |
| Stato | Superato localmente nel perimetro automatico macOS |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di massima qualità ingegneristica; GS-DOR-302 |
| Riferimenti | GS-STD-001-29; GS-QRY-001; GS-DEV-002; GS-API-003 |

## Perimetro

La baseline è `8901f4ad3f17a27f02fc7628221641d66346b38c`. La revisione
distribuita esamina limiti e cancellazione del Core, ingressi Kit/CLI, ownership
delle attività macOS e strumenti di verifica. Le correzioni sono guidate da
difetti riprodotti, senza refactoring cosmetici o accelerazioni non misurate.
Durante l'audit vengono pubblicati i completamenti KH `d368285` e `a2716ef`
(GS-VER-305) e il checkpoint di coesione GS-VER-284. La composizione conclusiva
conserva questi commit, la loro storia e la GUI GS-VER-304: i sette file view
coincidono esattamente con il suo inventario verificato e il catalogo conserva
anche i due nuovi messaggi delle query. Il lavoro ulteriore non pubblicato
rimane nelle copie delle altre sessioni.

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

`make verify` e `Scripts/check-app-store-packaging.sh --macos-only` terminano
entrambi con **exit 0** sul commit pulito
`98d458554de317524447bcfd9eae3355a71dfce6`, in una copia isolata. I
**540 input di programma** hanno SHA-256
`f0fafbecf4f6d31969bea2d8e9c3bbb2fed35e1dd5c901a6dcc6b8512d76d6cb`:
path relativo UTF-8 ordinato, NUL, contenuto, NUL. Il
[riepilogo strutturato](allegati/GS-VER-302/verifica.json) conserva l'inventario
per file, i risultati e gli hash dei log delle regressioni.

La verifica comprende **664 definizioni Core,
145 Kit**, 2.816 dichiarazioni pubbliche, 40 tag compilati, 63 fixture e 196
controlli CLI testuali. Sono superati 130 operazioni standalone e 260 confronti
integrali CLI/Kit, 51 rifiuti, 64 controlli dei file legacy, due formati
d'importazione e 22 checkpoint di recupero.

La suite nativa macOS supera **117 definizioni e 349 esecuzioni**, zero failure
e zero skip. Build Debug/test e Release, analisi statica Release e archivio
macOS senza firma sono completati. Oracoli: **244 righe indipendenti più 64
casi Fraction binary64**. **Due PDF/A-2u sono conformi** secondo veraPDF 1.30.4,
già installato e selezionato tramite `VERAPDF`. Ambiente: Xcode 27.2,
Apple Swift 6.4.2, macOS 27.2.1 e Python 3.14.10 nei controlli.

I fingerprint sono invariati prima e dopo gate, preflight e sanitizer; la copia
è pulita durante tutte le esecuzioni. I successivi aggiornamenti documentali e
della matrice sono ricontrollati separatamente prima della pubblicazione.

Le corse precedenti sul checkout condiviso avevano exit 0, ma il confronto
finale rilevava l'arrivo degli otto file GUI: quegli esiti non vengono attribuiti
alla composizione nuova. L'isolamento elimina questa ambiguità senza scartare
il lavoro delle altre sessioni. Il merge preserva anche il checkpoint pubblico
di coesione, così i branch consolidati possono essere rimossi senza perdere
commit; tale topologia ha valore di recupero secondo GS-REP-002.

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

Il [confronto Release dell'implementazione query](allegati/GS-VER-302/core-query-final-benchmark-summary.json)
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

Queste misure riguardano il checkpoint di ottimizzazione su base `d368285`;
i cinque file dell'esperimento query sono invariati nella composizione finale,
ma il vecchio digest del binario non viene attribuito al nuovo modulo completo.
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

- [Address Sanitizer finale](allegati/GS-VER-302/isolated-asan-summary.json):
  **19 definizioni**, nessun diagnostico, incluso il costruttore originale;
  runtime effettivamente collegato e 540 input invariati durante la prova.
- [Thread Sanitizer finale](allegati/GS-VER-302/isolated-tsan-summary.json):
  **117 definizioni della suite macOS completa**, nessun failure, skip o avviso
  runtime; strumentazione effettiva verificata. Commit e tutti i 540 input
  coincidono prima e dopo le due prove isolate, senza modifiche successive
  ai sorgenti eseguibili. Le prove preliminari e il loro delta DocC restano
  distinti dagli allegati conclusivi.

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
restano aperti. Il profilo corrente rinvia iPadOS. Le prime corse non trovavano
veraPDF sul percorso predefinito; la composizione isolata lo seleziona dalla
toolchain già installata e valida effettivamente i due PDF/A-2u. Le build macOS
segnalano il CoreSimulator precedente alla versione
richiesta da Xcode, senza dedurne prove su simulatore iPadOS. Nessun voto assoluto
di qualità è ricavato dal solo superamento dei controlli.
