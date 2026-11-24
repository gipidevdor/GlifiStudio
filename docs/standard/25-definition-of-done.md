# 25. Definition of Done

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-25 |
| Tipo | Capitolo normativo |
| Versione | 0.6.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-18 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

Una modifica è completa soltanto quando tutti i punti applicabili sono soddisfatti:

- criteri di accettazione verificati;
- requisiti e tracciabilità aggiornati;
- ADR creato o aggiornato quando necessario;
- codice formattato, compilato e revisionato;
- test pertinenti aggiunti e superati;
- errori, cancellazione, sicurezza e privacy valutati;
- benchmark eseguiti se cambia un hot path;
- migrazioni e compatibilità provate se cambiano dati persistenti;
- documentazione ed esempi aggiornati;
- nessun segreto o dato non autorizzato incluso;
- pull request compilata, revisioni bloccanti risolte e proprietà del codice rispettata;
- dipendenze e automazioni nuove motivate, inventariate e fissate in modo riproducibile;
- log e artefatti esaminati per dati sensibili;
- quality gate verdi o deroghe valide;
- evidenza di verifica archiviata;
- variante scientifica, descriptor, determinismo e casi degeneri specificati quando applicabili;
- reference test indipendente e invarianti matematiche superati per ogni metodo modificato;
- lineage e invalidazione del DAG verificati per ogni nuovo artefatto analitico;
- intenzione, oggetto, stato, errore e livello di disclosure specificati per ogni
  nuovo flusso utente;
- parità semantica, localizzazione, tastiera, VoiceOver, focus e dimensioni adattive
  verificate per ogni modifica dell'esperienza;
- finding, caveat, solidità e suggerimenti confrontati con evidenze e rule set;
- impatto su cronologia, ripristino e relazione valutato quando cambia il dominio.
- conformità alla specifica GS-DOM/DAT/LNG/QRY/ANA/RUN/UI/VIZ/VAL/PROD
  applicabile, senza estenderne implicitamente il contratto;
- ValidationManifest almeno V0–V4 per ogni capacità che entra nel percorso Must;
- kill/recovery, risorse bounded e diagnostica senza contenuto provati quando
  cambiano package, parser, query o operazioni lunghe.
- criteri di eccellenza [GS-STD-001-29](29-eccellenza-ingegneristica-apple.md)
  applicabili alle aree toccate soddisfatti con l'evidenza prevista, oppure
  dichiarati "Da introdurre" senza presentarli come verificati.

Una modifica non è completa se il solo modo di integrarla richiede bypass, credenziali personali, stato locale non versionato o un controllo disabilitato.
