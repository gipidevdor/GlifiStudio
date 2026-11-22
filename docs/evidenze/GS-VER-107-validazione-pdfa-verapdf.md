<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-107 — Validazione PDF/A-2u degli export con veraPDF

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-107 |
| Tipo | Evidenza di verifica con validatore esterno |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata di RQ-061 per il formato PDF |

## Ambito

Supera il limite di GS-VER-093 e GS-VER-104 (nessun validatore PDF/A esterno): la conformità
dichiarata PDF/A-2u dell'export scientifico (ADR-0023, GS-VER-033) è verificata con veraPDF, il
validatore di riferimento della PDF Association, installato su autorizzazione esplicita.

- veraPDF 1.30.2 (pacchetto ufficiale greenfield), installato a livello utente in
  `~/Library/Application Support/veraPDF` ed eseguito con Amazon Corretto 11; non disponibile come
  port MacPorts;
- i test di export copiano i PDF prodotti nella cartella indicata da `GLIFI_ORACLE_PDF_DIRECTORY`;
- `Scripts/check-pdfa.py` valida i PDF con `--flavour 2u` e fallisce su qualunque esito diverso da
  PASS; `Scripts/verify.sh` lo esegue sui PDF dei test appena eseguiti, `make check-pdfa` riesegue
  gli export in una cartella temporanea; senza veraPDF il controllo viene saltato con messaggio
  esplicito, salvo `--require`.

## Procedura e risultato

1. il report breve (tutti i formati) e il report lungo paginato sono entrambi **conformi PDF/A-2u**
   (PASS) secondo veraPDF;
2. controllo negativo: il PDF con offset xref spostati catturato durante l'analisi di GS-VER-093
   risulta FAIL, quindi il controllo non accetta documenti strutturalmente corrotti;
3. gate completo `make verify` con la validazione integrata.

## Limiti

Il controllo copre i PDF prodotti dalle fixture dei test; contenuti con script o font diversi da
quelli delle fixture sono coperti dalla stessa pipeline di rendering ma non da un corpus dedicato.

## Esito

**Superato localmente: gli export PDF sono conformi PDF/A-2u secondo veraPDF, con controllo
negativo e integrazione nel gate.**
