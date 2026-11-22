# SPDX-License-Identifier: BSD-3-Clause
# Oracolo di GlifiTermWeightingTests (GS-MET-001-07): varianti TF, IDF, normalizzazioni di riga
# e BM25-v1, calcolati con formule indipendenti sulla matrice densa con una riga vuota.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))),
                 "common.R"))
X <- matrix(c(2, 1, 0, 0,
              1, 3, 1, 0,
              1, 0, 0, 4,
              0, 0, 0, 0), 4, byrow = TRUE)
rowmax <- function(M) apply(M, 1, max)
safe <- function(M) { M[!is.finite(M)] <- 0; M }
tf <- list(
  RAW = X,
  BINARY = (X > 0) * 1,
  L1 = safe(X / rowSums(X)),
  MAX = safe(X / rowmax(X)),
  AUGMENTED = ifelse(X > 0, 0.5 + 0.5 * X / rowmax(X), 0),
  SUBLINEAR = ifelse(X > 0, 1 + log(X), 0)
)
for (k in names(tf)) emit(paste0("TF_", k), as.vector(t(tf[[k]])))
N <- nrow(X); df <- colSums(X > 0)
idf_u <- log(N / df); idf_s <- log((N + 1) / (df + 1)) + 1
emit("IDF_UNSMOOTHED", idf_u); emit("IDF_SMOOTH", idf_s)
W1 <- sweep(tf$SUBLINEAR, 2, idf_u, "*"); n1 <- sqrt(rowSums(W1^2))
emit("TFIDF_SUBLINEAR_UNSMOOTHED_L2", as.vector(t(safe(W1 / n1))))
W2 <- sweep(tf$AUGMENTED, 2, idf_s, "*"); n2 <- rowSums(abs(W2))
emit("TFIDF_AUGMENTED_SMOOTH_L1", as.vector(t(safe(W2 / n2))))
bm25 <- function(q, k1, b) {
  len <- rowSums(X); avg <- mean(len)
  idf <- log(1 + (N - df + 0.5) / (df + 0.5))
  sapply(1:N, function(d) sum(sapply(q, function(t) {
    f <- X[d, t]; if (f == 0) 0 else idf[t] * f * (k1 + 1) / (f + k1 * (1 - b + b * len[d] / avg))
  })))
}
emit("BM25_IDF", log(1 + (N - df + 0.5) / (df + 0.5)))
emit("BM25_Q13_STANDARD", bm25(c(1, 3), 1.2, 0.75))
emit("BM25_Q24_K2_B0", bm25(c(2, 4), 2, 0))
