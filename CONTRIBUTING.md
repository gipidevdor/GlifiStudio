<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Contribuire a Glifi Studio

Il repository è privato: può contribuire soltanto chi è stato autorizzato dal responsabile del repository. L'accesso non implica il permesso di copiare dati, credenziali o materiali di terzi nel progetto.

## Prima di iniziare

1. Leggere lo [standard di progetto](docs/standard-di-progetto.md), l'[architettura](docs/architettura.md) e gli [ADR vigenti](docs/adr/README.md).
2. Aprire o collegare una issue per ogni modifica non banale.
3. Registrare con un ADR le decisioni che cambiano confini, dipendenze, formati persistenti, sicurezza, piattaforme o tecnologie strutturali.
4. Non lavorare mai con corpus reali o dati personali nel repository.

## Flusso di lavoro

- Creare un branch breve da `main`, con nome `tipo/descrizione-breve`, per esempio `feat/importazione-pdf` o `fix/offset-unicode`.
- Mantenere ogni modifica focalizzata e integrare spesso `main` senza riscrivere la storia condivisa.
- Aprire una pull request in bozza appena il contesto è abbastanza chiaro.
- Compilare integralmente il modello di pull request e collegare requisiti, ADR, issue ed evidenze applicabili.
- Richiedere revisione solo dopo il superamento locale di `make verify-app-store`. Deroga
  puntuale concessa dall'iniziatore il 2026-11-21 per le PR #34 e #33, prive di macchina macOS
  locale: il preflight è stato soddisfatto dal job `verify` del workflow `Verifica` e dal job
  `app-store-baseline` del workflow `App Store preflight`, entrambi sul runner `xcode-27` e
  verdi sulla head definitiva; il limite è registrato nelle evidenze GS-VER-166 e GS-VER-167.
  Ogni altra deroga richiede una decisione esplicita dell'iniziatore registrata qui.
- Integrare soltanto con controlli verdi, conversazioni risolte e approvazioni richieste dalla ruleset.

## Commit

I messaggi seguono la forma `tipo(ambito): risultato`, con descrizione breve all'imperativo. Tipi ammessi:

- `feat`, `fix`, `perf`, `refactor` per il prodotto;
- `test`, `docs` per qualità e documentazione;
- `build`, `ci`, `chore` per toolchain e manutenzione;
- `revert` per annullamenti espliciti.

Un cambiamento incompatibile usa `!` dopo il tipo o l'ambito e spiega conseguenze e migrazione nel corpo. Non inserire numeri di issue al posto della descrizione del risultato.

## Qualità richiesta

Prima della pull request eseguire:

```sh
make bootstrap
make format
make quality-static
make quality
make verify
make verify-app-store
```

`make quality-static` e `make quality` accelerano il feedback su documentazione,
dialetto Swift e formattazione; non sostituiscono `make verify`. Il contratto
completo è in [GS-DEV-002](docs/loop-di-sviluppo-e-qualita.md).

Ogni correzione deve includere un test di regressione quando riproducibile. Ogni modifica a hot path, formati o persistenza deve includere rispettivamente benchmark, prove di compatibilità o migrazione. L'interfaccia nasce in italiano ma tutte le stringhe visibili devono restare localizzabili e accessibili.

## Dipendenze e codice di terzi

Una dipendenza nuova richiede motivazione, valutazione di alternative Apple, manutenzione, licenza, sicurezza, dimensione e strategia di rimozione. Non copiare codice da fonti esterne senza provenienza e licenza compatibile. `Package.resolved`, quando generato per l'applicazione, deve essere versionato.

## Sicurezza e riservatezza

Non inserire segreti, certificati, profili di provisioning, chiavi, token, dati personali, documenti degli utenti o dettagli riservati nelle issue e nei log. Le vulnerabilità seguono [SECURITY.md](SECURITY.md), non il normale issue tracker.

## Licenza dei contributi

Inviando un contributo, il contributore dichiara di avere il diritto di fornirlo e accetta che sia distribuito secondo la [BSD 3-Clause](LICENSE). Un eventuale DCO o CLA resta una decisione separata finché proprietà e modello contributivo non saranno formalizzati.
