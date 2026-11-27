<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Contesto e stato dei risultati di ricerca

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-335 |
| Tipo | Correzione dell'interazione di ricerca macOS |
| Versione | 1.0.1 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta di perfezionamento UX/UI con verifiche durante lo sviluppo |
| Riferimenti | GS-UI-001; GS-UX-001-07; GS-UX-001-09; GS-STD-001-15; GS-STD-001-29; GS-VER-335 |

## Definition of Ready

La ricerca pubblica risultato, espressione e selezione prima di leggere la
fonte del primo riscontro. Una failure o cancellazione della seconda
admission perde il contesto precedente e lascia un risultato parzialmente
pubblicato. Inoltre il campo modificabile e il risultato conservato non
espongono uno stato esplicito di aggiornamento: l'espressione eseguita è
visibile soltanto nella provenienza espandibile.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Pubblicare insieme risultato, espressione effettiva, selezione e fonte dopo tutte le letture; distinguere la bozza corrente dai risultati conservati nel solo percorso Ricerca; guidare verso salvataggio/apertura e importazione quando manca una precondizione |
| provenienza | L'espressione mostrata accanto ai risultati è quella realmente eseguita; non attribuire vecchie concordanze alla nuova bozza |
| dominio/API | Riutilizzare le operazioni Kit/CLI esistenti, nessun nuovo task owner, schema, algoritmo o dipendenza |
| failure semantics | Query rifiutata, busy e interruzione della lettura della fonte conservano risultato, espressione, selezione e testo precedenti; cancellazione prima della pubblicazione non aggiorna i campi; retry usa Cerca |
| esperienza prevista | Avviso SwiftUI nativo con Label e SF Symbol quando la bozza differisce; espressione effettiva visibile con testo selezionabile; Invio e pulsante Cerca mantengono la stessa azione; ContentUnavailableView riusa le azioni native Salva/Nuovo/Apri e Importa/Fonti, senza suggerire una ricerca disabilitata |
| verifica | Test prima del fix con runtime iniettato: seconda admission interrotta mediante pressione critica o cancellazione, stato invariato e retry; query non valida, rifiuto busy e successo senza risultati; proprietà di aggiornamento e transizione nessun progetto/progetto vuoto/fonti importate verificate separatamente; percorsi visuali da distinguere dalle verifiche del modello |
| dati e privacy | Fixture sintetiche, nessuna scrittura di eventi o modifica del progetto dalla ricerca, nessun nuovo log del contenuto |
| accessibilità | Componenti e colori semantici nativi, avviso combinato in un elemento accessibile, testo adattabile; efficacia VoiceOver, Voice Control, contrasto e destra-sinistra non dichiarata senza audit |
| prestazioni e piattaforme | Stesso insieme di letture, nessuna ottimizzazione; regressioni nel target macOS del workspace, nessuna attestazione iPadOS |
| tracciabilità | GS-VER-335 distingue RED, GREEN e limiti; localizzazioni, metadata e gate integrato coordinati dall'integratore |

**Ready** prima dei test e della correzione produttiva. Il coordinatore
esegue il RED e assegna la successiva verifica del candidato.
