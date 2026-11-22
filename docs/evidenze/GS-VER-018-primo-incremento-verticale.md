<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-018 — Primo incremento verticale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-018 |
| Tipo | Evidenza di verifica funzionale e cross-platform |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-002, TV-003, TV-040, TV-052 e TV-073 |

## Ambito

- identificatori UUID opachi, tipizzati, namespaced e serializzabili;
- acquisizione bounded di un file TXT, UTF-8 strict con BOM opzionale, sorgente
  immutata e digest SHA-256;
- tokenizzazione italiana `it-token-v1` con intervalli UTF-8 half-open,
  componenti, frasi e classi speciali;
- profilo deterministico di caratteri, frasi, token, type e frequenze;
- stessa operazione attraverso GlifiCore, GlifiKit e app macOS/iPadOS;
- CLI `status` testuale e JSON conforme a `cliProtocolVersion = 1`;
- stati UI localizzati `it`/`en` per vuoto, caricamento, pronto ed errore.

## Procedura

1. eseguire i test Swift in scratch directory esterna al workspace;
2. confrontare tutti gli otto casi seed italiani con offset, surface, classe,
   componenti e sentence boundary esatti;
3. verificare input con BOM, UTF-8 malformato, limite byte, file mancante,
   determinismo, ordinamento e sostituibilità del tokenizer;
4. eseguire il contratto CLI testuale e JSON;
5. compilare Debug e Release degli schemi macOS e iPadOS senza firma;
6. eseguire l'intero `make verify`.

## Risultato osservato

- 23 test Swift complessivi superati, inclusi 20 GlifiCore e 3 GlifiKit;
- gli otto casi `Fixtures/Linguistics/it-v1/token-boundaries.json` coincidono
  esattamente con l'implementazione sugli offset UTF-8;
- import non valido e risorse mancanti producono failure tipizzate e localizzabili
  senza path o contenuto del corpus;
- `GlifiCLI` conserva lo smoke storico e produce l'envelope JSON canonico atteso;
- entrambi gli schemi Xcode condivisi compilano su Xcode 27 con Apple Swift 6.4;
- il gate completo `make verify` termina con esito positivo.

## Limiti

Questa evidenza non promuove l'intero GS-LNG a corpus gold. Mancano split bloccati,
review annotatori, lemma/POS/NER, soglie e rapporto di deriva. Il profilo iniziale è
bounded a 64 MiB e in-memory: streaming, package `.glifi`, SQLite, SpanMap di
normalizzazione, indice, QueryAST e recovery restano da implementare.

Markdown è decodificabile dal confine di ingestion, ma il profilo viene rifiutato
fail-closed finché non esiste una trasformazione visibile con SpanMap esatto. La UI
espone quindi soltanto TXT. Build automatica non sostituisce audit VoiceOver,
tastiera, dispositivi fisici, benchmark o studio con utenti.

## Esito

**Superato localmente per il primo percorso TXT bounded e per la sua integrazione
GlifiCore → GlifiKit → Xcode.** Le funzioni persistenti e scientifiche ulteriori
restano bloccate dai rispettivi gate.

