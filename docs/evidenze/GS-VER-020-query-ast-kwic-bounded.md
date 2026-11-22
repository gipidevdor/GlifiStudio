<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-020 — QueryAST e KWIC bounded

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-020 |
| Tipo | Evidenza di verifica funzionale, API e sicurezza query |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-003, TV-007, TV-053, TV-060 e TV-073 |

## Ambito

- algebra `QueryAST v1` tipizzata, tagged Codable, JSON canonico e identità
  SHA-256;
- parser `glifi-query-v1` con precedenza, AND implicito, escaping, phrase/slop,
  prossimità, range, campi e diagnostica a intervalli UTF-8;
- validazione indipendente dei limiti anche per AST costruiti
  programmaticamente;
- ricerca su forma, normalizzazione italiana e testo tokenizzato, operatori
  booleani, phrase e prossimità;
- sottoinsieme regex su token compilato in NFA bounded, privo di backtracking,
  gruppi, alternanze, backreference e quantificatori annidati;
- concordanze KWIC con SourceRevisionID, offset half-open, contesto configurabile,
  ordinamento canonico e troncatura esplicita;
- esecuzione sulla generazione `.glifi` verificata attraverso lo stesso percorso
  GlifiCore, GlifiKit e GlifiCLI JSON v1.

## Procedura

1. verificare precedenza, escaping, Unicode, round-trip AST e digest canonico;
2. forzare i limiti di byte, profondità, nodi, phrase, prossimità, regex,
   fonti, scan, risultati e contesto;
3. confrontare match, superfici e offset per termini, phrase, booleani,
   prossimità e regex sul seed italiano;
4. rifiutare campi senza capability e pattern con forme di backtracking;
5. creare un package, incorporare due fonti, interrogarne la generazione e
   verificare ordine e lineage;
6. ripetere create/import/query mediante GlifiCLI e controllare l'envelope e gli
   offset JSON;
7. eseguire `make verify`, incluse fixture, controlli repository e build
   Debug/Release macOS e iPadOS.

## Risultato osservato

- 39 test Swift complessivi superati: 35 GlifiCore e 4 GlifiKit;
- il parser produce lo stesso AST/digest dopo round-trip canonico e rifiuta input
  oltre i limiti con failure tipizzata;
- il valutatore conserva la superficie fonte e gli offset UTF-8, senza accesso
  laterale allo store;
- il pattern avversario `(a+)+` viene rifiutato dal sottoinsieme regex;
- il contratto CLI trova le due occorrenze attese della fixture alle posizioni
  `[4, 7)` e `[8, 11)` nella generazione uno;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

Lo scan corrente è deliberatamente bounded e non sostituisce l'indice persistente.
Lemmi, POS, entità, metadati, range tipizzati, scope Project/Corpus, DocumentID,
cursor, ranking, streaming e spiegazioni complete restano non disponibili e
falliscono esplicitamente. La fixture è un seed sintetico, non un fuzz corpus o una
baseline prestazionale; deadline, cancellazione sotto carico e dispositivi fisici
richiedono evidenze dedicate.

## Esito

**Superato localmente per il confine QueryAST/parser, lo scan testuale bounded, le
concordanze KWIC e la parità GlifiKit/GlifiCLI dichiarata.** Non promuove l'intero
sistema di ricerca GS-QRY a feature complete.
