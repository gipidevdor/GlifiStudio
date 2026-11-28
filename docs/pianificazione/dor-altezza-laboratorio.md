<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Altezza adattiva del laboratorio statistico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-340 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Perfezionamento della correttezza dei comportamenti e verifica GUI macOS richiesta dall'iniziatore |
| Riferimenti | GS-APL-002; GS-APL-003; GS-STD-001-15; GS-STD-001-29; GS-VER-339; GS-VER-340 |

## Definition of Ready

Nella verifica GUI macOS lo strumento ha restituito una cattura iniziale di
2560 × 1600 pixel e una successiva cattura del laboratorio Welch alta 4530
pixel. Le azioni inferiori risultavano irraggiungibili al tentativo effettuato.
La cattura iniziale non bastava a dimostrare il minimo verticale del prodotto.
Dopo i probe hostless non conclusivi, una sonda passiva nel contenitore
DocumentGroup reale misura un frame alto 2265 punti contro 1179 disponibili:
il RED del prodotto è confermato prima di modificare il layout. La sonda
resta in un worktree separato e non viene inclusa nella consegna.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Il laboratorio statistico deve accettare una finestra di 1280 × 800 punti senza innalzare il minimo verticale oltre il viewport; dati, parametri e azioni restano raggiungibili mediante i contenitori nativi e il loro scorrimento |
| superficie | Solo il layout macOS del laboratorio statistico, la diagnostica temporanea isolata e le verifiche pertinenti; nessuna modifica di algoritmi, API Kit/CLI, formati o contenuto scientifico |
| failure semantics | Un test che non riproduce l'espansione non costituisce RED; errori di compilazione, albero AX vuoto o problemi del runner non costituiscono una regressione del layout; senza RED pertinente non si modifica il layout produttivo |
| esperienza prevista | Conservare Form grouped, split ridimensionabile e presentazione compatta; usare vincoli adattivi, senza fissare l'altezza dell'interfaccia a un numero di pixel o alla dimensione dello schermo |
| verifica | Prima del fix, NSHostingController con sizingOptions minSize in NSWindow di 1280 × 800 punti, misura pubblica di contentMinSize e frame dopo layout; selezione Welch, esempio sintetico e risultato; italiano e inglese, testo standard e accessibilità; se il laboratorio isolato non riproduce il problema, wrapper NavigationSplitView fedele al dettaglio Home e poi finestra DocumentGroup reale con osservatori passivi pubblici. Confrontare frame e contentLayoutRect con visibleFrame dello schermo, distinguendo pixel e punti; osservare apertura dettagli e scorrimento tramite CUA |
| accessibilità | Il test di dimensionamento non attesta VoiceOver, Voice Control, navigazione o scorrimento reale; raggiungibilità delle azioni e ridimensionamento richiedono anche la successiva verifica GUI |
| dati e risorse | Esempio numerico sintetico già disponibile; nessun corpus personale, nuova dipendenza, entitlement o dato persistente; finestre di test possedute e chiuse al termine |
| tracciabilità | GS-VER-340 distingue osservazione GUI, tentativi di riproduzione, RED eventuale, candidato e GREEN; gate integrato e metadata coordinati dall'integratore |

**Ready** prima dei test e di qualsiasi correzione produttiva. Se il difetto
non è riproducibile con le osservazioni pubbliche previste, resta aperto e
non viene applicata una correzione speculativa.
