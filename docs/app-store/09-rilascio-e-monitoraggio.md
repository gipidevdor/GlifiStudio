# Rilascio e monitoraggio

| Campo | Valore |
| --- | --- |
| Identificatore | GS-AS-009 |
| Tipo | Piano operativo di rilascio |
| Versione | 1.1.0 |
| Stato | Pianificato |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Rilascio

La pubblicazione è manuale. Dopo App Review e approvazione `unlisted`, il
responsabile verifica in una regione pilota pagina prodotto, installazione, primo
avvio, link privacy/supporto e flussi principali. Solo allora il collegamento viene
condiviso attraverso il canale autorizzato.

Il piano di rollback considera che una versione App Store non può essere rimossa
dai dispositivi già installati: si può sospendere la distribuzione, comunicare una
mitigazione e preparare una nuova build. Migrazioni dati devono essere compatibili o
avere una procedura di recupero testata.

## Monitoraggio

Xcode Organizer è il canale primario per crash, hang, launch, memoria, scritture ed
energia delle build distribuite, quando Apple dispone di un campione sufficiente.
La 0.1 non incorpora telemetria, crash upload o subscriber MetricKit: feedback e
ticket restano canali espliciti e separati. Accesso alle metriche, triage e report
seguono minimo privilegio e non devono includere contenuto dei corpus.

Definire turnazione, severità, tempi di risposta, soglie di regressione e criteri
di hotfix prima del rilascio. Il link non in elenco deve essere trattato come
distribuibile, non come segreto revocabile. La policy completa è
[GS-APL-014](../apple/14-osservabilita-e-telemetria-macos.md).
