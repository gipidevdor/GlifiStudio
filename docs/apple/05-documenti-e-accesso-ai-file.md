# Documenti e accesso ai file

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-005 |
| Tipo | Standard applicativo Apple |
| Versione | 0.5.0 |
| Stato | Attivo |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-01 |
| Approvazione | Ciclo DocumentGroup `.glifi` introdotto; conflict/file provider da validare su dispositivo |

## Regole

- Importazione e apertura **DEVONO** passare attraverso picker o pannelli di sistema.
- Accesso persistente fuori dal container **DEVE** usare i meccanismi security-scoped previsti dalla piattaforma.
- Letture e scritture coordinate **DEVONO** rispettare modifiche esterne, provider di file e conflitti.
- Il salvataggio **DEVE** essere atomico o recuperabile e non lasciare un progetto dichiarato valido in stato parziale.
- L'inizializzazione **NON DEVE** rimuovere un package non vuoto, un file o un link simbolico.
  Un flag iniziale obsoleto non autorizza a ricreare un progetto già valido.
- Un'apertura fallita **DEVE** conservare utilizzabile la sessione precedente; l'accesso
  security-scoped acquisito **DEVE** durare quanto la sessione ed essere poi rilasciato.
- File ricevuti da provider esterni **DEVONO** essere considerati input non affidabili e validati prima dell'uso.
- Path visualizzato e identità persistente **NON DEVONO** coincidere.
- Cache ricostruibili **DEVONO** risiedere in collocazioni appropriate e non essere incluse nei backup senza necessità.
- Salvataggio naturale e ripristino **DEVONO** distinguere fonti, progetto,
  indagini, cronologia, artefatti autorevoli, cache e stato per-scena.
- Una persona **NON DEVE** essere obbligata a esportare manualmente ogni grafico per
  conservarne il finding; la persistenza segue il dominio dell'indagine.
- Le app **DEVONO** dichiarare `studio.glifi.project` conforme a `UTType.package` e
  usare un ciclo document-based SwiftUI coerente con GS-DAT-001.
- Lettura e serializzazione del package **NON DEVONO** eseguire I/O lungo sul
  Main Actor; autosave e conflitti mantengono generazioni verificabili.
- `DocumentGroup` e il Document API disponibile in Xcode 27 **DEVONO** essere
  prototipati contro multiwindow, file coordination, autosave e conflict handling;
  la scelta del protocollo Swift non cambia il formato `.glifi`.

Il contratto è [GS-DAT-001](../specifiche-di-design/02-dati-lineage-e-persistenza.md).
Riferimenti: [DocumentGroup](https://developer.apple.com/documentation/swiftui/documentgroup),
[FileDocument](https://developer.apple.com/documentation/swiftui/filedocument),
[Creating a document-based app](https://developer.apple.com/documentation/swiftui/creating-a-document-based-app)
e [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox).
