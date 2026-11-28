<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-333 — Attribuzioni e avvisi degli strumenti BDD

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-333 |
| Tipo | Riesame delle licenze dirette e dei materiali incorporati |
| Versione | 1.0.0 |
| Stato | Superato localmente: licenze, tre copie legali compilate, BDD e gate macOS |
| Responsabile | Codex, con verifica serializzata dall'integratore |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita dell'utente: rispettare tutte le licenze |
| Riferimenti | GS-LIC-001 § 8; GS-STD-001-13; ADR-0046 versione 1.1.0; GS-DOR-332; GS-BDD-001; GS-VER-332; CMP-332; RQ-062; RQ-063 |

## Problema osservato e confini del riesame

L'integrazione iniziale conservava le licenze MIT di CucumberSwift 6.9.0 e
CucumberSwiftExpressions 1.4.2 sulle revisioni risolte. Un riesame indipendente
ha individuato due attribuzioni indirette mancanti: dialetti Cucumber/Gherkin
incorporati nei sorgenti Swift e diagnostica Cucumber Expressions adattata.
La presenza dei due soli package nel lockfile non dimostrava la completezza
degli avvisi dei materiali incorporati.

Questa evidenza registra il successivo riesame. GS-VER-332 e i relativi
allegati restano la registrazione storica dell'integrazione BDD e non vengono
riscritti per rappresentare verifiche compiute in seguito.

## Fonti primarie e limiti storici

