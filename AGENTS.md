<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Istruzioni operative per agenti software

Queste istruzioni valgono per l'intero repository.

## Ordine delle fonti

1. richiesta esplicita dell'utente;
2. standard e requisiti controllati in `docs/`;
3. ADR accettati;
4. codice e test esistenti;
5. appunti grezzi, soltanto come provenienza non normativa.

Non modificare `appunti-1.txt` o `appunti 2.txt` salvo richiesta esplicita: sono record di origine incompleti.

I documenti in `docs/standard/` sono il distillato normativo, le ADR in `docs/adr/` ne registrano la motivazione storica. Se un'ADR accettata è più recente e in conflitto con uno standard controllato, aggiornare lo standard nello stesso cambiamento invece di ignorare la ADR o lo standard non allineato.

## Vincoli di base

- Nome canonico: **Glifi Studio**; identificatori tecnici: `GlifiStudio` e `Glifi*`.
- Target iniziali: macOS 27 e iPadOS 27; Xcode 27 con Apple Swift 6.4 o
  successiva compatibile della serie 6; Swift 6 language mode e SwiftPM tools 6.4.
- Lingua iniziale: italiano per interfaccia e documenti controllati; ogni elemento dell'interfaccia deve restare internazionalizzabile e accessibile.
- Codice sorgente, identificatori, commenti e messaggi di commit in inglese, secondo le convenzioni Apple/Swift.
- Usare `GlifiStudio.xcworkspace`, non aprire il solo progetto per il lavoro ordinario.
- Conservare la separazione fra app, `GlifiKit`, motore `GlifiCore` e strumenti headless.
- Preferire API Apple native dopo verifica di disponibilità e adottare accelerazioni soltanto su evidenza di profiling o benchmark.
- Non introdurre dipendenze, entitlement, rete, telemetria, sincronizzazione, formati persistenti o backend alternativi senza requisiti e decisioni applicabili.

## Metodo di modifica

- Preservare modifiche preesistenti e non ampliare lo scopo senza necessità.
- Aggiornare nello stesso cambiamento codice, test, documentazione, tracciabilità e ADR pertinenti.
- Non inserire segreti, firma Apple, dati personali, corpus reali o materiale di terzi non autorizzato.
- Non indebolire un controllo per far passare una modifica; correggere la causa o registrare una deroga formale.
- Aggiungere SPDX `BSD-3-Clause` ai nuovi file testuali che supportano commenti.
- Mantenere i documenti controllati in italiano, con un argomento per documento e identificatore univoco.

## Eccellenza ingegneristica di classe Apple

La barra completa è `docs/standard/29-eccellenza-ingegneristica-apple.md` (GS-STD-001-29, ADR-0024). Per le aree toccate:

- preferire componenti, materiali, stili di testo, colori semantici e SF Symbols di sistema; non imitare l'aspetto della piattaforma con cromature personalizzate;
- ogni modifica di interfaccia considera VoiceOver, Voice Control, tastiera, testo di accessibilità, contrasto, pseudo-lingua e destra-sinistra;
- niente `default` negli `switch` su enum del progetto, niente force unwrap, errori di dominio tipizzati e fail-closed su ciò che può corrompere dati;
- misurare prima di ottimizzare (Instruments, metriche XCTest, benchmark) e non bloccare il Main Actor;
- i criteri "Da introdurre" non sono gate: non trasformarli in controlli finché non esistono codice conforme e verifica, e non dichiarare conforme un criterio privo dell'evidenza prevista.

## Verifica

Eseguire il controllo più mirato durante il lavoro e `make verify` prima della consegna. Se un controllo non è eseguibile, dichiarare esattamente cosa manca e non presentare come verificato ciò che non lo è.
