# 8. Gestione della configurazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-08 |
| Tipo | Capitolo normativo |
| Versione | 1.0.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 8.1 Repository

Il progetto **DEVE** usare Git e mantenere codice, configurazioni riproducibili, documentazione controllata, test e script necessari alla verifica nello stesso repository quando condividono il ciclo di cambiamento.

Il repository resta privato finché il titolare non autorizza un cambio di visibilità mediante il gate [GS-REP-008](../repository/08-passaggio-a-pubblico.md). La licenza open source del contenuto autorizzato **NON DEVE** essere interpretata come autorizzazione a pubblicare repository, storia o materiale di terzi.

File temporanei, credenziali, materiale di firma, dati personali, corpora riservati e artefatti ricostruibili di grandi dimensioni **NON DEVONO** essere aggiunti. Una eccezione di storage richiede proprietario, provenienza, licenza, limiti e ADR o deroga applicabile.

## 8.2 Branch e integrazione

- `main` **DEVE** rappresentare la baseline integrata e rimanere costruibile e verificabile.
- Dopo il bootstrap remoto, ogni modifica **DEVE** passare tramite pull request e branch breve.
- L'integrazione **DEVE** richiedere i quality gate applicabili e risoluzione delle osservazioni bloccanti.
- Force push e cancellazione di `main` **NON DEVONO** essere consentiti.
- Un bypass **DEVE** essere limitato, motivato, auditabile e seguito da revisione.
- I conflitti **DEVONO** essere risolti preservando modifiche preesistenti non pertinenti.

## 8.3 Commit e storia

I commit **DOVREBBERO** essere atomici, descrivere il risultato e mantenere distinguibili modifiche funzionali, riformattazioni e file generati. I messaggi **DOVREBBERO** seguire la convenzione definita in [CONTRIBUTING.md](../../CONTRIBUTING.md).

Riscritture distruttive della storia condivisa **NON DEVONO** essere eseguite senza autorizzazione, piano di coordinamento e conservazione delle evidenze necessarie. Rimuovere un segreto dalla storia **NON DEVE** sostituirne revoca o rotazione.

## 8.4 Elementi di configurazione

Sono elementi controllati almeno:

- requisiti, standard, ADR, rischi e deroghe;
- sorgenti, test, fixture e benchmark;
- workspace, progetto, schemi, entitlement e configurazioni di build;
- formatter, script, modelli di collaborazione e CI;
- schemi e specifiche dei formati;
- dataset e risultati di riferimento autorizzati e identificati;
- manifesti, lockfile, inventari e licenze delle dipendenze;
- artefatti, simboli, note, firme e attestazioni di rilascio.

Ogni elemento generato **DEVE** dichiarare fonte e procedura di rigenerazione. `Package.resolved`, quando prodotto dalla risoluzione dell'applicazione, **DEVE** essere versionato.

## 8.5 Denominazione e portabilità

Il nome visibile e gli identificatori tecnici **DEVONO** rispettare [GS-ID-001](../identita-del-progetto.md). Ogni rinomina **DEVE** aggiornare nello stesso cambiamento codice, configurazioni, test, script, documentazione e integrazioni applicabili, preservando soltanto i record di provenienza dichiarati immutabili.

I percorsi versionati **NON DEVONO** differire soltanto per maiuscole e minuscole. Symlink esterni, path non portabili e file che superano la soglia del repository **DEVONO** essere rifiutati o autorizzati esplicitamente.

## 8.6 Backup e recupero

Il remote **NON DEVE** essere l'unica copia. Branch, tag, configurazioni server-side e record necessari al ripristino **DEVONO** essere sottoposti a backup cifrato e prova periodica secondo [GS-REP-007](../repository/07-backup-e-recupero.md).
