# SPDX-License-Identifier: BSD-3-Clause
# Independent base-R mathematical oracle; no som/smacof source is incorporated.
emit <- function(name, value) {
  cat(name, paste(sprintf("%.17g", as.vector(t(value))), collapse=" "), "\n")
}
data <- rbind(c(0,1,2),c(2,-1,0),c(4,3,1),c(1,5,-2),c(-2,0,3))
pca <- prcomp(data, center=TRUE, scale.=FALSE)
rotation <- pca$rotation
for (axis in seq_len(ncol(rotation))) {
  pivot <- which(abs(rotation[,axis]) > 1e-12)[1]
  if (!is.na(pivot) && rotation[pivot,axis] < 0) rotation[,axis] <- -rotation[,axis]
}
grid <- expand.grid(x=seq(-2,2,length.out=3),y=seq(-2,2,length.out=2))
initial <- t(vapply(seq_len(nrow(grid)),function(i)
 colMeans(data)+grid$x[i]*pca$sdev[1]*rotation[,1]+grid$y[i]*pca$sdev[2]*rotation[,2],numeric(3)))
emit("KH_SOM_PCA_LINEAR_3X2",initial)
mixed <- rbind(c(1,1e-200),c(-1,1e-200),c(1,-1e-200),c(-1,-1e-200))
mixed.pc <- prcomp(mixed)
mixed.rotation <- mixed.pc$rotation
for (axis in 1:2) {
 pivot <- which(abs(mixed.rotation[,axis]) > 1e-12)[1]
 if (mixed.rotation[pivot,axis] < 0) mixed.rotation[,axis] <- -mixed.rotation[,axis]
}
mixed.grid <- expand.grid(x=c(-2,2),y=c(-2,2))
mixed.initial <- t(vapply(1:4,function(i)
 mixed.grid$x[i]*mixed.pc$sdev[1]*mixed.rotation[,1]+
 mixed.grid$y[i]*mixed.pc$sdev[2]*mixed.rotation[,2],numeric(2)))
emit("KH_SOM_PCA_MIXED_SCALE",sweep(mixed.initial,2,c(1,1e-200),"/"))

input <- rbind(c(0,1),c(2,-1),c(4,3))
codes <- rbind(c(-1,0),c(1,0),c(-1,2),c(1,2))
xy <- as.matrix(expand.grid(x=0:1,y=0:1));xy[,1]<-xy[,1]+0.5*(xy[,2]%%2);xy[,2]<-xy[,2]*sqrt(3)/2
train <- function(codes,steps,alpha0,radius0) {
 for (t in seq_len(steps)) {
  row<-input[(t-1)%%nrow(input)+1,]
  winner<-which.min(rowSums((codes-matrix(row,nrow(codes),2,byrow=TRUE))^2))
  radius<-1+(radius0-1)*(1-t/steps)
  rate<-alpha0*(steps/100)/(steps/100+t)
  for (unit in seq_len(nrow(codes))) {
   neighbor<-exp(-sum((xy[unit,]-xy[winner,])^2)/(2*radius^2))
   codes[unit,]<-(1-rate*neighbor)*codes[unit,]+rate*neighbor*row
  }
 }
 codes
}
first<-train(codes,5,0.05,2)
final<-train(first,7,0.02,1.5)
emit("KH_SOM_PHASE1",first)
emit("KH_SOM_PHASE2",final)
distances<-sapply(seq_len(nrow(final)),function(i)sqrt(rowSums((input-matrix(final[i,],nrow(input),2,byrow=TRUE))^2)))
winners<-apply(distances,1,which.min)
distortion<-mean(vapply(seq_len(nrow(input)),function(i) {
 weights<-exp(-rowSums((xy-matrix(xy[winners[i],],nrow(xy),2,byrow=TRUE))^2)/2)
 sum(weights*distances[i,]^2)
},numeric(1)))
emit("KH_SOM_DIAGNOSTICS",matrix(c(mean(apply(distances,1,min)),distortion),nrow=1))
emit("KH_SOM_ASSIGNMENTS",matrix(winners-1,nrow=1))
y<-c(1,3,2,7,6,4);level<-c(1,1,2,2,3,3)
order.primary<-order(level,y,seq_along(y))
primary<-numeric(6);primary[order.primary]<-isoreg(seq_along(y),y[order.primary])$yf
primary<-primary*sqrt(6/sum(primary^2))
secondary<-rep(tapply(y,level,mean),each=2)
secondary<-isoreg(seq_along(y),secondary)$yf
secondary<-secondary*sqrt(6/sum(secondary^2))
emit("KH_MDS_PRIMARY_DISPARITIES",matrix(primary,nrow=1))
emit("KH_MDS_SECONDARY_DISPARITIES",matrix(secondary,nrow=1))
