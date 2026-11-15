### Note ###
## This file loads the necessary packages and defines custom functions that all 
## other R scripts in this study use. 

## At the time of manuscript submission, some of the packages were taken from 
## their respective Github repositories instead of CRAN. For clarity, I will
## list the versions of these packages below. Please also see the text file
## "sessionInfo.txt" for info on the versions used for all others. 

## Once you have all of the packages, I recommend simply sourcing this file 
## prior to running any lines from other scripts. You may need to adjust the max
## number of DLLs that R can handle; see 'set max DLLs' section below.

####################### load or install&load packages ##########################

## IMPORTANT: GITHUB PACKAGES
## I'll list below the packages I obtained from Github instead of CRAN.
## Please be sure to cross-reference the versions listed to the right against 
## what is currently on Github!
#devtools::install_github("hadley/tidyverse")                          #v1.2.1
#devtools::install_github("geomorphR/geomorph",ref="Stable")           #v3.0.7
#devtools::install_github("liamrevell/phytools")                       #v0.6-61
#devtools::install_github("mwpennell/geiger-v2")                       #v2.0.6
#devtools::install_github("MomX/Momocs")                               #v1.2.9.4
#devtools::install_github("mjskay/tidybayes")                          #v1.0.1

## Use the next code chunk to to check if each package is on your machine. If
## a package is installed, it will be loaded. If any are not, the missing 
## package(s) will be installed from CRAN and then loaded.
## First, specify the packages of interest:
packages=c("plyr","ggplot2","boot","dplyr","spatialEco","fANCOVA","geomorph",
           "sp","lattice","abind","phytools","viridis","leaflet","dendextend",
           "geiger","splitstackshape","pracma","alphashape3d","Hmisc","emmeans",
           "xlsx","cluster",'MCMCglmm',"nFactors","sensiPhy","spatstat","MuMIn",
           "gghighlight","ggmcmc","caper","ptinpoly","glmulti","caret","mda",
           "lsmeans","sjstats","ggridges","forcats","Momocs","mcmcse",
           "tidybayes","class","reshape2","cowplot"
           )
## Load or install&load all
package.check<-lapply(packages,FUN=function(x){   #apply to the list of packages
  if(!require(x,character.only=TRUE)){            #if any is not installed
    install.packages(x,dependencies=TRUE)         #install it
    library(x,character.only=TRUE)                #otherwise load it
  }
})
## verify they are loaded
search()

## unmask PCA() from Momocs
PCA<-Momocs::PCA

## Source phylo FDA (Motani and Schmitz 2011, Evolution)
## I have not included this in the FigShare repository
## Please obtain this from the article's site, then:
#source("./phylo.fda.v0.2/phylo.fda.v0.2.R") 

################################ set max DLLs ##################################
## because of the number of packages that are loaded, it may be necessary for 
## you to adjust the maximum number of DLLs that R can handle. please note that
## these settings are machine-specific.

## the following code will do this for computers that use Windows:
#user_renviron=path.expand(file.path("~",".Renviron"))
#if(!file.exists(user_renviron)) # check to see if the file already exists
#  file.create(user_renviron)
#file.edit(user_renviron) # open with another text editor if this fails

#then add the following line (without the '#'), save, and restart R:
#R_MAX_NUM_DLLS=500


############################# custom functions #################################
## Custom functions that will be necessary to run analyses

