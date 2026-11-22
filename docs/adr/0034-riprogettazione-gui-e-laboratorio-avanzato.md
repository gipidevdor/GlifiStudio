<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0034 — Riprogettazione della GUI e laboratorio avanzato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0034 |
| Versione | 1.0.0 |
| Stato | Accettato per ambito e architettura; verifiche separate |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita: riprogettare e ottimizzare la GUI, includendo tutto il lavoro svolto, con priorità all'ergonomia |
| Riferimenti | ADR-0002; ADR-0014; ADR-0024; ADR-0031; ADR-0032; ADR-0033; GS-DOR-222 |

## Contesto

Gli incrementi precedenti hanno ampliato il motore, la CLI e alcuni percorsi
applicativi. La distinzione fra disponibilità di libreria e disponibilità nella
GUI resta necessaria, ma la nuova richiesta autorizza a rendere accessibile dalla
GUI il lavoro già realizzato. L'esclusione del percorso UI in ADR-0032 descrive
quel cambiamento storico e non limita questa nuova estensione esplicita.

L'ampiezza del catalogo non giustifica un'interfaccia che richieda di conoscere
gli algoritmi o di preparare JSON per una normale analisi delle fonti.

## Decisione

1. Riorganizzare l'accesso per compiti e contesto: progetto e fonti, esplorazione
   e confronto, codifica, conclusioni ed esportazione. Offrire accessi diretti
   agli strumenti e ricerca delle destinazioni; preservare i percorsi esistenti.
2. Usare componenti SwiftUI di sistema, colori semantici e controlli
   localizzati. Ambito e azione principale restano riconoscibili; parametri e
   provenienza usano presentazione progressiva senza nascondere caveat essenziali.
3. Integrare su macOS le famiglie di ADR-0032 tramite la facciata GlifiKit,
   usando input derivati dalle fonti del progetto e controlli guidati. Le
   operazioni in memoria producono risultati di sessione: questa decisione non
   introduce un nuovo schema di Artifact, formato persistente o capability planner.
4. Distinguere lo stato scientifico per variante dalla semplice disponibilità
   del controllo UI. Fonte, selezione effettiva, parametri, limiti e seed sono
   ispezionabili; nessun lemma/POS, classificazione o codice viene inventato
   quando mancano le annotazioni o le precondizioni richieste.
5. Mantenere separazione App/Kit/Core, calcoli fuori Main Actor, budget bounded,
   cancellazione e errori tipizzati. Conservare il risultato valido precedente
   in caso di errore o annullamento e invalidare il contesto al cambio progetto.
6. Riutilizzare i formati JSON esistenti di richiesta canonica e risultato per
   due azioni esplicite di esportazione, senza envelope/versione ulteriori.
   La provenienza del progetto resta ispezionabile nella GUI; il JSON del
   risultato non viene chiamato export completo di progetto o di indagine.
7. Verificare automaticamente il lotto e osservare la GUI reale quando il Mac è
   accessibile. La richiesta di massima ergonomia guida il lavoro, ma richiede
   successive prove con utenti, tastiera e tecnologie assistive per essere valutata.

## Conseguenze

La nuova GUI può offrire analisi finora headless senza una migrazione del
progetto. I risultati di sessione non diventano implicitamente Findings,
Evidence o contenuti del rapporto persistito. Una futura integrazione stabile
con il planner o la persistenza richiederà propri contratti e verifiche.

ADR-0032 e ADR-0033 restano record storici; la nuova autorizzazione supera la
sola esclusione della UI per le operazioni in memoria. Baseline 0.1, stato
scientifico dei metodi, sviluppo dedicato iPadOS e gate G4/G5 restano distinti.

La verifica del lotto è registrata in [GS-VER-222](../evidenze/GS-VER-222-riprogettazione-gui.md).
Nessuna affermazione di ergonomia assoluta o prestazioni migliori può derivare
dal solo superamento delle build.
