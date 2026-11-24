# ADR-0007 — Denominazione Glifi Studio

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0007 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Direzione di prodotto del 2026-09-15 |
| Sostituisce | Denominazione iniziale non formalizzata |

## Contesto

La denominazione iniziale era presente nel repository, nel progetto Xcode, nei moduli, nelle configurazioni e nei contenitori di lavoro. Il progetto richiede un'identità unica che distingua il nome mostrato alle persone dagli identificatori tecnici senza spazi.

## Decisione

Il prodotto assume il nome canonico **Glifi Studio**. Gli identificatori tecnici adottano la radice `GlifiStudio` e i componenti condivisi la radice `Glifi`, secondo [GS-ID-001](../identita-del-progetto.md).

La rinomina si applica a interfaccia, workspace, progetto e schemi Xcode, target, moduli Swift, bundle identifier, script, documentazione e contenitori di lavoro. Le fonti grezze originarie restano immutate come record di provenienza.

## Conseguenze

- il nome mostrato è separato dai nomi adatti a Swift, Xcode e filesystem;
- la coerenza della denominazione viene verificata automaticamente;
- riferimenti esterni futuri devono usare la nuova identità;
- la disponibilità legale del nome e il namespace bundle definitivo devono ancora essere confermati;
- eventuali dati o integrazioni esterne basati sulla denominazione precedente richiederanno una migrazione esplicita.

## Alternative considerate

- mantenere la denominazione precedente: respinto per decisione di prodotto;
- usare spazi anche in moduli e target: respinto perché incompatibile o poco robusto in diversi contesti tecnici;
- rinominare retroattivamente le fonti grezze: respinto perché ridurrebbe la tracciabilità della provenienza.

## Verifica

`Scripts/check-naming.py` impedisce la reintroduzione della denominazione precedente negli artefatti controllati e verifica i principali nomi visibili e tecnici. La build completa è registrata in GS-VER-005.