## influ_physig() for multivariate data
## Takes the influ_physig() function from sensiPhy and replaces the method of 
## signal measurement with the multivariate method used in Geomorph. Suitable
## for high-dimension data (e.g. geometric morphometric landmarks)
influ_physig_kmult<-function(data,phy,iter=10000,cutoff=2,track=TRUE,...) 
{
  if (!inherits(phy,"phylo")) 
    stop("tree should be an object of class \"phylo\".")
  datphy<-match_dataphy(data[,1]~1,data,phy)
  full.data<-datphy$data
  phy<-datphy$phy
  trait<-full.data
  rownames(trait)<-phy$tip.label
  N<-nrow(full.data)
  mod.0<-geomorph::physignal(A=trait,phy=phy,iter=iter,print.progress=F,...)
  influ.physig.estimates<-data.frame(species=numeric(),estimate=numeric(),
                                     DF=numeric(),perc=numeric(),pval=numeric())
  counter<-1
  if (track==TRUE) 
    pb<-utils::txtProgressBar(min=0,max=N,style=3)
  for (i in 1:N) {
    crop.data<-trait[-i,]
    crop.phy<-ape::drop.tip(phy,phy$tip.label[i])
    mod.s<-geomorph::physignal(A=crop.data,phy=crop.phy,iter=iter,
                               print.progress=F,...)
    estimate<-mod.s$phy.signal
    sp<-phy$tip.label[i]
    DF<-mod.s$phy.signal-mod.0$phy.signal
    perc<-round((abs(DF/mod.0$phy.signal))*100,digits=1)
    pval<-mod.s$pvalue
    estim.simu<-data.frame(sp,estimate,DF,perc,pval,stringsAsFactors=F)
    influ.physig.estimates[counter,]<-estim.simu
    counter=counter + 1
    if (track==TRUE) 
      (utils::setTxtProgressBar(pb, i))
  }
  if (track == TRUE) 
    on.exit(close(pb))
  sDF<-influ.physig.estimates$DF/stats::sd(influ.physig.estimates$DF)
  influ.physig.estimates$sDF<-sDF
  param0<-list(estimate=mod.0$phy.signal,pval=mod.0$pvalue)
  reorder<-influ.physig.estimates[order(abs(influ.physig.estimates$sDF),
                                        decreasing=T),c("species","sDF")]
  influ.sp<-as.character(reorder$species[abs(reorder$sDF) > cutoff])
  res<-list(call=match.call(),cutoff=cutoff,full.data.estimates=param0,
            influential.species=influ.sp,
            influ.physig.estimates=influ.physig.estimates,data=full.data,
            phy=phy)
  class(res)<-"influ.physig"
  return(res)
}

## tree_physig_kmult() for multivariate data
## Takes the tree_physig() function from sensiPhy and replaces the method of 
## signal measurement with the multivariate method used in Geomorph. Suitable
## for high-dimension data (e.g. geometric morphometric landmarks)
tree_physig_kmult<-function(data,phy,n.tree="all",iter=10000,track=TRUE,...) 
{
  if (n.tree == "all") 
    n.tree <- length(phy)
  if (class(phy) != "multiPhylo") 
    stop("phy must be class 'multiPhylo'")
  if (length(phy) < n.tree) 
    stop("'n.tree' must be smaller (or equal) than the number of trees in the 'multiPhylo' object")
  datphy <- match_dataphy(data[,1]~1,data,phy)
  full.data <- data
  phy <- datphy$phy
  N <- nrow(full.data)
  trees <- sample(length(phy), n.tree, replace = F)
  tree.physig.estimates <- data.frame(n.tree = numeric(), estimate = numeric(), 
                                      pval = numeric())
  counter = 1
  if (track == TRUE) 
    pb <- utils::txtProgressBar(min = 0, max = n.tree, style = 3)
  for (j in trees) {
    mod.s<-geomorph::physignal(A=data,phy=phy[[j]],iter=iter,print.progress=F,...)
    estimate <- mod.s$phy.signal
    pval <- mod.s$pvalue
    if (track == TRUE) 
      (utils::setTxtProgressBar(pb, counter))
    estim.simu <- data.frame(j, estimate, pval)
    tree.physig.estimates[counter, ] <- estim.simu
    counter = counter + 1
  }
  if (track == TRUE) 
    on.exit(close(pb))
  statresults <- data.frame(min = apply(tree.physig.estimates, 
                                        2, min), max = apply(tree.physig.estimates, 2, max), 
                            mean = apply(tree.physig.estimates, 2, mean), sd_tree = apply(tree.physig.estimates, 
                                                                                          2, stats::sd))[-1, ]
  statresults$CI_low <- statresults$mean - qt(0.975, df = n.tree - 
                                                1) * statresults$sd_tree/sqrt(n.tree)
  statresults$CI_high <- statresults$mean + qt(0.975, df = n.tree - 
                                                 1) * statresults$sd_tree/sqrt(n.tree)
  stats <- round(statresults[c(1:2), c(3, 5, 6, 1, 2)], digits = 5)
  cl <- match.call()
  res <- list(call = cl, Trait = data, tree.physig.estimates = tree.physig.estimates, 
              N.obs = N, stats = stats, data = full.data)
  class(res) <- "tree.physig"
  return(res)
}


