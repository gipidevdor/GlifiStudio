# SPDX-License-Identifier: BSD-3-Clause
# Independent R/stats reference for KH A.7.2: chisq.test(correct=TRUE)
# and chi$residuals (Pearson), separately from chi$stdres.
# Source: KH public func.pm commit 7b7fbc1, lines 788-815.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "common.R"))

small <- matrix(c(1, 0, 0, 1), 2, byrow=TRUE)
yates <- suppressWarnings(chisq.test(small, correct=TRUE))
pearson <- suppressWarnings(chisq.test(small, correct=FALSE))
emit("KH_CHI_YATES", c(yates$statistic, yates$p.value))
emit("KH_CHI_PEARSON", c(pearson$statistic, pearson$p.value))

counts <- matrix(c(12, 5, 7, 7, 15, 4, 6, 5, 17), 3, byrow=TRUE)
fit <- suppressWarnings(chisq.test(counts, correct=TRUE))
emit("KH_CHI_RXC", c(fit$statistic, fit$p.value, fit$parameter))
emit("KH_CHI_EXPECTED", as.vector(t(fit$expected)))
emit("KH_CHI_PEARSON_RESIDUALS", as.vector(t(fit$residuals)))
emit("KH_CHI_STANDARDIZED_RESIDUALS", as.vector(t(fit$stdres)))

for (degrees in c(1, 2, 1000, 10000, 100000)) {
    statistics <- pmax(0, degrees + c(-1, 0, 1) * sqrt(2 * degrees))
    emit(paste0("KH_CHI_TAIL_DF", sprintf("%d", degrees)), pchisq(statistics, df=degrees, lower.tail=FALSE))
}
