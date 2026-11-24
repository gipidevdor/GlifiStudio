<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-130 — Determinismo delle misure d'accordo e della modularità

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-130 |
| Tipo | Evidenza di correzione di difetto |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | GS-MET-001-03 § Riduzioni concorrenti; RQ-025 |

## Difetto

Il gate ha fallito in modo intermittente su
`qualitativeAgreementTableMatchesExplicitTable`: due analisi della **stessa** richiesta davano
risultati diversi. La riproduzione mostra la causa esatta: due chiamate consecutive di
`krippendorffAlphaNominal` nello stesso processo restituivano `expectedDisagreement = 0.75` e
`0.7500000000000001`.

Le somme di `CohenKappaNominal-v1`, `KrippendorffAlpha-v1` e `FleissKappa-v1` iteravano un insieme
o i valori di un dizionario: l'ordine di un contenitore hash non è riproducibile fra istanze e
l'addizione floating-point non è associativa, quindi l'ultima cifra cambiava. Lo stesso difetto
era presente nella modularità delle reti lessicali, dove la somma finale iterava le chiavi di un
dizionario di comunità.

La conseguenza non è cosmetica: gli Artifact sono content-addressed, quindi la stessa tabella di
codifica poteva produrre due digest diversi, rompendo il riuso get-or-store e la garanzia D0
dichiarata da GS-MET-001-03 § Riduzioni concorrenti.

## Correzione

Ogni somma segue ora un ordine dichiarato e riproducibile:

- Krippendorff nominale lavora su una matrice di coincidenze indicizzata per interi, costruita
  nell'ordine di prima apparizione delle categorie nelle unità incluse; marginali, disaccordo
  osservato e atteso scorrono gli indici in ordine crescente;
- Cohen somma le categorie nell'ordine di prima apparizione nei giudizi dei due codificatori;
- Fleiss somma i quadrati dei conteggi di unità in ordine di etichetta;
- la modularità somma le comunità in ordine crescente di identificatore.

## Procedura e risultato

1. `agreementMeasuresAreBitIdenticalAcrossRepeatedCalls`: su otto unità con disaccordi e giudizi
   mancanti, 32 ripetizioni di alfa, kappa di Cohen e kappa di Fleiss coincidono **bit a bit**
   (confronto su `bitPattern`, non entro tolleranza); l'alfa calcolata su categorie intere
   coincide con quella su categorie stringa;
2. `qualitativeAgreementTableMatchesExplicitTable`, che prima falliva in circa una esecuzione su
   tre, ripetuto otto volte in processi separati: sempre verde;
3. `make verify` completo verde.

## Limiti

Il controllo copre le riduzioni delle misure d'accordo e la modularità. Una verifica sistematica
di tutte le riduzioni floating-point del motore (ricerca di somme su contenitori hash in ogni
famiglia di metodi) non è stata eseguita: la revisione manuale di questo incremento ha esaminato
le occorrenze di iterazione su `values`/`keys` in GlifiCore e non ne ha trovate altre che sommino
valori in virgola mobile, ma non sostituisce un controllo automatico nel gate.

## Esito

**Superato localmente: a parità di input le misure d'accordo e la modularità sono identiche bit a
bit, come richiede la classe D0 dichiarata.**
