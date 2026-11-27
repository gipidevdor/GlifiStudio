<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Contesto coerente della fonte da codificare

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-329 |
| Tipo | Correzione della semantica di presentazione |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di perfezionamento del codice e della semantica |
| Riferimenti | RF-043; RQ-011; RQ-047; RQ-058; GS-APL-001; GS-UX-001-09; GS-UX-001-16; GS-VER-329 |

## Definition of Ready

`StudioHomeModel.loadCodingSource` pubblica i segmenti della nuova fonte prima
di leggere il numero di caratteri e prima di cambiare la revisione selezionata.
Una failure del secondo accesso lascia i segmenti B sotto l'identità A;
il passaggio precedentemente risolto viene già cancellato. Una failure più
tardiva, nel recupero dei testi delle codifiche B, conserva invece una
proiezione parziale con i testi A. La scelta deve produrre un contesto coerente
soltanto dopo tutte le letture necessarie.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Rendere atomica la pubblicazione di revisione, segmenti, limite dei caratteri, passaggio, stato qualitativo e testi delle codifiche; solo caricamento del contesto di codifica e relativi test del modello |
| provenienza | Identità e intervalli visibili appartengono alla stessa revisione; nessun segmento B viene mostrato come contenuto A |
| dominio/API | Sessione e DTO Kit esistenti, firme pubbliche e trasporto CLI invariati; nessun nuovo task owner, formato, dipendenza o flusso UI |
| failure semantics | Rifiuto busy, failure tipizzata o cancellazione conservano l'intero contesto precedente; non cancellare la selezione valida prima di un caricamento riuscito; retry usa la stessa azione |
| verifica | Ready e test prima del fix; runtime iniettato interrompe deterministicamente la seconda admission (caratteri) o la terza (testi delle codifiche), mediante pressione critica oppure cancellazione; due fonti e codifiche sintetiche distinte, stato precedente invariato e retry riuscito; busy sospeso tramite gate esistente |
| pubblicazione | Preparare tutte le letture in valori locali e pubblicare sul Main Actor senza await fra le assegnazioni; nessuna pubblicazione dopo cancellazione |
| piattaforme | Modello condiviso verificato nel target nativo macOS e workspace ordinario; nessuna attestazione iPadOS o audit grafico/assistivo manuale |
| dati e privacy | Nessun evento o dato del progetto modificato dal caricamento; fixture sintetiche, nessun contenuto/path nuovo in log o rete |
| prestazioni | Stesso insieme di letture bounded; nessuna ottimizzazione o misura prestazionale richiesta per una correzione di stato |
| tracciabilità | GS-VER-329 e gate integrato macOS registrati dal coordinatore; indici, matrice e changelog aggiornati nel medesimo lotto |

**Ready** prima di qualsiasi modifica produttiva. La prima consegna contiene
soltanto questa scheda e le regressioni; il coordinatore esegue il RED comune
e assegna successivamente l'intervento.
