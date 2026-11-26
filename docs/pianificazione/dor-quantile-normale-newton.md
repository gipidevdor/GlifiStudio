<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Inversione normale con iterazione protetta

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-325 |
| Tipo | Ottimizzazione numerica misurata |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di ottimizzazione dopo GS-VER-319 |
| Riferimenti | RQ-008; RQ-027; RQ-062; RQ-063; GS-MET-001-21; GS-STD-001-17; GS-VER-325; CMP-325 |

## Problema e confini

GS-VER-319 misura il quantile normale bounded a circa 4,44 microsecondi per
chiamata nel proprio probe, contro 0,105 della precedente approssimazione.
Il nuovo riferimento originale conserva correttezza e provenienza; il costo
residuo deriva dalla bisezione completa e dalla rivalutazione della coda.
La nuova baseline del banco condiviso GS-VER-324 deve essere congelata
prima di modificare il runtime. La consultazione iniziale degli header
`math.h` e Accelerate dell'SDK macOS 27.2 non individua un inverso normale
o erf inversa pubblici; la verifica indipendente dei framework è coordinata
con l'agente di revisione: anche la scansione completa indipendente degli header
Accelerate non individua una primitiva pubblica applicabile.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Ridurre il costo misurato delle sole funzioni normalQuantile/normalLogUpperTail con un metodo originale; fermarsi se manca un miglioramento dimostrabile o la correttezza regredisce |
| requisiti | RQ-008/027: quantili e casi degeneri invariati entro le tolleranze approvate; RQ-062/063 e GS-STD-001-17: baseline, candidato, confronto e tracciabilità |
| dominio/API | Nessuna nuova API, dipendenza, variante scientifica o formato; il contratto D1 resta quello di GS-MET-001-21 |
| failure semantics | Stessa validazione finita 0<p<1, stesso errore tipizzato; mediana esatta; bracket e fallback bounded; nessun risultato parziale o non finito ammesso |
| esperienza prevista | Stessi risultati e messaggi pubblici; riduzione del lavoro scalare per intervalli e consumatori esistenti |
| verifica | Oracoli R e tolleranze precedenti intatti; subnormali e adiacenze della mediana, confine8, monotonia/simmetria, griglia severa esterna e consumatori; confronto Release del banco condiviso dopo baseline congelata |
| dati e migrazione | Nessun formato nuovo; vecchi risultati D1 corretti restano validi; revisione cache da valutare con l'integratore se cambia il contratto osservabile |
| sicurezza/privacy | Solo formule matematiche e Swift originale; nessun coefficiente Acklam/NR o sorgente esterno; nessuna rete nel prodotto |
| prestazioni/sistema | Al massimo 12 tentativi Halley protetti, probe locale con segni verificati e bisezione finale sul bracket esistente; derivata dalla densità e dalla coda esistenti, nessuna accelerazione di piattaforma introdotta senza verifica |
| tracciabilità | GS-VER-325 per metodo, test e limiti; GS-VER-324 per confronto integrato; indici e matrice a cura dell'integratore |
| decisioni e recupero | Nessuna nuova architettura; se i criteri falliscono si conserva il kernel319; snapshot sorgente prima/dopo e nessun confronto sotto build concorrenti |

**Ready**. L'autorizzazione implementativa resta subordinata alla fine della
baseline condivisa e al congelamento del banco da parte dell'integratore;
questa scheda precede qualunque modifica dei sorgenti di prodotto.
