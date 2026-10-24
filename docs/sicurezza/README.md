<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Threat model e architettura di sicurezza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-SEC-001 |
| Tipo | Specifica normativa di sicurezza |
| Versione | 1.3.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-10-24 |
| Approvazione | Baseline proposta; threat review e prove avversarie richieste ai gate G2 e G4 |
| Riferimenti | GS-STD-001-13; GS-STD-001-14; GS-DAT-001; GS-QRY-001; GS-RUN-001; ADR-0017; ADR-0019 |

## 1. Scopo e autorità

Questa specifica definisce asset, assunzioni, confini di fiducia, minacce, controlli
e verifiche di sicurezza di Glifi Studio. Governa app macOS/iPadOS, `GlifiKit`,
`GlifiCore`, `GlifiCLI`, package `.glifi`, import, analisi, modelli, diagnostica ed
export. GS-DAT governa consistenza e recovery dei dati; GS-RUN governa i budget;
GS-STD-001-14 governa il processo sicuro e la privacy.

Una funzione non diventa sicura perché usa un framework Apple, è locale oppure
opera in App Sandbox. Ogni byte esterno resta non fidato fino alla validazione e
ogni output esportato attraversa un nuovo confine di fiducia.

## 2. Obiettivi e non-obiettivi

Gli obiettivi sono:

- preservare confidenzialità di fonti, query, risultati, path e metadati;
- impedire che input controllato alteri file esterni, codice, configurazione o
  generazioni committate;
- rendere rilevabile corruzione, incompletezza e sostituzione accidentale;
- mantenere disponibilità e responsività entro budget finiti;
- conservare integrità scientifica, provenance e distinzione fra dati osservati e
  output probabilistici;
- fallire in modo chiuso, recuperabile e spiegabile.

SHA-256 e i checksum del package provano integrità rispetto ai digest registrati,
non autenticità dell'autore contro un soggetto che può riscrivere sia contenuto sia
manifesto. Cifratura end-to-end, firma dei progetti, collaborazione multiutente e
protezione da un account locale già compromesso sono fuori dalla baseline 0.1 e
richiedono un nuovo threat model.

## 3. Profilo operativo e assunzioni

La 0.1 è locale, singolo utente, senza account, rete, sincronizzazione, plugin,
telemetria o esecuzione di codice contenuto nei documenti. Le build App Store usano
App Sandbox e Hardened Runtime con entitlement minimi. Fonti esterne sono aperte
soltanto dopo una scelta esplicita del sistema; accessi persistenti usano bookmark
security-scoped e vengono chiusi al termine dell'operazione.

Si assume integro il sistema operativo supportato, la catena di firma Apple e il
toolchain approvato. Non si assume benigno alcun file selezionato, package `.glifi`,
bookmark risolto, metadata, query, regex, modello ML, output generativo o nome file.
Il sandbox limita l'impatto di una compromissione, ma non sostituisce validazione,
limiti, isolamento degli stati e minimo privilegio.

## 4. Asset e classificazione

| Classe | Esempi | Regola minima |
| --- | --- | --- |
| S0 pubblico | codice, documentazione, fixture sintetiche approvate | Redistribuibile secondo licenza |
| S1 operativo | versioni, durata aggregata, codici di esito allowlist | Locale; nessun identificatore persistente |
| S2 riservato | nomi file, path, bookmark, query, metadati progetto | Omissione da log; export solo esplicito |
| S3 contenuto | fonti, estratti, OCR, annotazioni, findings, report | Accesso minimo; mai in diagnostica predefinita |
| S4 segreto | credenziali, chiavi, materiale di firma | Mai nel repository, package o diagnostica |

ProjectID e OperationID sono S2 quando possono correlare attività. Un ID
pseudonimizzato non diventa anonimo per il solo hashing.

## 5. Confini di fiducia

```text
file/query/modello non fidato
          │ TB-01 selezione o argomento CLI
          ▼
  staging limitato e validazione ── TB-02 ──► parser/normalizzatore
          │                                      │
          │ contenuto validato                    │ artefatti candidati
          ▼                                      ▼
 GlifiCore + budget runtime ─────── TB-03 ──► transazione `.glifi`
          │                                      │
          ├── TB-04 ──► UI / preview             └── commit manifesto
          ├── TB-05 ──► log/signpost locali
          └── TB-06 ──► staging export ──► file scelto dall'utente
```

