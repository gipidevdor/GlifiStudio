<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Accessibilità e validazione UX

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-13 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Criteri proposti; validazione con utenti non ancora eseguita |
| Documento padre | [GS-UX-001](README.md) |

## Accessibilità del lavoro analitico

L'accessibilità riguarda il completamento dell'indagine, non la sola presenza di
etichette. Una persona deve poter creare un progetto, importare fonti, comprendere
il profilo, avviare un piano, leggere un finding, valutarne caveat, raggiungere le
fonti, confrontare oggetti, conservare un risultato ed esportare una relazione con
le tecnologie assistive applicabili.

## Requisiti trasversali

- Ogni destinazione ha titolo, gerarchia e landmark comprensibili.
- Focus e posizione di lettura non vengono azzerati da aggiornamenti progressivi.
- Cambiamenti importanti, errori e completamenti sono annunciati tempestivamente
  senza produrre rumore continuo.
- Ogni azione tramite drag, hover, grafico o gesto ha equivalente accessibile.
- Findings, solidità e caveat non dipendono da solo colore, forma o posizione.
- Grafici offrono descrizione, riepilogo, dati tabellari, focus sui valori e Audio
  Graphs quando appropriato.
- Matrici e reti offrono navigazione strutturata, filtri e alternative testuali;
  migliaia di elementi non entrano come un'unica sequenza VoiceOver ingestibile.
- Dynamic Type o impostazioni di testo, contrasto, Reduce Motion, Reduce
  Transparency e Differentiate Without Color non eliminano contenuto essenziale.
- Tutti i flussi primari funzionano con tastiera e Full Keyboard Access.

Si applicano inoltre [GS-APL-003](../apple/03-accessibilita.md),
[GS-MET-001-22](../metodi-analitici/22-visualizzazioni-scientifiche.md) e il
[piano App Store](../app-store/05-accessibilita.md).

## Validazione human-centred

Il processo applica un profilo tailored di ISO 9241-210: comprendere contesto e
utenti, specificare bisogni e requisiti, produrre alternative, valutarle con persone
rappresentative e iterare. Un prototipo visualmente rifinito non costituisce prova
di usabilità o comprensione scientifica.

La matrice degli studi include almeno:

| Dimensione | Misura osservata |
| --- | --- |
| Efficacia | completamento corretto dei compiti e risultati recuperabili |
| Efficienza | tempo, passaggi, errori, richieste di aiuto e recuperi |
| Comprensione | interpretazione corretta di finding, incertezza e caveat |
| Calibrazione | fiducia coerente con la solidità mostrata, senza sovrainterpretazione |
| Provenienza | capacità di raggiungere evidenza, fonte e metodo corretti |
| Inclusione | completamento con VoiceOver, tastiera, testo grande e input applicabili |
| Soddisfazione | misura dichiarata e commento qualitativo, non sostituto dell'efficacia |

Soglie, campione, profili, compiti, ambiente e protocollo vengono approvati prima
del test. I risultati negativi producono requisiti o decisioni, non vengono mediati
in un punteggio composito che nasconda blocchi.

## Scenari minimi

1. comprendere una raccolta nuova senza configurare un algoritmo;
2. spiegare perché un'analisi è inclusa o non applicabile;
3. distinguere finding, evidenza e caveat;
4. risalire da un numero alla fonte corretta;
5. confrontare due gruppi senza scegliere preventivamente un test;
6. interpretare “dati insufficienti” senza scambiarlo per errore tecnico;
7. riprendere e diramare un'indagine;
8. produrre una relazione senza perdere attribuzione.

## Riferimenti

- [ISO 9241-210:2019](https://www.iso.org/standard/77520.html)
- [Apple Human Interface Guidelines — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple — VoiceOver evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria)
- [Apple — Audio graphs](https://developer.apple.com/documentation/accessibility/audio-graphs)
