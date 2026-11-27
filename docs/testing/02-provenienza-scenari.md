<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Provenienza delle fonti degli scenari BDD

| Campo | Valore |
| --- | --- |
| Identificatore | GS-LIC-003 |
| Tipo | Registro controllato delle fonti di verifica |
| Versione | 1.0.0 |
| Stato | Attivo con limiti dichiarati |
| Responsabile | Glifi Studio contributors |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di completare gli scenari usando anche fonti web con condizioni verificate |
| Riferimenti | GS-LIC-001; GS-LIC-002; GS-BDD-001; GS-STD-001-16; ADR-0046 |

## Modalità di uso

Le fonti primarie sotto sono consultate il **2026-11-27** per individuare
classi di casi e verificare le relative condizioni. Per questi riferimenti,
i nuovi scenari, passi, nomi, numeri e testi sintetici sono originali. Non vengono
importati esempi narrativi, suite, corpora, paragrafi, immagini, ABNF, codice
o dataset delle fonti. Una fonte consultabile non diventa per questo BSD.

Il registro distingue una fonte di requisiti da un oracolo: due facciate che
usano lo stesso Core non costituiscono verifiche numeriche indipendenti.
Le attese devono derivare dal contratto Glifi dichiarato, da calcoli autonomi
o dagli oracoli già documentati, senza attribuire a una fonte un risultato che
non contiene. I candidati sotto non attestano da soli copertura eseguita:
feature e inventario BDD identificano i casi effettivi, l'evidenza del lotto
registra RED, GREEN e controlli integrati.

## Cinque gruppi di fonti verificati

