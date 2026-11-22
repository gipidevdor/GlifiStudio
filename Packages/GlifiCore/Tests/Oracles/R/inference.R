# SPDX-License-Identifier: BSD-3-Clause
# Oracolo di GlifiInferenceExtensionsTests: BCa sugli stessi replicati, contrasti pianificati,
# t appaiato con intervallo, Wilcoxon appaiato esatto, d_z.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
x <- c(2, 4, 4, 5, 7, 9, 10); t0 <- mean(x)
t <- c(4.1, 5.2, 5.9, 6.3, 4.8, 7.0, 5.5, 6.1, 5.85, 6.6, 4.4, 5.0, 7.3, 6.9, 5.7, 6.0, 5.1, 4.9, 6.8, 5.3)
jack <- sapply(seq_along(x), function(i) mean(x[-i])); m <- mean(jack)
a <- sum((m - jack)^3) / (6 * sum((m - jack)^2)^1.5); z0 <- qnorm(mean(t < t0))
za <- qnorm(c(0.05, 0.95)); adj <- pnorm(z0 + (z0 + za) / (1 - a * (z0 + za)))
emit("BCA", c(z0, a, adj, quantile(t, adj, type = 7)))
g <- list(c(3, 4, 5), c(6, 7, 9), c(1, 2, 2, 4)); y <- unlist(g)
f <- factor(rep(seq_along(g), sapply(g, length))); fit <- lm(y ~ f)
mse <- sigma(fit)^2; df <- fit$df.residual; mu <- sapply(g, mean); n <- sapply(g, length)
for (cc in list(c(1, -0.5, -0.5), c(0, 1, -1))) {
  est <- sum(cc * mu); se <- sqrt(mse * sum(cc^2 / n)); tt <- est / se
  emit("CONTRAST", c(est, se, tt, 2 * pt(-abs(tt), df)))
}
p1 <- c(0.5, 0.25, 0.2, 0.4, 0.1); p2 <- c(0.1, 0.3, 0.05, 0.2, 0.0)
tp <- t.test(p1, p2, paired = TRUE)
emit("PAIRED_T", c(tp$statistic, tp$p.value, tp$conf.int))
emit("PAIRED_WILCOXON_DZ", c(wilcox.test(p1, p2, paired = TRUE, exact = TRUE)$p.value,
                             mean(p1 - p2) / sd(p1 - p2)))
