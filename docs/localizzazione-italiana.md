# Baseline linguistica italiana

| Campo | Valore |
| --- | --- |
| Identificatore | GS-I18N-001 |
| Tipo | Specifica della configurazione linguistica analitica |
| Versione | 0.5.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Decisione | [ADR-0004](adr/0004-italiano-lingua-iniziale.md) |

## Ambito

La baseline analitica iniziale di Glifi Studio è calibrata per la lingua italiana. Questo documento governa la lingua del contenuto analizzato; l'internazionalizzazione dell'interfaccia è disciplinata separatamente da [GS-I18N-002](internazionalizzazione-interfaccia.md).

| Aspetto | Valore iniziale | Identificatore |
| --- | --- | --- |
| Locale predefinito | Italiano, Italia | `it_IT` |
| Lingua predefinita dell'analisi | Italiano | `it` |

## Regole dell'analisi linguistica

- L'italiano è la lingua predefinita quando un progetto non specifica una lingua.
- Tokenizzazione, normalizzazione e segmentazione **NON DEVONO** assumere che ogni testo sia italiano.
- Lingua e versione del backend linguistico **DEVONO** essere registrate negli artefatti derivati.
- Il riconoscimento automatico della lingua, quando introdotto, **NON DEVE** sovrascrivere una scelta esplicita dell'utente.
- Qualità, corpora di riferimento e soglie per token, frasi, lemmi, parti del
  discorso, feature morfologiche ed entità seguono
  [GS-MET-001-18](metodi-analitici/18-valutazione-servizi-linguistici.md) e restano
  da approvare tramite DA-008.
- Segmentazione, SurfaceToken, apostrofi, clitici, trattini, abbreviazioni,
  normalizzazione e corpus gold applicano il contratto operativo
  [GS-LNG-001](specifiche-di-design/03-contratto-linguistico-italiano.md).

## Estensione futura

Nuove lingue analitiche devono usare contratti sostituibili di GlifiCore e fixture specifiche, senza modificare il significato dei risultati già prodotti in italiano.

## Verifica

La baseline richiede un test del default `it`/`it_IT` e, quando saranno disponibili
le prime funzioni linguistiche, corpus gold italiani versionati con precision,
recall, F1, accuracy e metriche specifiche del compito. La sola presenza di Natural
Language non costituisce una verifica.

## Esperienza iniziale in italiano

La tassonomia concettuale resta indipendente dalla lingua, ma microcopy, domande,
findings, caveat, solidità e messaggi di dati insufficienti vengono progettati
inizialmente in italiano secondo [GS-UX-001-14](esperienza-utente/14-vocabolario-e-localizzazione-semantica.md).
La validazione deve verificare comprensione scientifica e non soltanto correttezza
grammaticale. “Confidenza” non viene usato come termine ombrello per confidence OCR,
probabilità, intervallo statistico e solidità.
