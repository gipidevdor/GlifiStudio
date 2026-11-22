# Backup e recupero

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REP-007 |
| Tipo | Piano operativo |
| Versione | 1.0.0 |
| Stato | Da attivare con il remote |
| Responsabile | Amministratore del repository, da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Richiesta prima della baseline remota |

## Obiettivi iniziali

Il repository remoto privato sarà la fonte integrata, non l'unica copia. L'obiettivo candidato è perdere al massimo un giorno di storia non ancora replicata e ripristinare accesso a codice e documentazione entro quattro ore da un guasto ordinario. Gli obiettivi vanno approvati in base alla criticità reale.

## Copie

- remote Git privato principale con protezioni e audit;
- clone amministrativo completo e cifrato su supporto indipendente dal provider;
- esportazione protetta delle impostazioni non contenute in Git, incluse ruleset, accessi e ambienti;
- backup separato degli artefatti di rilascio, chiavi e documenti legali secondo le rispettive policy.

Una directory di lavoro non è un backup. Sincronizzazione e RAID non sostituiscono versioni storiche e copia indipendente.

## Procedura

Il backup deve includere branch, tag e oggetti raggiungibili, essere cifrato a riposo e durante il trasferimento, avere accessi minimi e retention definita. Una verifica automatica controlla completamento e integrità; almeno trimestralmente si esegue un ripristino in un ambiente isolato e si documentano durata, revisione recuperata e lacune.

Il ripristino comprende codice, configurazioni del servizio, protezioni, accessi minimi e riconnessione controllata della CI. I segreti non vengono copiati nel repository: sono ripristinati o ruotati dal sistema dedicato.

## Uscita dal progetto

Alla chiusura o al trasferimento si inventariano copie locali, fork, runner e backup; si revocano accessi e token; si trasferisce la titolarità con doppia verifica; si applicano retention e cancellazione autorizzata senza distruggere record legali necessari.
