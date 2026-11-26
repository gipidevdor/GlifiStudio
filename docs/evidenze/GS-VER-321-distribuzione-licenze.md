<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-321 — Distribuzione e verifica delle licenze

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-321 |
| Tipo | Verifica correttiva della distribuzione |
| Versione | 1.0.0 |
| Stato | Superato localmente su macOS |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di revisione licenze e correttezza |
| Riferimenti | GS-DOR-321; GS-VER-318; GS-VER-319; GS-VER-320; GS-VER-323; CMP-321 |

## Perimetro

LICENSE e THIRD_PARTY_NOTICES.txt sono risorse esplicite dei target applicativi.
Il verificatore del bundle macOS confronta i byte distribuiti con gli originali.
Il controllo dell'inventario verifica schema, percorsi, copertura di manifest,
workflow, immagini e font, fonti HTTPS e avvisi dichiarati. I digest vincolano
anche tutti gli avvisi, compresa l'attribuzione della fonte linguistica;
non decide la titolarità dei diritti, non cerca automaticamente codice copiato e non certifica assenza di
brevetti o altri vincoli legali.

## Verifica mirata

I nove test del verificatore passano e coprono inventario valido, nuovi
manifest/workflow/immagini/font non inventariati, input modificati dopo la
review, stato non revisionato, avvisi assenti/vuoti o modificati, percorsi
esterni o inesistenti, ID duplicati e symlink esterni. Il corpus esterno non
può evitare i controlli di provenienza cambiando il proprio ID: l'identità
attesa deriva dal catalogo chiamante. Il checker verifica hash del testo,
titoli delle pagine e revisioni distinte con relativi permalink.

La review incrociata ha riprodotto i falsi successi per ID mutato e avviso
vuoto prima della correzione; entrambi hanno una regressione nel gate.
Il self-test Xcode passa con 25 fixture negative, inclusa la rimozione di
ciascuno dei due testi legali; Config/Licenses è navigabile senza membership
nei target. La verifica integrata macOS è registrata nella sezione seguente.

## Verifica della composizione

`make verify` macOS termina con exit 0 in 533,242 secondi: 752 test Core,
164 Kit, 133 definizioni native e 420 esecuzioni, senza failure, skip o avvisi
runtime nel report nativo. Passano 248 righe di oracoli, 64 casi Fraction,
due PDF/A-2u reali, 196 controlli CLI testuali e 132 operazioni con 264
confronti completi Kit/CLI. Restano invariati i 2840 elementi dell'inventario
pubblico; 172 varianti e 22 checkpoint di recovery sono verificati.

Il bundle Release supera anche il confronto dei testi legali. Cinque prove
su una copia temporanea del bundle reale verificano successo del bundle
integro e rifiuto di LICENSE e THIRD_PARTY_NOTICES.txt assenti oppure
alterati. La directory della prova e la sua cache moduli vengono eliminate.

La review indipendente della catena analitica conferma che il riuso di un
piano attraversa comunque le factory aggiornate: le nuove revisioni
numeriche producono nuovi nodeID e cambiano le dipendenze dell'interpretazione
anche quando i valori coincidono. Le letture esplicite degli oggetti storici
restano storiche; nessuna cache complessiva salta il ricalcolo degli step.

Anche `Scripts/check-app-store-packaging.sh --macos-only` termina con exit 0
in 483,484 secondi: analisi statica e archivio Release non firmato superati.
Il controllo dell'archivio conferma localizzazioni, metadati SDK e testi legali
identici agli originali. In entrambi i bundle si ispezionano 17 elementi e
si osservano zero corrispondenze nei percorsi o suffissi di sviluppo vietati.

La composizione congelata contiene 1318 file, base
`f95e4c463e7c99f17ee91ca155882a4c34553ff9`. Il fingerprint dei file esterni
a docs e CHANGELOG, inclusi codice, test, fixture e configurazione, è
`c701e8b65af5d2a35d4c60df093bebc9469d8b489be4642b711c4b041af6319e` e resta
identico dopo le verifiche. HEAD e indice non vengono modificati. I quattro
file gold linguistici restano byte-identici a HEAD; cambia soltanto la
documentazione dei rispettivi diritti. La fixture LR/FLR sostitutiva è
verificata separatamente in GS-VER-323.

Il [rapporto strutturato](allegati/GS-VER-318-323-verifica.json) conserva
conteggi, comandi, risorse, prove negative e limiti. Il dossier locale
`macOS-2026-11-26-licenses-correctness` conserva manifest, log e riassunti
sanificati; le sole evidenze documentali vengono chiuse dopo il gate.

La diagnostica IDELaunchSession/placeholder device appartiene a Xcode;
il report nativo registra zero avvisi runtime. Non è una submission App Store.

## Pulizia

Rimossa la cache di build posseduta dal lotto dopo misurazione `du`:
3.139.308 KiB, circa 2,994 GiB. Rimossi inoltre tredici temporanei residui
del lavoro, 73.744 byte, dopo aver conservato i log utili nel dossier; la
pulizia del benchmark numerico è registrata anche nell'allegato GS-VER-319.
Conservati toolchain installate, librerie R, veraPDF, sorgenti ed evidenze.
Il file di lock stabile resta presente secondo il contratto delle cache.

## Limiti

Gli avvisi non concedono diritti aggiuntivi sulle fonti. Le verifiche delle
fonti e le sostituzioni numeriche sono registrate separatamente in
GS-VER-318 e GS-VER-319; la correzione degli export in GS-VER-320.
Nessuna attestazione iPadOS, CI remota o approvazione G4/G5.

## Preparazione del commit

La base verificata resta `f95e4c463e7c99f17ee91ca155882a4c34553ff9`. Alla richiesta di commit e push,
la head remota è `84071b232ba79224a0f2818313a8be796e3803f4`: i due commit
hanno lo stesso albero Git (`aa81d5d8b32c43647e5bf010cceb45f71e8e6e67`).
Il branch di consegna parte dalla head remota attuale senza modificare i
614 file non documentali verificati; il fingerprint resta identico.
Non viene riscritta né reintrodotta la precedente cronologia remota.
