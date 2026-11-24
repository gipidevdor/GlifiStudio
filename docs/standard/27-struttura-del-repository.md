# 27. Struttura del repository

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-27 |
| Tipo | Capitolo normativo |
| Versione | 1.3.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 27.1 Albero canonico

```text
GlifiStudio/
├── .github/                   # CI, Dependabot, issue e pull request
├── Apps/
│   ├── Shared/                # composizione UI condivisa e risorse
│   ├── macOS/                 # ingresso applicazione macOS
│   └── iPadOS/                # ingresso applicazione iPadOS
├── Benchmarks/                # misure riproducibili e manifesti
├── Config/                    # xcconfig, entitlement e configurazioni target
├── Fixtures/                  # soli dati sintetici o redistribuibili
├── Packages/
│   └── GlifiCore/             # GlifiCore, GlifiKit, GlifiCLI e relativi test
├── Scripts/                   # quality gate e operazioni riproducibili
├── docs/
│   ├── adr/                   # decisioni architetturali
│   ├── apple/                 # profilo tecnologico Apple
│   ├── evidenze/              # risultati controllati di verifica
│   ├── esperienza-utente/     # paradigma, indagine, planner e interazione
│   ├── metodi-analitici/      # specifiche matematiche e scientifiche
│   ├── repository/            # governo e configurazione del repository
│   ├── specifiche-di-design/  # dieci contratti implementativi autorevoli
│   └── standard/              # un argomento normativo per documento
├── GlifiStudio.xcodeproj/     # progetto Xcode condiviso
├── GlifiStudio.xcworkspace/   # ingresso Xcode canonico
├── AGENTS.md                  # regole operative per agenti software
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── GOVERNANCE.md
├── LICENSE
├── Makefile
├── README.md
├── SECURITY.md
└── SUPPORT.md
```

## 27.2 Responsabilità dei confini

- `Apps/` contiene adattatori di piattaforma e composizione; non deve diventare il motore analitico.
- `Packages/GlifiCore` possiede il codice condiviso verificabile senza UI; le dipendenze seguono i layer definiti dall'architettura.
- `Config/` non contiene segreti né valori personali.
- `Scripts/` fornisce ingressi stabili richiamati da `Makefile` e CI.
- `.github/` configura il servizio ma non sostituisce regole e script versionati.
- `docs/` contiene information item controllati; i file root contengono politiche di accesso immediato per collaboratori e piattaforma.
- `docs/metodi-analitici/` definisce semantica e verifica dei metodi senza dipendere da implementazione o GUI.
- `docs/esperienza-utente/` definisce semantica dell'interazione senza duplicare
  formule GS-MET, regole Apple o layout non ancora validati.
- `docs/specifiche-di-design/` definisce dominio, dati, lingua, query, sistema
  analitico, runtime, UI, visualizzazione, validazione e baseline prodotto; il suo
  indice mantiene i confini di autorità.

## 27.3 Dati e artefatti

Corpus reali riservati **NON DEVONO** essere collocati in `Fixtures/` o `Benchmarks/`. Fixture e generatori devono essere minimi, autorizzati e sufficienti a riprodurre il comportamento. Build, Derived Data, risultati, archivi, simboli e credenziali sono esclusi dal controllo versione.

Una nuova directory di primo livello **DEVE** avere responsabilità distinta, proprietario e documentazione; se altera i confini architetturali richiede ADR.
