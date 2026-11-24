<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Governo del progetto

Glifi Studio è inizialmente un progetto privato con governo leggero ma tracciabile. L'amministratore del repository svolge il ruolo di responsabile provvisorio finché i ruoli non vengono assegnati formalmente.

## Ruoli

- **Responsabile di prodotto**: approva visione, priorità, requisiti e rilascio.
- **Responsabile tecnico**: mantiene architettura, qualità tecnica e ADR.
- **Responsabile sicurezza e privacy**: valuta minacce, incidenti, dati e deroghe.
- **Maintainer**: revisiona e integra modifiche nel proprio ambito.
- **Contributore**: propone modifiche nel rispetto di standard e riservatezza.

Una persona può coprire più ruoli nella fase iniziale; ogni approvazione deve comunque rendere evidente quale responsabilità è stata esercitata.

## Decisioni

Le decisioni ordinarie vengono prese nella pull request. Le scelte durevoli o trasversali richiedono un ADR. Il responsabile tecnico accetta gli ADR tecnici; il responsabile di prodotto approva quelli che cambiano perimetro o contratto del prodotto; sicurezza e privacy hanno diritto di blocco motivato nel proprio ambito.

In caso di disaccordo, si registrano alternative, evidenze e conseguenze. Decide il responsabile della materia; se i ruoli non sono ancora assegnati, decide l'amministratore del repository e la decisione resta riesaminabile.

## Integrazione

`main` è la baseline integrata. L'integrazione avviene tramite pull request, con quality gate obbligatorio e almeno un'approvazione quando esiste un revisore diverso dall'autore. Nessuno approva una propria modifica in sostituzione della revisione disponibile.

Deroghe, bypass e modifiche d'emergenza devono essere motivati, limitati nel tempo e seguiti da verifica retrospettiva. La cronologia di `main` non viene riscritta.

## Rilasci e cambiamenti di visibilità

Solo il responsabile di prodotto autorizza un rilascio. Solo il titolare del repository può modificarne visibilità, licenza, proprietà o accessi. Il passaggio a repository pubblico richiede l'audit descritto nella [guida dedicata](docs/repository/passaggio-a-pubblico.md).
