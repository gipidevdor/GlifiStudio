<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Provenienza e licenze degli algoritmi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-LIC-002 |
| Tipo | Registro controllato di provenienza |
| Versione | 1.0.2 |
| Stato | Revisione locale con limiti dichiarati |
| Responsabile | Glifi Studio contributors |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di revisione delle licenze e delle fonti algoritmiche |
| Riferimenti | GS-LIC-001; GS-LIC-003; GS-STD-001-13; GS-DOR-318; GS-VER-318; GS-VER-319; GS-VER-321; ADR-0046; GS-VER-332 |

## Regola di attribuzione

Una citazione scientifica identifica un metodo; non concede il diritto di copiare
la sua implementazione, le tabelle, il testo, i dati o le figure. Un nome di
algoritmo, un risultato coincidente o l’assenza di pacchetti SwiftPM non dimostrano
la provenienza del codice. La BSD del progetto copre soltanto i contributi
originali, con le eccezioni dichiarate vicino al materiale.

Per nuove acquisizioni si **DEVONO** distinguere implementazione da specifica
matematica, port/adattamento di sorgente, materiale di test e strumento esterno.
Un port conserva gli obblighi del sorgente; cambiare linguaggio, nomi o commenti
non sostituisce la verifica della licenza. Una fonte non verificata **NON DEVE**
essere ammessa come codice redistribuibile sulla sola base della citazione.

L’[inventario verificabile](../Config/Licenses/materials.json) registra fonti,
revisione, licenza della fonte, relazione, file interessati, distribuzione e avvisi.
`reviewedInputs` vincola manifest di dipendenze, workflow e asset ai digest
revisionati. I glob coprono i materiali; i digest espliciti impediscono che una
sostituzione o aggiunta in quei gruppi riusi silenziosamente la review precedente.
Il controllo automatico verifica questa struttura; non certifica i diritti.

## Fonti implementative con avvisi conservati

