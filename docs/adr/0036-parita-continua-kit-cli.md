<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0036 — Parità continua fra GlifiKit e CLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0036 |
| Versione | 1.0.0 |
| Stato | Accettato per ambito e architettura; verifica separata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di mantenere sempre allineate CLI e Kit |
| Riferimenti | ADR-0002; ADR-0019; ADR-0032; ADR-0035; ADR-0041; GS-DOR-275 |

## Contesto

La parità verificata delle dodici operazioni di `text-analysis` non copre le
altre facciate GlifiKit. Alcune operazioni e opzioni di corpus sono disponibili
soltanto ai client Swift. Un elenco manuale dei comandi non intercetta le nuove
facciate e può lasciare divergenze silenziose.

## Decisione

1. Tutte le operazioni utente pubbliche di GlifiKit sono accessibili dalla CLI
   con gli stessi input, parametri, risultati e failure.
2. Il trasporto JSON e il dispatch risiedono in GlifiKit; la CLI gestisce file,
   envelope e stream senza ricostruire una seconda implementazione dei DTO.
3. I comandi preesistenti conservano sintassi e default. Gli ingressi condivisi
   permettono anche le configurazioni prima non rappresentabili.
4. Ogni simbolo pubblico è inventariato dal compilatore. Le esclusioni riguardano
   soltanto costruzione, serializzazione, presentazione o lifecycle, con motivo
   esplicito; una nuova API o una firma modificata richiede revisione del mapping.
5. Il gate confronta risultati completi su fixture condivise e tutti i casi
   operativi enumerabili. La baseline API non si aggiorna automaticamente nel
   gate. Il mantenimento della parità non promuove i manifest scientifici.

## Conseguenze

Nuovi comandi di sessione non introducono persistenza, rete, dipendenze o backend.
Gli schemi di trasporto restano distinti dal package `.glifi`. L'inventario API
aggiunge una revisione obbligatoria quando cambia il contratto pubblico; i test
di parità non sostituiscono gli oracoli numerici o gli audit applicativi.