| Confine | Da → a | Condizione d'ingresso |
| --- | --- | --- |
| TB-01 | filesystem/CLI → staging | autorizzazione, tipo osservato, identità e limiti iniziali |
| TB-02 | staging → parser | signature, dimensioni, profondità e budget validati |
| TB-03 | artefatto candidato → stato autorevole | schema, digest, invarianti e protocollo GS-DAT superati |
| TB-04 | dominio → presentazione | escaping, tipo semantico, lineage e classificazione preservati |
| TB-05 | dominio → diagnostica | evento e campi appartenenti ad allowlist, contenuto omesso |
| TB-06 | dominio → export | selezione, inventario, destinazione e manifesto confermati |

La UI, il nome del file, l'estensione, l'UTType dichiarato e un bookmark valido non
sono prove di contenuto benigno. `GlifiCLI` non amplia i privilegi del motore.

## 6. Metodo di analisi

La review usa STRIDE per superficie e abuse case specifici del dominio. Ogni
minaccia ha identificatore permanente, asset, precondizione, impatto, controlli,
verifica e rischio residuo. Probabilità e severità vengono rivalutate prima di G2,
quando cambia un parser, un entitlement, una dipendenza, un formato, la rete o un
modello, e prima di G4 sulla build candidata.

| ID | Minaccia e impatto | Controlli obbligatori | Prova richiesta |
| --- | --- | --- | --- |
| THR-001 | File con tipo falso o parser exploit | sniffing contenuto, parser allowlist, nessuna esecuzione | corpus avversario e fuzz |
| THR-002 | PDF/OCR malformato o ricorsivo | supporto sospeso fino a limiti, corpus e isolamento approvati | fuzz, timeout, crash triage |
| THR-003 | Decompression bomb/nesting | byte espansi, ratio, oggetti, profondità, tempo e disco bounded | fixture generata entro limite CI |
| THR-004 | Path traversal/assoluto | risoluzione component-by-component sotto radice verificata | casi `..`, assoluti, Unicode |
| THR-005 | Symlink, hard-link o race | rifiuto link inattesi, identità file, coordinamento e no-follow applicabile | race e sostituzione controllata |
| THR-006 | Collisione Unicode/case | nome canonico interno e collision check prima della materializzazione | fixture case-sensitive/insensitive |
| THR-007 | `.glifi` corrotto o incompleto | manifest commit point, digest, generazioni e recovery read-only | kill injection e mutazioni |
| THR-008 | `.glifi` modificato intenzionalmente | nessuna fiducia nei checksum autocontenuti; validazione completa | tampering di manifesto e store |
| THR-009 | Regex/query DoS | limiti AST/pattern/input, costo, deadline e cancellazione | fuzz e casi ReDoS |
| THR-010 | Exhaustion CPU/memoria/disco | admission GS-RUN, code bounded, spill bounded, quota temporanei | pressure test e benchmark |
| THR-011 | Partial result scambiato per completo | stato terminale tipizzato e nessun commit incompleto | cancellazione a ogni fase |
| THR-012 | Temp file osservabile o residuo | directory OS/same-volume, permessi restrittivi, cleanup idempotente | audit permessi e crash cleanup |
| THR-013 | Bookmark stale o sostituito | risoluzione con stale check, digest/identità e scope minimo | sostituzione/mancanza/autorizzazione |
| THR-014 | Export eccessivo o formula injection | inventario, escaping per formato, manifest, niente fonti di default | canary e apertura in consumer |
| THR-015 | Contenuto in log/crash report | `GlifiDiagnostics`, campi tipizzati, omissione S2–S4 | canary Console/Instruments |
| THR-016 | Modello ML compromesso/incompatibile | provenienza, digest/firma disponibile, schema output, sandbox logico | modello mancante/corrotto/ostile |
| THR-017 | Prompt injection da corpus | output non autorevole, tool least-authority, nessun side effect implicito | output generativo ostile |
| THR-018 | Dipendenza/build compromise | allowlist, pin immutabile, review, SBOM e scansione | gate supply-chain |
| THR-019 | Cache/indice stale usato come verità | chiavi complete, checksum, invalidazione e ricostruibilità | cache poisoning/stale tests |
| THR-020 | Dati esposti da preview/Spotlight/backup | funzioni disattive nella 0.1, minimizzazione e lifecycle | audit build e container |

