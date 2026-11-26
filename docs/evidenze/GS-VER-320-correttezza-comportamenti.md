<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-320 — Cancellazione degli export delle viste

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-320 |
| Tipo | Evidenza correttiva del lifecycle |
| Versione | 1.0.0 |
| Stato | Verifica mirata superata; gate integrato registrato dal coordinatore |
| Responsabile | Codex con revisione concorrente |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di massima correttezza dei comportamenti |
| Riferimenti | GS-DOR-320; GS-API-001 § 7; GS-API-003; GS-STD-001-18 |

## Difetto e correzione

`GlifiStudioProjectSession.exportVisualization` verificava la cancellazione
soltanto prima dell'admission. Un task cancellato durante l'admission poteva
ancora costruire e pubblicare il bundle e restituire una receipt di successo.
Il percorso project-command usato dalla CLI presentava lo stesso difetto.

Il writer interno ora controlla la cancellazione prima della verifica,
fra payload e immediatamente prima del rename staging→destinazione. Questa
è l'ultima osservazione: la cancellazione dopo il commit conserva successo e
receipt. Prima del commit restituisce `operation.cancelled`, categoria
`cancelled`, operazione `export`, retry `newRequest`, stato `unchanged`.
Il cleanup rimuove soltanto una directory staging creata dal writer corrente;
non adotta né rimuove destinazioni preesistenti.

API pubbliche, schema v1 e bytes del bundle restano invariati. Il callback dei
checkpoint è interno, sincrono, Sendable e non throwing; permette prove
deterministiche nel writer reale senza introdurre un nuovo trasporto.

## RED e GREEN

La regressione iniziale cancella il task nel provider runtime subito dopo
il controllo iniziale dell'admission: una definizione con due esecuzioni
(API nativa e project-command) fallisce con exit 1 e sei issue. Per entrambi
i percorsi sono osservati successo inatteso, destinazione pubblicata e retry
rifiutato perché la destinazione esiste già.

Il controllo mirato corretto passa con exit 0: **13 definizioni, 22 esecuzioni**,
senza issue. Include le tre definizioni nuove con dodici casi: API nativa e
project-command, task già cancellato con/senza destinazione utente e quattro
checkpoint con/senza cancellazione. I test verificano stato del progetto
invariato, eliminazione dello staging, conservazione dei file utente, retry
utile, output identici ai bytes iniziali e receipt/integrità validi dopo commit.

Restano verdi i controlli preesistenti di integrità, digest, compatibilità
delle quattro famiglie di viste e export di un Artifact persistito. Il lint
Swift mirato sui tre file del cambiamento passa. Il riepilogo portabile è
[GS-VER-320-verifica.json](allegati/GS-VER-320-verifica.json).

La revisione indipendente dell'agente di provenienza non rileva blocker:
verifica precedente alle scritture, ownership acquisita dopo la creazione,
cleanup del solo staging posseduto e receipt conservata dopo commit.
Una cancellazione che arriva nella finestra fra ultimo check e rename può
concludersi con successo, secondo il confine cooperativo dichiarato.

## Limiti

I checkpoint sono cooperativi: non interrompono una singola chiamata sincrona
Foundation o la costruzione di un payload. Questa correzione non certifica
la latenza di cancellazione, non attesta audit grafici/assistivi o iPadOS e
non autentica la provenienza di un bundle esterno. Il gate integrato macOS
e la sua composizione sono registrati nell'evidenza del lotto principale.
