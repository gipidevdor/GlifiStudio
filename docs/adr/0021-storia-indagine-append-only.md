<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0021 — Storia dell'indagine append-only separata dagli Artifact

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0021 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-16 |
| Data decisione | 2026-09-16 |
| Approvazione | Deriva da GS-UX-001-02/10 e dalla richiesta di implementazione affidabile |
| Fonte | GS-DAT-001; ADR-0014 |
| Sostituisce | Nessuno |

## Contesto

Gli Artifact analitici sono ricostruibili e vengono invalidati quando cambia il
corpus. Domanda, percorso cognitivo e selezione editoriale sono invece contenuto
autorevole: perderli durante una nuova importazione confonderebbe cache e lavoro
della persona. Inserirli nello stesso Analysis DAG renderebbe inoltre una
diramazione editoriale dipendente dalla disponibilità corrente del calcolo.

## Decisione

1. InvestigationHistory usa una radice generazionale distinta da fonti e Artifact.
2. Ogni evento è JSON canonico immutabile, limitato a 1 MiB e identificato da
   `InvestigationEventID` SHA-256 dei propri byte canonici.
3. Un evento conserva InvestigationID, predecessore opzionale, tempo Unix in
   millisecondi, classe dell'attore e payload tipizzato versionato.
4. La storia è un grafo append-only: revisionare una decisione aggiunge un evento;
   usare lo stesso predecessore crea head distinti senza merge implicito.
5. Manifest e SQLite schema 3 includono root digest e conteggio degli eventi. Il
   manifest resta l'unico commit point e la riapertura verifica oggetti e grafo.
6. L'import conserva integralmente gli eventi anche quando invalida ogni Artifact
   della proiezione corrente.
7. Lo schema 2 migra additivamente in transazione SQLite; fino alla prima scrittura
   il manifest 2 resta leggibile solo con root storia vuota.
8. La slice 0.1 ammette `created` ed `editorialSelectionChanged`. Nuovi payload
   richiedono versione, limiti, replay e test di compatibilità.

## Alternative considerate

- Investigation come Artifact del DAG: respinta perché verrebbe invalidata con il
  corpus e mescolerebbe autorità editoriale e output ricostruibile.
- snapshot mutabile per indagine: respinto perché cancella predecessori, impedisce
  diramazione verificabile e rende ambiguo il recovery.
- eventi soltanto in JSONL: rinviato; senza root generazionale e indice relazionale
  non soddisfa il commit atomico già adottato dal package.
- timestamp o UUID come unica identità: respinti; non verificano i byte persistiti.

## Conseguenze

- Domanda e selezione sopravvivono a riapertura e nuove importazioni.
- Branch e ordine editoriale sono riproducibili senza riscrivere la storia.
- Ogni commit aggiunge una generazione e copia i riferimenti agli eventi precedenti;
  compattazione e garbage collection richiederanno policy dedicate.
- Tempo e attore partecipano all'identità dell'evento, mentre non alterano
  EvidenceID, FindingID o identità scientifica degli Artifact.
- Osservazione, note, navigazione, autosave coalesced e Report restano estensioni
  esplicite, non casi impliciti del payload editoriale.

## Verifica

- round-trip e ricalcolo di InvestigationEventID;
- replay di due rami dallo stesso predecessore e rifiuto di finding estranei;
- creazione/revisione attraverso GlifiKit su un'Interpretation reale;
- conservazione della storia dopo invalidazione degli Artifact e riapertura;
- migrazione schema 2→3 e successivo commit verificato;
- gate repository, test Swift, build macOS/iPadOS e preflight App Store.
