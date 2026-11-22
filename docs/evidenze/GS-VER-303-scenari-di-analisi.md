<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-303 — Scenari di analisi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-303 |
| Tipo | Evidenza di verifica degli scenari applicativi |
| Versione | 1.1.0 |
| Stato | Superato nel profilo macOS; audit manuali separati |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita; GS-DOR-303 |

## Perimetro e risultato

Il `make verify` finale è **superato** sulla composizione identificata sotto,
con tutte le verifiche condivise e build Debug/Release macOS. Il piano
[GS-TST-001](../pianificazione/scenari-di-analisi.md) e la
[matrice eseguibile](../../Config/Testing/analysis-scenarios.json) collegano
**170 varianti operative** e cinque workflow ai test e agli oracoli.
L'[allegato strutturato](allegati/GS-VER-303-verifica-scenari.json) conserva
inventario dei sorgenti, digest, conteggi e limiti delle prove.

| Controllo | Esito osservato |
| --- | --- |
| Test Core / Kit | 644 / 149 definizioni, superate |
| Test nativi macOS | 125 definizioni, 409 esecuzioni; zero failure, skip e runtime warning |
| Oracoli numerici | 236 righe riprodotte; controllo Fraction su 64 casi binary64 |
| Analisi testuale | Tutti i 40 tag del compilatore, 63 fixture, 189 controlli CLI |
| Kit/CLI | 130 operazioni enumerate, 260 confronti di risultato completo |
| Input ostili | 51 rifiuti condivisi e 64 controlli dei comandi di progetto |
| Recovery / PDF | 22 checkpoint process-kill e due PDF/A-2u validati |
| Matrice degli scenari | 170 varianti, cinque workflow, 14 controlli negativi del verificatore |
| Risorse di build | 14 test sintetici su proprietà, lock, errori e pulizia |
| App | Build Debug e Release macOS superate |

## Test aggiunti ed estesi

Sono aggiunte **18 definizioni Swift**, con **223 esecuzioni** nelle
parametrizzazioni correnti, oltre all'estensione dei 17 scenari corpus già
esistenti. Le prove comprendono:

- importazione di testo e Markdown Unicode, ordine/digest delle fonti, matrici e codifica con lettura degli intervalli UTF-8, senza mutare il progetto;
- riapertura, riuso, richieste invalide e revisioni storiche/correnti distinte, con confronto completo dei DTO;
- cancellazione preventiva delle 63 fixture sia come richiesta tipizzata sia JSON: 126 percorsi;
- tutti gli 11 intenti pubblici, decisioni delle capability, precondizioni, progresso, terminale unico, grounding e assenza di finding inventati;
- tutti i 45 esempi reali degli operatori GUI, proprietà scientifiche per famiglia, pagine complete e anteprima ai confini 512/513 archi;
- reset durante task immediati non cancellati, retry e conservazione degli output validi;
- istanti con DST, policy temporali, date invalide e quattro combinazioni SOM geometria/Ward.

Gli oracoli aggiuntivi includono χ² = 10/3, Jaccard = 0,75, tassi che sommano
1.000, media zero e varianza campionaria uno, conteggi e coordinate UTF-8.
Il riuso aggiorna nei DTO i soli campi generazionali previsti dalla snapshot di
lettura; gli altri campi scientifici e i byte degli Artifact restano confrontati
integralmente.

## Difetti riprodotti e corretti

### Budget aggregato del planner

Il bundle keyness era ammesso senza addebitarlo al budget residuo. Con due
fonti da 100/200 byte il bundle costa 984 unità; una similarità da 684 portava
il piano a 1.668 con limite 1.000. I nove casi di confine falliscono prima del
fix con 42 issue e passano dopo la detrazione di `keynessBundleCost`.
Operazioni, ruoli, dipendenze, decisioni, somma dei passi e ordine delle fonti
rimangono verificati esplicitamente.

### Cache dei piani storici