## 7. Protocollo per input e parser ostili

1. Ogni input entra in una directory di staging controllata; nessun parser scrive
   direttamente nel progetto autorevole o nella destinazione finale.
2. Il sistema acquisisce valori di risorsa e identità senza seguire link non
   autorizzati, poi valida tipo reale, byte massimi e formato prima di allocazioni
   proporzionali a valori dichiarati dall'input.
3. Lettura, digest, decodifica ed estrazione sono streaming. Ogni fase riceve budget
   indipendenti di byte letti/prodotti, oggetti, pagine, profondità, memoria, disco,
   CPU e tempo trascorso.
4. Contatori usano aritmetica con overflow controllato. Offset, lunghezze, stride,
   dimensioni e prodotti sono validati prima di conversione e allocazione.
5. Markdown è dato: HTML/script, link, immagini remote, URI e comandi incorporati
   non vengono eseguiti o recuperati.
6. PDF e OCR restano non supportati finché THR-002 non ha corpus cattivo,
   sanitizer/fuzz, limiti e decisione sull'isolamento. Un crash riproducibile nel
   parser blocca la promozione.
7. Errori, timeout e cancellazione eliminano lo staging oppure lo marcano per
   cleanup; non producono una SourceRevision committata.

Archivi non sono un formato di importazione 0.1. Una futura introduzione richiede
un estrattore che validi l'intero indice prima di scrivere, vieti device/FIFO/link,
applichi limiti cumulativi e materializzi esclusivamente nomi interni generati.

## 8. Path, package e file temporanei

I path esterni sono riferimenti di presentazione, mai identità persistenti. Ogni
componente del package viene risolto rispetto a una radice già aperta e confrontato
con la radice canonica; path assoluti, vuoti anomali, `.`/`..`, separatori
alternativi, NUL, link inattesi e collisioni case/normalizzazione sono rifiutati.

Le sostituzioni critiche usano staging univoco sul volume destinazione, file
coordination e primitive di sostituzione sicura del sistema. I temporanei S2/S3:

- non usano nomi derivati dal corpus;
- non sono condivisi, indicizzati o inclusi in backup per scelta applicativa;
- hanno permessi minimi compatibili con il sandbox;
- sono tracciati da una transazione e rimossi in modo idempotente all'avvio;
- non vengono riutilizzati se owner, schema, digest o transazione non coincidono.

## 9. Query, regex e disponibilità

`glifi-query-v1` applica limiti prima della valutazione: byte e nodi AST, profondità,
numero di clausole, ampiezza delle alternative, lunghezza del pattern, dimensione
dell'input, match massimi e costo stimato. Le regex ammesse sono compilate una sola
volta, ricevono deadline/cancellazione e non possono eseguire callback o sostituzioni
con side effect. Pattern non valutabili con limite dimostrabile vengono rifiutati.

Lo scadere del budget produce `insufficientResources` o `cancelled`, mai un insieme
marcato completo. Il runtime limita concorrenza, buffer, file descriptor, spazio di
spill e lavoro per progetto; preserva la generazione committata prima di liberare
cache o checkpoint validi.

## 10. Modelli ML e contenuto generativo

Modello, tokenizer, vocabolario e configurazione sono input non fidati. Devono
avere provenienza, versione, digest, licenza, requisiti di runtime, limiti di forma e
schema output. Un modello non può aprire file, rete, tool o scritture autorevoli.

Il testo del corpus può contenere istruzioni rivolte a un modello: restano dati.
L'output generativo è classificato come tale, non crea Evidence/Findings, non
rimuove Caveat e non avvia export o altre azioni. L'assenza o il rifiuto del modello
non impedisce apertura, ricerca, conteggi e riproduzione dei metodi fondamentali.

## 11. Log, preview ed export

Solo eventi `GlifiDiagnostics` approvati attraversano TB-05. Contenuto, query,
prompt, estratti, path, URL, nomi file, bookmark e ID persistenti sono omessi, non
affidati alla sola redazione. I codici d'errore sono stabili; le cause tecniche
vengono ridotte a campi allowlist. La 0.1 non invia diagnostica.

Preview e tabelle trattano testo importato come testo, applicano escaping del
framework e non caricano risorse remote. Spotlight, Quick Look del contenuto e
thumbnail persistenti sono disattivi nella 0.1.

