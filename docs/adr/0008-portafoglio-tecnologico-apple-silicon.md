# ADR-0008 — Portafoglio tecnologico Apple e strategia Apple silicon

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0008 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Direzione di prodotto del 2026-09-15 e documentazione Apple |
| Sostituisce | Nessuno |

## Contesto

Glifi Studio elabora documenti e corpus potenzialmente grandi su macOS e iPadOS. L'hardware Apple offre CPU ad alte prestazioni ed efficienza, accelerazione vettoriale, GPU, Neural Engine, memoria unificata e servizi di sistema integrati. Usare un solo percorso general purpose lascerebbe capacità rilevanti inutilizzate; adottare indiscriminatamente framework e capability renderebbe però il sistema fragile, energivoro e difficile da verificare.

## Decisione

Il progetto adotta un portafoglio Apple-native e una strategia di accelerazione progressiva:

1. implementazione Swift deterministica, incrementale e testabile come riferimento;
2. Accelerate come prima scelta per primitive numeriche e vettoriali supportate;
3. Core ML per modelli, lasciando al sistema la scelta tra CPU, GPU e Neural Engine quando possibile;
4. Metal e Metal Performance Shaders per carichi paralleli il cui vantaggio end-to-end sia dimostrato;
5. Foundation Models soltanto per funzioni intelligenti assistive, disponibili con fallback e separate dai risultati analitici autoritativi;
6. framework documentali, Spotlight, App Intents, Core Transferable e BackgroundTasks integrati al maturare dei rispettivi flussi.

Le capacità vengono interrogate a runtime. Ogni percorso accelerato mantiene una baseline corretta, fallback, tolleranze numeriche, cancellazione e osservabilità. Le misure includono prestazioni, memoria, energia, stato termico e responsività su dispositivi reali.

## Conseguenze

- GlifiCore espone contratti sostituibili per linguistica, persistenza, inferenza e calcolo.
- Il prodotto può utilizzare pienamente Apple silicon senza vincolare i dati a una singola generazione di chip.
- Una funzione resta disponibile, eventualmente degradata, quando Apple Intelligence o un acceleratore non è disponibile.
- Capability, entitlement, rete e sincronizzazione non vengono aggiunti prima dei relativi requisiti.
- I benchmark e i test di correttezza diventano gate per promuovere un backend a default.

## Alternative considerate

- solo CPU general purpose: respinto perché non sfrutta primitive e acceleratori pertinenti;
- Metal per ogni elaborazione: respinto perché overhead e consumo possono superare il beneficio;
- dipendenza obbligatoria da Apple Intelligence: respinta per compatibilità, riproducibilità e disponibilità;
- selezione tramite modello commerciale del chip: respinta a favore del rilevamento di capacità a runtime.

## Documenti applicativi

- [Pipeline documentale e OCR](../apple/09-pipeline-documentale-e-ocr.md)
- [Linguistica e intelligenza on-device](../apple/10-linguistica-e-intelligenza-on-device.md)
- [Calcolo accelerato su Apple silicon](../apple/11-calcolo-accelerato-apple-silicon.md)
- [Persistenza e indicizzazione di sistema](../apple/12-persistenza-e-indicizzazione-di-sistema.md)
- [Integrazione di sistema e lavoro prolungato](../apple/13-integrazione-di-sistema-e-lavoro-prolungato.md)
