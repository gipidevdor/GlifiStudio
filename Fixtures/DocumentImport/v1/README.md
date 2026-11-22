<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Fixture sintetiche per importazione documentale

PDF digitale di due pagine ed EPUB testuale con due risorse XHTML. Testi e
struttura sono originali e artificiali; non contengono corpus o opere di terzi.
Lo spine EPUB ordina b.xhtml prima di a.xhtml, diversamente dall'ordine ZIP.
`Scripts/build-rich-document-fixtures.py` ricostruisce i file con la sola libreria
standard Python. Nessun renderer, modello o dipendenza esterna è incluso.
