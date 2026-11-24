<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-315 — Cleanup della validazione PDF/A

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-315 |
| Tipo | Verifica correttiva |
| Versione | 1.0.0 |
| Stato | Superato localmente su macOS |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di iterazione |
| Riferimenti | GS-DOR-315; CMP-315 |

## Difetto e correzione

La creazione dell'output temporaneo precedeva il try/finally, così un errore
nell'export lasciava la directory sul disco. L'export entra ora nel medesimo
ambito di cleanup della validazione. Nessuna directory esplicita viene acquisita
come risorsa posseduta e nessuna eccezione viene trasformata in successo.

## Prove mirate

Probe e RED sulla cattura iniziale: directory ancora presente dopo export
fallito; nove definizioni, due failure attese (CalledProcessError e
KeyboardInterrupt). Identici test con il fix: nove definizioni, quattordici
invocazioni controllate di main, exit 0. La stessa istanza d'eccezione viene
propagata; output propri rimossi dopo successo/failure, cartella e file utente
conservati. Le sei regressioni del controllo PASS introdotte dal 312 restano
verdi. Nessun Java o Swift viene avviato da queste fixture di ownership.

`pdfa-red-green.json` nel dossier locale `macOS-2026-11-24-audit-315` registra
hash di baseline, candidato e identici test. Il gate integrato è registrato nella chiusura seguente; nessuna verifica
manuale o iPadOS è attestata.

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
