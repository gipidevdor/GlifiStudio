<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-316 — Oracoli per valori molto piccoli

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-316 |
| Tipo | Verifica correttiva numerica |
| Versione | 1.0.0 |
| Stato | Superato localmente su macOS |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di iterazione |
| Riferimenti | GS-DOR-316; CMP-316; GS-VER-312 |

## Contratto del confronto

Il comparatore finito usa errore relativo puro, con uguaglianza gestita prima
della divisione: anche minimi subnormali distinti restano distinguibili da zero
e fra loro. Il floor storico 1e-15 resta soltanto nelle sei posizioni indicate
da GS-DOR-316; nessuna tolleranza aumenta. Il linkage lessicale controlla anche
i tiny significativi ed esenta i soli sei residui sotto la vecchia soglia
1e-9. Sopra soglia non introduce esenzioni. NaN/infinito e mismatch esadecimali
restano rifiutati.

## Prove mirate

Sulla cattura iniziale del lotto, il floor generale accetta sette sostituzioni
con zero e quattordici corruzioni relative di 1e-7; il linkage accetta gli stessi
tiny anche disponendo del solo letterale zero. RED: tredici definizioni,
79 failure attese, nessun errore di fixture. GREEN sugli identici test:
tredici definizioni, exit 0. Sono verificati subnormali, estremi finiti,
selettività delle sei eccezioni, vecchia soglia e stato del comando principale.

Il controllo reale require passa 244 righe e 64 casi Fraction. I 36 riferimenti selezionati (expected, script R/Python e test Swift NB/SOM/JS)
restano invariati; la suite
export Swift modificata dal lotto 317 è registrata come contributo concorrente,
senza dichiarare immutabile l'intero pool dei letterali. Il gate ha fotografato
il pool composito finale. Il messaggio delimita la prova alla presenza lessicale,
non all'effettivo uso di ogni valore in un assert.

Il dossier locale `macOS-2026-11-24-audit-315` conserva spike, RED/GREEN, hash
e attestazione dei riferimenti. Il gate integrato macOS è registrato nella chiusura seguente.

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