Ogni export attraversa staging e include soltanto la selezione dichiarata. CSV/TSV
neutralizzano celle interpretabili come formule quando destinate a fogli di calcolo;
HTML/Markdown non eseguono contenuto; JSON usa schema e encoding definiti. Prima
della scrittura finale vengono mostrati tipo, file, presenza di fonti e metadati.
L'`ExportManifest` GS-DAT registra byte e provenance, senza path sorgente.

La slice eseguibile PDF/Markdown/CSV/JSON rifiuta destinazioni esistenti e parent symlink,
scrive nomi generati in staging, applica limiti per file/manifest, esegue escaping
Markdown/CSV e verifica inventario, tipo, byte count e digest prima del rename. Il
PDF è aperto e verificato come documento bounded e taggato; i CSV sono una coppia
indivisibile con payload canonico e neutralizzazione formula-like. File
inattesi, path assoluti/traversal, link o manomissioni falliscono chiuso. Il report
contiene ID e strutture selezionate, mai il testo completo delle fonti per default.

Le letture di verifica dell'export mantengono aperta la radice no-follow e aprono
manifest e payload rispetto al suo descriptor. Tipo regolare, singolo hard link e
dimensione sono controllati sul file aperto; la lettura a chunk non trattiene byte
oltre la dimensione ammessa e verifica nuovamente dimensione e numero di link alla
fine. Un manifest JSON non decodificabile produce una failure export tipizzata.
La copertura e i limiti sono registrati in [GS-VER-148](../evidenze/GS-VER-148-letture-export.md):
inventario, scritture e rename non diventano una transazione filesystem ancorata,
gli antenati della radice non vengono verificati da questo incremento e non si
attesta protezione da ogni modifica concorrente, ACL o file provider.

## 12. Piattaforma, privilegi e supply chain

- App Sandbox, Hardened Runtime e firma sono obbligatori per la build di rilascio;
  entitlement aggiuntivi richiedono requisito, minaccia, test e ADR.
- L'accesso user-selected è preferito a directory generiche; il bookmark è aperto
  per il tempo minimo e ogni `startAccessing...` riuscito ha uno stop bilanciato.
- Processi/helper futuri hanno protocolli autenticati, messaggi bounded e privilegi
  non superiori alla funzione; un helper non è un modo per aggirare il sandbox.
- Nessuna dipendenza runtime esterna entra senza provenienza, licenza, pin, analisi
  transitive, manutenzione e strategia di rimozione secondo GS-STD-001-13.
- Build e release producono inventario/SBOM applicabile; segreti di firma non sono
  disponibili ai job di pull request.

## 13. Failure handling e risposta

Le failure seguono GS-STD-001-18 e GS-API-001. Corruzione e invariant violation
falliscono chiuso: nessuna riparazione silenziosa, nessuna prosecuzione su stato di
validità ignota. Il rapporto di recovery contiene solo codici, quantità e digest
consentiti.

Una vulnerabilità riceve ID privato, severità, versioni/formati interessati,
containment, correzione, test di regressione e decisione di disclosure. Una
modifica urgente non può eliminare lineage, validazione o gate; usa il processo di
deroga se un'evidenza non è immediatamente disponibile.

## 14. Gate ed evidenze

| Gate | Evidenza minima |
| --- | --- |
| G1 | asset, confini, minacce e requisiti tracciati |
| G2 | prototipi parser/package/query con limiti e failure injection |
| G3 | review sicurezza del diff, test negativi e matrice conformità aggiornata |
| G4 | fuzz/corpus avversario, sanitizer applicabili, audit entitlement/log/export e rischio residuo accettato |
| G5 | build firmata coerente, nessun P0/P1 aperto, risposta/rollback pronti |

La [matrice di conformità](../tracciabilita.md#matrice-di-conformità-implementativa)
è la risposta meccanica a requisito, clausola, codice, test, fixture, evidenza e
gate. Una riga `specificato` o `bloccato` non prova implementazione.

## 15. Riferimenti tecnici

- [Apple — Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Apple — Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Apple — FileManager.replaceItemAt](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat(_:withitemat:backupitemname:options:))
- [NIST SP 800-218 — Secure Software Development Framework](https://csrc.nist.gov/publications/detail/sp/800-218/final)
- [OWASP — Regular expression Denial of Service](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS)
