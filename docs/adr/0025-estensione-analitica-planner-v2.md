<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0025 — Estensione analitica post-0.1 e planner-v2

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0025 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-18 |
| Data decisione | 2026-09-18 |
| Approvazione | Estensione documentata richiesta esplicitamente dall'iniziatore |
| Integra | ADR-0006, DA-028, GS-PROD-001 |
| Sostituisce | Nessuno |

## Contesto

La baseline di prodotto 0.1 (GS-PROD-001) limita `planner-mvp-v1` al nucleo Must e dichiara
fuori dal prodotto 0.1 Correspondence Analysis, PCA/LSA/NMF, clustering, reti, collocazione
avanzata e content analysis multi-codificatore (DA-028). Queste famiglie sono ora implementate in
GlifiCore con specifica GS-MET, verifica contro oracoli esterni rieseguibili (GS-VER-099…105),
persistenza come Artifact e parità GlifiKit/CLI, ma restano irraggiungibili dal planner e
dall'interfaccia.

## Decisione

1. Si apre l'**incremento analitico post-0.1**: la baseline 0.1 non cambia; le famiglie elencate
   sopra entrano nel prodotto successivo a 0.1.
2. Il planner diventa `planner-v2` con catalogo `capability-catalog-v2`, sovrainsieme del catalogo
   MVP: profilo corpus e keyness conservano identità, regole di applicabilità e passi.
3. Una capability entra nel catalogo solo se soddisfa tutti i criteri: specifica GS-MET,
   evidenza GS-VER con oracolo indipendente o valori in forma chiusa, operazione persistita con
   riuso, parità GlifiKit/CLI e precondizioni verificabili dal planner sui soli fatti di
   collezione; i parametri scelti dal planner sono costanti dichiarate nel descrittore.
4. Le precondizioni che dipendono dal contenuto (per esempio coppie o archi presenti) rendono la
   capability `conditional` con caveat esplicito; il piano resta deterministico.
5. L'integrazione nell'interfaccia macOS/iPadOS segue le specifiche UX (GS-UX-004) in incrementi
   separati; fino ad allora le capability estese sono pianificabili ed eseguibili da GlifiKit e CLI.
6. Codebook e codifiche persistite (RF-043) e la scalabilità oltre i limiti bounded restano fuori
   da questa decisione e richiedono un ADR proprio.

## Conseguenze

- I piani prodotti da `planner-v2` per le stesse intenzioni possono includere più passi rispetto
  a `planner-mvp-v1`; i piani persistiti con l'identità MVP restano leggibili e riproducibili.
- Ogni nuova capability aggiunge righe di tracciabilità e compliance e un'evidenza GS-VER.
- La release 0.1 può essere distribuita senza le famiglie estese: la decisione non abbassa alcun
  gate della baseline.
