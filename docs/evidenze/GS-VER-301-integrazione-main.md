<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-301 — Integrazione della baseline e sincronizzazione Git

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-301 |
| Tipo | Evidenza di integrazione e verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente; limiti espliciti sotto riportati |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di commit, push, integrazione in main, eliminazione dei branch e allineamento remoto |

## Perimetro salvato

L'integrazione conserva il lavoro della copia principale, la baseline remota
`b5b0097`, i due checkpoint GUI e il completamento KH fino al commit `32b06f7`.
Le correzioni numeriche, i limiti, le identità canoniche e il refactoring remoti
sono mantenuti insieme alla GUI più recente e ai contratti CLI/Kit condivisi.
I checkpoint GUI precedenti sono conservati come antenati senza ripristinare
versioni di codice o documenti superate: questa topologia ha valore di recupero
e giustifica l'eccezione al normale squash prevista da GS-REP-002.

I riferimenti GUI sono consolidati nei documenti GS-VER-273/274 e GS-DOR-273/274;
GS-VER-234 continua a identificare la distinta riverifica di correttezza. Le
evidenze storiche restano limitate ai rispettivi checkpoint.

L'utente ha esplicitamente scelto di pubblicare lo snapshot salvato e conservare
separatamente il lavoro KH successivo ancora in corso. Quel worktree e i suoi
file sono preservati; le modifiche successive a `32b06f7` non sono presentate
come incluse o verificate da questa pubblicazione.

## Contratti e verifica

La risoluzione mantiene il trasporto dei limiti graph e i DTO completi di
profilo. Il controllo di parità espande anche le richieste KH annidate e
confronta i casi del compilatore con le fixture senza conteggi fissi. Lo
snapshot contiene 54 fixture per 36 tag testuali, inclusi 15 profili KH;
l'inventario pubblico aggiornato comprende 2.753 dichiarazioni.

Il gate conclusivo `make verify` è terminato con **exit 0** sul commit
`9959f92c3b7fb9c77184c1b6c5b6537dfb29134e`, poi pubblicato su `main`.
Il profilo selezionato è **solo macOS**, con build iPadOS differite, secondo
il target predefinito del repository. Ambiente: Xcode 27.2, Apple Swift 6.4.2,
macOS 27.2.1 e Python 3.14.10 nel PATH della verifica.

- **611 definizioni Core e 140 Kit** superate.
- **113 definizioni native macOS e 345 esecuzioni**, zero failure e zero skip;
  test Debug e build Release completati.
- **130 operazioni standalone e 260 confronti integrali CLI/Kit**, 51 rifiuti
  e due controlli del formato esplicito d'importazione superati.
- **54 fixture, 165 controlli CLI testuali, 36 tag e 2.753 dichiarazioni
  pubbliche** verificati dal compilatore e dal controllo di parità.
- **219 riferimenti numerici indipendenti, 64 casi Binary64 con Fraction**,
  22 checkpoint di recupero dopo terminazione del processo, QueryAST CLI,
  controlli statici, documentali e formattazione superati.

L'integrazione registra quattro nuovi riferimenti indipendenti delle scale KH.
La fixture positiva edge betweenness usa 1.024 celle per il nuovo accumulatore
esatto; la prova negativa a 128 celle continua a verificare il rifiuto tipizzato,
senza modificare i limiti di produzione. Due switch GUI rifiutano esplicitamente
il payload KH estraneo al rispettivo laboratorio.

I **519 input di programma** confrontati prima della pubblicazione coincidono
con quelli salvati per il gate. Identità del codice, fingerprint, riepilogo
sanificato dei test e conservazione dei worktree sono nell'
[allegato strutturato](allegati/GS-VER-301-verifica-integrazione.json).
Il commit conclusivo aggiorna soltanto questa evidenza e l'allegato.

## Limiti dell'evidenza

La validazione PDF/A-2u indipendente è **saltata perché veraPDF è assente**.
Xcode segnala CoreSimulator 1171.7.0 precedente al 1174.21.0 richiesto; questo
avviso non impedisce le verifiche macOS completate. Build iPadOS e prove su
dispositivo o simulatore iPadOS non sono incluse in questa esecuzione.
I risultati attestano lo snapshot salvato e i casi esercitati; non estendono
le evidenze storiche né chiudono le funzionalità KH successive ancora in corso.

## Pubblicazione e conservazione

GitHub ha rifiutato il primo push per la protezione dell'email privata. Soltanto
i commit nuovi non pubblicati sono stati ricreati con l'indirizzo pubblico
`noreply` dell'account; nessun force push o riscrittura remota.

I quattro branch remoti storici sono stati rimossi dopo la prova di inclusione
in `origin/main`; il branch temporaneo è stato rimosso dopo il push della
baseline verificata. L'elenco locale e `git ls-remote --heads origin`
contengono **soltanto `main`**. Anche i tre branch locali dei checkpoint GUI e
KH sono stati eliminati dopo aver conservato i worktree sullo stesso commit.

I worktree utili restano disponibili in stato detached. Il confronto dei file
prima e dopo il distacco conferma che le modifiche KH in corso sono rimaste
invariate. Cache e temporanei di questa integrazione sono stati rimossi dopo
aver conservato l'evidenza; la misura prima della rimozione è **1.670.056 KiB
(circa 1,59 GiB)**. Toolchain, dipendenze attive e file delle altre sessioni
sono conservati.

Nel controllo conclusivo sono comparse 242 copie locali con suffisso ` 2`:
241 identiche al file canonico e una identica alla precedente versione di
questa evidenza, già nel commit `8a1683d`. Nessuna contiene lavoro unico.
La provenienza non è determinata; tutte le copie sono conservate fuori dal
repository. Il controllo statico ripetuto dopo questo spostamento e il lint Swift
sono superati.
