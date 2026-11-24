<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-317 — Cancellazione dell'export scientifico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-317 |
| Tipo | Verifica correttiva del lifecycle |
| Versione | 1.0.0 |
| Stato | Superato localmente su macOS |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di iterazione |
| Riferimenti | GS-DOR-317; CMP-317 |

## Difetto e confine di commit

Il renderer/exporter non osservava il task dopo il controllo iniziale Engine.
La chiusura macOS poteva cancellare e attendere l'operazione mentre questa
pubblicava ancora l'export. Il candidato controlla ingresso, formati, payload,
metadati e letture bounded; l'ultimo check precede immediatamente il rename.
CancellationError preservato rimuove il solo staging. Dopo il rename non
esiste un nuovo check: successo e receipt restano validi.

L'osservatore interno Sendable non throwing usa i checkpoint di interruzione
preesistenti; non è un nuovo contratto pubblico. Il fault I/O postcommit resta
distinto dal flag cancellato e conserva lastCommittedGeneration normalizzato
dalla tassonomia storica. All'admission Kit già cancellata resta il suo stato
lastCommittedGeneration; la cancellazione che raggiunge l'exporter è mappata
da Engine e preservata da Kit come cancelled/export/unchanged.

## Prove mirate

RED sul vero exporter con task già cancellato: una definizione fallisce con
due issue, successo inatteso e destinazione pubblicata; source invariato e
file utente/progetto conservati. Il primo candidato passa i controlli di
cancellazione ma ha una singola aspettativa aggiuntiva errata sul fault
postcommit: il report è conservato separatamente e il runtime non viene
modificato per far passare il test. L'aspettativa viene riallineata alla
tassonomia storica verificata nella baseline.

GREEN finale: 18 definizioni / 46 esecuzioni, zero errori. Quattro definizioni
nuove coprono tredici casi: pre-cancel e destinazione preesistente, quattro
checkpoint con/senza cancellazione, read/verify già cancellati e fault storico.
I confronti verificano output e receipt identici fra default e osservatore
senza cancellazione per JSON/Markdown/CSV; non sono una prova binaria
prepatch/postpatch e non includono l'identità binaria dei PDF di sistema.
Restano verdi le regressioni PDF/CSV/recovery e letture sicure preesistenti.

Source pre/post e hash dei log sono nel dossier `macOS-2026-11-24-audit-315`.
Review indipendente: nessun blocker. Il gate integrato macOS è registrato nella chiusura seguente;
nessun controllo GUI manuale o iPadOS viene attestato.

## Chiusura della composizione macOS

Il gate `make verify` macOS termina con **exit 0** in **513,990 s** sulla
composizione di **1291 file**, base `741da2e`, fingerprint
`919d1366731d548ca3446f766ac9dcb547fed0d3f32d8dc697da2b26e9951c9c`.
Passano 740 test Core, 161 Kit, 133 definizioni native / 420 esecuzioni Debug,
senza failure, skip o runtimeWarnings nel report nativo. La build Release
è riuscita; non si dichiara una nuova esecuzione test Release o un archivio.

Passano 244 righe di oracoli e 64 casi Fraction, 2 PDF/A reali,
196 controlli CLI testuali, 132 operazioni / 264 confronti Kit-CLI,
inventario di 2840 dichiarazioni pubbliche e 22 checkpoint recovery.
Contenuti e modi dei 1291 file coincidono con il manifest alla fine del gate;
archivio sorgente verificato, HEAD e indice invariati. Il lotto preserva
i WIP 312–314; le sole evidenze e metadati vengono chiusi dopo il gate, con
confronto separato degli altri file.

Il [rapporto strutturato](allegati/GS-VER-315-317-verifica.json) riporta
conteggi, hash, riferimenti e limiti. Il dossier locale
`macOS-2026-11-24-audit-315` conserva cattura iniziale, fonte verificata, log,
JSON sanificati e review. La diagnostica IDELaunchSession di Xcode è distinta
dai runtimeWarnings del report (zero). Restano esclusi CI remota di questo
lotto, iPadOS e audit GUI/assistivi manuali.