Il descriptor precedente collocava il vecchio DAG sovrabudget e quello corretto
nella stessa identità, causando `planner.payload-plan-mismatch`. Due casi legacy
producono sei issue prima del bump e passano dopo: solo il producer del piano
passa da algorithmVersion `1` a `2`. Schema `1`, `planner-v2`, catalogo e decoder
restano invariati. Piani storici validi o sovrabudget, record e byte restano
leggibili e immutati; nuova richiesta e riapertura riusano il piano corretto.

### Preparazione delle risorse di build

`local` mascherava lo stato della pipeline `du`; inoltre su questo zsh l'uscita
in errore dalla funzione poteva evitare il trap del caller. Tre regressioni
riproducono la perdita della proprietà parziale. Il helper ora controlla lo
stato della sola pipeline e il dominio numerico e rilascia esplicitamente la
propria cache. La composizione conserva anche i guard I/O e gli ingressi di
cleanup del lotto concorrente: proprietà, lock, ERR_EXIT e KEEP restano
preservati. La suite integrata di 14 casi passa, incluso output numerico con
exit non zero e conservazione intenzionale con rilascio del lock.

## Identità e trasferimento

Il worktree isolato parte da `8901f4ad3f17a27f02fc7628221641d66346b38c`,
con overlay stabile del WIP e successivo allineamento ai file di
`d368285010dca17f5ef72819da25b6890d0de32a`. I **537 input** di codice,
risorse, fixture, configurazione e verifica hanno SHA-256
`6838063037d303a5f3621166e690b07f65c3a312e687496d463909ab5e850994`.
La concatenazione usa path relativo UTF-8 ordinato, NUL, contenuto e NUL;
inventario, contenuti e permessi coincidono prima e dopo il gate.

Il trasferimento guardato ha applicato **21 modifiche e otto aggiunte**, senza
eliminazioni o conflitti. Tutti i 537 input nel checkout condiviso coincidono
byte per byte e per permessi con il verificato. HEAD, indice e appunti protetti
restano invariati. Backup e journal del WIP precedente sono conservati;
nessun commit, push o reset è stato eseguito. Le rifiniture GUI e i controlli
lifecycle/tooling concorrenti sono preservati e inclusi nella verifica finale.

## Iterazioni e diagnostici

Le prime prove hanno corretto assunzioni dei nuovi test su offset UTF-8,
generazioni ricostruite al cache-read, esiti con caveat ed errore corpus
`lastCommittedGeneration`; gli assert scientifici completi sono conservati.
Due assert di finitezza usano closure esplicite per l'espansione della macro.

Il primo gate supera la parte condivisa ma termina con codice 137 entrando
in Xcode, senza risultato nativo; la causa non viene attribuita senza evidenza.
Il secondo si ferma sul separatore mancante di un commento importato. Dopo il
riallineamento, formattazione e controlli statici passano; il **terzo gate
completo termina con exit 0** sul fingerprint riportato.

L'host segnala CoreSimulator 1171.7.0 precedente al build 1174.21.0 richiesto
da Xcode, un avviso IDELaunchSession e il placeholder Mac senza versione OS.
Sono diagnostici host distinti da failure e runtime warning dei test. Il profilo
eseguito è macOS; nessun runtime iPadOS è attestato.

## Limiti della prova

Il checker attesta inventario e riferimenti: non dimostra da solo l'esecuzione
né la correttezza della mappatura variante/test. Le prove runtime e gli oracoli
restano separati. Test dei modelli e build non sono UI automation o audit
VoiceOver, Voice Control, contrasto, pseudo-lingua, RTL o usabilità.
Le 19 estensioni KH successive rimangono Core/Kit/CLI, senza adattatore GUI
dedicato. Nessuna promozione di manifest scientifici, G4/G5, prestazioni o
copertura di ogni possibile input/combinazione è dedotta da questo incremento.


## Pulizia

Rimossi **2,0 GiB** di artefatti rigenerabili e capture temporanei, misurati
con `du -sk` sui soli percorsi posseduti dal lotto; il dato non è una misura
dello spazio libero del volume. Restano app Release, snapshot sorgenti,
evidenze e backup del WIP. Toolchain e materiali delle altre chat sono
preservati; la cache di build è stata rimossa mediante il lock e il marcatore
di proprietà, senza scansioni globali per nome o anzianità.
