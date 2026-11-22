<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-274 — Presentazione corpus coerente su macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-274 |
| Tipo | Evidenza di verifica della presentazione applicativa macOS |
| Versione | 1.1.0 |
| Stato | Preparata; esecuzioni da acquisire |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | GS-DOR-274; GS-DOR-223; ADR-0041; RF-046; RQ-013/047/058/060/063 |

## Perimetro

Sono da verificare l'invalidazione sincrona dei derivati al cambio di tabella
e l'indipendenza dei task di filtro e proiezione del modello corpus macOS.
Righe, indici, conteggio, pagina e asse devono riferirsi alla presentazione
corrente; ricerca e tabella più recenti vanno applicate alla proiezione finale.
I risultati Core/Kit, i formati e la persistenza non cambiano.
Durante pending il modello espone isPreparingPresentation e la vista mostra
ProgressView localizzato cm.presentation.updating; conteggio e nessun risultato
sono nascosti, le pagine disabilitate, asse/tabella/ricerca ancora modificabili.

La revisione individua un possibile accesso fuori limite con indici della
tabella precedente e una possibile incoerenza asse/dati quando la ricerca
invalida il token della proiezione. Sono ipotesi da riprodurre, non un RED o
un crash osservato. Il test RED deve fermarsi sull'asserzione di invalidazione
prima di provocare il possibile trap; il GREEN prova la richiesta di pagina.

## Prove richieste

La suite nativa StudioCorpusPresentationTests deve essere registrata nel target
macOS e usare fixture correspondence reale, cambio a tabella più corta nello
stesso turno, richiesta di pagina durante pending, asse+ricerca+tabella,
latest-axis-wins e reset. L'attesa della presentazione usa withObservationTracking dello stato
observable, senza API await aggiunte al prodotto, hook o attese temporali
arbitrarie. Si registrano separatamente RED, GREEN, completezza
delle righe, localizzazione, parità del risultato scientifico e hash dei sorgenti.

CMP-234 parte specified. Il gate e il packaging macOS del contenuto finale sono
da acquisire e nessun esito precedente è trasferito al nuovo codice. La
barriera lifecycleNonce del lavoro 223 e il lotto 233 mantengono i propri limiti
e la propria attribuzione.

## Limiti

Soli test automatici macOS: nessuna attestazione della GUI reale, VoiceOver,
Voice Control, iPadOS, energia, CI remota o promozione scientifica. I contributi
concorrenti e i dati preesistenti rimangono preservati.
