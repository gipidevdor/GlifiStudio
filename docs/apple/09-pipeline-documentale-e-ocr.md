# Pipeline documentale e OCR

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-009 |
| Tipo | Standard applicativo Apple |
| Versione | 1.1.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0008 |

## Scopo

Questo documento assegna le tecnologie Apple alla pipeline di acquisizione,
interpretazione e presentazione. GS-DAT-001 governa formato, ingestion e offset;
PDF/OCR restano post-MVP e non modificano il contratto già deciso.

## Portafoglio tecnologico

| Tecnologia | Ruolo | Stato | Gate di attivazione |
| --- | --- | --- | --- |
| Uniform Type Identifiers | Dichiarazione e validazione dei tipi importati, esportati e trasferiti | Da adottare nella prima importazione | Elenco formati approvato |
| Foundation, `FileHandle`, coordinamento file | I/O incrementale, accesso coordinato e scritture recuperabili | Da adottare nella vertical slice | Contratto documentale e test di errore |
| PDFKit | Estrazione del livello testuale, pagine, selezioni e navigazione PDF | Pianificato | Corpus PDF digitale e round-trip delle posizioni |
| Vision | OCR locale con osservazioni, coordinate e confidenza | Pianificato | Corpus OCR, metriche e provenienza approvati |
| VisionKit | Acquisizione guidata da fotocamera e interazioni documentali di sistema su iPad | Condizionale | Requisito esplicito di scansione e permesso fotocamera |
| Image I/O e Core Graphics | Orientamento, decodifica e normalizzazione controllata delle immagini | Pianificato con OCR | Test colore, orientamento e memoria |
| Core Image | Pre-elaborazione immagini accelerata prima dell'OCR quando migliora la qualità | Da valutare | Confronto accuratezza, GPU, energia e memoria |
| Quick Look Thumbnailing | Anteprime efficienti senza renderer proprietario | Condizionale | Flusso di esplorazione documenti |
| Core Transferable | Contratto di importazione, esportazione, drag and drop e condivisione | Da adottare quando i tipi sono stabili | Tipi e policy di copia/riferimento approvati |

## Regole

- La fonte originale **NON DEVE** essere modificata implicitamente.
- Il testo digitale e il testo OCR **DEVONO** essere artefatti distinti con pagina, regione, revisione dell'algoritmo, lingua richiesta e confidenza applicabile.
- Vision **DEVE** operare sul dispositivo e la modalità `fast` o `accurate` **DEVE** essere scelta mediante profili d'uso e benchmark, non globalmente.
- La disponibilità della lingua OCR **DEVE** essere verificata a runtime; una lingua non supportata deve produrre un errore comprensibile o selezionare un backend approvato.
- PDFKit **NON DEVE** essere trattato come fonte infallibile: ordine di lettura, ligature, font incorporati e PDF corrotti richiedono fixture negative.
- Immagini e pagine **DEVONO** essere elaborate a finestre o tile quando la dimensione rende rischiosa una rasterizzazione completa.
- Filtri Core Image **DEVONO** essere confrontati con una pipeline senza pre-elaborazione e non possono alterare silenziosamente la fonte conservata.
- VisionKit, fotocamera e relativi usage description **NON DEVONO** entrare nei target prima del requisito di scansione.
- Le preview Quick Look **NON DEVONO** diventare il formato canonico né una dipendenza del motore.

## Evidenze richieste

- fixture MVP per testo/Markdown e, prima dell'attivazione post-MVP, PDF digitale,
  PDF immagine, rotazioni, documenti corrotti e lingue approvate;
- round-trip tra risultato, testo estratto, pagina e regione sorgente;
- profili memoria e tempo su Mac e iPad reali;
- confronto OCR per accuratezza, throughput ed energia;
- verifica di sandbox, security scope e coordinamento con provider di file.

## Riferimenti Apple

- [Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers/)
- [PDFKit](https://developer.apple.com/documentation/pdfkit)
- [Recognizing text in images](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- [VisionKit](https://developer.apple.com/documentation/visionkit)
- [Image I/O](https://developer.apple.com/documentation/imageio)
- [Core Image](https://developer.apple.com/documentation/coreimage)
- [Quick Look Thumbnailing](https://developer.apple.com/documentation/quicklookthumbnailing)
- [Core Transferable](https://developer.apple.com/documentation/coretransferable)
