# SPDX-License-Identifier: BSD-3-Clause
# Oracolo di GlifiAgreementExtensionsTests: fisher.test, Krippendorff sulla matrice di
# coincidenze (implementazione R indipendente) e Fleiss.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
emit("FISHER", c(fisher.test(matrix(c(3, 1, 1, 3), 2))$p.value,
                 fisher.test(matrix(c(3, 1, 1, 3), 2), alternative = "greater")$p.value,
                 fisher.test(matrix(c(8, 2, 1, 5), 2))$p.value))
d <- rbind(c(1, 2, 3, 3, 2, 1, 4, 1, 2, NA), c(1, 2, 3, 3, 2, 2, 4, 1, 2, 5), c(NA, 3, 3, 3, 2, 3, 4, 2, 2, 5))
kripp <- function(d, delta) {
  vals <- sort(unique(as.vector(d[!is.na(d)]))); o <- matrix(0, length(vals), length(vals))
  for (u in seq_len(ncol(d))) {
    x <- d[!is.na(d[, u]), u]; mu <- length(x); if (mu < 2) next
    for (i in seq_along(x)) for (j in seq_along(x)) if (i != j) {
      o[match(x[i], vals), match(x[j], vals)] <- o[match(x[i], vals), match(x[j], vals)] + 1 / (mu - 1)
    }
  }
  nc <- rowSums(o); n <- sum(nc)
  D <- outer(seq_along(vals), seq_along(vals), function(a, b) delta(a, b, vals, nc))
  1 - (n - 1) * sum(o * D) / sum(outer(nc, nc) * D)
}
nominal <- function(a, b, v, nc) as.numeric(a != b)
interval <- function(a, b, v, nc) (v[a] - v[b])^2
ordinal <- function(a, b, v, nc) mapply(function(x, y) (sum(nc[min(x, y):max(x, y)]) - (nc[x] + nc[y]) / 2)^2, a, b)
emit("KRIPPENDORFF", c(kripp(d, nominal), kripp(d, interval), kripp(d, ordinal)))
r <- rbind(c("a", "a", "a"), c("a", "b", "b"), c("c", "c", "b"), c("a", "c", "c"))
nij <- t(apply(r, 1, function(x) sapply(c("a", "b", "c"), function(k) sum(x == k))))
Pi <- (rowSums(nij^2) - 3) / 6; pj <- colSums(nij) / 12; Pe <- sum(pj^2)
emit("FLEISS", c((mean(Pi) - Pe) / (1 - Pe), mean(Pi), Pe))
