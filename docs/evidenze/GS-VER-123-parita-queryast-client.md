<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-123 — Parità della QueryAST fra GlifiCore, GlifiKit e CLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-123 |
| Tipo | Evidenza di contratto fra client |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task L2 di GS-DOR-005 |

## Ambito

RF-080 richiede che GUI, GlifiKit e GlifiCLI compilino ed eseguano la stessa QueryAST canonica
con lo stesso ordinamento. La catena di parità è verificata sulla fixture
`Fixtures/Query/v1/cases.json` (sette casi, due rifiutati):

1. `queryParityBetweenCoreAndKit` (GlifiKit): per ogni caso accettato il digest della sessione
   GlifiKit coincide con `canonicalDigest()` dell'AST di GlifiCore, gli intervalli coincidono nello
   stesso ordine con quelli del valutatore di GlifiCore e con quelli attesi dalla fixture; per i
   casi rifiutati entrambi i livelli falliscono con lo stesso codice (`query.regex-rejected`,
   `query.unknown-field`), che GlifiCore può sollevare in parsing o in validazione;
2. contract test CLI in `verify.sh`: `glifi query` produce, caso per caso, gli intervalli attesi,
   i codici di failure nell'envelope di errore e digest distinti per query distinte;
3. le app interrogano soltanto `GlifiStudioProjectSession.query` (le app non importano GlifiCore,
   controllo `check-architecture.sh`), quindi condividono lo stesso percorso di GlifiKit.

## Limiti

La parità della GUI è garantita dal percorso unico di GlifiKit e dal controllo architetturale,
non da un test di interfaccia su dispositivo (G4).

## Esito

**Superato localmente: QueryAST, digest, intervalli, ordine ed esiti di errore coincidono fra
GlifiCore, GlifiKit e CLI.**
