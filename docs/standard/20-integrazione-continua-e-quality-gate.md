# 20. Integrazione continua e quality gate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-20 |
| Tipo | Capitolo normativo |
| Versione | 1.4.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 20.1 Equivalenza locale e remota

La CI **DEVE** invocare lo stesso ingresso versionato usato localmente. Una regola essenziale **NON DEVE** vivere soltanto nella configurazione del provider. `Scripts/verify.sh` è l'ingresso canonico della baseline corrente. Un job early-fail di controlli statici (docs, compliance, dialetto) **PUÒ** girare
su runner Linux quando non richiede Xcode. Un job early-fail di formattazione
Swift **DEVE** usare runner con Apple Swift della baseline. Nessuno dei due
**DEVE** sostituire `verify` né rinominare i check richiesti dalla ruleset.

Il loop locale rapido `make quality` **DEVE** restare un sottoinsieme non bloccante rispetto a `make verify`: utile per l'iterazione, insufficiente per l'integrazione. `make quality-static` **DEVE** coprire i soli controlli eseguibili senza Apple Swift/Xcode.

## 20.2 Gate sempre obbligatori

Ogni pull request e ogni revisione di `main` **DEVONO** verificare almeno:

1. struttura, portabilità, dimensione e policy del repository;
2. assenza di credenziali o materiale di firma rilevabili;
3. Xcode 27, Apple Swift 6.4 o successiva compatibile della serie 6, Swift 6
   language mode, SwiftPM tools 6.4 e strict concurrency completa;
4. denominazione, metadati, identificatori e link documentali;
5. confini architetturali, localizzazione e baseline Apple;
6. dialetto Swift e formattazione Swift;
7. unit e integration test disponibili;
8. smoke test headless;
9. build pulita Debug e Release di macOS e iPadOS senza firma.

Un controllo fallito **DEVE** bloccare l'integrazione salvo deroga valida. Disabilitare o indebolire il controllo per ottenere esito verde equivale a non conformità.

## 20.3 Gate condizionali

Coverage diventa obbligatorio quando esiste una soglia approvata. Benchmark e confronto con baseline diventano obbligatori quando cambia un hot path, un backend o l'uso delle risorse. Test UI/accessibilità, migrazione, robustezza, firma e notarizzazione diventano obbligatori quando la modifica introduce il relativo rischio o quando il gate di ciclo di vita li richiede.

Reference test, property test e riproducibilità diventano obbligatori quando viene
aggiunta o modificata una variante GS-MET. Una modifica della formula o dei valori
predefiniti **DEVE** fallire finché versione logica, fixture, requisiti e
tracciabilità non sono aggiornati.

L'assenza di un gate condizionale **DEVE** essere esplicita nello stato di adozione; non può essere rappresentata come controllo superato.

## 20.4 Isolamento e riproducibilità

- Build e test **DEVONO** partire da checkout pulito e configurazioni versionate.
- Il workflow **DEVE** dichiarare runner, timeout, permessi e politica di concorrenza.
- Dipendenze eseguibili **DEVONO** usare revisioni immutabili.
- CI di pull request **NON DEVE** ricevere segreti di rilascio.
- Cache e artefatti **DEVONO** avere chiavi, retention e contenuto definiti.
- La cache SPM **DEVE** usare una chiave deterministica derivata dal manifest e dai
  sorgenti del package, senza includere segreti o DerivedData firmati.
- Un rilascio **NON DEVE** dipendere da stato disponibile soltanto sulla macchina di uno sviluppatore.

## 20.5 Evidenze

Il provider conserva log per diagnosi con retention minima adeguata. Un'evidenza controllata registra comando, revisione, ambiente, risultato e limiti senza copiare log contenenti dati sensibili. I job richiesti dalla ruleset si chiamano `verify` e `app-store-baseline`. I job
early-fail `static-quality` e `format-check` sono aggiuntivi e non li sostituiscono.