| Materiale | Testo primario riesaminato | Distinzione di provenienza |
| --- | --- | --- |
| CucumberSwift 6.9.0 | MIT sul commit risolto `5547f9025c0da3f0276a22a3c746bfebc405741f` | Copyright 2018 Tyler Thompson; revisione della dipendenza effettivamente selezionata |
| CucumberSwiftExpressions 1.4.2 | MIT sul commit risolto `ab4c6482d3230d24a13814a961b6fff1d50f830f` | Copyright 2022 Tyler Thompson; revisione transitiva effettivamente selezionata |
| Dati dei dialetti Cucumber/Gherkin in `Languages.swift` e nei tipi di passo localizzati | [MIT primaria](https://raw.githubusercontent.com/cucumber/gherkin/81ef221bd9e1f0d41b62e3986c5dd61439641117/LICENSE), snapshot `81ef221bd9e1f0d41b62e3986c5dd61439641117` | Copyright 2017 Cucumber Ltd, Gaspar Nagy, Björn Rasmusson, Peter Sergeant e contributori; snapshot della revisione della licenza, non origine storica esatta dell'adattamento Swift |
| Diagnostica adattata in `SyntaxError.swift` | [MIT primaria](https://raw.githubusercontent.com/cucumber/cucumber-expressions/eb1ad273949ad8bfd20632f73f1959bae6135a45/LICENSE), snapshot `eb1ad273949ad8bfd20632f73f1959bae6135a45` | Copyright 2016 Cucumber Ltd e contributori; snapshot della revisione della licenza, non origine storica esatta dell'adattamento Swift |

SwiftGen è il generatore citato upstream, con template proprio; non è una
dipendenza aggiunta dal lotto e non vengono copiati suoi template. Questa
distinzione non elimina la necessità di attribuire i dati Gherkin incorporati
nel sorgente generato.

## Avvisi e distribuzione dei test

`Config/Licenses/bdd-tools.txt` conserva copyright, permesso e disclaimer
integrali delle quattro attribuzioni. Il testo indica espressamente il
significato limitato degli snapshot di revisione delle due licenze indirette.
Il target BDD copia la directory `Licenses` come risorsa e mantiene una copia
byte-identica di questi avvisi in `Licenses/THIRD_PARTY_NOTICES.txt`. Il test
bundle collega anche GlifiKit e GlifiCore: conserva quindi anche
`Licenses/GlifiStudio-LICENSE.txt`, copia integrale della BSD del progetto,
e `Licenses/GlifiStudio-THIRD_PARTY_NOTICES.txt`, copia integrale degli avvisi
Core alla radice, inclusi Snowball e SplitMix.

`GlifiBDDLicenseTests` legge i tre file da `Bundle.module` e confronta ciascun
digest atteso nel test bundle compilato. È un test Swift separato: l'inventario
comportamentale continua a rappresentare 116 esempi Gherkin e 655 passaggi.
Il verificatore BDD controlla anche l'identità statica di tutte e tre le copie.
Una copia
distribuita di test bundle, strumenti o artefatti CI deve mantenere gli avvisi
applicabili insieme al materiale; la natura di dipendenza di sviluppo non
costituisce un'esenzione.

Il controllo generale delle licenze richiede per ogni pin remoto del lockfile
una propria voce revisionata, avviso e fonte primaria immutabile riferita al
commit risolto. Il controllo del lockfile è distinto dalla review dei materiali
incorporati senza un pin proprio: entrambi sono necessari per questo ambito.

## Stato della verifica

Sono stati osservati:

- identità byte per byte fra i tre testi controllati e le risorse del target
  test: SHA-256 `4031f3de35638d2d3bd578ab448b46929cc946157c3cc4420c178a410b755679`
  per i quattro avvisi MIT BDD,
  `81f47968bba326e331d547c1a4030f240512d62cb6e8c537cec2616da82d7d72` per
  la BSD del progetto e
  `dc869382f68d264c0054b209cf7f7c0926e09df5daeef8c9fd9b0895acabf944` per
  gli avvisi Core;
- superamento del test Swift che richiede i medesimi digest dai tre file letti
  in `Bundle.module`, dopo l'aggiunta anche della BSD e degli avvisi Core;
- `python3 -B Scripts/check-docs.py` superato dopo il nuovo documento e gli
  aggiornamenti controllati.

| Comando o ispezione | Esito |
| --- | --- |
| `python3 -B Scripts/check-licenses-tests.py` | 19 test superati, compresi i casi negativi sui pin e sulle fonti legali |
| `python3 -B Scripts/check-licenses.py` | 27 materiali inventariati e pin SwiftPM collegati alle rispettive voci revisionate |
| `python3 -B Scripts/check-bdd.py --self-test` | Copie legali identiche e regressioni sulle copie mancanti, vuote o alterate superate |
| `make verify`, profilo macOS | Exit 0: statici, oracoli, test SwiftPM, parità CLI/Kit, recovery, 135 test app e build Debug/Release superati |
| `make test-bdd` finale | Exit 0: 61 definizioni Swift Testing, compreso il test sui tre file legali; 116 scenari Gherkin e 655 passaggi superati |
| Ispezione delle risorse compilate | Tutti e tre i file sono byte-identici sia nel resource bundle sia nella copia incorporata nel prodotto `.xctest` |

La verifica generale è stata seguita dal test mirato finale dopo il
completamento delle copie BSD/Core. I sorgenti Swift di produzione non sono
cambiati durante il gate; non si attribuisce alla sola esecuzione precedente
la verifica delle copie aggiunte successivamente. Il Python 3.12.14 di mise
e veraPDF 1.30.4 già installati sono stati selezionati per il gate generale,
su macOS 27.2.1 con Xcode 27.2 e Apple Swift 6.4.2.

L'[allegato strutturato](allegati/GS-VER-333-verifica.json) conserva impronta
dei sorgenti, digest, posizioni relative dei file nel bundle e risultati.
La verifica è locale: non è stato avviato un workflow remoto né il profilo
iPadOS. Le cache rigenerabili e i download di review sono rimossi dopo
l'estrazione delle evidenze; strumenti attivi e cache globali delle
dipendenze restano disponibili.

Il riesame documenta le fonti e i controlli di questo cambiamento. Non è una
certificazione legale universale, non ricostruisce l'origine storica esatta
degli adattamenti e non dimostra automaticamente tutti i diritti delle
revisioni precedenti o di futuri materiali aggiunti.
