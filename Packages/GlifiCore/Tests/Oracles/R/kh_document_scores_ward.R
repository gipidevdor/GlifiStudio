# SPDX-License-Identifier: BSD-3-Clause
# Independent base-R formulas and stats::hclust; no KH implementation is incorporated.
emit <- function(name, value) {
  cat(name, paste(sprintf("%.17g", as.vector(t(value))), collapse=" "), "\n")
}
N <- 10
df <- c(1,5,10)
counts <- rbind(c(1,2,3),c(0,4,1))
exposure <- c(10,20)
idf <- log10(N/df)
tf <- counts/exposure
weighted <- sweep(tf,2,idf,"*")
divided <- sweep(tf,2,ifelse(idf==0,1,idf),"/")
emit("KH_DOCUMENT_LOG10_IDF",matrix(idf,nrow=1))
emit("KH_DOCUMENT_TF",cbind(tf,rowSums(tf)))
emit("KH_DOCUMENT_TF_IDF",cbind(weighted,rowSums(weighted)))
emit("KH_DOCUMENT_TF_DIVIDED_IDF",cbind(divided,rowSums(divided)))
presence <- rbind(c(1,1,0,1,0,0,0),c(1,1,1,0,0,0,0),c(0,0,1,1,1,0,0),
                  c(0,0,0,0,1,1,0),c(1,0,0,0,0,1,1))
distance <- dist(presence,method="binary")
tree <- hclust(distance,method="ward.D2")
n <- nrow(presence)
ids <- ifelse(tree$merge<0,-tree$merge-1,n+tree$merge-1)
sizes <- rep(1,n)
mergeSizes <- numeric(n-1)
for (step in seq_len(n-1)) {
  pair <- sort(ids[step,])
  ids[step,] <- pair
  mergeSizes[step] <- sizes[pair[1]+1]+sizes[pair[2]+1]
  sizes <- c(sizes,mergeSizes[step])
}
emit("KH_WARD_D2_JACCARD",cbind(ids,tree$height,mergeSizes))
vectors <- rbind(c(2,1,0),c(1,3,1),c(0,1,4),c(3,0,2))
unit <- vectors/sqrt(rowSums(vectors*vectors))
cosine <- 1-tcrossprod(unit)
diag(cosine) <- 0
cosineTree <- hclust(as.dist(cosine),method="ward.D2")
cosineIDs <- ifelse(cosineTree$merge<0,-cosineTree$merge-1,nrow(vectors)+cosineTree$merge-1)
cosineIDs <- t(apply(cosineIDs,1,sort))
emit("KH_WARD_D2_COSINE",cbind(cosineIDs,cosineTree$height,c(2,2,4)))
