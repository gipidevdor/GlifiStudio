<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Chiusura delle lacune funzionali KH Coder

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-300 |
| Tipo | Scheda di implementazione analitica |
| Versione | 1.1.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita: finire la completezza rispetto a KH Coder |
| Riferimenti | RF-087; RQ-025; RQ-058; RQ-060; RQ-063; GS-MET-001-23; GS-VER-234; ADR-0043 |

## Ambito

Implementare le lacune analitiche del confronto pubblico registrato in GS-VER-234:
matrice parola-contesto, z-score campionario per asse, esposizione esterna,
tie primary MDS, SOM a due fasi/PCA, sette misure su TF globale/span, scaling CA,
kappa del classificatore, aggiornamento incrementale NB e ranking TermExtract.
Il censimento finale del manuale A5/A6/A7, svolto durante il lavoro autorizzato,
ha aggiunto associazione documentale, punteggi TF/TF-IDF/TF diviso IDF,
Ward.D2 algebrico e χ²/Yates con significatività dei crosstab per codice.
Questa revisione registra l’estensione emersa: non retrodata la sua pianificazione.
Il riferimento è il manuale pubblico KH del 2016 e i sorgenti pubblici ufficiali:
non si dichiara equivalenza con un’edizione chiusa non disponibile.

## Criteri di uscita

- Implementazioni Swift originali con metodi/versioni distinti, nessun runtime R,
  Perl o Python di prodotto, nessuna dipendenza o formato persistente nuovo.
- Stessi input, parametri, risultati e failure in GlifiKit e CLI; default e risultati
  delle API preesistenti conservati salvo correzioni documentate.
- Oracoli indipendenti sintetici, casi ordinari/estremi, cancellazione e ammissione
  cumulativa prima di allocazioni; norme e output finiti o failure esplicite.
- Test mirati, suite completa e make verify; esiti e limiti effettivi in GS-VER-300.
- GUI, cache e modifiche concorrenti preservate; prove conservate e scratch pulite.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Lacune analitiche pubbliche chiuse in Core/Kit/CLI; GUI separata, nessuna promessa su tokenizer esterni, formati proprietari o edizioni non verificabili |
| failure semantics | Input incoerente, non finito, overflow o limiti generano errori di dominio; nessun risultato parziale; cancellazione cooperativa |
| tracciabilità | RF-087 e requisiti di correttezza/risorse; GS-MET-001-23, ADR-0043 e GS-VER-300 con prove per singolo profilo |

**Ready** per l’implementazione nel perimetro autorizzato.
