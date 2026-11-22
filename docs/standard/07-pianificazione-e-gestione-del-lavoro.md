# 7. Pianificazione e gestione del lavoro

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-07 |
| Tipo | Capitolo normativo |
| Versione | 0.2.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 7.1 Unità di lavoro

Ogni modifica non puramente editoriale **DEVE** essere associata a un'unità di lavoro identificabile. L'unità deve indicare:

- problema o opportunità;
- risultato atteso;
- requisiti e concern interessati;
- criteri di accettazione;
- rischi e dipendenze;
- responsabile e stato.

## 7.2 Definition of Ready

La Definition of Ready è un gate di ingresso al coding, non una dichiarazione di
completezza del prodotto. Prima del primo cambiamento implementativo sostanziale,
l'unità di lavoro **DEVE** registrare la seguente scheda:

| Voce | Evidenza minima | Quando può essere `N/A` |
| --- | --- | --- |
| outcome e confini | risultato osservabile, esclusioni e criterio di stop | Mai |
| requisiti | ID GS-SRS e criteri di accettazione verificabili | Mai |
| contratto di dominio/API | aggregate, invarianti, ownership, lifecycle e versioni | Solo modifica puramente interna senza confine |
| failure semantics | categorie, retry, cancellazione e stato che resta valido | Mai per I/O, async, persistenza o pipeline |
| esperienza prevista | flusso, stati vuoto/loading/failure/recovery e accessibilità | Solo componente headless senza effetto utente |
| verifica | test, fixture/oracolo, evidence ID candidato e gate | Mai |
| dati e migrazione | schema, lineage, compatibilità, commit/recovery | Solo se nessun dato entra, cambia o persiste |
| sicurezza/privacy | confini GS-SEC, input non fidati, dati, privilegi e abuse case | Mai; l'assenza di nuovi rischi va dichiarata |
| prestazioni/sistema | complessità, ResourceBudget, I/O, energia e benchmark | Solo se l'impatto è dimostrabilmente trascurabile |
| tracciabilità | riga nella matrice di conformità con stato iniziale | Mai |
| decisioni | ADR applicabili o questione aperta con owner | Se non esiste scelta architetturale nuova |

Ogni `N/A` **DEVE** avere una motivazione riesaminabile. Stato ammesso:

- `Ready`: tutte le voci obbligatorie possiedono evidenza;
- `Ready con rischio accettato`: solo incognite non bloccanti hanno owner, termine e
  rollback; non sostituisce una deroga richiesta dallo standard;
- `Non ready`: manca almeno un contratto che può cambiare risultato, dati,
  sicurezza, UX o strategia di prova.

Una feature `Non ready` può ricevere spike time-boxed che non entra nel prodotto.
Il suo codice resta separato e non stabilizza API/formati. La pull request **DEVE**
riportare lo stato DoR e il controllo di conformità deve poter collegare requisito,
specifica, codice, test, fixture, evidenza e gate. Il maintainer non può usare
l'urgenza come `N/A`.

## 7.3 Priorità

Il progetto usa le seguenti priorità:

- `Must`: necessario per la baseline o il rilascio indicato;
- `Should`: valore elevato, differibile soltanto con motivazione;
- `Could`: opzionale entro capacità disponibile;
- `Won't in scope`: escluso esplicitamente dal perimetro indicato.

La priorità **NON DEVE** essere dedotta dalla numerazione o dalla forza normativa del requisito.