## Plot posterior means and 95% CIs for MCMCglmm model
plot.estimatesMCMC<-function(x){
  if(class(x)!="summary.mcmc")
    x<-summary(x)
  n<-dim(x$statistics)[1]
  l<-max(nchar(strsplit(rownames(x$statistics)," ")[[1]]))
  par(mar=c(5,l+1,4,2)) #this approxmately works
  plot(x$statistics[,1],n:1,pch=19,xlim=range(x$quantiles)*1.1,yaxt="n",ylab="",
       xlab="",main="Posterior means with 95% CIs")
  grid()
  axis(2,at=n:1,labels=rownames(x$statistics),las=2)
  arrows(x$quantiles[,1],n:1,x$quantiles[,5],n:1,code=0)
  abline(v=0,lty=2)
  par(mar=c(5,4,4,2)) #reset back to default
}


# Compute phylogenetic half-life
# meant for objects genterated by fitDiscrete(model="OU")
half_life<-function(obj) log(2)/(obj$opt$alpha)


## Compute the mode of a set of data
modeStat<-function(x){
  uniquex<-unique(x)
  uniquex[which.max(tabulate(match(x,uniquex)))]
}


## Compute mean squared error from a linear model, e.g. using lm()
mse<-function(model) mean(model$residuals^2)


## Remaining three functions originally written by Christina Harvey
#angles in 3D space
xyzangles <- function(x1,y1,z1,x2,y2,z2,x3,y3,z3){
  i1=x2-x1
  i2=x2-x3
  j1=y2-y1
  j2=y2-y3
  k1=z2-z1
  k2=z2-z3
  dotprod=(i1*i2)+(j1*j2)+(k1*k2)
  len1=sqrt(i1^2+j1^2+k1^2)
  len2=sqrt(i2^2+j2^2+k2^2)
  theta=acos(dotprod/(len1*len2))*(180/pi)
  theta
}


#angles in 2D space
xyangles<-function(x1,y1,x2,y2,x3,y3){ 
  i1=x1;i2=x2;i3=x3
  j1=y1;j2=y2;j3=y3
  a=c(i1,j1)-c(i2,j2)
  b=c(i3,j3)-c(i2,j2)
  theta=acos(sum(a*b)/(sqrt(sum(a*a))*sqrt(sum(b*b))))*(180/pi)
  theta
} 


#angles between two planes in 3D space
xyzplaneangles <- function(x1,y1,z1,x2,y2,z2,x3,y3,z3, #plane 1
                           x4,y4,z4,x5,y5,z5,x6,y6,z6){ #plane 2
  #x1_std,y1_std,z1_std,x2_std,y2_std,z2_std,x3_std,y3_std,z3_std){
  #This computes the angle betweeon two planes composed of three points each
  #--- Vectors of Plane 1 - create vector from two 3D pts
  i1 = x2-x1
  j1 = y2-y1
  k1 = z2-z1
  i2 = x2-x3
  j2 = y2-y3
  k2 = z2-z3
  #--- Vectors of Plane 2 - create vector from two 3D pts
  i3 = x5-x4
  j3 = y5-y4
  k3 = z5-z4
  i4 = x5-x6
  j4 = y5-y6
  k4 = z5-z6
  #--- Orthogonal Vector of Plane 1 - Cross Product of the vectors on the plane
  i5 = j1*k2-k1*j2
  j5 = k1*i2-i1*k2
  k5 = i1*j2-j1*i2
  #--- Orthogonal Vector of Plane 2 - Cross Product of the vectors on the plane
  i6 = j3*k4-k3*j4
  j6 = k3*i4-i3*k4
  k6 = i3*j4-j3*i4
  #--- Dot Product of Orthogonal Vectors
  dotprod = ((i5*i6)+(j5*j6)+(k5*k6))
  len1    = sqrt(i5^2+j5^2+k5^2)
  len2    = sqrt(i6^2+j6^2+k6^2)
  interior = dotprod/(len1*len2)
  theta   = acos(interior)*(180/pi)
  
  return(theta)
}


options(max.print=999999)