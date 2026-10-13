<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Accessi ai file persistiti del package

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-011 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.3.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-06 |
| Approvazione | Richiesta dell'iniziatore: migliorare qualità e sicurezza; review della PR pendente |
| Riferimenti | GS-SEC-001 § 8; GS-DAT-001; RF-043; RQ-044; RQ-057; ADR-0019; ADR-0022; ADR-0027 |

## Confini e criteri di accettazione

**Ready** per l'implementazione, non per la chiusura della verifica.

| Voce | Evidenza |
| --- | --- |
| outcome e confini | Accessi ai file e permessi della persistenza; nessuna nuova funzionalità |
| failure semantics | Dati o lock non validi: corruption senza retry; contesa del lock: transientIO con transientBackoff, invariata |

- Applicare alle letture del manifest e della storia qualitativa i controlli bounded sugli
  oggetti persistiti, verificando il file aperto e mantenendo digest e validazione canonica.
- Rafforzare creazione dei file, writer lease e permessi di package/export senza cambiare
  formato persistente, API pubbliche, dipendenze, UI o strategia transazionale.
- Fallire con errori tipizzati, senza aggiornare la generazione o alterare file estranei.
- Aggiungere regressioni sintetiche per input non regolari, limiti, recupero e permessi;
  preservare round-trip e compatibilità delle fixture esistenti.

## Verifica e tracciabilità

### Estensione: letture relative a directory aperte

Su richiesta di prosecuzione dell'iniziatore, estendere il controllo alle directory
intermedie delle letture di manifest, fonti, descriptor, Artifact ed eventi:

- aprire la radice del package senza seguire link, quindi risolvere ogni componente con
  `openat`, `O_DIRECTORY` e `O_NOFOLLOW`; non ricostruire un path assoluto per leggere;
- rifiutare componenti vuoti, `.`/`..`, path assoluti, NUL e separatori alternativi prima
  di qualsiasi normalizzazione URL; mantenere i limiti bounded e il controllo del file finale;
- provare ogni livello di directory e la sostituzione deterministica di una directory già
  aperta: il descriptor resta ancorato all'oggetto originale, senza seguire il nuovo link;
- preservare API, formato e protocollo di commit; nessuna nuova dipendenza o policy;
- mantenere CMP-095 `blocked`: scritture, SQLite, ACL e file provider non sono coperti
  integralmente da questa estensione. Evidenza separata in
  [GS-VER-142](../evidenze/GS-VER-142-letture-directory-package.md).

La scheda è aggiornata insieme al codice; non costituisce attestazione retroattiva del gate DoR.

### Estensione: pubblicazione degli oggetti immutabili

Registrata prima del coding su richiesta dell'iniziatore di proseguire gli sviluppi.
Stato `Ready` nell'ambito di RF-043, RQ-044 e RQ-057, senza nuova decisione architetturale.

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e stop | Impedire che la promozione di fonti, Artifact, descriptor ed eventi crei directory o sposti byte attraverso directory simboliche; non sovrascrivere destinazioni esistenti |
| dominio/API | Helper interno con ownership RAII dei descriptor; API pubbliche, digest e commit point invariati |
| failure | Directory non valide: `corruption`, nessun retry; errori operativi di creazione/rinomina: `transientIO`, `transientBackoff`; manifest e ultima generazione restano validi |
| esperienza | Nessuna UI nuova: le failure tipizzate attraversano il contratto esistente; accessibilità N/A perché non cambia alcuna superficie |
| verifica | Regressioni sintetiche su quattro livelli, collisioni e sostituzione deterministica di directory già aperte; compilazione e gate Xcode 27; evidenza candidata GS-VER-144 |
| dati/migrazione | Nessuna migrazione; oggetti già esistenti riusati soltanto dopo confronto bounded di dimensione e digest; staging duplicato rimosso dal cleanup transazionale esistente |
| sicurezza/privacy | `mkdirat` privato e `openat` nofollow per ogni livello; `renameatx_np` esclusivo rispetto ai descriptor, senza fallback a copia o overwrite |
| prestazioni | Attraversamento lineare nel numero bounded di componenti; nessuna lettura aggiuntiva dell'intero payload rispetto alla validazione esistente; nessun miglioramento prestazionale dichiarato |
| rischi | Filesystem senza rinomina esclusiva: fallimento chiuso, senza fallback; restano fuori staging iniziale, sostituzione manifest, cleanup, SQLite, ACL e file provider |
| tracciabilità | CMP-095 resta `blocked`, TV-060 aperto; rollback con revert senza migrazione |

I test non devono usare sleep per simulare la sostituzione dei percorsi. Una directory
già aperta può essere rinominata fuori dal package: si garantisce l'identità del descriptor,
non il mantenimento della sua collocazione nominale. Il runtime locale macOS 26.5.2
non permette di dichiarare eseguiti test che richiedono macOS 27.

### Estensione: staging privato delle transazioni

Registrata prima del coding su richiesta di prosecuzione dell'iniziatore. Stato `Ready`
per RF-043, RQ-044 e RQ-057; nessuna nuova API pubblica o decisione architetturale.

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e stop | Creare ogni transazione con `mkdirat` esclusivo `0700` e scrivere i file staged con `openat`, `O_EXCL`, `O_NOFOLLOW`, `0600`, senza seguire directory sostituite |
| dominio/API | Helper interno; mantenere vivi i descriptor di staging fino alla promozione degli oggetti; nessun cambio a schema, nomi o commit point |
| failure | Collisioni: `corruption` senza retry; errori operativi di creazione: `transientIO` con `transientBackoff`; nessuna adozione di directory preesistenti |
| verifica | Test sintetici per collisioni, permessi, componenti non validi, directory sostituite e staging interrotto di fonti/Artifact/eventi; GS-VER-145 |
| sicurezza/privacy | File creati esclusivamente e sincronizzati; nessun chmod di oggetti preesistenti; nessuna nuova dipendenza, rete o telemetria |
| esperienza e dati | Nessuna superficie UI o migrazione; failure attraverso il contratto esistente; cleanup e recupero invariati |
| prestazioni | Nessun benchmark prestazionale rivendicato; accessi lineari nel numero bounded di componenti |
| rischi e recupero | Sostituzione manifest, cleanup, SQLite, lock e identità della radice per tutta la sessione restano fuori; rollback via revert, CMP-095 `blocked` e TV-060 aperto |

La scrittura ancorata a un descriptor non rende sicuri i successivi accessi path-based:
non si dichiara contenimento dell'intera transazione né durabilità ai power loss.

### Controlli

Controlli statici, lint Swift, compilazione e `make verify` sulla baseline Xcode 27/macOS 27.
Risultati e limiti sono registrati in [GS-VER-140](../evidenze/GS-VER-140-accessi-file-package.md),
nella matrice di tracciabilità e in CMP-095. Non è una nuova decisione architetturale:
si attuano controlli già richiesti da GS-SEC-001. La scheda è registrata insieme
all'implementazione; non attesta un'approvazione preventiva o il completamento del gate.

## Rischi e recupero

La verifica dinamica richiede il runtime previsto dal prodotto: non abbassare deployment target
o gate per eseguirla su un sistema precedente. La PR resta in bozza fino alla verifica completa.
Nessuna migrazione è necessaria; rollback tramite revert della modifica. Il contenimento di
tutti gli accessi sotto sostituzione concorrente resta fuori da questo incremento: l'estensione
protegge la risoluzione delle singole letture, non l'identità del package per l'intera sessione.
