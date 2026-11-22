# 18. Errori, logging e osservabilità

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-18 |
| Tipo | Capitolo normativo |
| Versione | 0.5.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 18.1 Errori

Il contratto trasversale usa categorie semantiche stabili, non i tipi di errore dei
framework sottostanti:

| Categoria | Quando si usa | Retry | Stato che rimane valido |
| --- | --- | --- | --- |
| `invalidInput` | request, schema, intervallo o parametro non valido | dopo correzione | stato precedente invariato |
| `unsupportedFormat` | tipo/variante riconosciuto ma non supportato | conversione o update | stato precedente invariato |
| `insufficientData` | quantità o qualità non sostiene il risultato | dopo modifica dati | input e artefatti precedenti; nessun nuovo risultato |
| `transientIO` | I/O/coordinamento temporaneamente fallito | bounded con backoff | ultima generazione committata |
| `authorizationDenied` | permesso o security scope assente/revocato | dopo gesto utente | stato precedente; riferimento indisponibile |
| `insufficientResources` | memoria, disco, tempo o termica oltre policy | dopo cambio condizioni | commit precedente e checkpoint verificati |
| `cancelled` | richiesta cooperativa accettata | nuova operazione | commit precedente; checkpoint verificato opzionale |
| `staleArtifact` | input/revisione non coincide più | ricalcolo | artefatto storico leggibile, non corrente |
| `incompatibleVersion` | formato, schema o protocollo non leggibile | update/export | originale intatto; read-only se sicuro |
| `corruption` | digest, schema o integrità non verificabile | recovery esplicito | solo generazione verificata precedente, se esiste |
| `invariantViolation` | difetto interno o stato impossibile | mai automatico | validità non presunta; componente fail-closed |

Ogni failure dichiara codice stabile namespaced, categoria, operazione,
`retryDisposition`, `retainedState`, azione possibile, `messageKey` e argomenti
localizzabili non sensibili. Messaggio UI, dettaglio tecnico e causa sottostante
sono livelli distinti. La causa Foundation/SQLite/parser non attraversa l'API
pubblica e non determina il testo localizzato.

`cancelled` e `insufficientData` sono esiti di dominio attesi, non difetti. Possono
essere rappresentati come outcome tipizzati; CLI o confini che richiedono un codice
usano comunque la stessa categoria. `resourceLimited` è uno stato controllato
GS-RUN-001 e diventa `insufficientResources` solo quando termina l'operazione.

Ogni operazione produce esattamente un terminale fra `succeeded`,
`insufficientData`, `cancelled` e `failed`. Progressi, preview, checkpoint e output
parziali non sono terminali e **NON DEVONO** essere persistiti o presentati come
completi. Un retry crea una nuova OperationID e riusa soltanto checkpoint verificati.

La mappatura concreta per Swift e CLI è normativa in
[GS-API-001](../api/README.md#8-tassonomia-delle-failure). Corruzione e invariant
violation non possono essere trasformate in un risultato vuoto o in un warning.

## 18.2 Logging

- Ogni operazione lunga **DEVE** avere un identificatore di correlazione.
- I log **DEVONO** distinguere livelli e categorie.
- Contenuti sensibili, query, estratti e path **DEVONO** essere redatti o omessi.
- Un log **NON DEVE** essere necessario per determinare programmaticamente l'esito di un'operazione.
- Diagnostica e metriche **DEVONO** avere overhead misurato e configurabile.
- Le app Apple **DEVONO** usare il sistema unified logging tramite `Logger`, con subsystem, categorie e livelli stabili.
- Ogni interpolazione **DEVE** dichiarare una privacy coerente; testo, prompt e path dell'utente restano privati o omessi.
- Le fasi costose **DEVONO** esporre intervalli `OSSignposter` correlabili con operazione, cancellazione e risultato.
- Metriche di produzione **NON DEVONO** introdurre telemetria di terzi senza una decisione privacy esplicita.
- La baseline 0.1 **NON DEVE** trasmettere log o metriche. Un bundle diagnostico
  esportato volontariamente **DEVE** mostrare l'inventario, applicare redazione e
  consentire ispezione prima della condivisione.
- `GlifiDiagnostics` **DEVE** essere l'unica facciata autorizzata sopra Unified
  Logging; app e librerie **NON DEVONO** creare logger, signposter o messaggi liberi.
- Eventi, categorie e nomi signpost **DEVONO** essere allowlist tipizzate. Valori
  ammessi dichiarano privacy; contenuto, query, prompt, estratti, path, URL e nomi
  file sono omessi, non semplicemente redatti.
- Xcode Organizer **DEVE** essere il primo canale per metriche aggregate di campo.
  La 0.1 **NON DEVE** sottoscrivere MetricKit o conservare payload diagnostici.
- Il contratto macOS completo è [GS-APL-014](../apple/14-osservabilita-e-telemetria-macos.md).

## 18.3 Recupero

Interruzione, crash o cancellazione **NON DEVONO** lasciare un progetto apparentemente valido ma semanticamente parziale. Scritture critiche **DEVONO** usare transazioni, file temporanei con sostituzione atomica o un protocollo equivalente documentato.

Il recovery `.glifi` segue GS-DAT-001: il manifest è il commit point, staging
incompleti non sono generazioni valide e una riparazione non inventa dati. Retry
riusa soltanto checkpoint con ID, input, schema e checksum coerenti. La UI conserva
il lavoro valido e distingue retry, nuova revisione, apertura read-only e recupero
da generazione precedente.
