<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Glifi Studio

Analisi testuale per macOS e iPadOS.

Raccogli documenti, esplora i testi e confronta i risultati. Ogni indagine conserva
fonti, metodi e passaggi di analisi, per risalire dal risultato al testo originale.

[Avvio rapido](#avvio-rapido) · [Documentazione](docs/README.md) · [Contribuire](CONTRIBUTING.md)

## Dai testi ai risultati

- **Organizza le fonti.** Importa TXT, Markdown, PDF ed EPUB in un progetto `.glifi`, conservando gli originali.
- **Esplora i testi.** Cerca parole e passaggi nel loro contesto, analizza le raccolte e confrontale.
- **Condividi il lavoro.** Esporta risultati e riferimenti in PDF/A-2u, Markdown, CSV e JSON.

Il laboratorio macOS aggiunge riassunti estrattivi, ricerca BM25, frequenze,
diversità lessicale, ponderazione dei termini e distribuzioni di Zipf e Heaps.
Il laboratorio avanzato offre dodici operazioni sui documenti del progetto,
con risultati di sessione ed esportazione delle richieste e degli esiti.
I laboratori dedicati aggiungono selezione LDA, MDS con più avvii, SOM avanzata,
comunità e layout dei grafi, foreste minime e pipeline linguistica nativa, oltre
alle analisi dirette del corpus, alla statistica su dati
espliciti, valutazione temporale e linguistica, matrici e grafi. Il catalogo
ricerca i singoli metodi e conserva l’identità dei risultati di sessione.
La disponibilità dei metodi nel
motore, nella riga di comando e nelle app è distinta nella
[matrice di tracciabilità](docs/tracciabilita.md).

## Stato del progetto

**In sviluppo.** Le app macOS e iPadOS condividono il percorso da progetto a
indagine ed esportazione. Le estensioni del laboratorio sono disponibili su macOS;
il loro adattamento a iPadOS resta pianificato.

Gli audit di accessibilità su dispositivo, la validazione con le persone e i gate
di rilascio restano aperti. Le verifiche riguardano revisioni precise, registrate
nelle [evidenze](docs/evidenze/README.md). La
[baseline di prodotto](docs/specifiche-di-design/10-product-baseline-mvp.md)
definisce il perimetro della versione 0.1.

## Avvio rapido

Servono Xcode 27, gli SDK macOS e iPadOS 27 e Apple Swift 6.4 o una versione
compatibile successiva della serie 6, in modalità Swift 6. I controlli richiedono
Python 3.10 o successivo; gli strumenti di validazione sono descritti nella
[guida dell'ambiente](docs/ambiente-di-sviluppo.md).

```sh
make bootstrap
open GlifiStudio.xcworkspace
```

Nel workspace scegli `GlifiStudio-macOS` o `GlifiStudio-iPadOS`.

Su macOS usa **Area di lavoro → Trova uno strumento…** (`⌘K`) per cercare
un'attività o un metodo. `⌘F` apre la ricerca nei testi; `⌘1`–`⌘7` raggiungono
le principali sezioni del progetto. Il laboratorio conserva impostazioni e
risultati durante la navigazione e separa i due pannelli nelle finestre ampie.

Per usare la riga di comando:

```sh
swift run --package-path Packages/GlifiCore GlifiCLI
```

Il comando restituisce `GlifiCore pronto`. Il
[contratto della CLI](docs/api/README.md) descrive comandi e formati di risposta.

## Verifica

```sh
make verify
```

Esegue controlli statici, test Core/Kit e macOS, verifiche CLI e build Debug/Release
dell'app macOS senza firma, secondo la priorità corrente del progetto. Il profilo
di entrambe le piattaforme è esplicito con `make verify-all`; iPadOS è rinviato.
Gli esiti e gli eventuali controlli saltati vanno registrati per la revisione verificata.

Per il feedback rapido usa `make quality`. Profili macOS, preflight App Store e
criteri di integrazione sono descritti nel
[loop di sviluppo](docs/loop-di-sviluppo-e-qualita.md) e nella
[guida ai contributi](CONTRIBUTING.md).

## Architettura

| Componente | Responsabilità |
| --- | --- |
| [App](Apps) | Interfacce native macOS e iPadOS |
| [GlifiKit](Packages/GlifiCore/Sources/GlifiKit) | Contratto applicativo condiviso |
| [GlifiCore](Packages/GlifiCore/Sources/GlifiCore) | Analisi, provenienza e persistenza |
| [GlifiCLI](Packages/GlifiCore/Sources/GlifiCLI) | Accesso dalla riga di comando |

Le app e la CLI accedono al motore tramite GlifiKit. I calcoli restano separati
dall'interfaccia. Consulta l'[architettura](docs/architettura.md) e il
[registro ADR](docs/adr/README.md) per le scelte di progetto.

## Documentazione

- [Orientarsi nella documentazione](docs/README.md)
- [Comprendere metodi e risultati](docs/metodi-analitici/README.md)
- [Progettare l'esperienza e l'accessibilità](docs/esperienza-utente/README.md)
- [Consultare i requisiti](docs/requisiti.md) e gli [standard](docs/standard-di-progetto.md)
- [Seguire lo sviluppo](docs/roadmap.md) e le [modifiche](CHANGELOG.md)

## Contribuire e sicurezza

Il repository è privato. Per contribuire, segui la [guida ai contributi](CONTRIBUTING.md) e le
[istruzioni operative](AGENTS.md). Per assistenza consulta il
[supporto](SUPPORT.md); per le vulnerabilità usa il
[canale di sicurezza](SECURITY.md). Ruoli e decisioni sono descritti nella
[governance](GOVERNANCE.md).

## Licenza

[BSD 3-Clause](LICENSE). Ambito, attribuzioni e materiali di terzi sono definiti
nella [politica di licenza](docs/licenza.md).
Le eccezioni sono registrate negli [avvisi di terzi](THIRD_PARTY_NOTICES.txt)
e nel [registro delle fonti](docs/algoritmi-e-provenienza.md).
