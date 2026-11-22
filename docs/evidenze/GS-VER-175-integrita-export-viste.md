<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-175 — Integrità degli export delle viste scientifiche

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-175 |
| Tipo | Evidenza di verifica degli export scientifici |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con agenti concorrenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Più milestone complementari richieste dall'iniziatore |
| Riferimenti | GS-DOR-175; GS-VIZ-001; GS-MET-001-22; RF-084; RQ-028; RQ-044 |

## Perimetro e fiducia

Tre milestone sul verificatore del bundle CSV/JSON/manifest v1 esistente:
struttura dell'inventario, coerenza della provenance con la specifica e
corrispondenza della tabella esportata.
Le firme e l'autenticazione dell'origine non fanno parte del contratto: senza
un digest esterno fidato non è possibile distinguere una riscrittura coerente
dell'intero bundle. Il verificatore non certifica il progetto esterno corrente.

## RED e verifica mirata

La DoR precede il codice. Due test falliscono sul verificatore precedente con
**exit 1 e 14 issue**, in 0,012 s: dieci contraddizioni di identità/conteggi/
riduzione/layout/caveat e quattro casi di record duplicati, media type errati,
ordine non canonico e percorso alternativo. Prima delle mutazioni viene
verificato il bundle originale, costruito attraverso DTO e builder pubblici.

Dopo l'implementazione **sette test Kit sono passati con exit 0**, in 0,022 s
nell'esecuzione congiunta. Le altre cinque funzioni coprono CSV modificato con
digest aggiornato, specifica contraddittoria con digest aggiornato, JSON malformato,
CSV non UTF-8, righe corte, identità duplicate e numeri non finiti. Il confronto
dei digest da solo non intercetta le contraddizioni fra payload coerentemente
rihashati; il controllo della specifica e la rigenerazione del CSV le rifiutano.

I test di compatibilità usano i quattro builder attuali: fattori, dendrogramma,
rete e tabella delle collocazioni. Il dendrogramma ha tre foglie e due righe di
fusione; la rete comprende anche mark per gli archi; una vista fattoriale con
esclusioni dichiarate ha meno osservazioni visibili senza una riduzione.
Rimangono validi campi opachi, generazione zero, software storico, frazioni UTC,
offset zero, JSON formattato diversamente e CSV con Unicode, virgolette e newline.

## Contratto implementato

Inventario esatto e ordinato dei due payload canonici, media type, dimensioni e
SHA-256; decodifica della specifica e uguaglianza dei campi di provenance condivisi.
Le tabelle sono rettangolari, gli identificatori locali sono unici e i numeri
rappresentati sono finiti. Non viene imposta una biezione universale fra mark,
righe e conteggio delle osservazioni: la semantica dipende dalla famiglia.

Il CSV deve coincidere con il profilo deterministico del writer v1 già esistente.
Writer, schema e API non cambiano; non è un importatore generico di ogni CSV
semanticamente equivalente. Il JSON viene invece decodificato semanticamente,
senza imporne la stessa spaziatura o disposizione delle chiavi.

Rifiuto tramite `visual-export.integrity-failed`, categoria `corruption`, operazione
`export` e retry `never`, già presenti. Nessuna nuova dipendenza o promozione
scientifica, nessuna attestazione di audit grafico o dispositivo.

## Gate finale

Il gate sull'albero aggiornato è condiviso con
[GS-VER-174](GS-VER-174-betweenness-cammini-estremi.md): test Core, Kit e nativi,
oracoli, CLI e recovery sono passati. L'esito globale è concluso con exit 0,
incluse le build Debug/Release macOS e iPadOS.

I [riscontri portabili del lotto](allegati/GS-VER-174-176-riscontri.json) conservano
conteggi, digest, controlli negativi e osservazioni con contesa, senza dati personali.
