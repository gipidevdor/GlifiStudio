<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0044 — Importazione nativa di PDF ed EPUB

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0044 |
| Tipo | Decisione di acquisizione e provenienza |
| Versione | 1.0.2 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di includere EPUB e PDF con preferenza per componenti Apple |
| Riferimenti | RF-004; RF-005; RF-006; GS-DOR-310; GS-DAT-001; GS-API-001; GS-SEC-001 |

## Decisione

Il nuovo incremento post-0.1 aggiunge importazione PDF ed EPUB al percorso
applicativo, GlifiKit e CLI, mantenendo invariata la baseline storica 0.1.
PDFKit fornisce pagine e testo incorporato; Vision esegue OCR soltanto quando
necessario. L'estrazione mantiene pagina, metodo e backend, con budget prima
della rasterizzazione. Il testo estratto da framework di sistema non è
dichiarato bit-identico fra revisioni del sistema operativo.

Per EPUB non esiste nell'SDK verificato un reader pubblico equivalente a
PDFKit. Si usano Foundation XMLParser e zlib di sistema: il contenitore ZIP,
manifest e ordine di lettura restano responsabilità esplicita dell'importatore.
AppleArchive non viene usato come lettore ZIP. L'importazione del testo non
carica WebKit, non esegue script e non accede a rete o risorse esterne.

L'originale incorporato resta immutabile. Uno snapshot canonico di testo,
coordinate pagina/risorsa e backend è un Artifact di estrazione, pubblicato
atomicamente con la fonte usando le generazioni esistenti. La riapertura legge
lo snapshot verificato e non invoca nuovamente i framework. Non occorre una
riestrazione delle fonti storiche. Le prove hanno rilevato il vincolo SQL4 sui
soli formati testuali: al primo import PDF/EPUB una migrazione transazionale
SQL5 ricostruisce source_entries con i quattro formati e project_metadata con
la nuova versione, preservando tutte le righe, generazioni, identità e digest.
Apertura e import TXT/Markdown mantengono SQL4 nei progetti mai sottoposti a
importazione ricca. Il formato del package e gli schemi manifest 3/4 restano invariati;
minimumReaderVersion diventa 2 soltanto con fonti ricche, mentre il nuovo reader
accetta anche i progetti precedenti. Interruzioni prima del commit possono
lasciare lo store già aggiornato, come una generazione preparata: il nuovo reader
verifica e recupera la generazione indicata dal manifest, senza alterarne i dati.

Le coordinate di query per questi documenti sono UTF-8 del testo acquisito;
i locatori pagina/capitolo le collegano al documento originale. Non si
rappresenta un byte del contenitore compresso come carattere dell'originale.
L'identità della revisione e il digest dello snapshot impediscono sostituzioni
silenziose delle rappresentazioni acquisite.

## Conseguenze e verifica

File non supportati, cifrati, strutturalmente incoerenti o oltre budget sono
rifiutati con failure tipizzata. Limiti cumulativi proteggono ZIP, XML e OCR;
nessuna promessa di supporto DRM, identità visiva o ordine perfetto su ogni
layout PDF complesso. Parser e OCR restano fuori Main Actor; test sintetici,
prove avversarie, persistenza atomica e parità dei client precedono la consegna.
L'isolamento fuori processo e gli audit reali G4 restano decisioni separate.
