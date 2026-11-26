<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Valutazione delle frazioni beta e gamma

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-326 |
| Tipo | Esperimento prestazionale delimitato |
| Versione | 1.0.0 |
| Stato | Ready per misure dopo la baseline del coordinatore |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta di ottimizzazione dopo la revisione di correttezza |
| Riferimenti | CMP-326; GS-STD-001-17; GS-MET-001-21; GS-VER-319; GS-VER-326 |

## Definition of Ready

I kernel beta e gamma usano frazioni continue DLMF proprie, valutate dal fondo
con profondità raddoppiata e verifica di convergenza. Le prime misure del
coordinatore indicano costi di circa 0,45 µs per t/F e 0,30 µs per gamma;
questi valori non costituiscono ancora un confronto candidato/baseline.
Non è autorizzata alcuna modifica produttiva prima della cattura della baseline.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Valutare e mantenere soltanto un beneficio stabile nei due kernel; file produttivi ammessi GlifiStatisticalFoundation.swift e GlifiContingencyAnalysis.swift |
| proposta iniziale | Accoppiare i coefficienti pari/dispari del loop dal fondo, la cui profondità è sempre pari; eliminare selezione modulo e conversione duplicata dell'indice senza cambiare la sequenza dei denominatori |
| matematica e provenienza | Identità DLMF già adottate nel lotto 319, nessun ritorno a codice Numerical Recipes, tabelle o coefficienti senza concessione verificata; nessuna API nativa inesistente |
| compatibilità | API, descriptor, schema e formule invariati; primo spike mantiene operazioni e ordine floating point, con confronto bit per bit dei risultati validi |
| failure semantics | Stessi guard di finitezza e denominatori non nulli, profondità massime, criterio di convergenza 8 ulp, failure tipizzate e osservazione della cancellazione; nessuna tolleranza indebolita |
| verifica numerica | Griglie indipendenti e casi estremi del lotto 319, confronto baseline/candidato, code subnormali e transizione delle due forme; failure e cancellazione non vengono convertite in valori |
| misura | Harness del coordinatore, codice Release isolato, stesso input/checksum, warm-up, ripetizioni alternate e dispersione; niente build o benchmark concorrenti durante la misura |
| criterio di uscita | Solo il coordinatore integra un candidato con correttezza e beneficio stabile; se assente, conservare i kernel correnti e registrare l'esperimento negativo |
| tracciabilità | GS-VER-326 e riepilogo dei confronti nello stesso lotto; indici, matrice e harness restano al coordinatore |
| recupero e risorse | Spike in directory temporanee possedute, rimozione dei binari rigenerabili dopo raccolta delle evidenze; nessuna dipendenza o toolchain rimossa |

**Ready** prima di qualsiasi modifica produttiva. Eventuali strategie diverse
da questo primo spike richiedono una nuova proposta al coordinatore e verifiche
numeriche adeguate prima dell'integrazione.

## Esito dell'esperimento

Il confronto ABBA del prodotto in GS-VER-326 non dimostra un beneficio stabile:
variazioni inferiori al 5%, con risultati identici. Il candidato accoppiato viene
scartato e i due sorgenti tornano byte per byte alla cattura precedente a 326,
conservando le correzioni del lotto 319. Nessuna ulteriore strategia gamma viene
introdotta in questo lotto.
