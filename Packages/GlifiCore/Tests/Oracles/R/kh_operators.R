# SPDX-License-Identifier: BSD-3-Clause
# Independent formulas and R reference implementations for the KH operator families.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
d <- matrix(c(0, 1, 3, 1, 0, 1, 3, 1, 0), 3)
emit("MDS_EIGEN", cmdscale(d, k = 1, eig = TRUE)$eig[c(1, 3)])
x <- matrix(c(0,0,2,0,0,2,2,2), 4, byrow = TRUE)
emit("SOM_ONE_UNIT", c(colMeans(x), mean(sqrt(rowSums(sweep(x, 2, colMeans(x))^2)))))
p <- c(0.5 * 3/4, 0.5 * 1/3); emit("BAYES_POSTERIOR", p / sum(p))
emit("LDA_ONE_TOPIC", c(2/5, 3/5, exp(-(2 * log(3/5) + log(2/5)) / 3)))
x <- matrix(c(0,0,0,1,1,0,10,10,10,11,11,10), 6, byrow = TRUE)
emit("CLARA_EXACT", cluster::pam(x, k = 2)$objective[2] * nrow(x))
# Exact integration over all 2^3 latent assignments, not a second Gibbs sampler.
words <- c(1, 1, 2); docs <- c(1, 1, 2); alpha <- 0.1; beta <- 1
states <- expand.grid(rep(list(1:2), 3))
weights <- numeric(nrow(states)); theta <- array(0, c(nrow(states), 2, 2))
phi <- array(0, c(nrow(states), 2, 2))
for (s in seq_len(nrow(states))) {
    z <- as.integer(states[s, ])
    ndk <- table(factor(docs, 1:2), factor(z, 1:2))
    nkw <- table(factor(z, 1:2), factor(words, 1:2))
    logp <- sum(apply(ndk, 1, function(row) lgamma(2*alpha) - lgamma(sum(row)+2*alpha) + sum(lgamma(row+alpha)-lgamma(alpha))))
    logp <- logp + sum(apply(nkw, 1, function(row) lgamma(2*beta) - lgamma(sum(row)+2*beta) + sum(lgamma(row+beta)-lgamma(beta))))
    weights[s] <- exp(logp)
    theta[s,,] <- (ndk+alpha) / (rowSums(ndk)+2*alpha)
    phi[s,,] <- (nkw+beta) / (rowSums(nkw)+2*beta)
}
weights <- weights/sum(weights)
emit("LDA_EXACT_THETA", apply(theta, c(2,3), function(v) sum(v*weights)))
emit("LDA_EXACT_PHI", apply(phi, c(2,3), function(v) sum(v*weights)))

# Review regressions: fixed-coordinate objectives; tied disparities use weighted block means.
delta <- matrix(c(0,1,1,1,0,2,1,2,0),3)
fitted <- as.matrix(dist(matrix(c(0,1,3),3)))
d <- as.numeric(as.dist(delta)); y <- as.numeric(as.dist(fitted))
block <- ave(y, d, FUN=mean)
projection <- isoreg(d[order(d)], block[order(d)])$yf
emit("MDS_FIXED_OBJECTIVES", c(sum((y-d)^2), sqrt(sum((y[order(d)]-projection)^2)/sum(y^2)), sum((y-d)^2/d)/sum(d)))
# Direct row-by-row SOM, no sufficient-statistic aggregation.
x <- matrix(c(0,1,2,3,4,0,10,11,11,10,12,12),6,byrow=TRUE)
m <- x[c(5,5,6,1),]
for (epoch in 0:2) {
 radius <- 2 * 0.25^(epoch/2)
 distances <- sapply(seq_len(nrow(m)), function(i) rowSums(sweep(x,2,m[i,])^2))
 winner <- max.col(-distances,ties.method="first")-1
 nextm <- m
 for (unit in 0:3) {
  h <- exp(-((unit%%2-winner%%2)^2+(unit%/%2-winner%/%2)^2)/(2*radius^2))
  nextm[unit+1,] <- colSums(x*h)/sum(h)
 }
 m <- nextm
}
emit("SOM_MULTI_UNIT", as.vector(t(m)))
emit("BAYES_TINY_LOG", log(2^-1074)-log(2))
pred <- array(0,c(nrow(states),2,2))
for (s in seq_len(nrow(states))) pred[s,,] <- theta[s,,] %*% phi[s,,]
pmean <- apply(pred,c(2,3),function(v)sum(v*weights))
emit("LDA_PREDICTIVE_PERPLEXITY", exp(-(2*log(pmean[1,1])+log(pmean[2,2]))/3))
