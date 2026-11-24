# SPDX-License-Identifier: BSD-3-Clause
# Independent R stats oracle for GS-MET-001-21 candidate Welch omnibus and Pearson scaling.
source("Packages/GlifiCore/Tests/Oracles/R/common.R")
groups <- list(c(3, 4, 5), c(6, 7, 9), c(1, 2, 2, 4))
fit <- oneway.test(unlist(groups) ~ factor(rep(seq_along(groups), lengths(groups))),
                   var.equal = FALSE)
emit("WELCH_ANOVA", c(fit$statistic, fit$parameter, fit$p.value))
x <- c(-3, -1, 2, 5)
y <- c(4, -2, 3, 6)
fit <- cor.test(x, y, method = "pearson")
emit("PEARSON_SCALE", c(fit$estimate, fit$p.value))
# Use small translated observations as the independent oracle; computing their
# large-offset representations inside the reference implementation can itself round means.
groups <- list(c(0, 1), c(2, 3, 4))
fit <- oneway.test(unlist(groups) ~ factor(rep(seq_along(groups), lengths(groups))),
                   var.equal = FALSE)
emit("WELCH_OFFSET", c(fit$statistic, fit$parameter, fit$p.value))
emit("PEARSON_OFFSET", cor(c(0, 0, 1), c(0, 1, 2)))
