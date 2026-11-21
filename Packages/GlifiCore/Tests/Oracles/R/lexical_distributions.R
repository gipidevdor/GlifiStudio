# SPDX-License-Identifier: BSD-3-Clause
# Independent stats::lm and stats::quantile oracles for GS-MET-001-04/05.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))),
                 "common.R"))
fit <- function(x, y) {
  model <- lm(log(y) ~ log(x))
  c(exp(coef(model)[1]), coef(model)[2], summary(model)$r.squared,
    sqrt(mean(residuals(model)^2)), residuals(model))
}
emit("ZIPF", fit(1:5, c(20, 9, 6, 4, 3)))
emit("HEAPS", fit(c(1, 4, 9, 16), c(1, 2, 3, 4)))
x <- c(1, 2, 4, 8, 10)
emit("DESCRIPTIVE", c(mean(x), median(x), var(x), sd(x), quantile(x, c(0, .1, .25, .5, .75, .9, 1), type=7)))
