# 15. Interfaccia, accessibilità e localizzazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-15 |
| Tipo | Capitolo normativo |
| Versione | 0.6.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

- Le interfacce macOS e iPadOS **DEVONO** seguire le Apple Human Interface Guidelines applicabili.
- Le funzioni principali **DEVONO** essere utilizzabili tramite tastiera.
- Controlli personalizzati **DEVONO** esporre ruolo, nome, valore e azioni accessibili.
- Gli stati di avanzamento **DEVONO** essere percepibili e le operazioni lunghe cancellabili quando consentito dal modello dei dati.
- Colore, animazione o posizione **NON DEVONO** essere l'unico mezzo per comunicare informazione essenziale.
- Testi visibili **NON DEVONO** essere incorporati nel codice in modo da impedire la localizzazione.
- Errori mostrati all'utente **DEVONO** spiegare conseguenza e possibile recupero senza perdere la causa strutturata interna.
- Dataset e test UI **DEVONO** includere testo multilingue, direzioni di scrittura applicabili e contenuto lungo.
- La baseline analitica iniziale **DEVE** applicare [GS-I18N-001](../localizzazione-italiana.md).
- L'interfaccia **DEVE** applicare [GS-I18N-002](../internazionalizzazione-interfaccia.md): italiano come lingua sorgente, chiavi semantiche, cataloghi condivisi e indipendenza dalla lingua dell'analisi.
- Layout e interazioni **DEVONO** applicare i profili Apple per [interfaccia adattiva](../apple/02-interfaccia-adattiva.md) e [accessibilità](../apple/03-accessibilita.md).
- Il paradigma, il modello mentale e la catena epistemica **DEVONO** applicare
  [GS-UX-001](../esperienza-utente/README.md).
- Route, scene, selezione, comandi, stati e componenti semantici **DEVONO**
  applicare [GS-UI-001](../specifiche-di-design/07-information-architecture-e-interazione.md).
- Grafici e tabelle analitiche **DEVONO** applicare
  [GS-VIZ-001](../specifiche-di-design/08-visualizzazione-scientifica.md), inclusa
  un'alternativa tabellare accessibile collegata allo stesso lineage.
- La navigazione primaria **DEVE** partire da indagine, intenzione e oggetto studiato;
  nomi degli algoritmi appartengono al dettaglio metodologico.
- Ogni finding **DEVE** rendere raggiungibili evidenza, fonti, metodo e caveat con
  progressive disclosure nella stessa esperienza.
- Ogni numero o segno significativo **DEVE** avere un'azione equivalente per mouse,
  touch, tastiera e VoiceOver e dichiarare la classe di lineage effettiva.
- Aggiornamenti progressivi **NON DEVONO** perdere focus, selezione o contesto senza
  una transizione percepibile.
- Un'etichetta di solidità **NON DEVE** derivare da un confidence score universale;
  richiede una policy scientifica specifica e versionata.
- L'interfaccia **DEVE** poter comunicare dati insufficienti senza trasformarli in
  errore tecnico o conclusione debole.
