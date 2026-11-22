# SPDX-License-Identifier: BSD-3-Clause
# Oracolo di GlifiMultivariateMethodsTests: SVD, CA, PCA, LSA, HAC, Lloyd e NMF (pacchetto NMF,
# variante Lee–Seung senza riscalatura con ε=1e-12, dagli stessi fattori iniziali).
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
N <- matrix(c(4, 2, 0, 1, 1, 3, 2, 0, 0, 1, 5, 2, 2, 0, 1, 3, 3, 1, 1, 1), 5, byrow = TRUE)
emit("SVD", svd(N)$d)
P <- N / sum(N); r <- rowSums(P); cc <- colSums(P)
S <- diag(1 / sqrt(r)) %*% (P - r %o% cc) %*% diag(1 / sqrt(cc)); s <- svd(S)
sgn <- sapply(1:3, function(j) sign(s$v[which(abs(s$v[, j]) > 1e-12)[1], j]))
F <- diag(1 / sqrt(r)) %*% s$u[, 1:3] %*% diag(s$d[1:3] * sgn)
G <- diag(1 / sqrt(cc)) %*% s$v[, 1:3] %*% diag(s$d[1:3] * sgn)
emit("CA_SV", s$d[1:3]); emit("CA_TOTAL", sum(s$d^2)); emit("CA_F1", F[, 1]); emit("CA_F2", F[, 2])
emit("CA_G1", G[, 1])
X <- N / rowSums(N); p <- prcomp(X)
L <- p$rotation; sg <- sign(apply(L, 2, function(v) v[which(abs(v) > 1e-12)[1]]))
emit("PCA_VAR", p$sdev[1:3]^2); emit("PCA_L1", L[, 1] * sg[1]); emit("PCA_S1", p$x[, 1] * sg[1])
emit("PCA_SCALED_VAR", prcomp(X, scale. = TRUE)$sdev[1:3]^2)
emit("LSA_RESIDUAL", sqrt(sum(svd(N)$d[3:4]^2)))
for (m in c("single", "complete", "average", "ward.D2")) emit(paste0("HC_", toupper(m)), hclust(dist(X), m)$height)
km <- kmeans(X, centers = X[c(1, 3), ], algorithm = "Lloyd", iter.max = 100)
emit("KMEANS", c(km$cluster, km$tot.withinss, km$iter)); emit("KMEANS_C1", km$centers[1, ])
emit("KMEANS_C2", km$centers[2, ])
suppressMessages(library(NMF))
Y <- matrix(c(1, 2, 0, 0, 1, 3, 1, 3, 3, 2, 1, 1), 4, byrow = TRUE)
W0 <- matrix(c(0.5, 0.2, 0.3, 0.9, 0.7, 0.4, 0.1, 0.6), 4, byrow = TRUE)
H0 <- matrix(c(0.2, 0.8, 0.5, 0.6, 0.1, 0.9), 2, byrow = TRUE)
fit <- nmf(Y, 2, method = "lee", seed = nmfModel(W = W0, H = H0), rescale = FALSE, eps = 1e-12,
           .stop = function(object, i, y, x, ...) i >= 100)
emit("NMF_W", as.vector(t(basis(fit)))); emit("NMF_H", as.vector(t(coef(fit))))
emit("NMF_OBJECTIVE", sum((Y - basis(fit) %*% coef(fit))^2))
# Matrice sparsa 150×200 (seed 7, 5 % di celle non nulle): dati di massa per la SVD troncata.
set.seed(7)
M <- matrix(0, 150, 200); cells <- sample(length(M), 1500); M[cells] <- rpois(1500, 3) + 1
idx <- which(M != 0, arr.ind = TRUE); idx <- idx[order(idx[, 1], idx[, 2]), ]
emit("INFO_BULK_SVD_TRIPLETS", as.vector(t(cbind(idx - 1, M[idx]))))
sv <- svd(M, nu = 0, nv = 3)
emit("INFO_BULK_SVD_VALUES", sv$d[1:8])
v1 <- sv$v[, 1]; v1 <- v1 * sign(v1[which(abs(v1) > 1e-12)[1]])
emit("INFO_BULK_SVD_V1", v1)
# Silhouette (Rousseeuw 1987) sui profili di riferimento con il taglio di Ward a due cluster.
suppressMessages(library(cluster))
sil <- silhouette(c(1, 2, 2, 1, 1), dist(X))
emit("SILHOUETTE", c(sil[, "sil_width"], mean(sil[, "sil_width"])))
