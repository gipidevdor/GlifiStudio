<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-312 — Affidabilità dei verificatori automatici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-312 |
| Tipo | Verifica correttiva |
| Versione | 1.0.0 |
| Stato | Superato localmente su macOS |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di correzioni e ottimizzazioni trasversali |
| Riferimenti | GS-DOR-312; CMP-312; RQ-062; RQ-063 |

## Difetti e correzioni osservate

La baseline `741da2e` supera quality-static, ma il controllo PDF/A può attestare
conformità dopo un exit status 79 se riceve output PASS completo. Il candidato
richiede processo riuscito, un risultato per ogni PDF e nessun FAIL; un errore
produce diagnostica distinta, con al massimo 2000 caratteri per ciascuno stream.
La semantica dello strumento assente resta opzionale oppure bloccante con
`--require`.

Il comparatore degli oracoli può inoltre valutare infinito come vicino a un
valore finito. Il collegamento ai letterali può sollevare OverflowError su
infinito e ValueError su NaN. Il candidato rifiuta gli operandi non finiti prima
dell'aritmetica e del round, con diagnostica per chiave nel collegamento.

## Regressioni mirate

| Controllo | RED | GREEN |
| --- | --- | --- |
| PDF/A | Sei definizioni: tre failure attese, comprese exit 79 con PASS completo e diagnostica stderr | Stesse fixture: sei definizioni, nove invocazioni controllate di main, exit 0 |
| Oracoli | Quattro definizioni: dieci failure e tre errori sul verificatore Git di base, con copia isolata e identici test | Quattro definizioni, exit 0; NaN e ±infinito rifiutati, soglie finite e confronto esadecimale conservati |

I test PDF/A eseguono un vero processo sintetico senza Java o Swift. I test
degli oracoli non richiedono R. Entrambe le suite sono integrate in
quality-static e make verify; non modificano fixture, soglie o numerica del
prodotto. Il controllo reale `check-oracles.py --require` riproduce 244 righe;
l'oracolo Fraction riproduce 64 casi. La review indipendente della finitezza
non rileva blocker.

## Fonte, limiti e verifica integrata

Il dossier locale `macOS-2026-11-24-audit-312` conserva RED/GREEN, hash,
comandi, review e spike numerico. Le prove mirate precedono e non sostituiscono
il gate della composizione completa, registrato nella chiusura seguente.

Il floor assoluto storico 1e-15, il relativo 1e-12 e l'esclusione dal linkage
lessicale dei valori di magnitudine sotto 1e-9 restano invariati. Il controllo
generale non prova la protezione di tutte le quantità molto piccole: le loro
regressioni scientifiche dedicate restano necessarie. Lo spike relativo puro
passa le 244 righe locali, ma non giustifica da solo una nuova policy portabile
per i residui teoricamente nulli. Non sono attestati CI remota, iPadOS o audit
GUI/accessibilità manuali.

## Chiusura della composizione macOS

La composizione congelata ha base `741da2e` e **1284 file**, fingerprint
`345c5f70a0ce4133c1325476a92f08ce40815bdad272ca5d75dc432131474b0e`. Il gate
`make verify` macOS termina con **exit 0** in **515,177 s**: 736 test Core,
161 Kit e 133 definizioni native / 420 esecuzioni Debug, senza failure, skip
o runtimeWarnings nel report nativo; build Release riuscita. La sola suite
Statistics ripete 12 definizioni / 57 esecuzioni in Release, senza errori.

Verificati anche 244 righe di oracoli e 64 casi Fraction, 2 PDF/A reali,
196 controlli CLI testuali, 132 operazioni / 264 confronti Kit-CLI, inventario
pubblico di 2840 dichiarazioni, 172 varianti e 22 checkpoint di recovery.
Il bundle Release ha risorse e lookup it/en corretti, 15 voci ispezionate e
zero corrispondenze nell’ambito vietato dichiarato. Non è un nuovo archivio
App Store e non attesta Finder o restoration.

Tutti i 1284 contenuti e modi coincidono con il manifest alla fine del gate;
archivio sorgente verificato, HEAD e indice invariati. Le sole evidenze e i
metadati di tracciabilità vengono chiusi dopo la verifica, conservando il
manifest del gate e il confronto separato dei file non documentali.
Il [rapporto strutturato](allegati/GS-VER-312-314-verifica.json) conserva
misure, conteggi e limiti. Il dossier locale `macOS-2026-11-24-audit-312`
contiene manifest, archivio, log, JSON sanificati e review indipendenti.

La diagnostica IDELaunchSession DVTAssertions appartiene a Xcode; i report
dei test non contengono runtimeWarnings. Restano esclusi CI remota di questo
lotto, iPadOS, audit visuali/assistivi manuali e G4/G5.
