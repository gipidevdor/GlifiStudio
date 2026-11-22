# Accessibilità della build candidata

| Campo | Valore |
| --- | --- |
| Identificatore | GS-AS-005 |
| Tipo | Piano di verifica accessibilità App Store |
| Versione | 1.2.0 |
| Stato | Pianificato |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Criterio

Una caratteristica di accessibilità può essere dichiarata in App Store Connect
soltanto quando tutti i compiti comuni applicabili sono completabili con quella
caratteristica. La valutazione è distinta per macOS e iPadOS e riguarda la build
candidata, non la sola presenza di etichette nel codice.

## Audit minimo

- VoiceOver: ordine, ruoli, nomi, valori, azioni, aggiornamenti e focus;
- Voice Control e Full Keyboard Access: ogni azione principale è raggiungibile;
- Dynamic Type/Larger Text: nessun contenuto essenziale troncato o sovrapposto;
- contrasto, Dark Mode, Differentiate Without Color e Increase Contrast;
- Reduce Motion e Reduce Transparency senza perdita informativa;
- touch target, puntatore, tastiera esterna e orientamenti iPad supportati;
- zoom e ridimensionamento finestre macOS;
- errori, progresso e cancellazione percepibili senza un singolo canale sensoriale;
- grafici, matrici, reti e timeline con descrizione, valori tabellari, focus e
  navigazione alla fonte senza dipendere dal solo colore o dalla posizione;
- primo percorso, profilo progressivo, planner, finding, caveat, confronto,
  cronologia e relazione completabili end-to-end;
- catena Conclusione → Evidenza → Fonti → Metodo e azioni equivalenti per ogni
  selezione visuale significativa;
- aggiornamenti progressivi senza perdita inattesa del focus o della posizione di
  lettura.

Accessibility Inspector aiuta l'audit ma non sostituisce prove manuali con
tecnologie assistive e utenti rappresentativi. Gli esiti confluiscono nella
dichiarazione macchina solo dopo approvazione.

## Riferimento

[Apple — Accessibility nutrition labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)
