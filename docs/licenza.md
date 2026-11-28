<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Politica di licenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-LIC-001 |
| Tipo | Politica di licenza del progetto |
| Versione | 0.4.0 |
| Stato | Attivo |
| Responsabile | Glifi Studio contributors |
| Ultima modifica | 2026-11-27 |
| Approvazione | Decisione dell'iniziatore del progetto, 2026-09-15 |
| Licenza | BSD 3-Clause (`BSD-3-Clause`) |

## 1. Decisione

Glifi Studio è distribuito inizialmente secondo la licenza [BSD 3-Clause](../LICENSE), identificatore SPDX `BSD-3-Clause`.

Salvo indicazione differente in un file o in una directory, la licenza si applica al codice sorgente, alla documentazione e agli altri materiali originali presenti nel repository.

## 2. Copyright

L'intestazione iniziale è:

```text
Copyright 2026 Glifi Studio contributors
```

La definizione dell'eventuale titolare principale, la gestione dei contributi esterni e l'adozione di CLA o DCO restano questioni aperte. Prima di accettare contributi di terzi deve essere verificato che il contributore abbia il diritto di concederli sotto BSD-3-Clause.

## 3. Identificatori nei file

I nuovi file sorgente originali dovrebbero riportare, nel formato di commento appropriato:

```text
SPDX-License-Identifier: BSD-3-Clause
```

Il testo integrale non deve essere duplicato in ogni sorgente; il riferimento normativo è il file `LICENSE` alla radice.

## 4. Materiali di terzi

- Una dipendenza o un materiale di terzi conserva la propria licenza.
- La relativa licenza e gli avvisi obbligatori devono essere inventariati e distribuiti quando richiesto.
- Materiale incompatibile con BSD-3-Clause o con la modalità di distribuzione prevista non deve essere incorporato senza una decisione esplicita.
- La presenza della licenza BSD-3-Clause nel repository non modifica i diritti sui corpus importati dagli utenti.

## 5. Eventuale cambiamento futuro

La licenza potrà essere riesaminata per le versioni future soltanto dopo una verifica della titolarità dei diritti e degli accordi con i contributori.

Una modifica futura non revoca la BSD-3-Clause sulle copie e sulle versioni già distribuite con tale licenza.

## 6. Verifica di rilascio

Ogni rilascio deve includere:

- il file `LICENSE` integro;
- l'inventario delle dipendenze e delle licenze applicabili;
- gli avvisi di terzi richiesti;
- l'identificatore SPDX nei metadati del pacchetto, quando supportato.

## 7. Registro di provenienza e distribuzione

[GS-LIC-002](algoritmi-e-provenienza.md) distingue riferimento matematico,
implementazione da specifica, adattamento di codice, fixture e strumento esterno.
L’[inventario controllato](../Config/Licenses/materials.json) riporta le condizioni
della fonte senza applicarle automaticamente all’intero progetto.

La distribuzione dell’app conserva il testo BSD del progetto e gli
[avvisi di terzi](../THIRD_PARTY_NOTICES.txt). Il controllo del bundle ne verifica
la presenza e l’integrità; non si limita alla presenza del file nel repository.
Un futuro pacchetto CLI o sorgente deve conservare i medesimi testi applicabili.

La fixture [Pinocchio](../Fixtures/Linguistics/it-gold-v1/ATTRIBUTION.md) è
un’eccezione esplicita alla licenza generale: eventuali apporti protetti della
trascrizione restano sotto le condizioni attribuite alla fonte, mentre
annotazioni e metadati originali sono BSD. Le porzioni testuali nei JSON non sono
relicenziate dalla BSD; la fixture non viene inclusa come risorsa dell’app.

R, i pacchetti degli oracoli, veraPDF, Python e azioni CI rimangono strumenti
esterni con licenze proprie. Prima di copiarli, collegarli o distribuirli nel
prodotto serve una nuova valutazione. Una citazione di articolo o manuale non
è una concessione di licenza sul relativo codice, testo, tabella o dato.

## 8. Dipendenze BDD esclusivamente di sviluppo

[ADR-0046](adr/0046-bdd-cucumber-swift.md) adotta CucumberSwift 6.9.0 e la
dipendenza transitiva CucumberSwiftExpressions 1.4.2 con licenza MIT. Manifest
e lockfile identificano versioni e commit; ciascun pin remoto richiede una
propria voce revisionata, una fonte di licenza immutabile riferita al commit
risolto e un avviso completo. L'inventario registra la verifica delle licenze
sulle revisioni effettive. Gli
[avvisi completi](../Config/Licenses/bdd-tools.txt) conservano copyright,
permesso e disclaimer MIT delle due dipendenze e dei materiali indiretti.

I dialetti incorporati in `Languages.swift` e nei tipi di passo localizzati
provengono dal progetto Cucumber/Gherkin; la diagnostica adattata in
`SyntaxError.swift` proviene da Cucumber Expressions. Sono materiali
incorporati, anche se non compaiono come package aggiuntivi nel lockfile.
Si conservano anche i rispettivi copyright Cucumber Ltd e contributori,
inclusi Gaspar Nagy, Björn Rasmusson e Peter Sergeant per Gherkin, con i testi
MIT primari. Le revisioni
`81ef221bd9e1f0d41b62e3986c5dd61439641117` per Gherkin e
`eb1ad273949ad8bfd20632f73f1959bae6135a45` per Cucumber Expressions
identificano gli snapshot di **revisione della licenza**: non attestano la
revisione storica esatta da cui gli adattamenti Swift sono stati ricavati.

SwiftGen è citato upstream come generatore. L'integrazione selezionata non lo
aggiunge come dipendenza né copia i suoi template nel repository; la sua
citazione non sostituisce gli avvisi sui dati Gherkin effettivamente
incorporati.

Queste librerie sono collegate al bundle dei test e il generatore è eseguito
durante la loro build. Non sono dipendenze dei target app, GlifiKit, GlifiCore
o CLI e non vengono copiate nel bundle applicativo. Il confine test non elimina
gli obblighi sulle copie degli strumenti e delle librerie. Il test bundle
collega anche GlifiKit e GlifiCore e conserva tre file nella risorsa `Licenses`:

- `THIRD_PARTY_NOTICES.txt`: i quattro avvisi MIT BDD, copia integrale di
  `Config/Licenses/bdd-tools.txt`;
- `GlifiStudio-LICENSE.txt`: la BSD 3-Clause del progetto, copia integrale del
  `LICENSE` alla radice;
- `GlifiStudio-THIRD_PARTY_NOTICES.txt`: gli avvisi del Core, inclusi Snowball
  e SplitMix, copia integrale di `THIRD_PARTY_NOTICES.txt` alla radice.

Il controllo statico confronta ciascuna copia byte per byte con il testo
controllato e `GlifiBDDLicenseTests` ne verifica i tre digest nel bundle
compilato. Ogni distribuzione di test, strumenti o relativi artefatti CI deve
mantenere tutti i testi applicabili insieme alla copia distribuita. Gli avvisi
BDD rimangono distinti da quelli applicativi e dai testi dei componenti Core,
che il test bundle deve comunque conservare.

Aggiornamenti, macro, ulteriori plugin o materiali incorporati richiedono
riesame delle nuove revisioni e dipendenze, senza trasferire la licenza BSD del
progetto al codice esterno. [GS-VER-333](evidenze/GS-VER-333-licenze-bdd.md)
registra il riesame e i controlli: la loro esecuzione documenta questo ambito,
senza costituire una certificazione legale universale o ricostruire la
provenienza storica completa.
