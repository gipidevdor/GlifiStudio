<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Affidabilità verificabile dei test BDD e dell'inferenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-341 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di ricontrollare il codice e migliorarne la qualità ingegneristica |
| Riferimenti | GS-STD-001-12; GS-STD-001-16; GS-STD-001-29 § 29.6; ADR-0031; ADR-0046; GS-BDD-001; GS-MET-001-21; RQ-011; RQ-027; RQ-058; RQ-060; RQ-062; RQ-063; CMP-341 |

## Definition of Ready

La revisione individua contratti verificabili da correggere nello stesso
perimetro: vita del processo CLI avviato dai test, completezza e ordine del
report BDD, risoluzione esplicita dei trait e stabilità dell'inferenza su valori
finiti estremi e classificazione degli errori di importazione dello stato
del classificatore nel modello macOS. Non assegna un voto globale al repository né promuove criteri
privi dell'evidenza richiesta.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Rendere effettive cancellazione e scadenza dei subprocessi BDD; rifiutare report o JSON ambigui; evitare failure dovute soltanto a intermedi numerici non rappresentabili quando il risultato finito è calcolabile |
| failure semantics | Terminazione e raccolta del solo figlio diretto posseduto dal test; failure tipizzate per risultati realmente non rappresentabili; nessun report incompleto accettato e nessuna sostituzione di un errore con un numero fittizio |
| ciclo di vita CLI | Supervisione del processo posseduto, scadenza, SIGTERM e SIGKILL se necessario, attesa di terminazione e rilascio delle risorse; nessuna promessa di gestione dei discendenti |
| limiti output | Controllo di 1 MiB prima della lettura dell'output; il controllo non costituisce quota sulle scritture disco del figlio |
| report e inventario | Schema V2 con identità esatte degli scenari e digest dell'ordine dei passaggi; confronto di posizione, keyword e nome; rifiuto di chiavi JSON duplicate e numeri non JSON o non finiti |
| dipendenze | Disabilitare esplicitamente i trait CucumberSwift per non attivare macro tramite l'ambiente SPI_BUILD; versioni, licenze e pin restano controllati |
| inferenza | Conservare il percorso e i bit nominali; usare un fallback numericamente valido per contrasto normalizzato, errore standard dell'effetto e code di confidenza estreme; failure tipizzata quando il valore finale non è rappresentabile |
| persistenza | Producer 4 soltanto per group-metric-comparison; posthoc e paired restano 3, correlazione e associazione 2; lettura dei risultati storici producer 1–3 conservata e nessuna promozione dei vecchi valori memorizzati |
| input del modello macOS | JSON di stato del classificatore malformato o strutturalmente incompleto restituisce una failure di input correggibile; stato precedente conservato, nessuna attestazione di audit UI |
| verifica | Regressioni nominali e avversarie, sei casi di ciclo di vita del subprocesso, regressioni negative del gate e prove numeriche indipendenti; controlli pertinenti e make verify macOS serializzato dall'integratore |
| sicurezza/privacy | Solo fixture sintetiche; nessuna rete, entitlement o formato di progetto nuovo; processi e file temporanei dei test restano posseduti e puliti |
| tracciabilità | GS-DOR-341, GS-VER-341, CMP-341 e documenti dei contratti aggiornati; GS-VER-332 e GS-VER-333 restano evidenze storiche |
| criteri aperti | UI e accessibilità, sanitizer, DocC e metriche/audit G4 senza prove specifiche restano Da introdurre o nello stato già dichiarato; la revisione non attesta qualità universale |
| decisioni e recupero | Correzioni che attuano ADR-0031 e ADR-0046, senza nuova scelta architetturale; revert del lotto con conservazione dei reader storici e delle fixture pertinenti |

**Ready.** La richiesta autorizza la correzione e le prove dei contratti
individuati; soltanto gli esiti osservati nel lotto finale determinano ciò che
può essere dichiarato verificato.
