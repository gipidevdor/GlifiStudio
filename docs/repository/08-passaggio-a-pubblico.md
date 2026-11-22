# Passaggio futuro a repository pubblico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REP-008 |
| Tipo | Gate di transizione |
| Versione | 1.0.0 |
| Stato | Definito, non autorizzato |
| Responsabile | Titolare del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Necessaria prima di ogni cambio di visibilità |

Il repository resta privato finché il titolare non approva esplicitamente la pubblicazione. La presenza della BSD 3-Clause non rende automaticamente pubblicabile ogni file o l'intera cronologia.

## Gate obbligatorio

Prima del cambio di visibilità:

1. inventariare tutti i file, branch, tag, grandi oggetti e commit eliminati ma ancora presenti;
2. eseguire scansione completa della storia per segreti, dati personali e informazioni riservate;
3. ruotare ogni credenziale che possa essere stata esposta, anche se rimossa dalla revisione corrente;
4. verificare titolarità, contributi, BSD 3-Clause, licenze di terzi, marchi, dataset, font, immagini e modelli;
5. rimuovere riferimenti a URL, account, issue, persone o infrastrutture private;
6. assegnare contatti reali per sicurezza, condotta, supporto e proprietà del codice;
7. adattare governance, contribution policy e roadmap a contributori esterni;
8. configurare protezioni, anti-abuso, security reporting e automazioni appropriate al repository pubblico;
9. costruire e verificare una copia candidata isolata;
10. ottenere approvazione documentata di prodotto, tecnica, sicurezza e titolarità.

## Storia

Se la cronologia contiene materiale non pubblicabile, decidere fra pulizia coordinata, repository pubblico con storia nuova o mantenimento privato. Qualunque riscrittura richiede mappatura delle revisioni, conservazione autorizzata dell'originale e comunicazione ai collaboratori. Eliminare un segreto dalla storia non sostituisce la sua revoca.

## Dopo la pubblicazione

Verificare da un account non privilegiato visibilità, download, issue, Actions, pacchetti e pagine collegate. Monitorare le prime ventiquattro ore e predisporre un percorso reversibile; riportare il repository a privato non garantisce la cancellazione delle copie già ottenute.
