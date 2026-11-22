# Gate di submission App Store

| Campo | Valore |
| --- | --- |
| Identificatore | GS-AS-010 |
| Tipo | Checklist di autorizzazione al rilascio |
| Versione | 1.3.0 |
| Stato | Attivo |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Regola di decisione

La submission è autorizzata soltanto quando tutti i gate sono verdi e le evidenze
si riferiscono alla stessa build. Un controllo locale verde non garantisce
l'approvazione Apple; un solo elemento non verificato impedisce l'invio.

| Gate | Criterio di uscita | Stato iniziale |
| --- | --- | --- |
| Prodotto | GS-PROD-001 approvato; percorso Must completo; nessuna capacità post-MVP esposta stabile | Bloccato |
| Codice | test, analisi, build Release e archivi verdi | Parziale |
| Qualità | dispositivi, accessibilità, prestazioni, energia, install/upgrade | Bloccato |
| Esperienza | flussi GS-UX completi; comprensione, lineage, dati insufficienti e adattamento validati | Bloccato |
| Scientifico | metodi `Must` versionati e ValidationManifest GS-VAL V0–V4, determinismo, descriptor e lineage approvati | Bloccato |
| Sicurezza/privacy | inventory, manifest, label e policy coerenti | Parziale |
| Identità | nome, bundle, team, profili, versione/build registrati | Bloccato |
| Pagina prodotto | metadati e screenshot reali approvati | Bloccato |
| Supporto | URL privacy/supporto pubblici e presidiati | Bloccato |
| Review | contatti, note e accesso dimostrativo verificati | Bloccato |
| TestFlight | cicli interno ed esterno conclusi | Bloccato |
| Unlisted | submission effettuata e richiesta approvata | Bloccato |

## Automazione

`make check-app-store` verifica la baseline configurabile oggi.
`make verify-app-store` aggiunge analisi e packaging senza firma.
`make app-store-submission-check` legge lo stato operativo e fallisce finché ogni
condizione di rilascio non è vera. Lo stato non deve essere modificato per ottenere
un risultato verde senza l'evidenza corrispondente.
