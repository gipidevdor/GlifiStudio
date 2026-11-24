# SPDX-License-Identifier: BSD-3-Clause
# Standalone base-R oracle; no Glifi source, package, KH implementation or runtime dependency.

options(digits = 17)
emit <- function(name, value) {
  cat(name, paste(sprintf("%.17g", as.vector(t(value))), collapse = " "), "\n")
}

counts <- matrix(c(1, 2, 5, 9, 2, 4, 4, 8, 3, 8, 0, 7), nrow = 3, byrow = TRUE)
emit("KH_MATRIX_Z_ROWS", t(apply(counts, 1, function(x) as.vector(scale(x)))))
emit("KH_MATRIX_Z_COLUMNS", scale(counts))
emit("KH_MATRIX_EXPOSURE", sweep(counts, 1, c(100, 200, 50), "/") * 1000)

targets <- list(matrix(c(1, 0, 0, 5, 1, 0, 0, 1, 0), ncol = 3, byrow = TRUE),
                matrix(c(6, 1, 0, 0, 1, 0), ncol = 3, byrow = TRUE))
contexts <- list(matrix(c(1, 10, 3, 20, 5, 30), ncol = 2, byrow = TRUE),
                 matrix(c(4, 30, 5, 30), ncol = 2, byrow = TRUE))
alpha <- c(2, 0.5)
vectors <- matrix(0, nrow = 3, ncol = 2)
support <- matrix(0, nrow = 2, ncol = 3)
for (level in seq_along(targets)) {
  for (target in seq_len(3)) {
    selected <- targets[[level]][, target] > 0
    support[level, target] <- sum(selected)
    if (any(selected)) {
      vectors[target, ] <- vectors[target, ] +
        alpha[level] * colMeans(contexts[[level]][selected, , drop = FALSE])
    }
  }
}
stopifnot(identical(as.vector(t(vectors)), c(6, 45, 10.25, 65, 0, 0)))
emit("KH_MATRIX_CONTEXT", vectors)
emit("KH_MATRIX_CONTEXT_SUPPORT", support)

ca <- matrix(c(30, 10, 10, 30), nrow = 2, byrow = TRUE)
p <- ca / sum(ca)
r <- rowSums(p)
c <- colSums(p)
s <- (p - outer(r, c)) / sqrt(outer(r, c))
decomposition <- svd(s)
sigma <- decomposition$d[1]
stopifnot(abs(sigma - 0.5) < 1e-15)
for (power in c(1, 0, 0.5)) {
  rows <- decomposition$u[, 1] / sqrt(r) * sigma^power
  columns <- decomposition$v[, 1] / sqrt(c) * sigma^power
  emit(paste0("KH_MATRIX_CA_POWER_", power), matrix(c(sum(r * rows^2),
                                                       sum(c * columns^2)), nrow = 1))
}
