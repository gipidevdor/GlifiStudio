<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-336 — Catalogo da tastiera e stato accessibile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-336 |
| Tipo | Regressione di interazione e revisione della semantica accessibile |
| Versione | 1.0.0 |
| Stato | Superato nel profilo automatico macOS; audit interattivo distinto |
| Responsabile | Codex con revisione separata della presentazione |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di perfezionare UX e UI |
| Riferimenti | GS-DOR-336; GS-UI-001; GS-APL-003; GS-UX-001-13; CMP-336 |

## Difetto riprodotto e correzione

Invio nella ricerca degli strumenti privilegiava il singolo metodo trovato
anche in presenza di strumenti corrispondenti. Nel caso concreto `PageRank` sono
visibili il metodo e lo strumento Operatori: la scelta automatica era ambigua. Il resolver estratto è lo stesso chiamato dalla UI.
La regressione precedente al fix fallisce con quattro issue: tre combinazioni
ambigue e la ricerca PageRank reale. Il summary nativo registra cinque definizioni,
tre superate e due fallite.

Il resolver corretto ammette un unico risultato complessivo; zero o più
risultati conservano il catalogo. Il testo localizzato mostra conteggio e
istruzione coerente con Invio o con la scelta esplicita. I controlli, gli stili
e i colori restano nativi e semantici. I test coprono anche risultati unici
di entrambe le famiglie, risultati assenti e più elementi nella stessa famiglia.

## Nome, valore e annunci degli errori

La barra diagnostica sovrascriveva il nome accessibile dei valori con il solo
nome di ruolo. Ora gli argomenti mantengono anche il valore effettivo, e lo
stato del motore distingue checking e ready con valore localizzato.

Una nuova failure produce `AccessibilityNotification.Announcement` con il
solo messaggio localizzato. La scelta fra chiave specifica e fallback di
categoria è condivisa con il testo visibile. Non vengono annunciati payload,
argomenti, progressi ordinari o completamenti generici; non cambia il focus.
`onChange` non annuncia lo stato iniziale di una vista ricreata. L'API è stata
verificata nel SDK locale, disponibile da macOS 14/iOS 17, sotto il target 27.

## Verifica e limiti

Il build esplorativo macOS è superato. Il Mac bloccato ha impedito l'avvio
interattivo mediante il tool desktop: nessuna ispezione visiva, prova da
tastiera reale o audit VoiceOver viene dichiarata in questa evidenza.
L'integratore ha eseguito le regressioni native e il gate finale sui sorgenti
congelati; gli esiti sono riportati nell'
[allegato](allegati/GS-VER-336-verifica.json).

La revisione dei modifier non sostituisce Accessibility Inspector, VoiceOver,
Voice Control, contrasto, pseudo-lingua, destra-sinistra o studi con persone.
Nessuna promozione G4/G5 o verifica iPadOS è implicita. Non cambiano API,
algoritmi, dati, permessi, formati o dipendenze di prodotto.

## Chiusura automatica macOS

Le regressioni native mirate sono verdi: 18 definizioni / 22 esecuzioni.
`make verify` è superato in **503,55 s** sulla fase immutabile precedente
`4ca2364b5295b759dacffaa131c37240578fec8a20ea36c34056dfbdba3c2484`.
Dopo il fix della macro Make e la normalizzazione del solo formato del catalogo
(con dati JSON identici), `make verify-app-store` è superato in **810,27 s**:
include nuovamente il gate completo, analisi e archivio macOS senza firma.
La suite comprende 782 definizioni Core, 169 Kit e 65 BDD; il report richiede
8 feature, 122 scenari e 697 passaggi. I nativi confermano 144 definizioni e
435 esecuzioni, senza failure o skip; i controlli cache sono 16.

I **609 input controllati** hanno fingerprint finale SHA-256
`5ea8f0cc9877bc94349db307cd2279654b50c6e2b9a99d3b4a42ee0627bb4c1a`,
immutato alla chiusura. Il log `make-verify-app-store.log` ha SHA-256
`cc6bfe43eceeaf582993ee30b354a969617b17b594b404fb18b144e2bf7f4ebb`.
Gli allegati distinguono la fase mirata, il primo gate e il preflight finale;
i manifest e i riepiloghi nativi sono nel dossier locale. Nessuna firma,
submission App Store, qualifica iPadOS o verifica assistiva manuale è attestata.
