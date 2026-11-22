<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Importazione PDF ed EPUB

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-310 |
| Tipo | Incremento di acquisizione documentale |
| Versione | 1.0.2 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di includere EPUB e PDF privilegiando le tecnologie Apple |
| Riferimenti | RF-004; RF-005; RF-006; RQ-044; RQ-058; RQ-060; ADR-0044; GS-VER-310 |

## Esito e confini

Importare PDF ed EPUB insieme a TXT e Markdown nel percorso app/Kit/CLI.
PDFKit legge testo e pagine; Vision riconosce le pagine prive di testo. EPUB
usa un lettore ZIP bounded con zlib dello SDK e Foundation XMLParser per
container, OPF e capitoli XHTML nell'ordine dichiarato. Nessun runtime o
pacchetto esterno, rete, WebKit headless o entitlement aggiuntivo.

L'originale binario resta incorporato e verificato per digest. Il testo
acquisito, i riferimenti a pagine/risorse e il backend sono salvati come snapshot
versionato nello stesso commit della fonte, usando gli Artifact esistenti.
La riapertura non ripete OCR o estrazione e non cambia coordinate o risultati.
I range UTF-8 descrivono la rappresentazione testuale; non sono offset nel PDF
binario o nel contenitore compresso. TXT/Markdown conservano il contratto attuale.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Importazione PDF digitale/scansionato ed EPUB testuale non cifrato; selezione file nativa e trasporto CLI corrispondente; nessun reader impaginato o nuovo formato di report |
| requisiti | RF-004/005/006 e nuovo requisito EPUB; formato e metodo ispezionabili, originale preservato, risultati interi e bounded |
| contratto di dominio/API | Estensione esplicita dei formati; snapshot di estrazione e coordinate pagina/capitolo; i client attraversano GlifiKit |
| failure semantics | Password/DRM o contenuti non supportati, XML/ZIP/PDF invalidi, limiti e cancellazione generano failure tipizzate senza testo/path; nessun commit parziale della fonte |
| esperienza prevista | Stesso comando importa; TXT/Markdown/PDF/EPUB ammessi dal selettore di sistema; provenienza distinta da coordinate binarie; etichette localizzabili |
| verifica | Fixture sintetiche, ZIP ostili e CRC, PDF multipagina/OCR, reopen senza riestrazione, query/salto alla fonte e parità CLI; gate make verify macOS prima della consegna |
| dati e migrazione | Originale e snapshot atomici negli oggetti e Artifact già previsti; SQL5 lazy e transazionale al primo import ricco conserva tutte le righe; payload storici invariati, minimumReaderVersion 2 per nuove fonti; rollback e fence del reader corrente verificati, rifiuto dei reader precedenti previsto dal contratto senza esecuzione di un binario storico |
| sicurezza/privacy | Nessuna esecuzione di script né accesso a risorse esterne; entità XML e path fuori contenitore rifiutati; limiti prima di decompressione e rasterizzazione |
| prestazioni/sistema | Estrazione fuori Main Actor; pagine/risorse elaborate progressivamente, un buffer OCR per volta, controlli di cancellazione e budget cumulativi |
| tracciabilità | GS-VER-310, ADR-0044, contratti di dati/importazione/API e matrice aggiornati nello stesso lotto; nessuna promozione G4/G5 |

## Criterio di uscita

Tutti i formati attraversano importazione, salvataggio, riapertura, fonte,
ricerca e analisi senza conversioni tacite o ricalcoli del testo acquisito.
Prove ed esiti sono distinti dai limiti di OCR, layout, DRM e validazione reale.
Pulire soltanto gli artefatti rigenerabili del lotto, conservando le prove utili.

**Ready** per il lotto autorizzato; esiti e limiti in GS-VER-310.
