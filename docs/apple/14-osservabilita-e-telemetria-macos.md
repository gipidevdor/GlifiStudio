<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Osservabilità e telemetria macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-014 |
| Tipo | Standard applicativo Apple |
| Versione | 1.0.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0017 |

## Scopo

Questo documento governa esclusivamente eventi diagnostici, log, signpost,
metriche operative e loro eventuale uscita dal dispositivo nell'app macOS. Non
definisce la cronologia dell'indagine, le metriche scientifiche né i dati di
prodotto.

## Confine approvato per la 0.1

La baseline è **senza telemetria gestita dall'app**:

- Glifi Studio **NON DEVE** incorporare SDK analytics, crash reporting o session
  replay proprietari o di terzi;
- l'app **NON DEVE** creare identificatori di installazione o dispositivo per
  correlare eventi;
- log, crash, signpost e metriche **NON DEVONO** essere caricati verso endpoint
  Glifi Studio o di terzi;
- il target **NON DEVE** acquisire entitlement di rete per finalità diagnostiche;
- la dichiarazione App Store e `PrivacyInfo.xcprivacy` **DEVONO** restare allineati
  all'assenza di raccolta dati;
- ogni futura raccolta richiede requisito, finalità, base privacy, minimizzazione,
  retention, threat model, aggiornamento delle dichiarazioni e un nuovo ADR.

La proprietà `GlifiTelemetryPolicy` rende interrogabili questi divieti dal codice.
La allowlist delle dipendenze esterne e dei framework collegati è vuota nella 0.1:
il quality gate respinge ogni nuovo package remoto, framework binario o gestore di
dipendenze, oltre a `MetricKit` sottoscritto, rete applicativa e logging non
centralizzato. Un framework Apple o package futuro entra nell'allowlist soltanto
insieme a requisito, ADR e verifica applicabili; una denylist di vendor è solo
difesa aggiuntiva e non costituisce prova di conformità.

## Diagnostica Apple di produzione

`Xcode Organizer` è il canale primario per crash, hang, launch, memoria, scritture
su disco ed energia delle build distribuite. I dati sono aggregati e resi
disponibili da Apple per i dispositivi partecipanti; l'app non aggiunge codice di
raccolta, endpoint o identità. L'accesso in App Store Connect/Xcode **DEVE** seguire
minimo privilegio e i risultati **DEVONO** essere trattati come campioni, non come
una misura completa della popolazione.

`MetricKit` è disponibile su macOS 27, ma la 0.1 **NON DEVE** registrare un
subscriber: nello scaffold attuale non esiste un'esperienza locale che renda i
payload utili alla persona, né una retention necessaria. L'adozione è ammessa solo
se un requisito dimostra l'azione locale prodotta dal dato; i report restano sul
dispositivo, con persistenza limitata, nessun upload automatico ed export
volontario ispezionabile.

## Unified Logging

Il solo ingresso autorizzato è `GlifiDiagnostics`, basato su `Logger`, con
subsystem stabile `studio.glifi.GlifiStudio` e categorie allowlist:

| Categoria | Scopo | Livello ordinario |
| --- | --- | --- |
| `lifecycle` | Avvio, disponibilità e transizioni di processo | `info` |
| `runtime` | Profilo risorse, admission e cancellazione | `info` / `notice` |
| `performance` | Signpost delle sole fasi costose | signpost |
| `recovery` | Integrità, rollback e riparazione futura | `error` / `fault` solo se appropriato |

Altri moduli **NON DEVONO** istanziare `Logger`, `OSLog`, `OSSignposter`, usare
`print` nell'app o accettare messaggi diagnostici liberi. Gli eventi sono enum
tipizzati e le stringhe di formato sono statiche.

### Classificazione dei valori

| Dato | Regola |
| --- | --- |
| Stato enum, codice errore stabile, profilo risorse | Può essere pubblico se non deriva dal corpus |
| Conteggio o durata | Solo se necessario; preferire bucket e nessuna correlazione persistente |
| Operation ID | Opaco, effimero, non derivato da path, contenuto o identità |
| Nome file, path, bookmark, URL, titolo, autore | Omettere; non basta marcarlo private |
| Testo, query, estratto, token, prompt, finding | Vietato nei log e nei signpost |
| Identificatore personale, hardware seriale, account | Vietato |

Ogni interpolazione ammessa **DEVE** dichiarare `privacy` esplicitamente. La
redazione Apple è difesa ulteriore, non autorizzazione a registrare contenuto. I
livelli `error` e `fault` si usano con parsimonia perché possono aumentare costo e
persistenza; cancellazione, dati insufficienti e pressione gestita non sono fault.

## Signpost

`OSSignposter` usa la categoria `performance` e nomi statici. Le fasi riservate
sono `ImportSources`, `ExtractText`, `Tokenize`, `BuildIndex`, `RunQuery` e
`RunInference`. Un intervallo **DEVE** avere una sola coppia begin/end, ID generato
dal signposter e nessun metadato del corpus. Il wrapper **DEVE** preservare risultato
ed errori dell'operazione misurata.

I signpost servono a Instruments e non sono KPI persistenti, progress UI o lineage.
Nuovi nomi entrano nell'allowlist insieme al flusso costoso che misurano.

## Diagnostica esportabile

La 0.1 non espone un bundle diagnostico. Prima di introdurlo sono obbligatori:

1. generazione soltanto su azione esplicita;
2. inventario visibile e preview prima della condivisione;
3. allowlist dei campi, redazione verificata e divieto di fonti/query/path;
4. limite di dimensione e finestra temporale;
5. file temporaneo nel container, cleanup e nessun invio automatico;
6. test con canary sensibili che devono risultare assenti.

## Gate di conformità

- audit statico con allowlist di package/framework, import, endpoint, `print` e
  istanze OSLog;
- test della policy `GlifiTelemetryPolicy` e del wrapper dei signpost;
- confronto fra privacy manifest, binario, dichiarazione App Store e dipendenze;
- ispezione Console/Instruments con corpus canary prima di ogni release candidate;
- riesame Organizer per regressioni tra versioni, registrando campione e limite.

Riferimenti Apple: [Logging](https://developer.apple.com/documentation/os/logging),
[OSLogPrivacy](https://developer.apple.com/documentation/os/oslogprivacy),
[OSSignposter](https://developer.apple.com/documentation/os/ossignposter),
[MetricKit](https://developer.apple.com/documentation/metrickit),
[performance delle app distribuite](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-shipping-app)
e [privacy manifest](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).
