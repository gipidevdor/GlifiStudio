# Identità e convenzioni di denominazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ID-001 |
| Tipo | Specifica dell'identità di progetto |
| Versione | 1.1.0 |
| Stato | Attivo |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |

## Scopo

Questo documento definisce il nome canonico del prodotto e la sua traduzione in identificatori tecnici. La decisione e il relativo rationale sono registrati in [ADR-0007](adr/0007-denominazione-glifi-studio.md).

## Nome canonico

Il marchio e nome visibile **DEVE** essere scritto **Glifi Studio**, con spazio e iniziali maiuscole. Il nome è invariabile nelle localizzazioni iniziali italiana e inglese; eventuali adattamenti futuri richiedono una decisione esplicita.

## Nomi tecnici

| Ambito | Nome canonico |
| --- | --- |
| Workspace e progetto Xcode | `GlifiStudio` |
| Target applicativi | `GlifiStudio-macOS`, `GlifiStudio-iPadOS` |
| Tipi applicativi | `GlifiStudioMacApp`, `GlifiStudioPadApp` |
| Package e motore | `GlifiCore` |
| API applicativa | `GlifiKit` |
| Eseguibile headless | `GlifiCLI` |
| Bundle identifier multipiattaforma candidato | `studio.glifi.GlifiStudio` |
| Prefisso degli information item | `GS-` |

I nomi tecnici **DEVONO** usare caratteri ASCII, non contenere spazi e seguire UpperCamelCase quando il formato lo consente. Il prefisso documentale `GS-` rimane stabile e identifica Glifi Studio.

## Interfaccia e localizzazione

Il nome visibile **DEVE** provenire dalla chiave semantica `app.name` del catalogo di stringhe. Il nome tecnico **NON DEVE** essere mostrato come sostituto del marchio nell'interfaccia. Bundle, moduli, schemi e percorsi possono usare il nome tecnico e non devono essere tradotti.

## Provenienza e compatibilità

I file `appunti-1.txt` e `appunti 2.txt` sono fonti grezze immutabili e conservano la denominazione originaria per garantire la provenienza. Tutti gli artefatti controllati, il codice e le configurazioni **DEVONO** usare la denominazione corrente.

Il bundle identifier è una baseline tecnica candidata per un'unica scheda App Store
macOS/iPadOS: la verifica legale del nome, la registrazione presso Apple e
l'assegnazione del team restano tracciate in DA-014 e DA-018.
