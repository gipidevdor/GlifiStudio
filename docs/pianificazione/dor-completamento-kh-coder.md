<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Completamento delle varianti native KH Coder

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-233 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita corrente di implementare tutti gli algoritmi mancanti nel motore nativo; GUI separata |
| Riferimenti | RF-087; RQ-025; RQ-048; RQ-058; RQ-060; RQ-063; GS-MET-001-23; GS-API-002; ADR-0035; CMP-160; CMP-162 |

## Contesto di registrazione

La richiesta dell’iniziatore ha autorizzato il lavoro nel worktree isolato
`glifi-kh-completion-20261122`, basato su `02c1c66`, separato dalle modifiche
applicative concorrenti. Questa scheda consolida i contratti dopo l’avvio del
codice e dei mirati; **non attesta registrazione o Ready prima dell’implementazione**.
Lo stato Ready riguarda la prosecuzione delimitata e la verifica del lotto.
Gli ID 230–232 sono occupati dall’incremento macOS concorrente e non sono riusati.

## Scheda Definition of Ready

| Voce | Contratto dell’incremento |
| --- | --- |
| outcome e confini | Colmare le varianti identificate nel confronto pubblico: tre comunità, due layout, Prim, Simpson, SMACOF ordinale e multi-start, SOM esagonale/U-matrix/Ward, selezione K LDA, pipeline italiana opzionale. Core/Kit/CLI transitori; GUI separata e nessuna nuova persistenza |
| requisiti | RF-087 e correttezza/provenienza/risorse di RQ-025, RQ-048, RQ-058, RQ-060, RQ-063; nessuna nuova lingua promossa |
| contratto di dominio/API | Formule e varianti in GS-MET-001-23; nove operazioni piatte GS-API-002 nello schema/versione 1; vecchi default conservati, nuovi ordinal/simpson espliciti; DTO con ordine, seed, obiettivi, convergenza e provenienza applicabili |
| failure semantics | GlifiFailure→GlifiStudioFailure e cancellazione propagate; input malformed, OOV totale in held-out, annotazioni richieste sconosciute, overflow e budget fail-closed; metriche scientificamente non definite restano assenti con motivo |
| esperienza prevista | Flusso headless richiesto: request riproducibile, risultato strutturato e failure tipizzata. Nessuna modifica a viste, accessibilità applicativa o stato GUI; tali verifiche appartengono al lotto separato |
| verifica | Oracoli analitici/scalari, PAVA tramite partizioni esaustive, passo Guttman, probabilità LDA esatte, grafi canonici, regole Snowball, offset, cancellazione, limiti e parità Core/Kit/CLI. Trenta fixture presenti (15 storiche e 15 nuove); esecuzione e gate finale registrati in GS-VER-233, senza anticiparne l’esito |
| dati e migrazione | Dati sintetici e riferimento dichiarato; nessun formato persistente o migrazione; schema di trasporto 1 conservato. Confronto del ramo precedente per la compatibilità delle richieste storiche |
| sicurezza/privacy | Nessuna rete, telemetria, download di asset, dipendenza o privilegio nuovo. Output scientifico può contenere il testo richiesto, diversamente dai metadati diagnostici; bound prima delle allocazioni principali e nessuna copia di codice GPL KH |
| prestazioni/sistema | Budget cumulativi prima di fit/ricerca e buffer quadratici; ammissione theta include documenti vuoti, fold-in prior-only analitico; benchmark Release con fixture/hash/ambiente e ripetizioni, senza soglie o miglioramenti inventati. Backend accelerati richiedono confronto con riferimento scalare |
| tracciabilità | RF-087, TV-087/088, CMP-160/162 aggiornati puntualmente con nuove fonti, test e GS-VER-233; risultati storici conservati nel proprio ambito |
| decisioni e recupero | ADR-0035 accetta ambito/architettura, non approvazione scientifica. Varianti nuove candidate; V6 esterno, hardware di riferimento e G4 aperti. Revert puntuale senza migrazione |

**Ready** per completare verifiche, integrazione documentale e gate del perimetro
autorizzato. Il gate di uscita richiede il `make verify` sul contenuto finale e
la registrazione di risultati e limiti realmente osservati dal coordinatore.
