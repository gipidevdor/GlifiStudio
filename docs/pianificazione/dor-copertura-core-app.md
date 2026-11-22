<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Copertura funzionale del core nell'app

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-223 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready con rischio accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di includere tutte le features del core |
| Riferimenti | RF-026; RF-028; RF-033; RF-037; RF-040; RF-041; RF-044; RF-045; RF-046; RF-087; ADR-0035; GS-UX-001-17 |

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Accesso applicativo alle famiglie analitiche utente del core; gli operatori infrastrutturali restano parte dei percorsi esistenti |
| requisiti | Analisi corpus dirette e parametrizzate; statistica generale, matrici/grafi, valutazioni temporali e linguistiche; conservazione di metodo, input effettivo e limiti |
| dominio/API | Facciate GlifiKit soltanto; API persistite esistenti oppure DTO di sessione; nessun nuovo schema `.glifi` |
| failure semantics | Input e costi bounded, errori tipizzati, cancellazione posseduta, output precedente conservato, nessun commit tardivo dopo reset |
| esperienza prevista | Accesso ricercabile per metodo/scopo, impostazioni e risultati separati, annotazioni e dati espliciti, tabelle equivalenti paginabili, stringhe it/en |
| verifica | Inventario delle famiglie, confronto facciata/core e test dei modelli; `make verify`, controlli documentali e osservazione GUI solo quando eseguibile |
| dati e migrazione | Input aggiuntivi in memoria, nessun corpus reale o annotazione inventata; JSON dei nuovi DTO distinto da progetto e indagine |
| sicurezza/privacy | Nessuna rete, dipendenza o entitlement; parsing tabellare limitato agli input espliciti, nessun eval o codice eseguibile |
| prestazioni/sistema | Preparazione e calcolo fuori Main Actor, limiti prima delle allocazioni rilevanti e pagine di risultati; nessuna promessa prestazionale senza misura |
| tracciabilità | GS-VER-223 registra capacità, prove e limiti; CMP-223 resta implemented finché gli audit applicabili sono aperti |
| decisioni | ADR-0035 autorizza l'integrazione, senza promozione scientifica, nuovo backend annotativo o chiusura G4/G5 |

## Rischio accettato

**Ready con rischio accettato.** L'ampiezza delle capacità richiede una verifica per famiglia e input sintetici.
La richiesta autorizza l'implementazione, non una certificazione di ergonomia o
di validità scientifica globale. Il contenuto preesistente e le lavorazioni
concomitanti devono essere preservati; la verifica finale identifica i sorgenti
effettivamente controllati.
