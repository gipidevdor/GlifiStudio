<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-131 — Descrittore v2 con revisioni dichiarate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-131 |
| Tipo | Evidenza di fondazione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | GS-DOR-010, incremento A (ADR-0028 accettato) |

## Ambito

Primo dei tre incrementi di ADR-0028. Introduce la forma con cui un'analisi dichiara le revisioni
delle fonti che legge, **senza** ancora cambiare l'invariante del package né il protocollo di
commit: a questo punto nessuna fabbrica dichiara revisioni, quindi il comportamento osservabile è
identico a prima.

- **Descrittore**: `sourceRevisionIDs` opzionale, ordinato canonicamente e privo di duplicati
  (`analysis.duplicate-source-revision`). Le tre letture sono distinte: campo assente = dipende
  dall'intera generazione (v1); campo dichiarato non vuoto = legge solo quelle revisioni (v2);
  campo dichiarato vuoto = non legge alcuna fonte.
- **Identità**: le revisioni dichiarate entrano nell'identità del nodo, ma **solo quando sono
  dichiarate**: la forma serializzata di un descrittore v1 non contiene il campo e la sua identità
  resta quella calcolata prima che la v2 esistesse.
- **Compatibilità fail-closed**: uno schema v1 che dichiara revisioni, uno v2 che non le dichiara e
  qualunque schema ignoto sono rifiutati con `analysis.unsupported-descriptor-version`.
- **Digest selettivo**: `GlifiProjectSnapshot.corpusVersionDigest(for:)` è la radice delle fonti
  ristretta alle revisioni dichiarate; una revisione estranea alla generazione è rifiutata con
  `project.source-revision-not-found` (`invalidInput`, `lastCommittedGeneration`).

## Procedura e risultato

1. `selectiveDescriptorDeclaresSourceRevisionsAndPreservesV1Identity`: un descrittore che non
   dichiara revisioni riproduce **il valore d'oro** del `nodeID` e del digest canonico, catturati
   con il codice precedente alla v2 — è la prova che i package esistenti continuano ad aprirsi;
   dichiarare le revisioni produce uno schema v2 e un nodo diverso; l'ordine di chiamata non conta
   (riordino canonico); dichiarare l'insieme vuoto è diverso dal non dichiarare nulla; i duplicati
   sono rifiutati; round-trip JSON con e senza il campo;
2. `selectiveCorpusVersionDigestRestrictsTheSourceRoot`: su un progetto con due fonti, il digest
   sulle revisioni dichiarate coincide con la radice quando le dichiara tutte, differisce su un
   sottoinsieme, **non cambia dopo l'importazione di una fonte estranea** — la proprietà su cui si
   appoggerà il nuovo invariante — e rifiuta una revisione non presente;
3. il test che prima pretendeva il rifiuto dello schema v2 è stato riscritto su uno schema v3
   inesistente, così il contratto fail-closed sulle versioni ignote resta verificato;
4. `make verify` completo verde: conteggi di generazione e Artifact del contract test CLI
   invariati, 22 checkpoint di recovery validi.

## Limiti

Nessun Artifact dichiara ancora le proprie revisioni: l'invariante del package, il trasporto degli
Artifact al commit e il riuso dopo l'importazione appartengono agli incrementi B e C. Finché B non
è completo, il beneficio di ADR-0028 non è osservabile.

## Esito

**Superato localmente: il descrittore può dichiarare le proprie fonti e l'identità dei descrittori
già persistiti è dimostrata invariata.**
