<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Politica di licenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-LIC-001 |
| Tipo | Politica di licenza del progetto |
| Versione | 0.2.0 |
| Stato | Attivo |
| Responsabile | Glifi Studio contributors |
| Ultima modifica | 2026-11-26 |
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
