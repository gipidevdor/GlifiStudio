<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Leggere, raccogliere e concludere

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-18 |
| Tipo | Specifica dell'esperienza di studio documentale |
| Versione | 1.1.0 |
| Stato | Definito; usabilità con utenti da validare |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di mettere al centro contenuto e conclusioni |
| Documento padre | [GS-UX-001](README.md) |
| Riferimenti | ADR-0048; GS-DOR-344; GS-API-007; RQ-030; RQ-032; RQ-037 |

## Compito e gerarchia

La persona studia documenti importanti per formulare conclusioni verificabili.
La vista Studio si apre su una lettura dominante. Il titolo della fonte e il
contenuto prevalgono sulle impostazioni. Una breve guida nello stato vuoto
invita a scegliere una fonte; non impone di configurare algoritmi o categorie.

Il percorso principale è **leggere → raccogliere passaggi → scrivere conclusioni**.
«Raccogli passaggio» agisce sulla selezione nativa e ne mostra il testo prima
della registrazione. Il taccuino è un pannello richiesto dalla persona, con
sezioni «Passaggi» e «Conclusioni». Ogni passaggio offre «Vai alla fonte»;
una conclusione può rimandare a più passaggi. Il confronto si attiva su richiesta,
con due letture identificate e chiusura chiara. Su spazio ridotto il contenuto
si riorganizza senza comprimere il testo a dimensioni illeggibili.

## Dettagli progressivi e fiducia

Gruppi, riordino, provenienza tecnica e associazione all'indagine sono controlli
secondari. Digest e offset non sono moduli da compilare nel percorso ordinario.
I titoli della persona non alterano le citazioni. Le conclusioni sono dichiarate
come testo personale, distinto dai risultati calcolati. La fonte originale
rimane archiviata e verificabile. Per PDF il lettore usa il documento originale;
la raccolta dal testo estratto conserva coordinate verificabili, senza promettere
un'evidenziazione geometrica non disponibile.

Le azioni completate del taccuino vengono salvate come revisioni prima di
dichiararne il successo. L'editor di una conclusione distingue la bozza dal
testo salvato e offre Salva/Annulla; lo stato di salvataggio resta leggibile.
Non si perdono bozze in modo silenzioso cambiando fonte o
vista. Una failure non sostituisce la lettura valida con un risultato parziale;
risposte tardive da una fonte precedente non cambiano il contesto corrente.

Se Studio viene aperto durante un'altra operazione, inizializza il taccuino e la
lettura quando il progetto torna disponibile. Ricaricare dopo modifiche di
un'altra finestra conserva titolo e testo dell'editor, riconcilia i passaggi e i
gruppi ancora disponibili e segnala i collegamenti rimossi. Un estratto eliminato
non può risultare salvato tramite un'operazione vuota: l'editor conserva la bozza
e spiega come copiare il titolo o recuperare il passaggio.

## Accessibilità e verifica

La selezione con mouse ha un'alternativa accessibile per frasi o caratteri,
raccolta in un dettaglio dedicato. Tutte le azioni hanno etichette localizzabili,
accesso da tastiera, focus comprensibile e colori di sistema. Confronto e fonte
restano riconoscibili senza affidarsi al solo colore. Il testo conserva copia,
selezione e navigazione native. La configurazione linguistica di analisi resta
italiana; l'internazionalizzazione dell'interfaccia non aggiunge altre lingue.

Test di modello, selezione Unicode, build e audit visivo sono prove distinte.
VoiceOver, Voice Control, tastiera completa, contrasto, pseudo-lingua e
destra-sinistra devono essere registrati per quanto realmente eseguito.
L'intuitività richiede osservare persone rappresentative leggere, raccogliere,
concludere e tornare alla fonte: nessun conteggio di test certifica da solo
questo risultato.
