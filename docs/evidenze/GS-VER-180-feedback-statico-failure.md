<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-180 — Feedback statico delle failure

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-180 |
| Tipo | Evidenza di correzione e verifica statica |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro statico |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-180; RQ-058; RQ-063; RF-073; TV-071; CMP-180 |

## Perimetro e identità

L'incremento aggiunge a `Scripts/quality-static.sh` i controlli esistenti
`check-failure-taxonomy.py` e `check-failure-messages.py`, già presenti in
`Scripts/verify.sh`. La tassonomia e i cataloghi non cambiano. Tutti i controlli
statici preesistenti restano attivi. GS-DEV-002 è aggiornato alla versione 1.5.0,
preservando le modifiche concomitanti relative ai profili macOS.

La verifica riguarda RQ-058 e RF-073, con TV-071 e clausola CMP-180;
RQ-063 è coperto dalla [GS-DOR-180](../pianificazione/dor-controlli-statici-failure.md)
registrata Ready prima del coding. La copia di lavoro parte da
`a86a53b512bd777f191c89692e0c573a3d37a3ff` e comprende le modifiche locali
concomitanti. Gli esiti non sono riferiti al solo commit di base né attestano CI
remota o revisioni successive.

## Ambiente

| Componente | Valore osservato |
| --- | --- |
| Sistema, `sw_vers` | `ProductName: macOS`; `ProductVersion: 27.2.1`; `BuildVersion: 26B131` |
| Shell, `zsh --version` | `zsh 5.9 (arm64-apple-darwin26.0)` |
| Python selezionato | Python 3.12.14, già installato tramite mise |
| Eseguibile Python | `/Users/gpicchiarelli/.local/share/mise/installs/python/3.12.14/bin/python3` |
| Python del PATH iniziale | `/usr/bin/python3`, Python 3.9.6 |
| Esecutore e data | Codex, 2026-11-21 |

I valori del sistema sono riportati come restituiti dagli strumenti, senza
dedurne equivalenza con i target Xcode. Questa verifica statica non invoca Swift,
Xcode o build applicative.

## Procedura e risultati positivi

1. `zsh -n Scripts/quality-static.sh`: superato.
2. Prima esecuzione di `make quality-static` con il PATH iniziale: interrotta in
   `check-fixtures.py`, prima dei due controlli aggiunti, perché Python 3.9.6 non
   supporta `zip(strict=True)`. Il prerequisito Python 3.10 o successivo è
   dichiarato in GS-DEV-001.
3. Ripetizione con l'interprete già installato, senza modifiche al Python di
   sistema o al PATH globale:

   ```sh
   PATH="/Users/gpicchiarelli/.local/share/mise/installs/python/3.12.14/bin:$PATH" make quality-static
   ```

   Esito `0`: tutti i controlli statici superati, compresi **120 siti** conformi
   alla tassonomia, **11 categorie** con messaggio di ripiego e **20 chiavi**
   localizzate emesse da GlifiKit.
4. `git diff --check -- Scripts/quality-static.sh docs/loop-di-sviluppo-e-qualita.md`:
   superato.

## Controlli negativi e confronto prima/dopo

Un programma Python di verifica ha copiato con `shutil.copy2` i file restituiti
da `git ls-files --cached --others --exclude-standard -z` in una directory
temporanea separata, senza hardlink, e vi ha inizializzato un repository Git
locale. La baseline dello snapshot ha superato `make quality-static`.

La fixture sintetica aggiunta soltanto nello snapshot è
`Packages/GlifiCore/Sources/GlifiKit/GlifiStaticFailureFixture.swift`:

```swift
// SPDX-License-Identifier: BSD-3-Clause
import GlifiCore

private func glifiStaticFailureFixture() -> GlifiFailure {
    GlifiFailure(
        code: "synthetic.static-failure",
        category: .invalidInput,
        operation: .importText,
        retryDisposition: .never,
        retainedState: .unchanged,
        messageKey: "failure.synthetic.untranslated"
    )
}
```

Nel secondo caso il solo valore `retryDisposition` diventa `.afterCorrection`,
valido per `.invalidInput`, così il controllo dei messaggi viene raggiunto.
Entrambe le versioni della fixture terminano con una nuova riga. Il loop
precedente è la copia esatta di `Scripts/quality-static.sh` ottenuta con
`git show HEAD:Scripts/quality-static.sh` alla revisione di base indicata sopra.
Il programma alterna soltanto le due versioni del loop e le due fixture nello
snapshot; i controlli reali restano attivi, senza sostituzioni o stub.

