<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-198 — Confronto keyness completo nel client macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-198 |
| Tipo | Evidenza di verifica applicativa e compatibilità della facciata |
| Versione | 1.2.0 |
| Stato | Superato nel perimetro automatico macOS |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-198; RF-031; RF-045; RQ-003; RQ-011; RQ-013; RQ-026; RQ-028; RQ-058 |

## Perimetro

L'incremento E completa il confronto diretto nell'Indagine macOS: popolazioni
esplicite, intera famiglia paginata e campi v2 già prodotti da GlifiKit, inclusi
test selezionato, p del G-test, q BH e intervalli Katz/Woolf. La soglia diagnostica
configurabile non modifica la selezione Fisher preregistrata a cinque.

Il ponte del livello di confidenza aggiunge a `GlifiStudioKeynessOptions` una
proprietà e un init a tre argomenti senza default, conservando l'init pubblico
a due argomenti e il suo default 0,95. È un'addizione della facciata su un
parametro scientifico esistente: nessuna formula, schema o migrazione nuova.

La presentazione usa un helper bounded fuori dal Main Actor prima di pubblicare
risultato, richiesta, pagina e snapshot. Le prove con DTO alterati riguardano
il contenimento applicativo, non la bonifica degli Artifact o un nuovo attacco
end-to-end al package; i guard non ricalcolano test, correzioni o intervalli.
La tolleranza D1 del contenimento degli intervalli è applicata separatamente a
ciascun lato, usando soltanto stima ed estremo pertinente: un estremo opposto
molto grande non può rendere ammissibile un limite inferiore incoerente.

## Verifiche mirate osservate

GS-DOR-198 Ready, ADR-0033 E e GS-UX-001-17 E precedono il codice. Il comando
`make test-macos` termina con **exit 0, 55 definizioni e 195 esecuzioni,
zero fallite e zero saltate**, con `runtimeWarnings: []`. Nove test
parametrizzati producono 149 esecuzioni, più 46 non parametrizzate.
La nuova copertura client 198 comprende **8 definizioni e 67 esecuzioni**:
sette definizioni/19 esecuzioni di comportamento e una definizione/48 DTO
alterati. Log `198-macos-green-retry.log` e riepilogo sanificato
`macos-results.json` sono conservati nel dossier del lotto.

I test di comportamento provano parità completa con Kit, livelli 0,80/0,99 e
1e-300, richiesta e gruppi effettivi immutabili, riuso, selezione Fisher/G-test
distinta dalla soglia diagnostica, tutta la famiglia oltre venti termini e
pagine diretta/ultima/invalida, failure con stato precedente conservato,
cancellazione con retry, assenza di progetto e reset. Sono distinti gruppi senza
token e margini degeneri, con le failure scientifiche esistenti.

Il filtro SwiftPM conclusivo `--filter keyness` è superato: **quattro definizioni
Kit, sette esecuzioni**, più otto test Core (quattro esistenti e i quattro test
199). La facciata prova il riferimento a funzione del costruttore a due
argomenti, il default, livelli diversi con identità/riuso e i rifiuti senza clamp,
inclusa la failure numerica per un livello estremo formalmente ammesso.
Log `198-199-keyness-final-retry.log` nel dossier.

La nuova view macOS compone sezioni del Form dell'Indagine; il ramo iPadOS
conserva il percorso esistente. Le 49 nuove voci it/en e i controlli statici di
localizzazione/lint/diff sono superati. Questi controlli non sono un audit GUI.
La percentuale del livello effettivo è resa in notazione scientifica sotto
1e-6, mantenendo il formato nativo per valori ordinari: è una scelta di
presentazione che conserva il valore, distinta da formule e soglie inferenziali.
La compilazione/test dopo tale adeguamento è superata: ancora 55 definizioni e
195 esecuzioni, zero fallite/saltate, con log
`198-macos-final.log` nel dossier.

[GS-VER-199](GS-VER-199-identita-keyness.md) è una dipendenza di correttezza:
il descrittore risolve anche il livello e la cache applica livello e cap della
famiglia. Le quattro prove Core e il gate comune soddisfano questa dipendenza.

CMP-198 è `verified` nel perimetro automatico macOS sul nuovo freeze descritto
sotto. Lo snapshot `58d18024…80e8b` di GS-VER-196/197
resta storico e non viene esteso retroattivamente al nuovo codice.

## Snapshot e gate conclusivo

Il nuovo snapshot di **854 file** è basato su
`a86a53b512bd777f191c89692e0c573a3d37a3ff`, con manifest SHA-256
`0ed9b459878fbc6922245faac4ef5ce4c1b9b15804aa7ec6fdc4d4eb7e0add91`.
Non è un nuovo commit né una prova CI remota. I contributi concomitanti sono
inclusi soltanto nel contenuto congelato; questa evidenza non promuove le loro
clausole scientifiche e non attesta modifiche successive al freeze.

