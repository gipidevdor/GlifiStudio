# SPDX-License-Identifier: BSD-3-Clause
# Original external-oracle driver for GS-VER-319; no R implementation is embedded.
source("Packages/GlifiCore/Tests/Oracles/R/common.R")

t_grid <- expand.grid(
  statistic = c(1e-8, 0.001, 0.2, 1, 3, 10, 100, 1e4, 1e100),
  degrees = c(0.1, 0.5, 1, 2, 7, 40, 1000, 1e5)
)
emit("T_GRID", 2 * pt(-t_grid$statistic, df = t_grid$degrees))
f_grid <- expand.grid(
  statistic = c(1e-8, 0.001, 0.2, 1, 3, 10, 100, 1e4),
  numerator = c(0.1, 0.5, 1, 2, 7, 40, 1000),
  denominator = c(0.1, 0.5, 1, 2, 7, 40, 1000)
)
emit("F_GRID", pf(f_grid$statistic, f_grid$numerator, f_grid$denominator,
                  lower.tail = FALSE))
chi_grid <- expand.grid(
  statistic = c(1e-8, 0.1, 1, 3, 10, 50, 100, 1000, 1e5),
  degrees = c(1, 2, 3, 7, 40, 100, 1000)
)
emit("CHI_GRID", pchisq(chi_grid$statistic, chi_grid$degrees, lower.tail = FALSE))
emit("QNORM_TAIL", qnorm(c(5e-324, 1e-320, 1e-310, 1e-308,
                           .Machine$double.xmin, 1e-300, 1e-16,
                           pnorm(-8), 1e-15, 1e-14)))
