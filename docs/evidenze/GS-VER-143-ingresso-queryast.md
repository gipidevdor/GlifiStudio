<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-143 — Ingresso QueryAST nel percorso headless

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-143 |
| Tipo | Evidenza di ingresso headless e parità |
| Versione | 1.0.0 |
| Stato | Parziale; verifica nativa pendente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-06 |
| Approvazione | Attuazione GS-DOR-012; verifica del nuovo incremento pendente |
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
  il toolchain locale 6.2 rifiuta `swift-tools-version: 6.4`. Build, test Core/Kit
  e smoke CLI aggiunti richiedono esecuzione sui check Xcode 27 della PR; non
  vengono attestati come superati da questa evidenza locale.

## Limiti

La protezione del file AST riguarda il componente terminale, non un sandbox di
tutti i componenti del percorso scelto dall'utente. La lettura è bounded, non uno
snapshot atomico di un file modificato concorrentemente. Nessuna prova esaustiva
di interleaving filesystem, fuzz guidato da copertura o benchmark nuovo.
Indice, metadati/annotazioni, streaming e audit GUI su dispositivo restano fuori
perimetro. Per ritirare l'ingresso basta un revert; i package non richiedono
migrazione.
