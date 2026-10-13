<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Accessi ai file persistiti del package

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-011 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.1.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-04 |
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
