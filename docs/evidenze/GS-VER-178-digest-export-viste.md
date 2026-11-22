<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-178 — Codifica dei digest degli export visuali

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-178 |
| Tipo | Evidenza di correttezza e prestazioni |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con quattro agenti concorrenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Ottimizzazione complementare richiesta dall'iniziatore |
| Riferimenti | GS-DOR-178; GS-VIZ-001; GS-VER-175; GS-VER-207; CMP-186; GS-STD-001-12; GS-STD-001-17; GS-STD-001-29 |

## Perimetro e ingresso

Base pubblicata `38bba29`, worktree isolato `codex/indexed-optimization-20261122`.
La DoR precede test, harness e codice produttivo. Nessuna modifica a GUI,
trasporti CLI, sessioni o ai file attualmente occupati dalle altre chat.
API pubbliche, dipendenze e formati invariati. Dati esclusivamente sintetici.

## Protocollo

Baseline Release compilata prima della patch produttiva; harness identico nel
confronto. Inventario completo delle fonti, input e risultati verificati fuori
timer. Host Mac16,3, 16 GiB, dieci CPU logiche; macOS 27.2.1 (26B131),
Xcode 27.2 (27B52), Apple Swift 6.4.2. Alimentazione AC, Low Power Mode attivo,
nessuna preferenza modificata. Cache calde, nessun flush; contesa con altre
chat registrata. Le misure locali non costituiscono soglia di rilascio,
audit GUI, misura energetica o attestazione G4.

## Correttezza e confini

Due nuovi test e sette regressioni di integrità Release sono verdi. Vettori
SHA-256 vuoto/abc e 256 payload completi binari/Unicode da zero a 4096 byte
coincidono con il formatter precedente. Prefisso, lunghezza e ASCII minuscolo
sono verificati. Un riferimento separato ricostruisce CSV, JSON canonico,
manifest e tutti e tre i file: bundle e manifest sono uguali integralmente.
I rifiuti di metadati, inventari, specifiche malformate e payload rihashati
restano attivi. Nessuna modifica al renderer CSV, a Presentation o alle API.

Il nuovo helper esegue sempre SHA256.hash sull'intero payload, poi codifica i
32 byte con un lookup ASCII immutabile e un buffer UTF-8 da 71 byte. Gli indici
dei due nibble sono limitati a 0...15. Nessuna cache dei digest o controllo
rimosso; stesso formato v1 e stessi fallimenti tipizzati.

## Misure Release

Supporto opt-in esistente, nessuna dipendenza modificata: un warm-up, sette
campioni e otto confronti completi per scenario e corsa. Preparazione,
riferimenti, uguaglianza e SHA sono fuori timer. I tre scenari misurano 20000
digest, 128 bundle da sedici righe e quattro verifiche di una tabella da 10000
righe. Input e output completi hanno gli stessi SHA nelle sei corse.
Le due coppie finali usano ordine A/B/B/A. I bundle di test compilati prima e
dopo sono identificati con SHA-256; le ripetizioni della base usano il bundle
archiviato e --skip-build, con controllo della sua immutabilità prima/dopo.

| Workload | Mediana prima, coppie 2/3 (s) | Mediana dopo, coppie 2/3 (s) | Rapporto prima/dopo |
| --- | --- | --- | --- |
| `visual-export-digest-20000` | 0.682954 / 0.686880 | 0.024886 / 0.024988 | 27.444× / 27.488× |
| `visual-export-large-verification-4` | 0.626526 / 0.632258 | 0.626192 / 0.629349 | 1.001× / 1.005× |
| `visual-export-small-bundle-128` | 0.068672 / 0.069001 | 0.059036 / 0.058936 | 1.163× / 1.171× |

La verifica grande resta sostanzialmente invariata: il vantaggio del digest
non viene attribuito all’intera pipeline. RSS massimo del comando completo
SwiftPM/test, inclusi riferimenti e checksum fuori timer: export-baseline-2: 145555456 byte; export-candidate-2: 145260544 byte; export-baseline-3: 145457152 byte; export-candidate-3: 147013632 byte.