| Materiale | Relazione col prodotto | Condizioni conservate |
| --- | --- | --- |
| Snowball Italian 3.1.0 | Regole e tabelle italiane implementate in `GlifiItalianStemmer`; nessuna libreria libstemmer nel package | BSD-3-Clause della [pagina ufficiale](https://snowballstem.org/license.html) e della [release 3.1.0](https://raw.githubusercontent.com/snowballstem/snowball/v3.1.0/COPYING); copyright e testi integrali in [THIRD_PARTY_NOTICES.txt](../THIRD_PARTY_NOTICES.txt) |
| SplitMix64 fixed-increment | Sequenza di `GlifiSplitMix64` e oracolo Python, con costanti del generatore di Sebastiano Vigna | La [fonte primaria](https://prng.di.unimi.it/splitmix.c) dedica i diritti al pubblico dominio e concede anche permesso esplicito di uso/copia/modifica/distribuzione; avviso conservato |

La pagina Snowball e il file della release recano elenchi di copyright diversi:
sono conservati entrambi, senza sostituirli con il copyright del progetto.
Nessuno di questi avvisi implica approvazione di Glifi Studio da parte degli autori.

## Nuclei numerici corretti nel lotto 318–321

La baseline citava Numerical Recipes nei nuclei beta/gamma e usava i coefficienti
di Acklam per il quantile normale. Non era registrata una concessione primaria
sufficiente per tali sorgenti. L’editore di
[Numerical Recipes](https://www.numerical.recipes/otherstufftop.html) precisa che
il codice non è liberamente redistribuibile come sorgente; la leggibilità online
non è una concessione di riuso.

La correzione GS-VER-319 sostituisce quei nuclei con implementazioni Swift proprie
da relazioni matematiche: frazioni continue beta/gamma, simmetria e inversione
della coda normale. `logGamma` usa `lgamma_r` di sistema, eliminando anche la tabella
Lanczos priva di provenienza registrata. Non è sufficiente cancellare una citazione:
la procedura, le guardie e i test sono riesaminati nel cambiamento numerico.

I riferimenti sono [DLMF 8.17](https://dlmf.nist.gov/8.17),
[8.9](https://dlmf.nist.gov/8.9) e [7.9](https://dlmf.nist.gov/7.9).
Le [condizioni DLMF](https://dlmf.nist.gov/about/notices) dichiarano copyright
NIST e restrizioni alla riproduzione dei contenuti. Il progetto cita le identità
matematiche e scrive codice proprio: non include pagine, immagini, testo,
tabelle o codice DLMF e non presenta il sito come materiale BSD o genericamente
pubblico dominio. La voce `LicenseRef-NIST-DLMF` descrive la fonte, non la licenza
della nuova implementazione Swift.

Il permesso originale di Acklam non è stato verificato da una fonte primaria
accessibile durante questa review: non viene dedotto da copie di terzi.
La sostituzione rimuove i coefficienti dalla versione corrente; non riscrive
la storia Git né attesta i diritti sulle revisioni precedenti.

## Specifiche scientifiche e riferimenti KH

Le varianti, le formule e le bibliografie per famiglia restano nei documenti
[GS-MET-001](metodi-analitici/README.md). Includono ponderazioni, keyness,
clustering, reti, LDA/NMF e riassunti: un riferimento alla pubblicazione primaria
non autorizza a incorporare un’implementazione trovata sul web.

[GS-MET-001-23](metodi-analitici/23-operatori-kh-coder.md) dichiara manuale KH,
sorgenti pubblici storici KH e documentazione R consultati per precisare i
comportamenti. Il [repository KH pubblico](https://github.com/ko-ichi-h/khcoder)
indica GPL-2.0 e una beta obsoleta: non viene presentato come sorgente BSD né
come prova dell’edizione corrente. Le analisi native hanno contratti e test
propri. Non sono stati osservati sorgenti KH/R vendorizzati o collegati nel
prodotto; l’ispezione corrente non ricostruisce però il processo di scrittura
storico e non prova da sola l’assenza di derivazione espressiva. Qualunque nuovo
port o frammento copiato richiede licenza e decisione specifiche.

## Confronto campionario con sorgenti KH e R

La seconda passata GS-VER-318 confronta quattro nuclei Swift correnti e i commit
introduttivi `94c564b`/`d368285` con le fonti riferite, senza conservarne i sorgenti.
Il [rapporto con hash e confini](evidenze/allegati/GS-VER-318/confronto-fonti-kh.json)
distingue corrispondenze matematiche da struttura implementativa:

| Nucleo | Corrispondenze e differenze osservate |
| --- | --- |
| SOM KH online/PCA | Schedule, due fasi, osservazioni cicliche e inizializzazione a ±2 deviazioni sono informati da R som. Il [pacchetto som](https://cran.r-project.org/web/packages/som/index.html) è GPL ≥ 3, distinto da altri pacchetti R GPL ≥ 2. C++/R usa matrici TNT, dispatch SomParam e delta di matrice; Swift usa aggiornamenti scalari, `hypot`, SVD LAPACK diretta, limiti e failure numeriche. La fonte software va registrata anche se non è una dipendenza del prodotto. |
| Ward.D2 | Comune la ricorrenza Lance–Williams. R usa distanza condensata e cache nearest-neighbor; Swift scandisce le coppie attive e conserva identità e merge del progetto, struttura già presente nell’HAC prima del profilo KH. |
| χ² KH | KH forma comandi `chisq.test` e analizza stringhe di output. Swift calcola margini e prodotti interi esatti e risultati tipizzati, con sommatoria e gestione dei degeneri proprie; non riproduce il ponte Perl/R. |
| LR/FLR | Confrontate formule dalle pubblicazioni primarie e la valutazione Swift con `log1p`/`exp`, conteggi e set tipizzati. Il sito ufficiale del software TermExtract non era accessibile: nessun confronto integrale del suo sorgente viene dichiarato. La fixture derivata dall’esempio del paper è sostituita in GS-VER-323 da nove candidate originali con struttura e frequenze diverse; rimangono riferimenti alle formule. |

Non è stata individuata una copia espressiva inequivocabile nei nuclei esaminati.
È un esito campionario: la coincidenza di formule/default non dimostra un port,
mentre strutture diverse non provano da sole un processo storico indipendente.
La dichiarazione «originale» in un commento del progetto resta un’affermazione
di provenienza da valutare, non una certificazione ottenuta dall’audit.
L’individuazione futura di un port richiede riesame della licenza o sostituzione;
la classificazione «riferimento» non è un modo per approvare codice GPL copiato.

## Oracoli e strumenti separati

Gli scenari BDD usano anche le fonti primarie revisionate in
[GS-LIC-003](testing/02-provenienza-scenari.md): Gherkin, NIST/SEMATECH,
Unicode e RFC JSON/CSV. Il registro distingue licenza del codice, dati e
pubblicazioni, conserva revisioni e condizioni e dichiara l'uso di casi
originali senza acquisire esempi o suite esterne. Sono riferimenti per
classi di casi, non nuovi oracoli indipendenti o dipendenze del prodotto.
Il manuale NIST è pertinente a t/paired/Welch e goodness-of-fit, non viene
attribuito a tutte le famiglie. Gli altri scenari mantengono forme chiuse,
invarianti originali o riferimenti alle specifiche interne già riesaminate;
il registro collega i nomi effettivi delle feature senza anticipare esiti GREEN.

R e i pacchetti `igraph`, `NMF`, `cluster` sono strumenti GPL eseguiti come
processi di verifica su dati sintetici del progetto. Le licenze sono verificate
su [R](https://www.r-project.org/about.html),
[igraph](https://cran.r-project.org/web/packages/igraph/index.html),
[NMF](https://cran.r-project.org/web/packages/NMF/index.html) e
[cluster](https://cran.r-project.org/web/packages/cluster/index.html).
Il package Swift non li importa o collega; il repository conserva gli script
chiamanti originali e risultati numerici, senza il runtime o sorgenti dei pacchetti.
L’[FAQ GNU sugli output](https://www.gnu.org/licenses/gpl-faq.html#WhatCaseIsOutputGPL)
distingue l’output ordinario da output che incorpora contenuti del programma:
nuovi output di codice, testo o immagini richiedono riesame, non una presunzione
estesa a ogni tipo di risultato.

Python usa la libreria standard negli oracoli; veraPDF è un validatore separato
con [condizioni proprie](https://verapdf.org/home/). Le azioni CI `checkout` e
`cache` restano eseguibili esterni MIT fissati ai commit inventariati.
Le versioni effettive di R, pacchetti, Python, veraPDF e SDK **DEVONO** accompagnare
le prove che li usano: la versione corrente di CRAN non prova quella installata.
L’inventario non è un lockfile dell’intera macchina di sviluppo.

### Runner BDD e generatore Swift Testing

CucumberSwift 6.9.0 e CucumberSwiftExpressions 1.4.2 sono compilati nel
confine dei test; non sono oracoli numerici indipendenti né dipendenze dei
target di produzione. Le revisioni nel lockfile corrispondono ai tag e ai
checkout puliti esaminati. Le licenze sono MIT, distinte dalla BSD del codice
originale del progetto:

| Fonte primaria al commit | SHA-256 del LICENSE letto |
| --- | --- |
| [CucumberSwift, 5547f902](https://github.com/cucumberswift/CucumberSwift/blob/5547f9025c0da3f0276a22a3c746bfebc405741f/LICENSE) | `fe9f4f27ef428cbca240370cc8a49fa12176947fae195e2e6b45ad6a3ab988bc` |
| [CucumberSwiftExpressions, ab4c6482](https://github.com/cucumberswift/CucumberSwiftExpressions/blob/ab4c6482d3230d24a13814a961b6fff1d50f830f/LICENSE) | `109631cb84ae9b5d6e72d3e776870f2e824b7d48c8ac8f8c4ceb08131debb9a8` |

Gli [avvisi completi](../Config/Licenses/bdd-tools.txt) conservano copyright,
permesso e disclaimer di entrambe le fonti. Il confronto dei componenti
selezionati, compresi parser condiviso e generatore, non ha individuato
ulteriori licenze dichiarate; non costituisce una certificazione della
titolarità di tutto il repository upstream. La review del grafo controlla
che soltanto `GlifiBDDTests` consumi runner e plugin, senza import nei
sorgenti applicativi. Il generatore scrive nel workdir del plugin; il codice
generato resta un artefatto della cache. Una redistribuzione del bundle di
test, del generatore o di codice upstream generato deve conservare gli
avvisi MIT pertinenti.

I trait sono disabilitati esplicitamente con `traits: []` secondo
[SwiftPM](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/addingdependencies/#Packages-with-Traits):
senza questa scelta il default `Macros` upstream dipenderebbe da `SPI_BUILD`.
Manifest, lockfile, avvisi e digest revisionati vengono riesaminati insieme.

L'integratore ha verificato la risoluzione anche con `SPI_BUILD=1`: il grafo
contiene soltanto CucumberSwift 6.9.0 e CucumberSwiftExpressions 1.4.2, senza
SwiftSyntax. Il lockfile conserva gli stessi commit e lo stesso `originHash`;
il suo SHA-256 resta
`d7192d75b75156eb6544d3282fa4043f9ced4e28890da1312d7579981911a59f`.
Il dossier locale `macOS-2026-11-27-semantics` conserva `bdd-resolve.log`
(SHA-256 `78e694cfa8e7597590d6936e9bc588686f78110c4ddcf37c6644863deb0c8f85`)
e `bdd-dependency-graph.json`
(SHA-256 `320f8d8322537b7d306fdf4f42ff47a47baaff1e86aab7cf4f6e70862b65abb9`).
Questa prova riguarda la risoluzione, non il risultato dei test BDD o del
gate integrato, registrati separatamente in GS-VER-332.

Il successivo gate macOS composito è superato: il controllo licenze registra
25 materiali e 21 digest coerenti. La verifica del bundle Release ispeziona
17 elementi, conserva LICENSE e THIRD_PARTY_NOTICES identici alle fonti e
non trova cartelle o estensioni vietate nell'ambito dichiarato, compresi
`tests` e `.xctest`. È una prova di packaging con filtri dichiarati, non
un'analisi esaustiva dei simboli binari; la separazione del codice Cucumber
dai target applicativi è verificata anche sul grafo delle dipendenze.
Il log composito ha SHA-256
`dccda4c30b675a31188afc0dce651a4aaa3d5c56f2a233bb659f9f6da2e6a28a`.

## Testo, immagini e sistema

Il gold Pinocchio distingue testo originario, trascrizione Wikisource e
annotazioni originali. [Attribuzione e revisioni specifiche](../Fixtures/Linguistics/it-gold-v1/ATTRIBUTION.md)
conservano la via CC BY-SA 3.0 dichiarata dalla fonte per eventuali apporti
protetti della trascrizione; soltanto intervalli e metadati originali sono BSD.
I quindici paragrafi e le annotazioni non sono stati modificati. Le fixture non
sono risorse del bundle app; la redistribuzione sorgente conserva i relativi avvisi.

Master e prompt di icona e hero documentano una generazione per il progetto in
[Design](../Design/README.md). La review di provenienza non dimostra esclusività,
distintività o registrabilità del marchio, ancora da approvare prima della submission.
Non sono presenti font binari o corpus KH copiati come asset.

Framework Apple, SQLite e zlib sono forniti dal sistema/SDK. Non si attribuisce
BSD al loro codice e non si copiano le loro librerie nel repository. Il renderer
PDF usa font di sistema e fallback: il permesso di incorporare font nei documenti
va distinto dal diritto di distribuirli come risorsa app. Le
[condizioni Apple pubblicate](https://www.apple.com/legal/sla/) rinviano ai
permessi del singolo font; la verifica PDF/A dimostra conformità tecnica, non
la titolarità dei diritti sul font.

## Confini della review

Questo registro documenta decisioni tecniche, materiali osservati e condizioni
primarie consultate il 2026-11-26. Non certifica assenza di rivendicazioni, brevetti,
diritti di marchio o diritti su future importazioni degli utenti. Non sostituisce
la verifica di titolarità dei contributi o una valutazione giuridica del rilascio.
La storia Git conserva le revisioni anteriori: un rilascio sorgente deve usare
la revisione corretta e non presentare la sostituzione attuale come bonifica storica.
