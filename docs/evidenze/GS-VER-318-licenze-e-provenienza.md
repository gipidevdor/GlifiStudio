<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-318 — Licenze e provenienza degli algoritmi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-318 |
| Tipo | Revisione di licenze, attribuzioni e fonti |
| Versione | 1.0.0 |
| Stato | Revisione locale e controlli mirati superati; gate integrato registrato in GS-VER-321 |
| Responsabile | Codex con revisione parallela di tre agenti |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita dell’iniziatore sulle licenze e sulla correttezza |
| Riferimenti | GS-DOR-318; GS-LIC-001; GS-LIC-002; GS-VER-319; GS-VER-321 |

## Esiti e correzioni

L’audit comprende package Swift, sorgenti e citazioni algoritmiche, oracoli R/Python,
fixture, workflow CI e immagini. Sono registrati **23 materiali** e **19 input
revisionati con digest** nell’[inventario](../../Config/Licenses/materials.json).
Nessuna nuova libreria, installazione o acquisizione di sorgenti eseguibili.
Le fonti e i confini sono nel [registro GS-LIC-002](../algoritmi-e-provenienza.md).

| Riscontro della baseline | Risoluzione nel cambiamento |
| --- | --- |
| Nuclei beta/gamma citano Numerical Recipes; coefficienti Acklam e Lanczos senza prova primaria conservata di riuso | Sostituzioni numeriche originali da identità matematiche e `lgamma_r` di sistema in GS-VER-319; provenienza precedente dichiarata, senza semplice rimozione delle citazioni |
| Regole Snowball e sequenza SplitMix senza avvisi upstream | Testi primari conservati integralmente in THIRD_PARTY_NOTICES; distribuzione nel bundle verificata dal lotto 321 |
| Manifest Pinocchio attribuisce BSD senza distinguere testo e annotazioni e contiene una conclusione giuridica assoluta | Licenza delle annotazioni distinta da condizioni della trascrizione, attribuzione, permalink e hash; rettifica in ADR-0030 e GS-VER-138 |
| Soltanto politica generale di licenza, senza inventario verificabile | Registro di provenienza, inventario con relazione/distribuzione e digest; gate strutturale e bundle nel lotto 321 |
| Fonti di algoritmo e strumenti GPL trattabili come un’unica categoria | R/pacchetti/veraPDF/Python/CI separati dal prodotto; KH e DLMF classificati come riferimenti, con condizioni e limiti espressi |

La fonte primaria Snowball è stata controllata alla pagina licenza e al file
COPYING della release 3.1.0: gli avvisi diversi sono mantenuti entrambi.
La fonte Vigna è stata verificata con dedica al pubblico dominio e permesso
esplicito. Il controllo della copia del testo della release Snowball produce
SHA-256 `880802872ce34f313df826e96131b1b147dcfa09c76fc82129f25503a922a678`.
I link primari e le condizioni sono registrati nell’inventario, senza importare
libstemmer o sorgenti C del generatore.

## Fonte linguistica verificata

Il [rapporto di provenienza](allegati/GS-VER-318/provenienza-pinocchio.json)
registra **15/15 paragrafi** trovati nelle cinque revisioni delle pagine 9–13.
Le revisioni sono anteriori al recupero originariamente registrato; la verifica
rimuove blocchi noinclude, figure, template e tag e normalizza soltanto spazi.
Non corregge ortografia, punteggiatura o maiuscole. Restano identici a HEAD
sorgente, `token-boundaries.json`, `adjudications.json` e `baseline.json`.

L’attribuzione sceglie prudenzialmente CC BY-SA 3.0, indicata nei metadati
Wikisource dell’opera, per gli eventuali apporti protetti alla trascrizione.
Non si converte la trascrizione in BSD e non si pretende di restringere il
testo originario in pubblico dominio. La review non ricostruisce il log di
scaricamento mancante del 2026-09-20.

## Verifiche mirate

Con Python 3.14 locale passano inventario, sei test del checker, fixture e docs:
23 materiali; 19 casi gold complessivi; metadati e link locali validi.
Il primo tentativo con `/usr/bin/python3` usa una versione che non supporta
`zip(strict=True)` e fallisce nel checker fixture preesistente: non è riportato
come esito positivo. L’ambiente di gate già disponibile usa Python **3.12.14**,
R **4.6.0**, `igraph` **2.3.3**, `NMF` **0.28** e `cluster` **2.1.8.2**;
le verifiche integrate e la riproduzione degli oracoli sono registrate da root
nei lotti di composizione, senza nuova installazione.

Il checker prova coerenza del catalogo, esistenza dei file, digest revisionati
e disponibilità degli avvisi. La verifica dei dati prova corrispondenza e
immutabilità delle fixture; nessuno di questi controlli certifica i diritti.

## Seconda passata sulle fonti KH e R

Il [confronto campionario](allegati/GS-VER-318/confronto-fonti-kh.json) registra
fonti primarie, hash, commit introduttivi e differenze implementative per
LR/FLR, SOM, χ² e Ward. R som è registrato separatamente con la sua GPL ≥ 3.
La review verifica anche i sorgenti introduttivi, non soltanto l’assenza di
file vendorizzati: il profilo SOM è dichiarato come reimplementazione
comportamentale informata dai sorgenti.

Nessun port espressivo inequivocabile è stato identificato nei quattro nuclei.
Le corrispondenze funzionali sono deliberate; i dettagli osservati e i limiti
stanno nel rapporto, senza dedurre dalla licenza della fonte quella delle
relazioni matematiche. Non è una certificazione clean-room né un’approvazione
all’incorporazione futura del codice GPL.

La ricerca mirata su fixture, oracoli, test e asset identifica un caso LR/FLR
adattato dall’esempio del paper, dichiarato esplicitamente nel vecchio oracolo.
È sostituito con dati realmente sintetici in GS-VER-323: nove candidate,
cinque simboli, frequenze e struttura delle adiacenze diverse. Le affermazioni
sull’originalità degli input correnti non estendono tale proprietà al caso
precedente. Le prove di ricalcolo e i test sono registrati nel lotto 323. Pinocchio resta la fonte esterna esplicitamente attribuita.
Gli altri match osservati sono formule e una copia di codice interno per test
di equivalenza; la ricerca testuale non prova la provenienza di ogni possibile
literal non annotato.

## Limiti conservati

Non si certificano titolarità dei contributi storici, assenza di brevetti o
registrabilità del marchio. L’icona ha master/prompt di generazione documentati,
ma l’approvazione come marchio resta aperta. Il renderer PDF usa font di sistema:
conformità PDF/A e permesso di embedding del font sono proprietà diverse,
documentate con il limite specifico nella chiusura del lotto comportamentale.

Il repository conserva riferimenti a sorgenti KH storici GPL: nessun componente
vendorizzato o collegato osservato, senza pretendere una prova del processo
storico di scrittura. Gli output numerici degli oracoli non incorporano sorgenti
o testi dei pacchetti. La sostituzione attuale dei nuclei non modifica la storia
Git, che non deve essere presentata come bonificata.

L’audit non include una consulenza giuridica, il canale iPadOS, una nuova
submission App Store o verifiche manuali assistive. Le consultazioni web sono
read-only; nessun messaggio inviato a terzi e nessuna modifica ad appunti grezzi.
