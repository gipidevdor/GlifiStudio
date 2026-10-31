<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-143 — Ingresso QueryAST nel percorso headless

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-143 |
| Tipo | Evidenza di ingresso headless e parità |
| Versione | 1.1.0 |
| Stato | Superato sul runner Xcode 27 nel perimetro G3 dichiarato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-24 |
| Approvazione | Attuazione GS-DOR-012; esito tecnico G3, non audit G4 |
| Riferimenti | GS-DOR-012; GS-QRY-001; GS-API-001; RF-080; RQ-042; RQ-044; RQ-046; CMP-081; TV-053; TV-060 |

## Ambito

`query --ast <query.json>` e `GlifiStudioProjectSession.query(canonicalAST:)`
ricevono il QueryAST v1 già definito. Il Core decodifica JSON bounded (64 KiB,
1.024 nodi, profondità 32) e controlla le invarianti prima di scansionare fonti.
Il contatore di decodifica è locale al decoder e protetto da `Mutex`, senza
conformità `Sendable` non verificate. Tutti i tipi di arco ricorsivo consumano
profondità; la radice è a zero. I flag regex sconosciuti sono rifiutati.

Testo e AST passano dallo stesso percorso `GlifiEngine.executeQuery`: digest,
ordine, offset, KWIC, limiti e troncatura restano comuni. La CLI apre il file con
`O_NOFOLLOW`, `O_NONBLOCK`, `O_CLOEXEC`, controlla tipo/dimensione con `fstat` e
legge al massimo 64 KiB più un byte sentinella. I descriptor e la sessione vengono
chiusi anche in caso di failure. I messaggi sono localizzabili e non riportano
path, contenuto o dettagli del decoder. Nessun nuovo formato persistente,
dipendenza, rete o UI.

## Regressioni aggiunte

- `GlifiQueryASTInputTests`: round-trip canonico, digest, limiti esatti di byte,
  nodi/profondità, alberi profondi/larghi, tutti gli archi ricorsivi, schema e
  grammatica incompatibili, JSON malformato, scope non decodificabile, campi e
  operatori non validi, regex non ammesse, cancellazione e canary privacy.
- `GlifiQueryParityTests`: sulla fixture esistente, uguaglianza dell'intero
  risultato Kit tra testo e AST, generazione immutata, mapping delle failure e
  rifiuto della sessione chiusa.
- `Scripts/check-query-ast.py`, invocato da `make verify`: parità dell'envelope
  CLI per JSON compatto e non canonico, limite esatto 64 KiB, byte/nodi/profondità
  oltre budget, input incompatibili/malformati, symlink, directory, FIFO, file
  mancante, argomenti mancanti/combinati, canary su stdout/stderr e riuso dopo
  failure. Timeout esplicito per evitare che un FIFO blocchi il gate.

## Verifiche osservate

- Linux, Swift 6.2: `make quality-static`, `make check-failure-taxonomy`,
  `make check-failure-messages`, `Scripts/format.sh --check` e `git diff --check`
  superati. Sintassi Python dello smoke test e sintassi zsh di `verify.sh` valide.
- `make verify` e `make verify-app-store` tentati: arresto sul controllo disco
  `df -g`, opzione BSD/macOS non disponibile su GNU/Linux. Non è stato cambiato
  il gate per aggirare la piattaforma richiesta.
- `swift test --package-path Packages/GlifiCore --filter queryASTInput` tentato:
  il toolchain locale 6.2 rifiuta `swift-tools-version: 6.4`. Nessuna build o
  esecuzione nativa viene attribuita alla VM Linux.

### Esecuzione remota del 2026-10-16

Sulla revisione `f1e112ba5664a7a0bb56d7cb4884eb064b9779cb` di
[PR #18](https://github.com/gpicchiarelli/GlifiStudio/pull/18) i quattro check
`static-quality`, `format-check`, `verify` e `app-store-baseline` sono passati.
L'ambiente registrato nel log è macOS 27.0.1, immagine `xcode-27-arm64`.

| Check | Job | Esito osservato |
| --- | --- | --- |
| `verify` | `117221998396` | 246 test Swift superati; smoke CLI QueryAST superato |
| `app-store-baseline` | `117221926507` | Preflight superato; 246 test Swift e smoke CLI QueryAST superati |

Il log dello smoke riporta «QueryAST CLI: parità, limiti, file ostili, permessi,
argomenti e privacy superati». Le regressioni Core/Kit e CLI dell'ingresso AST
sono quindi eseguite, non soltanto compilate. Il test dell'albero profondo usa
la costruzione testuale integrata con PR #17, senza ricorsione di `JSONEncoder`
prima del decoder bounded. La classificazione dei permessi è documentata in
[GS-VER-147](GS-VER-147-permessi-queryast.md).

CMP-081 passa da `blocked` a `verified` per la parità G3 fra Core, Kit e CLI,
insieme all'evidenza preesistente [GS-VER-123](GS-VER-123-parita-queryast-client.md).
Questo esito non estende il perimetro della slice né attesta la validazione
PDF/A: il gate l'ha saltata per assenza di veraPDF. Il preflight non è
un'approvazione App Store né una verifica di distribuzione firmata.

## Limiti

La protezione del file AST riguarda il componente terminale, non un sandbox di
tutti i componenti del percorso scelto dall'utente. La lettura è bounded, non uno
snapshot atomico di un file modificato concorrentemente. Nessuna prova esaustiva
di interleaving filesystem, fuzz guidato da copertura o benchmark nuovo.
Indice, metadati/annotazioni, streaming e audit GUI su dispositivo restano fuori
perimetro. Per ritirare l'ingresso basta un revert; i package non richiedono
migrazione.
