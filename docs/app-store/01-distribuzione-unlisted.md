# Distribuzione App Store non in elenco

| Campo | Valore |
| --- | --- |
| Identificatore | GS-AS-001 |
| Tipo | Piano di distribuzione |
| Versione | 1.1.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0011 |

## Modello

Un'app non in elenco usa la normale infrastruttura App Store e supera App Review,
ma non compare in ricerca, classifiche, categorie, raccomandazioni o altre liste.
È accessibile con un collegamento diretto. Il collegamento è inoltrabile e non è un
meccanismo di sicurezza.

## Sequenza obbligatoria

1. completare prodotto, metadati, privacy, accessibilità e supporto;
2. caricare e associare una build firmata alla versione;
3. indicare nelle note di revisione che la destinazione richiesta è `unlisted`;
4. inviare l'app alla normale App Review;
5. inoltrare la richiesta Apple per la distribuzione non in elenco;
6. attendere l'approvazione e verificare il collegamento prima di comunicarlo;
7. rilasciare manualmente secondo il piano approvato.

Una build beta o incompleta non è idonea alla richiesta. Per la baseline 0.1 il
collegamento è sufficiente e non esiste account applicativo: il prodotto limita la
scoperta, non autorizza un pubblico chiuso. Un futuro requisito di accesso ristretto
richiederà autenticazione indipendente e una nuova decisione.

## Riferimento normativo

[Apple — Unlisted App Distribution](https://developer.apple.com/support/unlisted-app-distribution)
