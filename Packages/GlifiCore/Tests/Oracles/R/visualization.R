# SPDX-License-Identifier: BSD-3-Clause
# Oracolo della proiezione dendrogramma (GS-VIZ-001): ordine delle foglie di hclust,
# in cui a ogni fusione il primo figlio precede il secondo, e taglio a k gruppi.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))),
                 "common.R"))
X <- matrix(c(0, 0, 1, 0.2, 5, 5, 5.5, 4.8, 9, 0.5, 9.4, 1, 2.2, 7.9, 0.4, 1.1),
            ncol = 2, byrow = TRUE)
for (m in c("single", "complete", "average", "ward.D2")) {
  h <- hclust(dist(X), m)
  key <- paste0("DENDRO_", toupper(sub(".D2", "", m, fixed = TRUE)))
  emit(paste0(key, "_MERGE"), as.vector(t(h$merge)))
  emit(paste0(key, "_ORDER"), h$order)
  emit(paste0(key, "_CUT3"), cutree(h, 3))
}
