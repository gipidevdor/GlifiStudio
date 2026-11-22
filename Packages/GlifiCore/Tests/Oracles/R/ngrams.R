# SPDX-License-Identifier: BSD-3-Clause
# Oracolo di GlifiNGramFrequencyTests (GS-MET-001-04 § Frequenze filtrate e n-grammi): conteggi,
# document frequency, frequenze relative sul denominatore prima dei filtri ed esclusioni per filtro.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))),
                 "common.R"))
docs <- list(c("la", "casa", "è", "bella", "la", "casa"), c("una", "casa", "bella"),
             c("la", "città", "è", "grande"))
chars <- function(form, n, padded) {
  g <- strsplit(if (padded) paste0("_", form, "_") else form, "")[[1]]
  if (length(g) < n) character(0) else sapply(1:(length(g) - n + 1),
                                              function(i) paste(g[i:(i + n - 1)], collapse = ""))
}
words <- function(d, n) if (length(d) < n) character(0) else
  sapply(1:(length(d) - n + 1), function(i) paste(d[i:(i + n - 1)], collapse = " "))
stat <- function(units, keys) {
  all <- unlist(units); df <- sapply(keys, function(k) sum(sapply(units, function(u) k %in% u)))
  cnt <- sapply(keys, function(k) sum(all == k))
  c(length(all), cnt, df, cnt / length(all))
}
tri <- lapply(docs, function(d) unlist(lapply(d, chars, n = 3, padded = TRUE)))
emit("NGRAM_CHAR3_PADDED", stat(tri, c("_ca", "cas", "asa", "sa_", "_è_", "ll")))
bi <- lapply(docs, words, n = 2)
emit("NGRAM_WORD2", stat(bi, c("casa bella", "la casa", "una casa", "è bella")))
# Stopword {la, è}: esclusi i bigrammi che le contengono; distinti e righe rimaste.
keys <- unique(unlist(bi)); has <- sapply(strsplit(keys, " "), function(p) any(p %in% c("la", "è")))
emit("NGRAM_WORD2_STOPWORDS", c(length(keys), sum(has), sum(!has)))
# Forme: minimumLength 4, minimumCount 2, maximumDocumentProportion 0,6 (nell'ordine dichiarato).
forms <- unique(unlist(docs)); cnt <- sapply(forms, function(f) sum(unlist(docs) == f))
df <- sapply(forms, function(f) sum(sapply(docs, function(d) f %in% d)))
len <- nchar(forms); ex_len <- len < 4; ex_cnt <- !ex_len & cnt < 2
ex_prop <- !ex_len & !ex_cnt & df / 3 > 0.6
emit("NGRAM_FORM_FILTERS", c(length(forms), sum(ex_len), sum(ex_cnt), sum(ex_prop),
                             sum(!ex_len & !ex_cnt & !ex_prop)))
