# SPDX-License-Identifier: BSD-3-Clause
# Oracolo di GlifiPostHocStatisticsTests: Tukey HSD, Games–Howell, Dunn, Kruskal–Wallis,
# Fisher-z, Spearman esatto, Hedges g.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
g <- list(c(3, 4, 5), c(6, 7, 9), c(1, 2, 2, 4))
y <- unlist(g); f <- factor(rep(seq_along(g), sapply(g, length)))
t <- TukeyHSD(aov(y ~ f))$f
emit("TUKEY_DIFF", t[, "diff"]); emit("TUKEY_LWR", t[, "lwr"]); emit("TUKEY_UPR", t[, "upr"])
emit("TUKEY_P", t[, "p adj"])
gh <- function(i, j) {
  a <- g[[i]]; b <- g[[j]]; va <- var(a) / length(a); vb <- var(b) / length(b)
  df <- (va + vb)^2 / (va^2 / (length(a) - 1) + vb^2 / (length(b) - 1))
  q <- abs(mean(a) - mean(b)) / sqrt((va + vb) / 2)
  c(q, df, ptukey(q, 3, df, lower.tail = FALSE))
}
m <- rbind(gh(1, 2), gh(1, 3), gh(2, 3))
emit("GH_Q", m[, 1]); emit("GH_DF", m[, 2]); emit("GH_P", m[, 3])
k <- kruskal.test(g); emit("KW", c(k$statistic, k$p.value))
r <- rank(y); N <- length(y); tt <- table(y); tie <- sum(tt^3 - tt)
dunn <- function(i, j) {
  ni <- sum(f == i); nj <- sum(f == j)
  se <- sqrt((N * (N + 1) / 12 - tie / (12 * (N - 1))) * (1 / ni + 1 / nj))
  z <- (mean(r[f == i]) - mean(r[f == j])) / se; c(z, 2 * pnorm(-abs(z)))
}
d <- rbind(dunn(1, 2), dunn(1, 3), dunn(2, 3))
emit("DUNN_Z", d[, 1]); emit("DUNN_P", d[, 2])
emit("DUNN_BONFERRONI", p.adjust(d[, 2], "bonferroni")); emit("DUNN_BH", p.adjust(d[, 2], "BH"))
x <- 1:6; yy <- c(2, 1, 4, 3, 6, 5); ct <- cor.test(x, yy)
emit("PEARSON_FISHER", c(ct$estimate, ct$conf.int))
emit("SPEARMAN_EXACT", c(cor.test(x, yy, method = "spearman", exact = TRUE)$p.value,
                         cor.test(1:5, c(2, 1, 4, 3, 5), method = "spearman", exact = TRUE)$p.value))
a <- c(1, 2, 3, 5); b <- c(4, 5, 6, 8, 9); n1 <- 4; n2 <- 5
sp <- sqrt(((n1 - 1) * var(a) + (n2 - 1) * var(b)) / (n1 + n2 - 2)); dd <- (mean(a) - mean(b)) / sp
nu <- n1 + n2 - 2; J <- exp(lgamma(nu / 2) - log(sqrt(nu / 2)) - lgamma((nu - 1) / 2))
se <- sqrt((n1 + n2) / (n1 * n2) + dd^2 / (2 * (n1 + n2)))
emit("HEDGES", c(dd, J, J * dd, se, dd - qnorm(0.975) * se, dd + qnorm(0.975) * se))