## Riscontri conservati e gate

[Misure, inventari e confronti completi](allegati/GS-VER-177-178-misure.json)
contengono tutte le 42 osservazioni input/output, campioni, termica e censimento
della contesa. Il censimento usa campioni ps, non prova isolamento. Log grezzi
e protocollo sono conservati in `/tmp/GlifiIndexed177Reports` sull'host locale.
CMP-185 e CMP-186 restano implemented; nessuna promozione scientifica.
Il primo make verify sulla base 38bba29 si ferma con exit 2 su due test
preesistenti degli intervalli del testo; i relativi file sono identici alla
base e non dipendono dai kernel di questo lotto. La correzione già pubblicata
dall'altra chat in aec1a00 viene integrata prima di ripetere il gate completo.
Il gate integrato è poi superato; nessun controllo viene indebolito.

## Osservazione separata sul renderer

Il predicato Character di csvField in GlifiVisualizationPresentation non
riconosce CRLF senza virgole o virgolette: Swift tratta CRLF come un solo
Character, diverso da CR e LF separati. Il predicato isolato è stato riprodotto
con exit 0; il riscontro JSON riporta un Character e matches=false. Il file è
occupato dalle altre chat GUI ed è escluso da questa patch. Questa è una
segnalazione sul codice preesistente, non una regressione introdotta né una prova
pubblica end-to-end. La fixture 178 contiene anche virgole e virgolette e resta
valida per il confronto dei digest; non attesta il quoting di ogni testo CSV.

## Integrazione complementare

La correzione aec1a00 è confluita nel merge d5a09ad senza modificare nessuno
dei cinque file posseduti dal lotto (due kernel, due file test e il benchmark).
Le misure descrivono il confronto sulla base 38bba29; la verifica funzionale
congiunta riguarda la composizione con aec1a00. Gli inventari delle due fasi
sono distinti nel riscontro JSON. La ripetizione integrata ha già superato
553 test Core, 112 Kit, 95 controlli CLI, due PDF/A-2u e 22 checkpoint recovery;
la parte nativa è poi conclusa con 99 test passati e zero saltati.

## Chiusura verificata e pulizia

make verify integrato termina con **exit 0** sul codice di d5a09ad:
**553 Core + 112 Kit + 99 nativi macOS = 764 test**, 95 controlli CLI su trenta
fixture condivise, 194 righe di oracoli numerici, 64 casi Fraction indipendenti,
due PDF/A-2u e 22 checkpoint recovery. Build Debug/Release macOS e iPadOS
Simulator completate. Tutti i 271 file Swift dell'inventario integrato sono
identici prima e dopo il gate. Gli ultimi aggiornamenti riguardano soltanto
registri, changelog ed evidenze e sono sottoposti ai controlli statici finali.

Il simulatore dell'host resta 1171.7.0 contro 1174.21.0 richiesto da Xcode;
le build generiche terminano comunque. Non sono eseguiti test runtime iPadOS
o su dispositivo. Resta l'avviso preesistente sull'apertura in-place dei
documenti iPadOS; nessuna attestazione App Store o G4 viene chiusa.

Archiviati e verificati i 666 file del risultato nativo; log, report, fonti,
inventari e protocollo sono conservati anche in
`~/Library/Caches/GlifiStudio/evidence/GS-VER-177-178`.
Rimossi soltanto cache e binari rigenerabili di questa sessione:
**3,744,992 KiB, circa 3.57 GiB**, misurati con du prima
della rimozione. È una misura dei blocchi attribuiti ai percorsi rimossi,
non una differenza df isolata su APFS. Toolchain, dipendenze, prove utili e
file delle altre chat sono conservati.

make quality finale termina con exit 0 dopo l’aggiornamento dei registri:
controlli statici, dialetto Swift e formattazione superati.
