<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-132 — Invariante selettivo e trasporto degli Artifact all'importazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-132 |
| Tipo | Evidenza di persistenza |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | GS-DOR-010, incremento B (ADR-0028 accettato) |

## Ambito

Secondo incremento di ADR-0028: l'invariante del package e il protocollo di commit.

- **Invariante**: una sola funzione, `artifactMatchesCorpus`, sostituisce le tre uguaglianze
  sparse fra `corpusVersionDigest` e digest radice della generazione. Un descrittore che non
  dichiara revisioni resta legato alla radice; uno che le dichiara è valido quando ogni revisione
  dichiarata appartiene alla generazione **e** il suo digest è la radice ristretta a quelle
  revisioni. I tre punti di enforcement — apertura verificata, snapshot storico di recovery e
  commit di un Artifact — usano ora la stessa funzione, così non possono divergere.
- **Significato di `project.artifact-corpus-mismatch`**: non più «l'Artifact non appartiene alla
  generazione corrente» ma «l'analisi non corrisponde più alle fonti che dichiara». Categoria e
  stato conservato restano `staleArtifact` / `lastCommittedGeneration`.
- **Trasporto al commit d'importazione**: `commitImport` non azzera più gli Artifact. Conserva
  quelli il cui corpus dichiarato è immutato e, per punto fisso, scarta ogni nodo il cui antenato
  non sopravvive o il cui digest d'antenato non coincide più. Lo store SQLite scrive le righe
  conservate nella nuova generazione (nessun cambio di schema: le colonne esistono già).

## Procedura e risultato

1. `projectPackageAcceptsArtifactsBoundToDeclaredRevisions`: un Artifact dichiarato su un
   sottoinsieme è accettato con il digest di quel sottoinsieme; è rifiutato se porta il digest
   della raccolta intera o se dichiara una revisione estranea; la riapertura rivalida entrambe le
   forme;
2. `projectPackageRetainsArtifactsUnaffectedByAnImport`: padre e figlio dichiarati sulla prima
   revisione sopravvivono all'importazione di una fonte estranea, mentre l'Artifact legato
   all'intera generazione è invalidato; lo stato sopravvive alla riapertura, quindi il trasporto è
   persistito e non ricostruito a runtime; un figlio il cui padre non sopravvive viene invalidato
   con lui;
3. `projectPackageInvalidatesPersistedArtifacts`, invariato, continua a dimostrare che senza
   revisioni dichiarate un'importazione invalida tutto;
4. `make verify` completo verde, compresi i 22 checkpoint di interruzione: il commit
   d'importazione conserva i suoi sei punti di ripresa con il trasporto attivo.

## Limiti

Nessuna analisi reale dichiara ancora le proprie revisioni: il beneficio è dimostrato sugli
Artifact di prova del package, non ancora sul profilo di corpus, sulla keyness o sulle analisi
derivate. Collegare le fabbriche e mostrare il riuso end-to-end è l'incremento C. La `case.json`
della fixture di persistenza resta non letta da alcun controllo.

## Esito

**Superato localmente: un'importazione invalida soltanto gli Artifact il cui corpus dichiarato è
cambiato, e la catena delle dipendenze è invalidata con esattezza.**
