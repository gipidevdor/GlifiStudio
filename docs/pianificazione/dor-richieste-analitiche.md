<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Richieste analitiche riproducibili in GlifiKit e CLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-162 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-01 |
| Approvazione | Prosecuzione esplicita dell'ambito RF-087 |
| Riferimenti | RF-087; RQ-060; RQ-063; GS-API-001; ADR-0032 |

## Contratto di ingresso

| Voce | Decisione pronta |
| --- | --- |
| outcome e confini | Riproduzione degli operatori RF-087 in memoria via GlifiKit e CLI |
| failure semantics | Tassonomia esistente, stato unchanged, nessun risultato parziale |
| tracciabilità | TV-088, CMP-162, GS-API-002 e GS-VER-162 nello stesso cambiamento |


Estendere gli operatori headless già verificati a una richiesta Swift tipizzata e
al comando CLI `text-analysis --request`, senza duplicare gli algoritmi.
Trasporto JSON versionato e transitorio: nessun nuovo formato di progetto,
persistenza, backend, dipendenza o modifica di app/planner.

Ogni risultato conserva ordine, variante, stato di validazione per metodo e SHA-256
della richiesta canonica con default risolti e seed. Nessuna promozione scientifica
deriva dal solo trasporto.

Input limitato a 1 MiB, profondità 32 e collezioni aggregate bounded; chiavi
sconosciute/duplicate, valori non finiti, versioni incompatibili e file speciali
falliscono con tassonomia esistente e senza divulgare testo o path nelle failure.
Il calcolo lascia l'actor chiamante e propaga cancellazione. Output scientifico
esplicito può contenere vocabolario, codici e ID forniti dal chiamante.

## Accettazione e verifica

Fixture sintetiche condivise per tutte le operazioni, confronto completo CLI/Kit
con tolleranza numerica dichiarata, round trip canonico, default/seed UInt64,
cancellazione, input ostili, privacy delle failure e separazione stdout/stderr.
Eseguire test mirati e `make verify`, registrando esiti effettivi in GS-VER-162.
Preservare modifiche concorrenti e usare directory temporanee e cache dedicate.

**Ready** prima del primo cambiamento implementativo.
