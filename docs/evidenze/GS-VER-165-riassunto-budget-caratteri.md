<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-165 — Budget del riassunto estrattivo in caratteri

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-165 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.1.0 |
| Stato | Superato in CI `xcode-27` sulla head della PR #31; CI su `main` attesa |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-07 |
| Approvazione | GS-DOR-013 (1.4.0); richiesta dell'iniziatore di proseguire lo sviluppo |
| Riferimenti | GS-DOR-013; GS-MET-001-19 § Budget implementato: `Budget-characters-v1`; RF-042; TV-036; CMP-164; GS-VER-146; GS-VER-151; GS-VER-164 |

## Ambito

Quinta slice di RF-042 sullo stesso Artifact `corpus-extractive-summary-v1`, fissata in
GS-MET-001-19 (versione 1.5.0):

- caso `characters` (`Budget-characters-v1`) di `GlifiSummaryBudgetUnit` in GlifiCore, con
  costo uguale agli scalari Unicode del testo sorgente esatto della frase;
- `GlifiSummaryCandidateSentence.characterCount`, calcolato dal motore sull'intervallo della
  frase; un intervallo non risolvibile fallisce con `summary.sentence-range-invalid`;
- `GlifiStudioSummaryBudget` in GlifiKit accetta l'identificatore senza nuovi tipi;
- `--characters <n>` di `glifi summarize`, mutuamente esclusivo con `--sentences` e `--tokens`;
- nessun nuovo campo nel payload e nessuna migrazione.

## Procedura e risultato atteso

1. `characterBudgetMatchesPython`: sui documenti dell'oracolo, con le lunghezze dei testi
   `TEXTS` di `Tests/Oracles/Python/summary.py` (17, 2, 16, 15, 5) e budget di 40 caratteri,
   ogni metodo seleziona le frasi `0 2 4` con 38 caratteri consumati (righe `*_SELECTED_C40`);
   punteggi e rank coincidono con il budget in frasi; con `MMR-v1`, `λ = 0,5` e rilevanza
   `CentroidCosine-v1` l'ordine di accettazione è `0 3 4` con 37 caratteri
   (`MMR_ORDER_C40_L05`);
2. `characterBudgetBounds`: la frase prima nel rank più lunga dell'intero budget è saltata e
   la successiva è scelta; una frase senza token che rientra nel budget resta non eleggibile;
   budget più piccolo di ogni frase eleggibile: selezione vuota; limiti 0 e 10 001 rifiutati,
   10 000 accettato;
3. `characterBudgetCountsSourceScalars`: dal testo importato con accenti decomposti, il costo
   di ogni frase è il numero di scalari Unicode del testo risolto, maggiore del numero di
   grafemi; budget pari alla somma: stessa selezione del budget in frasi; un carattere in meno:
   almeno una frase esclusa e `consumedBudget` uguale alla somma degli scalari scelti; Artifact
   distinto dal budget in frasi e rilettura con `storedDerivedResult`;
4. contract test CLI in `verify.sh`: `glifi summarize --characters 60`: unità e limite
   dichiarati, punteggi e rank uguali al budget in frasi, `consumedBudget` uguale alla somma
   dei code point dei testi scelti e non superiore a 60, Artifact distinto.

## Esecuzione locale

Sulla macchina di sviluppo Linux sono superati `make quality-static`, il lint `swift format`
dei file modificati, `git diff --check` e l'oracolo Python, confrontato con `expected.txt`.
GlifiCore non è compilato in locale: compilazione, test Swift, contract test CLI e gate
`make verify` sono affidati al workflow `Verifica` sul runner `xcode-27`.

## Esecuzione remota

Sulla head `3c3cfef` della [PR #31](https://github.com/gipidevdor/GlifiStudio/pull/31) i quattro
controlli CI `xcode-27` (`static-quality`, `format-check`,
[`verify`](https://github.com/gipidevdor/GlifiStudio/actions/runs/42352882717/job/128344655540),
[`app-store-baseline`](https://github.com/gipidevdor/GlifiStudio/actions/runs/42352882791/job/128344593322))
sono superati. Nel log `verify` risultano superati i tre test `Budget-characters-v1` delle
procedure 1–3 all'interno di 299 test Core, seguiti dai contract test CLI di `verify.sh`
(procedura 4). Rscript e veraPDF sono assenti sul runner: oracoli R e validazione PDF/A
risultano saltati, senza effetto sulle righe `*_C40` dell'oracolo Python, confrontate in locale.

## Limiti

- Il costo conta scalari Unicode, non grafemi né larghezza visiva: un emoji composto o un
  accento decomposto valgono più di un carattere percepito.
- Il budget conta il testo esatto dell'intervallo, inclusi gli eventuali spazi o segni che il
  segmentatore assegna alla frase.
- Nessuna valutazione ROUGE o umana; oracolo Python indipendente, non pacchetto terzo.
- CMP-164 resta `implemented` fino alla CI su `main` dopo l'integrazione.