`make verify-macos` e `Scripts/check-app-store-packaging.sh --macos-only`
terminano entrambi con **exit 0 sul medesimo snapshot**:

| Controllo | Esito osservato |
| --- | --- |
| SwiftPM | 389 test Core + 59 Kit = 448 superati |
| Oracoli | 153 righe superate |
| Export | Due PDF/A-2u conformi con veraPDF |
| CLI e fixture | 15 fixture, 51 controlli CLI, parità entro 1e-12 |
| Recovery e QueryAST | 22 checkpoint recovery e contratto CLI QueryAST superati |
| Test nativi macOS | 55 definizioni, 195 esecuzioni, 0 fallite, 0 saltate; `runtimeWarnings: []` |
| App macOS | Build Debug/Release, analisi statica e archivio senza firma validi |

Nessuna build iPadOS è inclusa. Gli avvisi host CoreSimulator
`1171.7 < 1174.21` e diagnostici `MacPlaceholderOS` sono non fatali e distinti
dai runtime warning dei test; non si dichiara assenza di qualsiasi avviso.

Il dossier locale è
`/Users/gpicchiarelli/Library/Caches/GlifiStudio/evidence/macOS-2026-11-21-0ed9b459/`:
manifest, log e riepiloghi sanificati identificano le prove. L'archivio
`verified-source.tar.gz` di **7 957 734 byte** ha SHA-256
`1122fb4261eb1c7e640c2046af43327e5965dbcaaf9fc3d1cbe9f97aa6c13985`.
L'identità del contenuto verificato rimane distinta dai metadati finali delle
evidenze aggiornati dopo il gate.

## Confronto conclusivo e pulizia

Il confronto finale conferma snapshot immutato e corrispondenza dei sorgenti
posseduti dal lotto: app, ponte Kit, factory/validazione Core e relativi test;
anche i commenti DocC del lotto precedente sono invariati. La copia di lavoro
ha però 14 percorsi modificati e cinque aggiunti dopo il freeze: oltre ai
metadati documentali/conformità, quattro percorsi appartengono a ottimizzazioni
successive di altre sessioni e sono **esclusi da questo gate**:

- `Packages/GlifiCore/Sources/GlifiCore/GlifiAnalysisGraph.swift`;
- `Packages/GlifiCore/Sources/GlifiCore/GlifiIdentifiers.swift`;
- `Packages/GlifiCore/Sources/GlifiCore/GlifiDigestEncoding.swift`;
- `Packages/GlifiCore/Tests/GlifiCoreTests/GlifiDigestEncodingTests.swift`.

Non si dichiara quindi che tutti i sorgenti eseguibili correnti corrispondano
allo snapshot, né che il lotto verifichi quelle ottimizzazioni o la compatibilità
con esse. `final-source-comparison.json` conserva il confronto puntuale.

La pulizia del solo lotto rimuove **3 065 084 KiB, circa 2,92 GiB** di cache,
worktree temporaneo e file temporanei rigenerabili; `cleanup.json` registra
`removalComplete: true`. Il worktree è rimosso tramite Git. Archivio verificato
degli 854 file, manifest con contenuti/permessi, log e riepiloghi utili restano
nel dossier stabile, insieme alle toolchain attive nelle rispettive cache.
File utente, dipendenze e worktree/cache delle altre sessioni sono preservati.

## Contenimento della presentazione

Le 48 mutazioni JSON finite sono decodificate come DTO e passate al helper di
produzione. Coprono popolazioni/opzioni, totali, termini univoci/ordinamento,
frequenze e somme con overflow, domini di tassi/p/q/G/attese, intervalli,
direzione/test e policy. Due controesempi con estremo opposto ±1e308 verificano
che la tolleranza di un lato non sia ampliata dall'altro.

Ogni caso asserisce la failure app `ui.keyness.invalid-result`, categoria
`corruption`, operazione `analyze`, retry `never`, stato `lastCommittedGeneration`
e chiave `failure.keyness.invalid-result`. I test del helper non aprono package
corrotti e non sostituiscono i test di conservazione del modello: la review del
percorso di produzione verifica validazione prima della pubblicazione, mentre
i test di comportamento provano il mantenimento dello stato per le failure
raggiungibili. Nessuna strategia JSON per NaN/infinito è introdotta; i guard di
finitezza del risultato sono revisionati distintamente dai DTO decodificabili.

## Limiti

Solo macOS e prove automatiche nel perimetro concordato. Nessuna attestazione
di finestre SwiftUI, VoiceOver, autosave, file provider, G4, iPadOS o CI remota.
La disponibilità del parametro non garantisce successo numerico per ogni Double
formalmente ammesso: le failure Core restano tipizzate senza clamp. I contributi
e le evidenze scientifiche delle altre sessioni sono preservati e non promossi
automaticamente dal completamento della presentazione.
