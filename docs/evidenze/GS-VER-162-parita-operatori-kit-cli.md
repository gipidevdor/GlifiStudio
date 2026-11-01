<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Verifica — Parità degli operatori testuali fra GlifiKit e CLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-162 |
| Tipo | Evidenza di verifica del contratto headless |
| Versione | 1.0.1 |
| Stato | Superato localmente; limiti dichiarati |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-01 |
| Approvazione | Ambito autorizzato RF-087; nessuna review esterna simulata |
| Riferimenti | GS-API-002; TV-088; CMP-162; GS-DOR-162; GS-VER-161 |

## Oggetto

Unico dispatcher GlifiKit con request Swift tipizzata, JSON bounded versionato,
digest canonico e DTO condivisi. La CLI adatta esclusivamente input/output.
Nessuna modifica agli algoritmi, alla UI, al planner o alla persistenza .glifi.

## Piano di verifica

- 15 fixture sintetiche, quattro varianti MDS e tutte le 12 operazioni.
- Parità completa Swift/JSON/CLI, ripetizione seeded e golden sui casi minimi.
- SHA-256 controllato anche da Python sui byte canonici esportati dai test Kit.
- Default risolti, ordine chiavi, seed UInt64 massimo, troncamenti, chiavi
  sconosciute/duplicate anche escaped, null errati e versioni future.
- Limiti di byte, profondità e collezioni, non finiti e cancellazione tipizzata.
- File regolari, link simbolici finali, FIFO, directory e file assenti; exit status,
  stdout/stderr e failure prive di canary e path.
- `make verify` su cache/temporanei isolati, senza cambiare servizi dell'host.

Tolleranza numerica 1e-12 assoluta e relativa; confronti strutturali esatti per
identificatori, digest, indici, interi e stringhe. L'evidenza scientifica resta
quella dei manifest GS-VER-161: la parità di trasporto non è una nuova promozione.
La revisione esterna V6 e le prove su dispositivo iPadOS rimangono aperte.

## Esito nella copia di sviluppo condivisa

Gate completo `make verify` terminato con **exit 0** sullo stato della copia di sviluppo condivisa.
I metadati della consegna sono stati ricontrollati separatamente dopo il gate;
la scheda DoR resta nella tracciabilità e non è classificata come rapporto di test.

- **291 test Core/Kit**: 256 Core e 35 Kit, inclusi sette nuovi test del trasporto.
- **15 fixture condivise, 51 controlli CLI**: risultati integrali entro 1e-12,
  golden minimi, ripetizioni seeded, identificatori e digest esatti, modalità
  testuale e JSON, errori e file speciali. Permessi negati verificati con file
  sintetico privo di autorizzazione alla lettura sull'host non root.
- **120 righe di oracoli numerici** indipendenti riprodotte e collegate ai test;
  nessun algoritmo statistico modificato da questo incremento.
- **22 checkpoint di recovery** dopo process kill e **due PDF/A-2u** conformi.
- **8 test macOS**, zero failure e zero test saltati, confermati dal bundle xcresult.
- Build macOS Debug/test e Release, iPadOS Debug e Release su destinazione
  generica Simulator, tutte completate.
- Controlli statici, confini architetturali, localizzazione, tassonomia delle
  failure, documentazione, conformità, fixture e formattazione superati.

Xcode 27.1, Apple Swift 6.4 e macOS 27.2. Python 3.14.9 già installato per i
controlli di sviluppo. Cache e temporanei dedicati, priorità CPU ridotta;
nessun aggiornamento di servizi, dipendenze o piattaforme. Le directory dedicate
di questa esecuzione sono state eliminate dopo i controlli.

Il controllo CLI ha individuato e fatto correggere l'ordine fra intestazione
testuale e JSON: entrambi ora usano lo stesso stream di FileHandle, senza
mescolare buffer differenti. Le failure POSIX di apertura distinguono input,
autorizzazione, risorse e I/O temporaneo secondo la tassonomia.

Il disallineamento CoreSimulator già presente sull'host e l'avviso iPadOS
sull'apertura in-place restano avvisi delle build; non è stata eseguita una prova
UI su dispositivo iPadOS. Nessun file delle app o configurazione dei servizi è
stato modificato da questo incremento. La revisione scientifica esterna V6 e le
soglie prestazionali su hardware di riferimento restano separate da questa
verifica del trasporto.

## Verifica del branch di pubblicazione

Il branch di pubblicazione è stato ricostruito in un worktree isolato sulla base
remota `3fa454feb5711d4533b31e62ce31deb85a3dad63`, preservando i quattordici commit
remoti successivi alla copia di sviluppo. Sono state riportate soltanto le
modifiche della libreria, dei suoi strumenti, dei test e della documentazione
pertinente; il checkout condiviso non è stato modificato.

`make verify` ripetuto sul contenuto integrato: **exit 0**, **326 test Core/Kit**
(290 Core, 36 Kit), **128 righe di oracoli**, **51 controlli CLI** su 15 fixture,
verifiche QueryAST CLI, **22 checkpoint di recovery** e **due PDF/A-2u** conformi.
Build macOS e iPadOS Debug/Release tutte completate; i medesimi avvisi dell'host
restano non bloccanti. I controlli statici e i metadati sono stati ricontrollati
prima del commit.

Gli otto test macOS dello stato precedente appartengono alle modifiche
applicative concorrenti della copia condivisa: non fanno parte di questo delta.
Il branch riproduce il gate applicativo presente su main, che esegue le build.
La revisione scientifica esterna V6 e le prove su dispositivo restano aperte.
