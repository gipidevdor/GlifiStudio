<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Parità continua fra GlifiKit e CLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-275 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita: «Devono essere sempre allineate cli e kit» |
| Riferimenti | RQ-060; RQ-063; GS-API-001; GS-API-002; ADR-0036 |

## outcome e confini

Ogni operazione utente pubblica di GlifiKit deve essere raggiungibile dalla CLI
con tutti i parametri del contratto Kit. Le primitive di costruzione dei DTO,
serializzazione, presentazione e lifecycle rimangono censite con motivazione;
non rappresentano algoritmi aggiuntivi. Non cambia il formato `.glifi` né lo
stato scientifico delle analisi.

## Contratto operativo

I nuovi ingressi JSON chiamano dispatcher GlifiKit condivisi. Statistica e
operatori usano gli stessi DTO Codable dei client nativi; valutazione e comandi
di progetto hanno richieste versionate e bounded. Opzioni di corpus e keyness,
input lessicali/temporali e annotazioni linguistiche conservano i parametri
effettivi. I vecchi comandi rimangono compatibili.

## failure semantics, privacy e risorse

File regolari aperti con descrittore controllato, limite di 1 MiB, profondità
limitata, rifiuto di chiavi duplicate e sconosciute, failure tipizzate e nessun
contenuto o percorso nella diagnostica. I calcoli restano fuori Main Actor e
conservano limiti, cancellazione e semantica transazionale delle API esistenti.
Nessuna rete, dipendenza, entitlement o modifica algoritmica.

## Accettazione e verifica

Fixture nominali per tutti i casi degli enum operativi; confronto integrale
Kit/CLI di valori, identità, diagnostici e parametri, oltre a failure e input
ostili. Inventario pubblico derivato dal compilatore per intercettare nuove API,
campi e firme senza copertura. `make verify` include questi controlli; evidenza
e limiti effettivi sono registrati in GS-VER-275. Nessuna affermazione di
copertura dei casi infiniti di input o di nuova validazione scientifica.

## tracciabilità e stato

**Ready**: RQ-060, RQ-063, TV-073, ADR-0036 e GS-API-003 definiscono il
contratto. CMP-275 e GS-VER-275 registrano implementazione, gate e limiti.
