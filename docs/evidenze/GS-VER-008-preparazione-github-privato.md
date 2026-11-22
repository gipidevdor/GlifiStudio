# GS-VER-008 — Preparazione del repository GitHub privato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-008 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non applicabile; risultato osservato |
| Data esecuzione | 2026-09-15 |
| Esecutore | Codex nell'ambiente locale del progetto |
| Revisione | Working tree precedente al primo commit |

## Obiettivo

Verificare che la preparazione specifica per GitHub sia completa, internamente coerente, priva di effetti remoti impliciti e integrata nel quality gate di prodotto.

## Ambito

Sono stati verificati configurazione dichiarativa, catalogo etichette, issue form, pull request, profili ruleset `solo` e `team`, template CODEOWNERS, policy Actions, bootstrap in anteprima, audit remoto, documentazione e integrazione con Xcode 27.

## Procedura

```sh
zsh -n Scripts/github/configure-repository.sh Scripts/github/create-codeowners.sh
./Scripts/github/configure-repository.sh gpicchiarelli/GlifiStudio solo
./Scripts/check-github-config.py
./Scripts/verify.sh
```

La modalità senza `--apply` ha prodotto soltanto il piano e non ha creato o modificato repository remoti.

## Risultato osservato

- GitHub CLI 2.100.0 e autenticazione GitHub disponibili;
- repository `gpicchiarelli/GlifiStudio` e `gpicchiarelli/glifi-studio` non esistenti al momento del controllo;
- 19 etichette univoche e valide;
- ruleset `solo` e `team` coerenti e riferite allo stesso controllo `verify`;
- issue form collegate esclusivamente a etichette catalogate;
- configurazione Actions con token read-only, sole azioni GitHub selezionate e SHA pinning richiesto;
- 162 file versionabili conformi e nessun segreto ad alta confidenza rilevato;
- 92 file Markdown e 91 identificatori univoci prima dell'aggiunta di questa evidenza;
- test Swift, smoke test CLI e build Debug/Release macOS e iPadOS superati;
- processo `Scripts/verify.sh` terminato con codice `0`.

## Esito

**Superato localmente.** La baseline è pronta per primo commit, creazione esplicita del repository GitHub privato, primo push, applicazione del profilo scelto e audit remoto.

## Limiti

Non esistendo il remote, non sono state verificate visibilità, ruleset effettive, minuti Actions, funzioni Advanced Security, backup o proprietà del codice. Queste evidenze devono essere prodotte dopo la creazione autorizzata del repository.
