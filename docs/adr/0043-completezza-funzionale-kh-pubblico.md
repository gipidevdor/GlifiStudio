<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0043 — Chiusura funzionale dei profili KH pubblici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0043 |
| Tipo | Decisione di estensione analitica |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di finire la completezza rispetto a KH Coder |
| Riferimenti | RF-087; ADR-0032; ADR-0035; ADR-0031; GS-DOR-300; GS-VER-234 |

## Contesto e decisione

L’audit GS-VER-234 ha distinto disponibilità delle famiglie e varianti mancanti.
La nuova richiesta autorizza le preparazioni e varianti pubbliche elencate in
GS-DOR-300, con contratti matematici espliciti e implementazioni Swift originali.
Le primitive restano in memoria e sono esposte insieme in Core, Kit e CLI.
Nessuna nuova persistenza, rete, telemetria, dipendenza, lingua di tokenizzazione
automatica o runtime esterno di prodotto è introdotto.

I default esistenti restano invariati; nuovi profili hanno identificatori propri.
Il ranking dei composti opera su candidati/token dichiarati: la disponibilità del
motore matematico non certifica MeCab, ChaSen o un tokenizer di altre lingue.
SOM conserva l’inizializzazione e continua gli stessi codebook tra le due fasi;
la ripetizione di due fit che reinizializzano i prototipi è esclusa.

Per la sola inizializzazione PCA del nuovo profilo SOM si usa LAPACK dgesvd
tramite Accelerate già collegato. Il percorso Jacobi condiviso può perdere un
asse rappresentabile quando ne quadra una norma molto piccola: il controesempio
mixed-scale ha un secondo valore singolare dell’ordine di 1e-200. La scelta è
motivata dalla correttezza numerica, con test discriminante e oracolo R, non da
un guadagno prestazionale presunto. Il backend condiviso e i risultati delle
API preesistenti non sono sostituiti; workspace e matrici sono ammessi prima
delle allocazioni e i segni degli assi seguono una regola deterministica.

## Conseguenze e verifica

La copertura è riferita al manuale KH pubblico e ai sorgenti citati, non a versioni
chiuse/future o a identità bitwise con RNG e dipendenze R non fissate. Varianti
nuove restano candidate fino alla validazione esterna prevista da ADR-0031.
Celle e lavoro sono ammessi prima dei buffer; errori numerici non diventano zeri
plausibili. Ogni metodo ha oracoli/test indipendenti e parità CLI/Kit. Evidenze,
limiti e pulizia sono registrati in GS-VER-300 prima della consegna.
