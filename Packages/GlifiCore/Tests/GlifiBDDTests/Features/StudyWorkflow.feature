# language: it
# SPDX-License-Identifier: BSD-3-Clause
# Original Italian fixture; the stored quote always refers to the original UTF-8 source.

@GS-CMP-332 @GS-CMP-344 @macos @study-workflow
Funzionalità: Gli estratti di studio conservano il testo originale e il lavoro personale
  Estratti, note, gruppi, ordine e confronto appartengono al progetto.
  Ogni citazione torna alla revisione e ai byte verificati della fonte.

  @phase-nominal
  Scenario: Lo stato di studio vuoto è disponibile nel progetto con fonti italiane
    Dato un progetto di studio con una fonte italiana originale
    Quando richiedo lo stato di studio tramite la CLI reale
    Allora lo studio contiene zero estratti note gruppi e selezioni di confronto

  @phase-nominal
  Schema dello scenario: Le operazioni di studio condividono il risultato nativo e quello CLI
    Dato la variante di studio "<variante>" su citazioni italiane originali
    Quando eseguo la variante di studio in fase nominale
    Allora il risultato di studio coincide con l'API nativa e con i fatti JSON <attese>
    E lo studio riaperto conserva contenuto e provenienza senza nuove scritture

    Esempi:
      | variante | attese |
      | saveState | {"revision":1,"notes.$count":1,"groups.$count":1,"order.$count":1} |
      | collect | {"revision":1,"excerpts.$count":1,"excerpts.0.anchor.quote":"La casa guarda il fiume."} |
      | resolve | {"excerpt.anchor.quote":"La casa guarda il fiume."} |
      | export | {"schema":"studio.glifi.study-export","schemaVersion":1,"state.excerpts.$count":1} |
      | original | {"$has:sourceRevisionID":true,"$has:contentDigest":true} |

  @phase-invalid-input
  Schema dello scenario: Ogni operazione di studio rifiuta parametri sconosciuti senza modifiche
    Dato la variante di studio "<variante>" su citazioni italiane originali
    Quando eseguo la variante di studio in fase JSON-invalido
    Allora lo studio fallisce con codice "command.unknown-field" e categoria "invalidInput" senza scritture

    Esempi:
      | variante |
      | state |
      | saveState |
      | collect |
      | resolve |
      | export |
      | original |

  @phase-pre-cancelled
  Schema dello scenario: Ogni operazione di studio precancellata conserva il progetto
    Dato la variante di studio "<variante>" su citazioni italiane originali
    Quando eseguo la variante di studio in fase precancellata
    Allora lo studio fallisce con codice "command.cancelled" e categoria "cancelled" senza scritture

    Esempi:
      | variante |
      | state |
      | saveState |
      | collect |
      | resolve |
      | export |
      | original |

  @study-complete-workflow
  Scenario: Due passaggi sostengono una conclusione e ritrovano fonti e ordine dopo riapertura
    Dato un progetto di studio con una fonte italiana originale
    Quando raccolgo due passaggi originali e li collego a note gruppi ordine e confronto
    Allora il taccuino conserva citazioni esatte e conclusioni personali distinte dalle fonti
    Quando riapro lo studio e torno alle fonti dei due passaggi
    Allora revisioni digest intervalli e byte originali coincidono con quelli raccolti
    E gli export JSON e Markdown sono riproducibili e rispettano l'ordine del taccuino

  @study-optimistic-conflict
  Scenario: Una bozza obsoleta non sostituisce lo studio già salvato
    Dato la variante di studio "resolve" su citazioni italiane originali
    Quando tento di salvare una revisione di studio superata
    Allora il conflitto ottimistico conserva lo studio e l'intero progetto

  @study-anchor-integrity
  Scenario: Citazione digest e coordinate alterati non diventano nuovi estratti autorevoli
    Dato la variante di studio "resolve" su citazioni italiane originali
    Quando tento di riscrivere citazione digest e coordinate dell'estratto raccolto
    Allora ogni anchor alterata è rifiutata e la fonte originale resta verificata

  @study-reference-integrity
  Scenario: Note gruppi ordine e confronto non ammettono riferimenti pendenti
    Dato la variante di studio "resolve" su citazioni italiane originali
    Quando propongo riferimenti di studio mancanti o più di due passaggi in confronto
    Allora nessun riferimento invalido modifica estratti note o progetto

  @study-project-identity
  Scenario: Uno studio esportato non attraversa l'identità di un altro progetto
    Dato la variante di studio "resolve" su citazioni italiane originali
    Quando ripristino lo stato in un progetto diverso con gli stessi byte sorgenti
    Allora il progetto destinatario rifiuta lo stato e conserva la propria identità

  @study-native-cancellation
  Scenario: Le API native di studio precancellate conservano il contesto completo
    Dato la variante di studio "resolve" su citazioni italiane originali
    Quando precancello ciascuna delle sei API native di studio
    Allora ogni cancellazione è tipizzata e non scrive una nuova generazione

  @study-restored-grapheme-boundary
  Scenario: Un ripristino con hash valido non può spezzare un grafema della fonte
    Dato la variante di studio "resolve" su citazioni italiane originali
    Quando ripristino una nuova anchor con hash valido che divide un emoji composto
    Allora il ripristino rifiuta il grafema spezzato senza modificare lo studio
