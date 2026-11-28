<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-343 — Dataset e lavoro di ricerca persistenti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-343 |
| Tipo | Evidenza di integrazione Core, Kit, CLI e GUI macOS |
| Versione | 1.1.0 |
| Stato | Superato nel profilo automatico macOS; audit manuali distinti |
| Responsabile | Codex, coordinamento della copia condivisa |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta sui quattro divari KH, escluso il multilingua; commit, push e integrazione su main |
| Riferimenti | ADR-0047; GS-API-004; GS-API-005; GS-API-006; GS-UX-001-17; CMP-343 |

## Funzionalità utilizzabili

I motori statistici e KH, lemma/POS, stemming italiano e stopword erano già
presenti. L’incremento completa i collegamenti applicativi e la persistenza,
senza duplicare gli algoritmi o introdurre altre lingue di analisi.

- CSV/XLSX: anteprima, mapping, tipi, encoding e policy esplicite; originale,
  fonti derivate, issue e coordinate delle celle nello stesso commit.
- Variabili tipizzate e sottoinsiemi nominati persistenti; query e metadati
  combinabili. Azioni native per confronti fra gruppi, incroci codici/gruppi,
  classificazione e annotazioni temporali, senza ricopiare i valori.
- Preparazione italiana condivisa con stopword, inclusioni, esclusioni,
  composti, forma/lemma/stem e POS; digest semantico e runtime coerenti per
  ricerca, corpus e matrici. I risultati storici conservano le scelte effettive.
- Acquisizione esplicita dei sette laboratori avanzati: impostazioni e output
  congelati, ripristino nativo senza riesecuzione; assegnazioni documentali e
  tagli HAC riutilizzabili come variabili con provenienza. Collegamento
  descrittivo a indagine, planner e rapporto, con esportazione degli stessi byte.
- Parità `research-call`, compresi `tablePath` e `statePath` per DTO sopra
  1 MiB. Envelope invariato; file regolari e stabili, budget, JSON rigoroso,
  esclusività degli alias, cancellazione ed errori tipizzati.

La GUI mantiene Form, tabelle, SF Symbols, colori semantici e navigazione nativi
esistenti. Gli archivi non sono autosalvataggi di ogni esecuzione.

## Snapshot e verifiche finali

Commit verificato: `4b30f9cb38671b2ebada38cb592a39b7a40bff72`.
Il [manifesto](allegati/GS-VER-343-inputs.json) fissa **1.020 input** versionati,
escludendo evidenze aggiornabili e appunti grezzi. Fingerprint SHA-256:
`245206c391bba588882f00a377df8ea0e594b3afecbed1830ab640253b214d3a`.
Tutti gli input sono rimasti identici fra verifica e packaging.

| Controllo | Esito finale |
| --- | --- |
| `make verify` macOS | Exit 0, 693,429 s; controlli statici, test e build Debug/Release, bundle validi |
| Swift Testing | Core 818, Kit 202, BDD 118 definizioni; nessuna failure |
| Cucumber completo | 17 feature, 795 scenari, 3.264 passaggi; 188 varianti e 6 workflow |
| API e CLI | 3.134 dichiarazioni revisionate; 158 operazioni e 316 confronti completi |
| Contratti testuali | 63 fixture condivise, 196 controlli CLI; ulteriori rifiuti di file, permessi, versioni, privacy e argomenti superati |
| Riferimenti numerici | 248 righe indipendenti riprodotte e 64 casi Fraction; nessuna promozione scientifica implicita |
| Recupero | 22 checkpoint con terminazione del processo e riapertura superati |
| App macOS | 176 definizioni, 488 esecuzioni; zero failure, skip o runtime warning del prodotto |
| PDF/A-2u integrativo | `check-pdfa.py --require`: i medesimi 2 PDF del gate conformi con veraPDF 1.30.4 già installato |
| Packaging macOS | Analisi statica e archivio senza firma superati in 533,271 s; risorse e identità del bundle verificate |

`make verify` non aveva `VERAPDF` nell’ambiente e ha segnalato lo skip del
rilevamento automatico. La successiva verifica **obbligatoria**, prima della
rimozione del temporaneo, ha validato gli stessi due PDF. Questo esito è
integrativo e non viene attribuito falsamente al passo saltato.

Il preflight è eseguito tramite i due componenti canonici di
`verify-app-store.sh`: `make verify` nel profilo macOS e
`Scripts/check-app-store-packaging.sh --macos-only`, sugli stessi input.
Le diagnostiche interne Xcode su IDELaunchSession e sul placeholder Any Mac
sono conservate nel log; non hanno prodotto failure o runtime warning dei test.

Il [riepilogo strutturato](allegati/GS-VER-343-verifica.json) conserva comandi,
conteggi, digest dei log ed esiti. Report Cucumber, PDF, xcresult completo e log
sanitizzati sono conservati localmente in
`~/Library/Caches/GlifiStudio/evidence/GS-VER-343/run-20261128-4b30f9c`.

## Regressioni e compatibilità

Gli ingressi grandi hanno un RED reale per entrambi i parametri sconosciuti;
il GREEN verifica API native, CLI reale, contenuto completo e riapertura.
La suite completa ha inoltre rilevato la cancellazione di una lettura preparata
con `lastCommittedGeneration` anziché `unchanged`: riprodotta in BDD e corretta
normalizzando le sole cancellazioni, senza anticipare le validazioni o cambiare
le attese del test preesistente. I test cache coprono successo e fallimento
senza fabbricare report scientifici positivi.

Il lettore minimo diventa 3 soltanto al primo salvataggio di dati di ricerca.
Progetti ordinari e ricchi precedenti mantengono i requisiti 1/2 e sono aperti
senza migrazione distruttiva. Manifest e SQLite non cambiano schema; commit
append-only e recupero generazionale rimangono quelli del package esistente.
I lettori precedenti rifiutano i progetti che richiedono 3. Il rollback del
codice non rende un vecchio lettore capace di interpretare i nuovi Artifact.

## Limiti e controlli non attestati

Excel è il profilo XLSX documentato in GS-API-004: XLS binario, formule, macro,
celle unite e collegamenti esterni sono rifiutati. Default: 16 MiB e 10.000 righe.
I filtri combinano query, sottoinsieme statico e una uguaglianza tipizzata;
non comprendono un editor booleano completo sui metadati. Lemma/POS richiedono
le capacità Apple disponibili, senza download o fallback silenzioso.

CUA ha verificato importazione, MDS, salvataggio e ripristino sullo snapshot
intermedio. Non è un audit completo finale di VoiceOver, Voice Control,
tastiera, contrasto, testo grande, pseudo-lingua o RTL. iPadOS, firma,
submission e CI remota non sono eseguiti da questi comandi. I gate G4/G5 e gli
stati scientifici dei metodi conservano le proprie evidenze e non sono promossi.

## Pulizia

Rimossi 3.762.732 KiB di cache gestita della sessione (circa 3,59 GiB secondo
`du`), due marker `.build` e i temporanei del generatore. Le evidenze utili sono
state copiate prima della rimozione. Un worktree duplicato pulito da 25.148 KiB
è stato rimosso dopo confronto degli alberi; l’altra copia è conservata.
Cache preesistenti, dipendenze, toolchain attive, file utente e modifiche uniche
negli altri worktree restano preservati. Le dimensioni sparse apparenti non
vengono dichiarate come spazio recuperato.

## Identità nel registro condiviso

L’identificativo iniziale GS-VER-336 è stato riallineato a GS-VER-343 per
preservare le evidenze create in parallelo e già presenti su main. I comandi e
gli esiti storici restano riferiti ai rispettivi snapshot.
