<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Associazione autorevole dei metadati delle viste esportate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-331 |
| Tipo | Correzione del contratto di provenienza |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di correttezza semantica e incarico di integrazione GS-VER-331 |
| Riferimenti | RQ-008; RQ-036; GS-API-003; GS-MET-001-22; GS-VIZ-001; GS-VER-331; CMP-331 |

## Problema e confini

L'export di sessione controlla la presenza dell'Artifact corrente ma accetta
dal chiamante nodo produttore, analisi e metodo senza confrontarli con la
fonte persistita. Una specifica Codable può quindi associare a un Artifact
reale metadati scientifici incompatibili; la verifica offline ne controlla
soltanto la coerenza interna. Questo controllo offline conserva il proprio
contratto: il contesto autorevole è disponibile nell'export della sessione.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Confrontare nodo, analisi e metodo dichiarati con l'Artifact corrente; coprire factor plot, dendrogramma, rete di finestra/documenti e tabella di collocazioni; includere l'admission della sola operazione export nel confine delle failure |
| requisiti | GS-MET-001-22: la vista è una proiezione dell'Artifact con metodo esplicito; GS-API-003: native e trasporto condiviso hanno la stessa failure |
| dominio/API | Nessuna API pubblica o formato nuovo; nessuna modifica al verificatore offline, al writer o ai descriptor |
| failure semantics | Artifact assente conserva `visual-export.stale-artifact`; metadati incompatibili producono `visual-export.source-mismatch`, `invalidInput`, correzione richiesta, stato invariato e nessuna cartella finale o staging residuo; sessione chiusa conserva codice/retry/stato con operazione export, cancellazione prima/dopo admission conserva operazione export e stato unchanged |
| esperienza prevista | L'esportazione mantiene l'associazione reale a nodo e metodo; la scelta lecita degli assi e altre proprietà di presentazione non viene sostituita da un confronto integrale con la vista standard |
| verifica | RED prima del fix per tre campi alterati in ciascuna famiglia, ingresso nativo e JSON condiviso; regressione separata con output Artifact corrotto dopo apertura per verificare failure tipizzata e operation export; due RED aggiuntivi per sessione chiusa e task già cancellata prima di includere ensureOpen nel catch; GREEN sullo stesso test, viste originali e assi alternativi ammessi; processo CLI indipendente e gate di parità a cura dell'integratore |
| dati e migrazione | Dati di progetto immutati; lettura tipizzata dei payload correnti quando il metodo non è interamente ricavabile dal descriptor |
| sicurezza/privacy | Fixture sintetiche temporanee con cleanup; fallimenti senza path o contenuti nei messaggi; nessuna rete o dipendenza |
| prestazioni/sistema | Nessun ricalcolo analitico; riuso della lettura Artifact già verificata e bounded; esecuzioni Swift serializzate dall'integratore |
| tracciabilità | GS-VER-331 documenta prova e limiti; matrice e indici aggiornati dall'integratore |
| decisioni e recupero | Fix autorizzato dopo Ready e RED specifico; non si dichiara autenticazione delle coordinate o di trasformazioni arbitrarie del payload di vista |

**Ready** prima di introdurre il test e modificare il runtime. Le prove
registrate separeranno la validazione della provenienza dalla consistenza
interna del bundle e dalla correttezza del mapping dato-segno.
