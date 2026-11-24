# Metadati e materiali della pagina prodotto

| Campo | Valore |
| --- | --- |
| Identificatore | GS-AS-003 |
| Tipo | Specifica editoriale App Store |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Regole editoriali

Ogni affermazione deve descrivere soltanto la build inviata, essere verificabile e
non suggerire capacità future. Nome e sottotitolo rispettano il limite di 30
caratteri; le parole chiave rispettano il limite di 100 caratteri. Italiano è la
lingua primaria e inglese la prima localizzazione secondaria.

La descrizione, le note della versione e i materiali devono concordare con i flussi
`Must`, le dichiarazioni privacy, l'età e la disponibilità effettiva delle funzioni.
Claim come “accurato”, “scientifico”, “deterministico” o “supporta l'italiano”
**DEVONO** riferirsi a varianti GS-MET, corpus, soglie ed evidenze applicabili alla
build; la disponibilità di un framework Apple non è sufficiente.
La bozza versionata in `Distribution/AppStore/Metadata` non è approvata finché il
prodotto è uno scaffold.

La pagina prodotto **NON DEVE** descrivere Glifi Studio come catalogo di algoritmi.
Può comunicare indagini guidate, sintesi, confronto e ritorno alle fonti soltanto
quando i relativi flussi GS-UX sono implementati e verificati. Claim su “evidenza
forte” o comprensione automatica richiedono SupportPolicy e studi applicabili.

## Screenshot e icona

L'icona candidata è originale, senza trasparenza e presente nel catalogo Xcode. La
versione di rilascio deve essere approvata come identità visuale e verificata alle
dimensioni reali, in Light/Dark/Tinted ove applicabile.

Gli screenshot devono provenire dalla build candidata, usare dati autorizzati,
evitare cornici o claim fuorvianti e rappresentare i principali flussi reali. Ogni
piattaforma ha una propria serie. Prima del caricamento si verificano dimensioni e
numero direttamente in App Store Connect, perché Apple può aggiornarli.

La sequenza candidata racconta un percorso reale: domanda e raccolta, preparazione,
sintesi di un finding, verifica dell'evidenza e ritorno alla fonte. Il dettaglio
metodologico può comparire, ma non sostituisce il valore comprensibile del flusso.

## Riferimenti

- [Apple — App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Apple — Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- [Apple — App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
