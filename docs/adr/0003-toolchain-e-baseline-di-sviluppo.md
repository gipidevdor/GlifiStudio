# ADR-0003 — Toolchain e baseline di sviluppo

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0003 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Toolchain disponibile e ADR-0001 |
| Sostituisce | Nessuno |

## Contesto

Il progetto richiede un ambiente compilabile per macOS e iPadOS, concorrenza Swift rigorosa e un simulatore iPad disponibile. La macchina di sviluppo dispone di Xcode 27.0, Swift 6.4, SDK 27 e runtime simulatore iOS/iPadOS 26.2.

## Decisione

- Xcode 27.0 e Swift 6.4 costituiscono la baseline iniziale della toolchain.
- Il codice usa Swift 6 language mode e strict concurrency.
- I deployment target minimi sono macOS 27.0 e iPadOS 27.0.
- Il progetto usa un workspace Xcode con app target separati e un package Swift locale condiviso.
- Configurazioni e schemi condivisi sono versionati.

## Conseguenze

- Entrambe le app possono essere compilate con la toolchain installata.
- La compatibilità con sistemi precedenti ai deployment target è esclusa.
- L'adozione esclusiva della generazione 27 riduce il bacino di dispositivi compatibili e semplifica l'uso delle API contemporanee.
- L'uso di API più recenti richiede availability check coerenti con i target.

## Alternative considerate

- un unico target multipiattaforma con condizioni di compilazione diffuse;
- due target applicativi separati e un package Swift locale condiviso;
- dipendenze globali da generatori del progetto non ancora adottati dal team.

La seconda alternativa rende espliciti i confini di piattaforma e mantiene il motore verificabile anche senza Xcode. La configurazione iniziale non impone strumenti globali ulteriori oltre alla toolchain Apple.

## Verifica

`Scripts/verify.sh` deve superare controllo documentale, controllo dei confini architetturali, lint, test e build macOS/iPadOS senza firma. La prima esecuzione riuscita è registrata in [GS-VER-001](../evidenze/GS-VER-001-bootstrap-ambiente.md).
