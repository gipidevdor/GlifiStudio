<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Stabilità delle statistiche inferenziali

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-328 |
| Tipo | Correzione di risultati numerici e casi limite |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di perfezionare codice e semantica |
| Riferimenti | RQ-008; RQ-027; RQ-062; RQ-063; GS-MET-001-04; GS-MET-001-21; GS-STD-001-16; GS-VER-328; CMP-328 |

## Problemi riprodotti

Sulla base `44dd90f`, un probe dei sorgenti correnti conferma tre difetti coesi:

1. La tolleranza della permutazione dipende dall'unità e dall'offset: il p esatto
   di `[0,1]` contro `[2,3]` passa da `1/3` a `1` dopo moltiplicazione per `1e-14`
   e a `2/3` dopo traslazione di `1e12`, pur conservando il medesimo disegno.
2. T a un campione e Cohen d espongono successi falsi quando i quadrati
   traboccano: `[1e308,0]` dà t zero e p uno invece di t uno e p un mezzo;
   due gruppi opposti producono d zero e deviazione infinita invece di sqrt(2).
   Le deviazioni finali corrette sono rappresentabili, anche se le varianze
   intermedie non lo sono.
3. Bootstrap della media costante `[1e308,1e308]` restituisce stima infinita e
   limiti NaN; Q7 su `[-1e308,1e308]` dà NaN a p zero e infinito alla mediana,
   mentre i risultati matematici sono finiti. Il contratto Q7 specifica una
   combinazione convessa degli estremi. Il consumatore BCa deve usare la stessa
   media stabile e normalizzare i contributi prima dei cubi del jackknife,
   mantenendo definizione, seed e repliche.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Permutazioni invarianti per cambi di unità affini positivi che conservano dati e differenze alla precisione dichiarata; medie, deviazioni, t, d e Q7 corretti per gli estremi riprodotti; nessun NaN/infinito restituito come successo falso |
| requisiti | RQ-008/027: formule, domini e risultati verificati; RQ-062/063: Ready, regressioni RED/GREEN ed evidenza |
| dominio/API | Stesse API e DTO; confronto esatto o Monte Carlo, alternative, PRNG, seed, numerosità e semantica degli intervalli conservati |
| failure semantics | Input non finiti restano invalidi; risultati finali non rappresentabili falliscono con errore di dominio esistente statistics.non-finite-result; intermedi non rappresentabili richiedono formula stabile quando il risultato finale è rappresentabile |
| esperienza prevista | Stesse azioni e messaggi localizzati; unità fisiche e offset non devono alterare l'inferenza né produrre risultati serializzabili solo in parte |
| verifica | RED comune prima del runtime; sei assegnazioni enumerate indipendentemente, trasformazioni affini esatte e Monte Carlo con seed identico; formule chiuse t a df1 e d; bootstrap costante e Q7 convesso; oracoli precedenti e make verify macOS senza tolleranze indebolite |
| dati e migrazione | Nessun formato nuovo; censire consumatori e aggiornare solo revisioni produttore dei risultati corretti che possono essere riusati da artifact vecchi; storici leggibili e famiglie indipendenti conservate |
| sicurezza/privacy | Fixture numeriche sintetiche; nessuna dipendenza, rete, entitlement o contenuto utente |
| prestazioni/sistema | Nessuna ottimizzazione dichiarata; somme e interpolazioni stabili con lavoro bounded; PRNG, budget e checkpoint di cancellazione conservati dove applicabili |
| tracciabilità | CMP-328 e GS-VER-328; indici, matrice e CHANGELOG a cura dell'integratore; nessun intervento sui percorsi query327 o cache corpus330 |
| decisioni e recupero | API e varianti scientifiche conservate salvo decisione esplicita; se la formula stabile amplia troppo il perimetro, segnalare il limite senza clamp o zero inventati; revert del solo lotto senza dati utente |

**Ready**. Questa scheda precede i nuovi test; il runtime rimane invariato
fino all'autorizzazione dell'integratore dopo il RED comune.
