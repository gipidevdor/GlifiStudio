# GS-VER-007 — Baseline del repository privato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-007 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non applicabile; risultato osservato |
| Data esecuzione | 2026-09-15 |
| Esecutore | Codex nell'ambiente locale del progetto |
| Revisione | Working tree precedente al primo commit |

## Obiettivo

Verificare che la struttura Git privata, le policy, i controlli, la CI e la documentazione del repository siano coerenti e non interrompano la baseline Xcode eseguibile.

## Ambiente

- macOS su Apple silicon;
- Xcode 27.0;
- Swift 6.4;
- repository Git locale su branch `main`, privo di commit e remote;
- target macOS 27 e iPadOS 27.

## Procedura

È stato eseguito dalla radice:

```sh
./Scripts/verify.sh
```

Il gate ha incluso struttura del repository, pattern di segreti, toolchain, naming, documentazione, architettura, localizzazione, baseline Apple, formato Swift, test package, smoke test CLI e build Xcode Debug/Release delle due piattaforme senza firma.

La sintassi dei file YAML è stata inoltre analizzata separatamente e il riferimento `actions/checkout` è stato confrontato con il tag remoto ufficiale `v5` prima di essere fissato al relativo SHA completo.

## Risultato osservato

- 150 file versionabili controllati dalla policy strutturale;
- nessuna credenziale ad alta confidenza o materiale di firma rilevato;
- 89 file Markdown e 88 identificatori documentali univoci prima dell'aggiunta di questa evidenza;
- test Swift superati: tre test con Swift Testing;
- smoke test `GlifiCLI` superato;
- build macOS Debug e Release superate;
- build iPadOS Debug e Release per simulatore superate;
- processo terminato con codice `0`.

## Esito

**Superato.** La baseline locale è pronta per il primo commit e per la successiva creazione di un remote privato. CI, ruleset, accessi, backup e funzioni di sicurezza server-side restano da verificare dopo la creazione del remote.

## Limiti

Il controllo dei segreti è intenzionalmente ad alta confidenza e non sostituisce secret scanning della storia e push protection. Le build non sono firmate. Non sono stati verificati minuti, piano, protezioni o disponibilità effettiva del runner sull'account GitHub futuro.
