# Modello di governo privato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REP-001 |
| Tipo | Procedura operativa |
| Versione | 1.0.0 |
| Stato | Attivo |
| Responsabile | Amministratore del repository, provvisorio |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline operativa richiesta dal promotore |

## Obiettivo

La visibilità privata riduce l'esposizione, ma non sostituisce controllo degli accessi, revisione o protezione dei dati. L'accesso viene concesso per necessità, con il ruolo minimo e per il tempo necessario.

## Responsabilità

| Attività | Responsabile | Approvazione o verifica |
| --- | --- | --- |
| Priorità e requisiti | Responsabile di prodotto | Promotore del progetto |
| Architettura e ADR | Responsabile tecnico | Revisore competente |
| Accessi e impostazioni remote | Amministratore repository | Titolare del progetto |
| Sicurezza, privacy e incidenti | Responsabile sicurezza | Responsabile di prodotto per rischio residuo |
| Integrazione in `main` | Maintainer | CI e revisione |
| Rilascio | Responsabile di prodotto | Checklist e firma autorizzata |

All'inizio una persona può ricoprire più ruoli. La pull request o l'ADR deve rendere riconoscibile il ruolo esercitato, senza simulare una separazione delle responsabilità inesistente.

## Ciclo degli accessi

1. registrare motivo, ruolo e perimetro dell'accesso;
2. richiedere autenticazione forte e dispositivo protetto;
3. concedere il ruolo minimo, evitando privilegi amministrativi ordinari;
4. riesaminare gli accessi almeno ogni tre mesi e a ogni cambio di collaborazione;
5. revocare immediatamente accessi non più necessari, token e chiavi correlate;
6. registrare incidenti o deviazioni senza includere segreti.

Account condivisi e credenziali trasferite fra persone sono vietati. Fork privati, copie locali, artefatti CI e backup restano soggetti alla stessa riservatezza del repository.

## Governo delle modifiche

Le regole generali sono in [GOVERNANCE.md](../../GOVERNANCE.md) e [CONTRIBUTING.md](../../CONTRIBUTING.md). Le eccezioni usano una deroga controllata; il bypass di una protezione non costituisce approvazione implicita della modifica.
