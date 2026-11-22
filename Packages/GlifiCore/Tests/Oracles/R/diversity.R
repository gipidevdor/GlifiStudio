# SPDX-License-Identifier: BSD-3-Clause
# Oracolo di GlifiLexicalDiversityTests (GS-MET-001-04, MTLD-bidirectional-v1): implementazione
# indipendente di McCarthy e Jarvis (2010), con fattore parziale sulla coda e media delle due
# direzioni; Inf quando i fattori sono zero.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))),
                 "common.R"))
mtld_dir <- function(x, tau) {
  factors <- 0; seen <- character(0); n <- 0
  for (w in x) {
    n <- n + 1; seen <- union(seen, w)
    if (length(seen) / n <= tau) { factors <- factors + 1; seen <- character(0); n <- 0 }
  }
  if (n > 0) factors <- factors + (1 - length(seen) / n) / (1 - tau)
  if (factors == 0) Inf else length(x) / factors
}
mtld <- function(x, tau = 0.72) mean(c(mtld_dir(x, tau), mtld_dir(rev(x), tau)))
set.seed(11)
A <- strsplit("a b a c a b d a e b a c f a b a", " ")[[1]]
B <- sample(letters[1:6], 200, replace = TRUE)
C <- rep("x", 7)
emit("MTLD_A", c(mtld_dir(A, 0.72), mtld_dir(rev(A), 0.72), mtld(A)))
emit("MTLD_A_TAU05", mtld(A, 0.5))
emit("MTLD_B", mtld(B))
emit("MTLD_B_TOKENS", match(B, letters))
emit("MTLD_C", mtld(C))
