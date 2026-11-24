<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Disponibilità e failure OCR native

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-311 |
| Tipo | Correzione dell'importazione documentale |
| Versione | 1.1.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Completamento dell'importazione PDF/OCR richiesta dall'utente |
| Riferimenti | RF-004; RF-005; RF-006; RQ-044; RQ-058; RQ-060; ADR-0044; ADR-0045; GS-VER-310; GS-VER-311 |

## Esito e confini

Il runner xcode-27 rifiuta entrambe le prove OCR native mentre il Mac locale le
supera. Il codice attuale riduce qualsiasi errore perform non cancellato a
invalidInput, perdendo la distinzione fra documento e risorse del riconoscitore.
La correzione preserva gli assert di testo riconosciuto e pagina vuota; nessun
successo vuoto, skip o deroga sostituisce un riconoscimento riuscito.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Discriminare il problema remoto e correggere disponibilità/tassonomia OCR; nessun cambiamento a EPUB, GUI o kernel numerici |
| requisiti | PDF digitale e scansionato mantengono la rappresentazione comune e locatori; gli errori del sistema non accusano un originale valido |
| dominio/API | API Core/Kit/CLI e formati persistenti invariati; eventuale profilo OCR modificato è nominale e documentato solo dopo prova discriminante |
| failure semantics | CancellationError, task cancellato e VN requestCancelled prevalgono; errori immagine, capacità e risorse sono distinti; nessuna descrizione o userInfo nativa nel trasporto |
| esperienza prevista | Stesso comando importa e stesse categorie localizzabili; nessun dettaglio diagnostico grezzo nell'interfaccia |
| verifica | Probe sintetico su locale e runner, anche processi freschi; regressioni deterministiche NSError e prove OCR reali invariate; make verify macOS e controllo remoto prima della chiusura |
| dati e migrazione | Originale e snapshot precedenti restano immutabili; nessun nuovo campo diventa obbligatorio nel decoder; nuove impostazioni, se adottate, sono registrate nel backend e nei metadati della nuova acquisizione |
| sicurezza/privacy | API Apple pubbliche; nessuna dipendenza, rete o entitlement di prodotto; diagnostica confinata a fixture sintetiche con campi NSError pubblici filtrati e bounded |
| prestazioni/sistema | Nessun fallback hardware o cambio accurate/fast non dimostrato; estrazione fuori Main Actor, budget e cancellazione conservati |
| tracciabilità | GS-VER-311, CMP-311, pipeline Apple e contratti aggiornati; prove locali e remote e relativi congelamenti distinti |

ADR-0045 registra la sequenza nativa positiva: accurate preferito, un solo
tentativo fast su errore di risorse del perform, profilo V2 esplicito e livello
effettivo nella provenienza. Nessun cambio per preflight, limiti, input,
cancellazione o successo vuoto; massimo 256 perform sulle 128 pagine ammesse.

## Criterio di uscita

Testo sintetico e pagina vuota soddisfano le aspettative originali sul runner,
le failure mantengono tassonomia e privacy, e lo snapshot riaperto conserva il
backend acquisito. Le misure sintetiche non qualificano corpus reali o G4/G5.

**Ready** per diagnosi e correzione nel perimetro dichiarato.
