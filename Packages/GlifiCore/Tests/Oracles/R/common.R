# SPDX-License-Identifier: BSD-3-Clause
# Oracoli numerici indipendenti per GlifiCore (R 4.6+). Ogni riga emessa ha la forma
# «CHIAVE valore…» con 15 cifre significative; Scripts/check-oracles.py la confronta con
# expected.txt e con i letterali dei test Swift.
.libPaths(c(path.expand("~/Library/R/glifi-oracles"), .libPaths()))
options(digits = 15, warn = -1)
emit <- function(key, values) {
  cat(key, paste(sprintf("%.15g", as.numeric(values)), collapse = " "), "\n")
}
