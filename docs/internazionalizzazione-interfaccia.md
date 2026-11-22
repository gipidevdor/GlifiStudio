# Internazionalizzazione dell'interfaccia

| Campo | Valore |
| --- | --- |
| Identificatore | GS-I18N-002 |
| Tipo | Specifica di internazionalizzazione dell'interfaccia |
| Versione | 0.3.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Decisione | [ADR-0005](adr/0005-interfaccia-internazionalizzabile.md) |

## Obiettivo

Le app Glifi Studio devono adattare lingua e formattazione alle preferenze della piattaforma senza modificare codice, motore o dati persistenti. L'italiano è la lingua sorgente, non un vincolo dell'interfaccia.

## Baseline

| Aspetto | Decisione |
| --- | --- |
| Lingua sorgente | Italiano (`it`) |
| Localizzazioni iniziali | Italiano (`it`) e inglese (`en`) |
| Selezione lingua | Impostazioni di sistema o dell'app gestite dalla piattaforma |
| Risorse | Catalogo Xcode condiviso `Localizable.xcstrings` |
| Identità delle stringhe | Chiavi semantiche stabili |
| Fallback | Valore della lingua sorgente italiana |

## Regole

- Ogni testo dell'interfaccia, compresi nomi e valori accessibili, **DEVE** provenire dal catalogo condiviso.
- Le chiavi **DEVONO** descrivere il significato e **NON DEVONO** usare il testo tradotto come identità.
- Frasi traducibili **NON DEVONO** essere costruite concatenando frammenti localizzati.
- Quantità, date, durate, unità e liste **DEVONO** usare API di formattazione sensibili al locale.
- Testo proveniente dai documenti dell'utente **NON DEVE** essere tradotto né confuso con il testo dell'interfaccia.
- Lingua dell'interfaccia e lingua dell'analisi **DEVONO** essere configurazioni indipendenti.
- Aggiungere una lingua **NON DEVE** richiedere modifiche a GlifiCore, GlifiKit o ai formati persistenti.
- Layout e controlli **DEVONO** tollerare espansione del testo, pluralizzazione e direzioni di scrittura future.
- Intenzioni, stati, tipi di finding/caveat e azioni **DEVONO** avere identificatori
  semantici indipendenti dalle frasi localizzate secondo GS-UX-001-14.
- Le formulazioni deterministiche **DEVONO** usare chiave, argomenti tipizzati e
  unità; non possono essere costruite concatenando frammenti o numeri preformattati.
- Una traduzione **NON DEVE** cambiare negazione, direzione, solidità, categoria
  epistemica o caveat di un finding.
- Route, comandi, Selection, componenti e stati GS-UI-001 **DEVONO** usare ID
  canonici e argomenti tipizzati indipendenti dal catalogo localizzato.

## Flusso per una nuova stringa

1. definire una chiave semantica nel catalogo;
2. fornire il valore sorgente italiano;
3. fornire o marcare esplicitamente le traduzioni previste dal rilascio;
4. usare la chiave tramite le API localizzabili SwiftUI;
5. verificare accessibilità, testo lungo e almeno italiano e inglese.
6. per findings e caveat, verificare la corrispondenza con la struttura canonica e
   la comprensione della formulazione.

## Verifica automatica

`Scripts/check-localization.py` verifica lingua sorgente, chiavi richieste, completezza italiana e inglese, inclusione del catalogo nei due target e impostazioni Xcode. Le build macOS e iPadOS compilano lo stesso catalogo come parte del quality gate.
