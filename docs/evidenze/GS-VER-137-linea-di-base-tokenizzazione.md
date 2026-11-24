<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-137 — Linea di base della tokenizzazione italiana

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-137 |
| Tipo | Evidenza di verifica linguistica |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | ADR-0030 (direzione DA-008); soglie assolute rinviate a G4 |

## Ambito

Prepara il meccanismo che l'adozione di un corpus gold esterno richiede: misurare la qualità della
tokenizzazione e impedirne la regressione.

- **Misura**: precision, recall e F1 a corrispondenza esatta dello span, sui confini di token e di
  frase, come prescrive GS-MET-001-18. Un confine spostato conta come errore su entrambi i lati,
  non come mezzo credito.
- **Linea di base**: `Fixtures/Linguistics/it-gold-v0/baseline.json` dichiara corpus, digest del
  corpus, dimensioni e punteggi osservati. Il test fallisce se il punteggio scende e **segnala
  anche quando sale**, perché una linea di base non aggiornata nasconderebbe la regressione
  successiva.
- **Legame con il corpus**: il digest lega la linea di base a una versione precisa del gold.
  Cambiare il corpus la invalida e il gate chiede di rimisurarla.

## Procedura e risultato

1. `italianTokenizerMeetsRecordedBaseline`: sui quattro casi di `it-gold-v0` (19 token, 4 frasi)
   `it-token-v1` ottiene F1 pari a 1 su entrambi i livelli, coerente con la linea di base
   registrata;
2. controprova: modificando di un byte il corpus gold, il gate fallisce con «il corpus è cambiato,
   la linea di base va rimisurata»;
3. `check-fixtures.py` verifica schema, licenza, scopo, corrispondenza del digest, dimensioni
   dichiarate e punteggi dentro [0, 1];
4. `make verify` completo verde.

## Limiti

**Il numero non dice che la tokenizzazione italiana sia buona.** Il gold è ancora sintetico:
quattro casi scritti dal progetto, 19 token in tutto. Un F1 pari a 1 su quel materiale misura
soltanto che il comportamento non è cambiato. La misura diventa informativa quando il gold sarà
sostituito da testo italiano reale, che è la decisione ADR-0030 ancora da completare: la scelta
della fonte e l'autorizzazione ad acquisirla spettano all'iniziatore. Nessuna soglia assoluta di
accettazione è fissata; resta in G4.

## Esito

**Superato localmente: la qualità della tokenizzazione è misurata con le metriche prescritte e
protetta da una linea di base verificata nel gate, in attesa del corpus reale.**
