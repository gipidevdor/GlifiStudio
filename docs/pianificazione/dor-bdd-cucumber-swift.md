<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Specifiche BDD con CucumberSwift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-332 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.1.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di integrare BDD con Cucumber Swift e scenari completi; successiva richiesta di rispettare tutte le licenze |
| Riferimenti | ADR-0046; GS-STD-001-13; GS-STD-001-16; GS-TST-001; GS-API-003; GS-VER-333; RQ-027; RQ-058; RQ-060; RQ-062; RQ-063; CMP-332 |

## Definition of Ready

Il lotto aggiunge feature comportamentali eseguibili alle verifiche esistenti.
Le capacità pubbliche continuano a essere inventariate dalla matrice degli
scenari di analisi e dalla verifica di parità Kit/CLI; una collezione BDD non
costituisce dimostrazione di correttezza per ogni input o variante numerica.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Integrare CucumberSwift nel confine test SwiftPM e scenari italiani che attraversino API reali; mantenere verifiche unitari, scientifiche e di parità esistenti |
| comportamenti | Percorsi nominali, casi limite e failure dei flussi coperti; progetto e fonti, query e coordinate, analisi, persistenza e riuso, codifica qualitativa ed export secondo l'inventario effettivamente eseguito |
| oracoli | Attese esplicite calcolabili su fixture sintetiche, contenuto e identità persistenti, invarianti e failure tipizzate; la parità fra due facciate non è l'unico oracolo |
| failure semantics | Scenario fallito su risultato errato, step mancante o ambiguo e feature non eseguibile; nessun successo da suite vuota, nessuna failure di prodotto trasformata in successo tecnico |
| dipendenze | ADR-0046, versioni riproducibili e `traits: []` esplicito indipendente da `SPI_BUILD`, voce revisionata e fonte di licenza immutabile per ogni pin; review distinta dei materiali Cucumber incorporati senza pin; snapshot della revisione delle licenze indirette separati dall'origine storica degli adattamenti; responsabilità e strategia di aggiornamento; uso limitato ai test |
| avvisi e copie | Copyright, permessi e disclaimer MIT completi per dipendenze e materiali incorporati; risorsa byte-identica nel test bundle, verifica statica e test Swift su Bundle.module; avvisi conservati nelle copie dei test, degli strumenti e degli artefatti CI distribuiti |
| sicurezza/privacy | Dati originali sintetici, isolamento dei progetti, nessun corpus personale, log contenenti segreti o nuova capacità di rete del prodotto |
| esperienza prevista | Feature leggibili in italiano con risultati osservabili; nessun nuovo controllo GUI né attestazione di accessibilità dall'esecuzione headless |
| prestazioni e sistema | Nessun hot path produttivo modificato; esecuzione deterministica senza dipendere da ordine, rete, clock o pause arbitrarie; cleanup dei progetti temporanei |
| dati e compatibilità | Nessun nuovo formato persistente, schema, entitlement o backend; i target app, GlifiKit, GlifiCore e CLI mantengono la separazione |
| verifica | Controlli mirati della suite e del suo inventario, controlli statici pertinenti e `make verify` macOS prima della consegna; iPadOS soltanto su richiesta esplicita |
| tracciabilità | GS-DOR-332, ADR-0046, clausola dello standard test e CMP-332 allineati; GS-VER-332 conserva l'integrazione storica, GS-VER-333 documenta il successivo riesame licenze e le verifiche finali con stato coerente |
| recupero e limiti | Revert del lotto senza migrazioni; audit GUI/assistivi, proprietà scientifiche non toccate, prestazioni e G4/G5 restano verifiche distinte |

**Ready.** La richiesta autorizza la nuova dipendenza di verifica; le prove e
l'inventario della suite determinano la copertura dichiarabile alla consegna.