| Fixture | SHA-256 dei byte UTF-8 |
| --- | --- |
| Retry `.never` | `580cd19042e2ab4ed1f7499b3b958028751b457269bb43b260d72d4dd9942490` |
| Retry `.afterCorrection` | `547104e870006a54cb7c5519f7f690f6cbeeedcf18885735c8a9010643f8af15` |

| Caso | Loop aggiornato | Loop precedente |
| --- | --- | --- |
| Snapshot senza fixture sintetica | Exit `0`, tutti gli statici superati | Non ripetuto |
| `.invalidInput` con retry `.never` | Exit di `make` `2`; `retryDisposition .never non ammesso per .invalidInput` | Exit `0`, difetto non rilevato dal loop |
| Retry valido e chiave `failure.synthetic.untranslated` | Exit di `make` `2`; `chiave emessa da GlifiKit senza messaggio: failure.synthetic.untranslated` | Exit `0`, difetto non rilevato dal loop |

In entrambi i casi negativi il loop aggiornato si interrompe prima di
`check-swift-dialect.py` e non stampa il messaggio finale di successo. Il secondo
caso attraversa il controllo di tassonomia prima di fallire sui messaggi.
Nessun sorgente originale è stato mutato e non sono state eseguite build.

## Pulizia ed evidenze conservate

Lo snapshot comprendeva **707 percorsi candidati** e **11.563.406 byte** di
sorgenti copiati. La directory temporanea, le fixture sintetiche e i metadati Git
locali sono stati eliminati automaticamente all'uscita dal contesto Python.
La misura descrive i byte delle copie rimosse: non è una misura dello spazio
libero effettivamente recuperato sul filesystem.

Questa evidenza conserva procedura, fixture, diagnostica ed esiti. Lo snapshot e
i log intermedi rigenerabili non sono conservati.

## Limiti ed esito

**Superato nel perimetro statico**: il loop rapido rileva due regressioni che
prima richiedevano il gate completo. La verifica riguarda i contratti già
controllati dai due script; non estende la loro copertura ad altre forme di
costruzione delle failure o a messaggi generati dinamicamente.

Il coordinatore ha eseguito `make verify` sulla composizione corrente il
2026-11-21, con Python 3.12.14, cache e temporanei dedicati: exit di `make` 2.
Repository, segreti, toolchain, configurazione GitHub e naming superati; arresto
in `check-docs.py` perché i documenti concomitanti `dor-riassunto-macos.md` e
`dor-completamento-algoritmi.md` condividono `GS-DOR-168`, e il secondo manca dei
marker `outcome e confini` e `**Ready`. Anche la ripetizione di
`make quality-static` sulla composizione si arresta sugli stessi documenti.

Le prove statiche positive e negative sopra riguardano lo snapshot dichiarato;
questa evidenza non attesta il gate completo sulla composizione in evoluzione.
Il gate va ripetuto dopo la stabilizzazione dei documenti concomitanti. Non
dimostra comportamento GUI, comprensibilità dei messaggi, accessibilità,
VoiceOver, prestazioni, build macOS/iPadOS, dispositivi reali o chiusura di G4.

Un successivo `check-docs.py` non segnala più la collisione di ID, ma resta
bloccato sui due marker mancanti nel DoR degli algoritmi. I controlli mirati
finali di compliance, tassonomia e messaggi sono superati: 120 siti, 11 categorie
e 20 chiavi. I temporanei dedicati al tentativo del gate sono stati rimossi;
la diagnostica utile è conservata in questa evidenza.

## Chiusura del gate dopo la stabilizzazione documentale

La ricognizione GS-VER-184 ha risolto i marker documentali che bloccavano il
primo lotto. Il successivo `make verify` globale del coordinatore termina con
exit 0 sulla composizione finale: 347 test Core, 52 Kit, 36 macOS, oracoli, CLI,
22 checkpoint recovery, due PDF/A-2u e build Debug/Release delle due piattaforme.
Il preflight macOS su snapshot identico è anch'esso superato. Gli esiti finali
e i limiti sono registrati in [GS-VER-182](GS-VER-182-runtime-eventi-macos.md);
i blocchi precedenti restano sopra come risultati storici delle prime prove.
