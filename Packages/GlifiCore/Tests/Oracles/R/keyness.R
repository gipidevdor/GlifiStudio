# SPDX-License-Identifier: BSD-3-Clause
# Oracolo di keyness-gtest-fisher-ha-ci-bh-v2 (GS-DOR-003, GS-MET-001-08): selezione di Fisher con
# attesa minima < 5, fisher.test di R, BH sulla famiglia dei p selezionati, IC di Katz (log ratio,
# base 2) e di Woolf (odds ratio) con correzione Haldane–Anscombe, livello 0,95.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))),
                 "common.R"))
keyness <- function(a, c, NA_, NB) {
  b <- NA_ - a; d <- NB - c; N <- NA_ + NB
  E <- c(NA_ * (a + c), NA_ * (b + d), NB * (a + c), NB * (b + d)) / N
  O <- c(a, b, c, d)
  G <- 2 * sum(ifelse(O == 0, 0, O * log(O / E))); pg <- pchisq(G, 1, lower.tail = FALSE)
  pf <- fisher.test(matrix(c(a, c, b, d), 2))$p.value
  p <- if (min(E) < 5) pf else pg
  z <- qnorm(0.975)
  lr <- log(((a + 0.5) / (NA_ + 1)) / ((c + 0.5) / (NB + 1)))
  se_lr <- sqrt(1 / (a + 0.5) - 1 / (NA_ + 1) + 1 / (c + 0.5) - 1 / (NB + 1))
  or <- ((a + 0.5) / (b + 0.5)) / ((c + 0.5) / (d + 0.5))
  se_or <- sqrt(1 / (a + 0.5) + 1 / (b + 0.5) + 1 / (c + 0.5) + 1 / (d + 0.5))
  c(pg, p, (lr - z * se_lr) / log(2), (lr + z * se_lr) / log(2),
    exp(log(or) - z * se_or), exp(log(or) + z * se_or))
}
# Caso di riferimento: target {casa, casa, mare}, riferimento {casa, città, città}.
small <- rbind(casa = keyness(2, 1, 3, 3), citta = keyness(0, 2, 3, 3), mare = keyness(1, 0, 3, 3))
emit("KEYNESS_SMALL_CASA", small["casa", ]); emit("KEYNESS_SMALL_CITTA", small["citta", ])
emit("KEYNESS_SMALL_MARE", small["mare", ])
emit("KEYNESS_SMALL_Q", p.adjust(small[, 2], "BH"))
# Caso grande: attese ≥ 5, selezione del G-test.
emit("KEYNESS_LARGE", keyness(30, 10, 1000, 1000))
