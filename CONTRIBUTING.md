<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Contribuire a Glifi Studio

Contribuisci solo se il responsabile del repository ti ha autorizzato. Il repository
è privato: l'accesso non autorizza a copiarvi dati, credenziali o materiali di terzi.

## Prima di iniziare

1. Leggi lo [standard](docs/standard-di-progetto.md), l'[architettura](docs/architettura.md) e le [decisioni vigenti](docs/adr/README.md).
2. Apri o collega una issue per ogni modifica non banale. Registra un ADR se cambi confini, dipendenze, formati persistenti, sicurezza, piattaforme o tecnologie strutturali.
3. Crea da `main` un branch breve, `tipo/descrizione-breve`, come `feat/importazione-pdf` o `fix/offset-unicode`. Mantieni la modifica focalizzata e integra spesso `main`, senza riscrivere la storia condivisa.

## Verifica la modifica

Prima della pull request eseguire:

```sh
make bootstrap
make format
make quality-static
make quality
make verify
make verify-app-store
```

`quality-static` e `quality` anticipano i controlli su documentazione, dialetto
Swift e formattazione; non sostituiscono `make verify`. Segui il
[contratto del loop di sviluppo](docs/loop-di-sviluppo-e-qualita.md).

La priorità corrente è macOS: gli ingressi predefiniti e la CI usano il profilo
macOS. `make verify-all` e `make verify-app-store-all` includono iPadOS e si usano
soltanto quando viene richiesta la verifica di entrambe le piattaforme.

Includi un test di regressione per ogni correzione riproducibile. Accompagna le
modifiche agli hot path con benchmark, ai formati con prove di compatibilità e
alla persistenza con prove di migrazione. L'interfaccia nasce in italiano:
mantieni tutte le stringhe visibili localizzabili e accessibili.

## Apri la pull request

Apri una bozza appena il contesto è chiaro. Compila tutto il modello e collega
requisiti, ADR, issue ed evidenze applicabili. Richiedi revisione solo dopo il
superamento locale di `make verify-app-store`.

Deroga puntuale concessa dall'iniziatore il 2026-11-21 per le PR #34 e #33, prive di macchina macOS
  locale: il preflight è stato soddisfatto dal job `verify` del workflow `Verifica` e dal job
  `app-store-baseline` del workflow `App Store preflight`, entrambi sul runner `xcode-27` e
  verdi sulla head definitiva; il limite è registrato nelle evidenze GS-VER-166 e GS-VER-167.
  Ogni altra deroga richiede una decisione esplicita dell'iniziatore registrata qui.

Integra solo con controlli verdi, conversazioni risolte e approvazioni richieste
dalla ruleset.

## Scrivi i commit

Usa `tipo(ambito): risultato`, con descrizione breve all'imperativo. Tipi ammessi:
`feat`, `fix`, `perf`, `refactor` per il prodotto; `test`, `docs` per qualità e
documentazione; `build`, `ci`, `chore` per toolchain e manutenzione; `revert` per
annullamenti espliciti.

Per un cambiamento incompatibile, aggiungi `!` dopo il tipo o l'ambito e spiega
conseguenze e migrazione nel corpo. I numeri di issue non sostituiscono la
descrizione del risultato.

## Dipendenze e codice di terzi

Motiva ogni nuova dipendenza e valuta alternative Apple, manutenzione, licenza,
sicurezza, dimensione e strategia di rimozione. Non copiare codice esterno senza
provenienza e licenza compatibile. Versiona `Package.resolved` quando viene
generato per l'applicazione.

## Sicurezza e riservatezza

Non usare corpus reali o dati personali nel repository. Non inserire segreti,
certificati, profili di provisioning, chiavi, token, dati personali, documenti
degli utenti o dettagli riservati nelle issue e nei log. Segnala le vulnerabilità
come indicato in [SECURITY.md](SECURITY.md), non nel normale issue tracker.

## Licenza dei contributi

Inviando un contributo, dichiari di avere il diritto di fornirlo e accetti la
distribuzione secondo la [BSD 3-Clause](LICENSE). Un eventuale DCO o CLA resta
una decisione separata finché proprietà e modello contributivo non saranno
formalizzati.
