# SPDX-License-Identifier: BSD-3-Clause
# Oracolo di GlifiPostHocStatisticsTests e GlifiInferenceExtensionsTests: range studentizzato,
# quantili normale e t. INFO_ documenta l'imprecisione di ptukey con ν piccoli e non interi.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
emit("PTUKEY", c(ptukey(3.5, 3, 10), ptukey(2, 4, 5), ptukey(4.2, 5, 20), ptukey(3, 3, 1000),
                 ptukey(6, 10, 3), ptukey(2.5, 3, 2), ptukey(5, 6, 60)))
emit("QNORM", qnorm(c(0.975, 1e-10, 0.3, 0.999999)))
emit("QT", c(qt(0.975, 7), qt(0.025, 4), qt(0.9, 2.5)))
emit("INFO_PTUKEY_K2_FRACTIONAL", c(ptukey(3, 2, 3.4482758620689653, lower.tail = FALSE),
                                    2 * pt(-3 / sqrt(2), 3.4482758620689653)))
