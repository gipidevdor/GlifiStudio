# 12. Standard di implementazione Swift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-12 |
| Tipo | Capitolo normativo |
| Versione | 0.5.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 12.1 Toolchain

- Versione di Xcode, Swift e SDK **DEVONO** essere dichiarate e riproducibili.
- Le versioni minime di macOS e iPadOS **DEVONO** essere definite prima di G2.
- Le impostazioni di compilazione rilevanti **DEVONO** essere mantenute nel repository.
- Warning nuovi nel codice modificato **DEVONO** essere risolti o derogati.
- Compilatore, modalità linguistica e versione degli strumenti SwiftPM **DEVONO**
  essere dichiarati separatamente; non sono identificatori intercambiabili.
- La baseline corrente **DEVE** usare Apple Swift 6.4 o una versione successiva
  compatibile della serie 6 fornita da Xcode 27, Swift 6 language mode e
  `swift-tools-version: 6.4`.
- Il controllo completo della concorrenza **DEVE** restare attivo. Una soppressione
  globale o l'uso della modalità Swift 5 richiede una deroga approvata.
- Feature sperimentali o upcoming language feature **NON DEVONO** essere abilitate
  globalmente senza requisito, verifica di compatibilità e decisione esplicita.

## 12.2 Formattazione

Il codice Swift **DEVE** essere formattato mediante `swift format` con configurazione `.swift-format` versionata. La versione del formatter **DEVE** essere compatibile con la toolchain e registrata. Il quality gate **DEVE** eseguire il formatter in modalità di controllo senza modificare i file. SwiftLint **NON DEVE** essere introdotto come seconda autorità stilistica. Il loop locale **DEVE** esporre `make format` (autofix) e `make lint`/`make format-check` (controllo strict), come definito da ADR-0020 e GS-DEV-002.

Le regole `.swift-format` obbligatorie, incluso il rifiuto di force unwrap/`try!`/IUO, **DEVONO** essere verificate da `Scripts/check-swift-dialect.py` oltre che dal lint del formatter.

## 12.3 Nomenclatura e API

- Le API **DEVONO** seguire le Swift API Design Guidelines.
- La chiarezza nel punto d'uso prevale sulla brevità.
- Tipi e protocolli usano `UpperCamelCase`; membri e funzioni usano `lowerCamelCase`.
- Abbreviazioni non convenzionali **NON DEVONO** apparire in nomi pubblici.
- I nomi **DEVONO** riflettere il glossario del dominio.
- Ogni simbolo pubblico **DEVE** avere documentazione DocC sufficiente a comprenderne contratto, errori e complessità non ovvia.

## 12.4 Visibilità e semantica

- Si usa il livello di accesso più restrittivo compatibile con il requisito.
- Le entità valore **DOVREBBERO** usare value semantics.
- Le entità con identità persistente **DEVONO** rendere l'identità esplicita.
- La scelta tra `struct`, `class` e `actor` **DEVE** derivare da semantica, ownership e isolamento.
- Lo stato globale mutabile **NON DEVE** essere introdotto.

## 12.5 Opzionali, errori e invarianti

- Force unwrap, `try!` e cast forzati **NON DEVONO** apparire in percorsi di produzione che trattano input o stato fallibile.
- Un uso eccezionale è ammesso soltanto per un'invariante locale evidente, documentata e testata.
- Gli errori di dominio **DEVONO** essere strutturati; stringhe destinate all'utente non sono il contratto dell'errore.
- Gli errori **NON DEVONO** essere ignorati silenziosamente.
- Input esterni **DEVONO** essere validati; violazioni di invarianti interne **DEVONO** emergere durante lo sviluppo.

## 12.6 Concorrenza

- Si usa Swift Concurrency con concorrenza strutturata.
- Task non strutturati e detached **DEVONO** avere ownership, motivazione e gestione della cancellazione documentate.
- Ogni operazione lunga **DEVE** osservare la cancellazione a intervalli proporzionati al lavoro.
- Confini `Sendable` e isolamento **DEVONO** compilare senza sopprimere avvisi in modo indiscriminato.
- `@unchecked Sendable` **DEVE** includere una motivazione e test delle invarianti di sincronizzazione.
- Un actor **NON DEVE** essere usato come rimedio automatico a un modello dati non progettato.

## 12.7 Prestazioni e memoria

- Copie di buffer grandi **DEVONO** essere intenzionali e misurate.
- Proprietà o API con costo non ovvio **DEVONO** documentare la complessità.
- Hot path **NON DEVONO** creare allocazioni per elemento senza giustificazione misurata.
- Codice `unsafe`, puntatori e memory mapping **DEVONO** essere isolati dietro API sicure, documentare precondizioni e possedere test mirati.
- Interoperabilità con buffer Accelerate, Metal o Core ML **DEVE** rendere esplicite ownership, durata, stride, alignment, precisione e copie.
- Availability check e feature detection **DEVONO** precedere l'uso di API o capacità non universali nella matrice supportata.
- Conditional compilation **DEVE** confinare differenze reali di piattaforma e non duplicare regole di dominio.

## 12.8 Implementazioni scientifiche

- Un tipo o protocollo pubblico **DEVE** riferirsi alla variante GS-MET applicabile.
- Valori predefiniti capaci di cambiare il risultato **DEVONO** essere risolti nel
  descrittore, non nascosti nell'implementazione.
- Precisione, conversioni, ordine delle riduzioni, `NaN`, infinito, overflow e
  underflow **DEVONO** seguire la politica numerica del metodo.
- Un backend Accelerate, BNNS, Core ML o Metal/MPS **NON DEVE** ridefinire formula,
  zero implicito, tie-break o caso degenere.
- PRNG, seed e derivazione dei sottoseed **DEVONO** essere iniettati e testabili;
  casualità globale implicita è vietata nei risultati riproducibili.