| ID | Fonte e revisione | Condizioni e uso ammesso nel lotto | Classi di casi originali |
| --- | --- | --- | --- |
| BDD-SRC-01 | [Gherkin 41.0.0, grammatica](https://github.com/cucumber/gherkin/blob/e21434718037092b4cd1127b8b4049e545bda71b/gherkin.berp) e [dialetti](https://github.com/cucumber/gherkin/blob/e21434718037092b4cd1127b8b4049e545bda71b/gherkin-languages.json), commit `e21434718037092b4cd1127b8b4049e545bda71b` | [LICENSE MIT allo stesso commit](https://raw.githubusercontent.com/cucumber/gherkin/e21434718037092b4cd1127b8b4049e545bda71b/LICENSE). Consultazione della struttura; nessun parser o dizionario aggiunto al progetto. Copie o parti sostanziali richiederebbero copyright e avviso MIT. | Italiano, contesto comune, schema con più esempi, tabelle, docstring e delimitatori; selezione senza casi, duplicati o passi omessi verificati dal contratto locale del runner. |
| BDD-SRC-02 | NIST/SEMATECH Handbook, [§ 1.3.5.3](https://www.itl.nist.gov/div898/handbook/eda/section3/eda353.htm) e [§ 1.3.5.15](https://www.itl.nist.gov/div898/handbook/eda/section3/eda35f.htm), pagine consultate nella data sopra | [Condizioni generali NIST](https://www.nist.gov/copyrights-disclaimers) e [distinzione SRD/non-SRD/terzi](https://www.nist.gov/open/copyright-fair-use-and-licensing-statements-srd-data-software-and-technical-series-publications). Solo riferimento a fatti e formule, senza dataset o esempi numerici del manuale. Nessuna qualifica generale di pubblico dominio. | Campioni appaiati o indipendenti, varianze uguali o diverse, gradi di libertà di Welch; goodness-of-fit su conteggi originali. |
| BDD-SRC-03 | [UAX #29, revisione 47, Unicode 17.0.0, 2025-08-17](https://www.unicode.org/reports/tr29/tr29-47.html); [WordBreakTest 17.0.0, 2025-03-24](https://www.unicode.org/Public/17.0.0/ucd/auxiliary/WordBreakTest.txt) | [Termini Unicode](https://www.unicode.org/copyright.html) distinguono pubblicazioni e dati. La [Unicode License V3](https://www.unicode.org/license.txt), SPDX `Unicode-3.0`, riguarda i dati e il software, non automaticamente il testo UAX. Nessun paragrafo, regola o riga della suite è copiato. | Forme composte/decomposte, segni combinanti, apostrofi, emoji con più scalari e riferimenti al testo sorgente, con stringhe inventate. |
| BDD-SRC-04 | [RFC 8259, JSON, dicembre 2017](https://www.rfc-editor.org/rfc/rfc8259.html), §§ 6–10 | L'avviso rinvia alle disposizioni IETF in vigore alla pubblicazione: [TLP 5, efficaci dal 2015-03-25, pagina corretta nel 2021](https://trustee.ietf.org/documents/trust-legal-provisions/tlp-5/). Il documento non è interamente BSD. Nessun componente di codice, ABNF o esempio è estratto. | Escape, UTF-8, campi strutturati, valori numerici non finiti non rappresentabili in JSON e input sintatticamente invalido, con envelope Glifi originale. |
| BDD-SRC-05 | [RFC 4180, CSV, ottobre 2005](https://www.rfc-editor.org/rfc/rfc4180.html), § 2 | RFC **Informational**, non Internet Standard. Conserva copyright Internet Society e rinvia al BCP 78; la revisione storica pertinente è [RFC 3978, marzo 2005](https://www.rfc-editor.org/rfc/rfc3978.html). Non si applica retroattivamente il TLP recente né si presume una licenza BSD. Nessuna grammatica o tabella d'esempio è estratta. | Campi vuoti, separatori e virgolette nei valori, raddoppio delle virgolette, righe CRLF e terminatore finale, con record inventati. |

Gherkin 41 identifica una **fonte di riferimento**, non la versione del parser
nel runner Swift. Il runner e i suoi limiti restano quelli di CucumberSwift
6.9.0 bloccato da ADR-0046. Una costruzione supportata nella grammatica di
riferimento non è automaticamente supportata o verificata dal runner scelto.

Il manuale NIST contiene esempi che rimandano a dataset esterni, tra cui
AUTO83B: non vengono acquisiti. Le condizioni NIST distinguono opere dei
dipendenti, materiali SRD, apporti di terzi e diritti fuori dagli Stati Uniti.
Le pagine Handbook non hanno una revisione immutabile esposta: si registra
la data di consultazione, senza inventare un tag o un digest del contenuto.
Il goodness-of-fit non sostituisce il diverso contratto del test di indipendenza.

## Associazione alle specifiche eseguibili

| Specifica | Fonti pertinenti e attese originali |
| --- | --- |
| [InterchangeContracts.feature](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/InterchangeContracts.feature), casi JSON | BDD-SRC-04: forme numeriche e stringhe con escape; token invalidi, controllo non escapato e nessun risultato parziale. Il limite binary64 e il rifiuto del surrogato isolato sono scelte del contratto Glifi, non divieti sintattici aggiunti all'RFC. |
| Stessa feature, casi Unicode | BDD-SRC-03: scalari originali `00E9`, `0065 0301` e `1F469 200D 1F52C`; byte e coordinate attesi distinti, codifica e riapertura, snapshot e storia immutati per confini invalidi. Nessuna riga UCD è riusata. |
| Stessa feature, casi CSV | BDD-SRC-05: cinque etichette originali e documenti CSV completi attesi in docstring JSON, con virgola, virgolette, CRLF e campi vuoti; confronto dei byte e verifica del bundle. Il CSV derivato da un builder e poi riletto non è l'unica attesa. |
| [StatisticsMethods.feature](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/StatisticsMethods.feature) | BDD-SRC-02 è pertinente alle distinzioni t/paired/Welch. Le altre attese sono forme chiuse, enumerazioni o invarianti originali, riferiti alla [fondazione statistica controllata](../metodi-analitici/21-fondazione-statistica.md), non esempi NIST copiati. |
| [CoreOperators.feature](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/CoreOperators.feature) | Matrici, grafi e lessici originali con proprietà autonome. I riferimenti restano le specifiche già riesaminate di [clustering](../metodi-analitici/14-clustering.md), [riduzione dimensionale](../metodi-analitici/15-riduzione-dimensionale-e-topic-analysis.md) e [reti](../metodi-analitici/16-reti-lessicali.md); NIST non è attribuito come fonte di tutti gli operatori. |
| [TextAnalysisVariants.feature](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/TextAnalysisVariants.feature) | Richieste originali di [Fixtures/TextAnalysis/v1](../../Fixtures/TextAnalysis/v1/cases.json), più modifiche sintetiche dichiarate per casi costanti o a due punti. Attese scritte separatamente; l'inventario dei contratti distingue input invariati e varianti modificate. |
| [EvaluationVariants.feature](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/EvaluationVariants.feature) | Annotazioni, etichette e metadati temporali originali; conteggi e proprietà di [valutazione](../metodi-analitici/18-valutazione-servizi-linguistici.md) controllati. Nessuna suite Unicode esterna è trasferita nel repository. |
| [ProjectOperationVariants.feature](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/ProjectOperationVariants.feature) | Corpus sintetico originale del progetto, già usato nei [test dei comandi](../../Packages/GlifiCore/Tests/GlifiKitTests/GlifiProjectCommandTests.swift); attese di persistenza, cache, source grounding ed export. Non è un corpus preso dal web. |
| [SourceProfiles.feature](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/SourceProfiles.feature) | Testo e Markdown originali; PDF/EPUB sintetici ricostruibili dal [builder BSD](../../Scripts/build-rich-document-fixtures.py). Si verificano conteggi, digest, formati e riapertura; non sono documenti di terzi. |
| [PlannerContracts.feature](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/PlannerContracts.feature) | Fonti sintetiche originali e contratti degli intenti già dichiarati nei [test del planner](../../Packages/GlifiCore/Tests/GlifiKitTests/GlifiPlannerScenarioTests.swift). I casi headless non attestano l'interazione delle viste. |

La feature usa il runner e gli step analitici già registrati per JSON; gli
step Unicode/CSV risiedono in
[GlifiInterchangeSteps.swift](../../Packages/GlifiCore/Tests/GlifiBDDTests/GlifiInterchangeSteps.swift).
Gli esempi si aggiungono alla copertura delle varianti pubbliche: non la
sostituiscono. L'esistenza dei file non equivale a un esito GREEN; quest'ultimo
deve provenire dal report completo controllato.

Il riferimento NIST al goodness-of-fit aiuta a distinguere quel metodo dal
test di indipendenza. Non documenta tutti gli operatori e non introduce un
nuovo endpoint di prodotto. Le famiglie ulteriori mantengono le proprie
specifiche e provenienze già riesaminate. Anche quando l'attesa è zero per
simmetria o accordo perfetto, la verifica riguarda i fatti e le dimensioni
dichiarate; non sostituisce le griglie numeriche e gli oracoli preesistenti.

Per Unicode, i risultati di tokenizzazione Apple possono applicare profili e
adattamenti linguistici; consultare UAX #29 non prova conformità integrale né
fissa la versione Unicode del sistema operativo. Si verificano le coordinate
e le equivalenze effettivamente richieste da Glifi. Una futura acquisizione
di righe UCD richiederebbe revisione del file esatto, avvisi di copyright e
licenza V3 conservati; la pubblicazione UAX richiede una verifica distinta.

Per JSON, nomi duplicati, limiti numerici e Unicode malformato richiedono
aspettative esplicite del trasporto Glifi: non si trasforma una raccomandazione
di interoperabilità RFC in un divieto già implementato. Per CSV si distinguono
il formato descritto, i parametri del prodotto e il caso di export che il
prodotto effettivamente espone. Non si inventano nuovi ingressi CSV o JSON.

## Identificazione delle fonti lette

I digest identificano i byte ricevuti da URL primari; non sono copie
redistribuite delle fonti e non certificano la loro titolarità. Per le
condizioni web non versionate la data sopra resta parte dell'identificazione.

| Fonte | SHA-256 |
| --- | --- |
| LICENSE Gherkin al commit sopra | `042bda2882d793c42fcd5f4d272579a432d1d52a0e5436202e5e823eae4771b6` |
| `gherkin.berp` allo stesso commit | `7f2f1a7e53aed1f009bb412b0dbf26d986b0dbcbdf2a9ea2f9854dc88c34cca0` |
| `gherkin-languages.json` allo stesso commit | `1d94884e2829c02a5971a5f899938779047b335bf823b2c4fb24bda95827f0a7` |
| UAX #29 revisione 47, HTML | `130d4e0d3f9da41bf9ad84bf580b3b92edc83886457cbc5a53b432761fd2c6ed` |
| `WordBreakTest.txt` 17.0.0 | `1de23a75f37904abc7d206239ee8d34f8fdf0fb4ab32a7174dfbabbde25419b2` |
| Unicode `license.txt`, V3 con copyright 1991–2026 | `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96` |
| [RFC 8259, testo](https://www.rfc-editor.org/rfc/rfc8259.txt) | `61a5378f4255c720beb2a4b4a63b29540147c140f36988bf086291989b4cd2d7` |
| [RFC 4180, testo](https://www.rfc-editor.org/rfc/rfc4180.txt) | `5d9ec035aa40c0108362cb767c9e2d08c30f7225cb2a4715f484cb13c29b5f21` |
| [RFC 3978, testo](https://www.rfc-editor.org/rfc/rfc3978.txt) | `6a90d1a320b7cc722fad8516856e923734cd895bb2cb86284d0991edb7e6d02f` |

Il tag annotato Gherkin `v41.0.0` è stato risolto dal servizio Git ufficiale
verso il commit indicato, distinto dall'oggetto tag
`b8d67257d8297fa904f25fc4d20d288ae480d3fa`. Il LICENSE è letto al commit,
non dedotto dalla sola etichetta della pagina GitHub.

L'[inventario licenze](../../Config/Licenses/materials.json) registra questi
cinque gruppi come `external-reference`, con `noticeFile: null`: nessun
materiale nuovo viene distribuito nell'app o acquisito come fixture.
Gli avvisi MIT del runner rimangono distinti e già conservati. Prima di
trasformare una citazione in un'acquisizione si riesaminano fonte, versione,
file, diritti e obblighi di attribuzione; questo registro non approva copie
future né costituisce una garanzia legale assoluta.
