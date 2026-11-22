<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0020 — Loop di qualità, dialetto Swift e CI early-fail

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0020 |
| Versione | 1.1.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Rafforzamento della qualità senza indebolire i gate esistenti |
| Integra | ADR-0003, ADR-0009, ADR-0015 |
| Sostituisce | Nessuno |

## Contesto

Il repository possiede già `make verify`, `swift format`, controlli documentali e
un job CI unico su runner `xcode-27`. Restano tre rischi operativi: il ciclo
locale è più lento del necessario per errori stilistici, la coerenza del dialetto
Swift 6 dipende da più script, e la CI non espone un early-fail di formato né una
cache SPM deterministica.

Introdurre SwiftLint o hook git obbligatori creerebbe una seconda autorità
stilistica e un percorso di sviluppo non equivalente alla CI.

## Decisione

1. L'autorità stilistica Swift resta Apple `swift format` con `.swift-format`
   versionato; SwiftLint non è adottato.
2. `Scripts/check-swift-dialect.py` è il controllo machine-readable del dialetto:
   tools 6.4, language mode 6, concurrency completa, regole obbligatorie e
   presenza dei target Make/CI.
3. Il loop locale espone `make format`, `make lint`/`make format-check`,
   `make check-swift-dialect`, `make quality` e `make verify`.
4. `make quality` esegue i controlli statici e stilistici senza build Xcode; non
   sostituisce `make verify`.
5. La CI espone early-fail `static-quality` (Linux, senza Xcode) e `format-check`
   (Xcode 27), e mantiene il job obbligatorio `verify` che invoca
   `Scripts/verify.sh`, con cache SPM a chiave deterministica su `verify` e
   `app-store-baseline`.
6. Non si introducono pre-commit hook obbligatori; eventuali hook locali restano
   facoltativi e non normativi.

## Alternative considerate

- SwiftLint come linter primario: respinta perché duplica `.swift-format` e
  introduce una dipendenza esterna non richiesta.
- Solo job `verify` monolitico: respinta perché ritarda il feedback su stile e
  dialetto.
- Pre-commit obbligatori: respinti perché frammentano il contratto rispetto a
  Makefile + CI e complicano agenti e ambienti headless.
- Rinominare il check richiesto: respinta perché le ruleset esigono il contesto
  `verify`.

## Conseguenze

- stile e dialetto falliscono prima del build completo;
- locale e remoto restano allineati sull'ingresso `Scripts/verify.sh`;
- la cache SPM riduce tempi ripetuti senza contenere segreti;
- una regola stilistica nuova richiede aggiornamento di `.swift-format` e del
  controllo dialettale nello stesso cambiamento.

## Verifica

`make check-swift-dialect`, `make quality` e `make verify` devono passare sulla
baseline Xcode 27. L'esito è registrato in
[GS-VER-029](../evidenze/GS-VER-029-loop-qualita-dialetto-swift.md).

## Riferimenti

- [GS-DEV-002](../loop-di-sviluppo-e-qualita.md)
- [GS-STD-001-12](../standard/12-implementazione-swift.md)
- [GS-STD-001-20](../standard/20-integrazione-continua-e-quality-gate.md)
- [GS-REP-005](../repository/05-ci-e-runner-xcode.md)
