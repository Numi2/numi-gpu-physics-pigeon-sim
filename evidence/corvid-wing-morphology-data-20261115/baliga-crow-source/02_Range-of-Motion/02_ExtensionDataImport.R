## the first half of this script imports linkage trajectory data
## the second half brings in extension ROM
## throughout the script, some light processing is done to create objects that
## will be used later

## please ensure your working directory is set to the 02_Range-of-Motion level


######################## linkage trajectory sourcing ###########################
#source individual species analyses
#all of these files will have "6bar-frames" in the title
ltpath<-"./data_import_scripts/Linkage_trajectory/"
ltlist<-list.files(path=ltpath,pattern="6bar-frames",
                   full.names=TRUE,recursive=TRUE)
for(i in 1:length(ltlist)){
  source(ltlist[i])
 }


############################### organize data ##################################
#create two separate lists of data, one for extensions and the other for 
#flexions
extensions<-ls(pattern='*.ext')
flexions  <-ls(pattern='*.flx')

extensions.list<-rbind(mget(extensions))
  names(extensions.list)<-extensions
flexions.list<-rbind(mget(flexions))
  names(flexions.list)<-flexions


################################# re-order data ################################
#best practice before running derivatives is to order the data by elbow angle
#extensions first
ordered.extensions.data<-list()
for (i in 1:length(extensions.list)){
  ordered.extensions.data[[i]]<-extensions.list[[i]][order(
                                              extensions.list[[i]]$elbowAngle),]
}
names(ordered.extensions.data)<-extensions
#flexions
ordered.flexions.data<-list()
for (i in 1:length(flexions.list)){
  ordered.flexions.data[[i]]<-flexions.list[[i]][order(
                                                flexions.list[[i]]$elbowAngle),]
}
names(ordered.flexions.data)<-flexions

############################# loess of extensions ##############################
#use the extensions.list to generate a loess curve for each species
loess.extensions<-list()
for (i in 1:length(extensions.list)){
  loess.extensions[[i]]<-loess.as(ordered.extensions.data[[i]]$elbowAngle,
                                  ordered.extensions.data[[i]]$manusAngle,
                                  degree=1,criterion=c("aicc","gcv")[2],
                                  user.span=NULL,plot=F)
}
names(loess.extensions)<-extensions
#predictions from the models
loess.extensions.predicts<-list()
for (i in 1:length(extensions.list)){
  loess.extensions.predicts[[i]]<-predict(loess.extensions[[i]])
}
names(loess.extensions.predicts)<-extensions


############################## loess of flexions ###############################
#use the flexions.list to generate a loess curve for each species
loess.flexions<-list()
for (i in 1:length(flexions.list)){
  loess.flexions[[i]]<-loess.as(ordered.flexions.data[[i]]$elbowAngle,
                                ordered.flexions.data[[i]]$manusAngle,
                                degree=1,criterion=c("aicc","gcv")[2],
                                user.span=NULL,plot=F)
}
names(loess.flexions)<-flexions
#predictions from the models
loess.flexions.predicts<-list()
for (i in 1:length(flexions.list)){
  loess.flexions.predicts[[i]]<-predict(loess.flexions[[i]])
}
names(loess.flexions.predicts)<-flexions


############################## linkage lengths #################################
#first create an object that will store the loess of 6-bar extensions 
#as coordinates. These will be used to determine their lengths
linkage.shapes<-list()
for (i in 1:length(ordered.extensions.data)){
  linkage.shapes[[i]]<-data.frame(elbowAngle=
                                    ordered.extensions.data[[i]]$elbowAngle,
                                  manusAngle=loess.extensions.predicts[[i]])}
names(linkage.shapes)<-names(ordered.extensions.data)
#extract sizes
linkageshapes.lengths<-NULL
for (i in 1:length(linkage.shapes)){
  linkageshapes.lengths[i]<-sum(sqrt(rowSums(apply(
    data.frame(linkage.shapes[i]),2,diff)^2)))
}
source("./avian_metadata/ROMnames.R")
names(linkageshapes.lengths)<-names(ROMnames)


########################## extension ROM sourcing ##############################
#source individual species analyses
#all of these files will have "6bar-frames" in the title
cspath<-"./data_import_scripts/Config_space/"
configglist<-list.files(path=cspath,pattern="ConfigSpace_",full.names=TRUE,
                        recursive=TRUE)
for(i in 1:length(configglist)){
  source(configglist[i])
}


############################### organize data ##################################
#create two separate lists of data, one for extensions and the other for 
#flexions
dorsalROMs<-ls(pattern='*.configSpace')
source("./avian_metadata/ROMnames.R")
names(dorsalROMs)<-ROMnames
dorsalROMs.list<-rbind(mget(dorsalROMs))
names(dorsalROMs.list)<-names(dorsalROMs)


############################### create hulls ###################################
#create convex hulls around the configuration space plots; these will be used
#for the elliptical fourier analyses
chull.list<-list()
for (i in 1:length(dorsalROMs.list)){
  chull.list[[i]]<-convexhull.xy(x=dorsalROMs.list[[i]]$elbowAngle,
                                 y=dorsalROMs.list[[i]]$manusAngle)
}
names(chull.list)<-names(dorsalROMs)
chull.stack<-list()
for (i in 1:length(dorsalROMs.list)){
  chull.stack[[i]]<-cbind(chull.list[[i]]$bdry[[1]]$x,
                          chull.list[[i]]$bdry[[1]]$y)
}
names(chull.stack)<-names(dorsalROMs)

#create Polygon stack to extract areas 
a<-lapply(chull.stack, Polygon)
areas<-NULL
for (i in 1:length(a)){
  areas[i]<-a[[i]]@area
}
names(areas)<-names(dorsalROMs)


############################### import hulls ###################################
#for use with the Momocs package to achieve elliptical Fourier analysis
Out(chull.stack)->configSpace.Out

#the following functions place the 'first point' on the max sum of elbow and
#manus angle (which generally corresponds to max extension)
obj<-list()
maxobjs<-NULL
for (i in 1:length(configSpace.Out)){
  obj[[i]]<-matrix(nrow=dim(chull.stack[[i]])[1])
}
for (i in 1:length(configSpace.Out)){
  for (j in 1:dim(chull.stack[[i]])[1]){
    obj[[i]][j,]<-sum(chull.stack[[i]][j,1],chull.stack[[i]][j,2])
  }
  maxobjs<-c(maxobjs,which.max(obj[[i]]))
}
configSpace.slid<-coo_slide(configSpace.Out,id=maxobjs)
fgProcrustes(coo_interpolate(configSpace.slid,50),tol=1e-10)->configSpace.proc
stack(configSpace.proc)
calibrate_harmonicpower_efourier(configSpace.proc,nb.h=15,thresh=96)
configSpace.eFourier<-efourier(configSpace.proc,nb.h=5,verbose=TRUE,norm=FALSE)


########################## config space ordination #############################
configSpace.PCA<-PCA(configSpace.eFourier,scale.=FALSE,center=TRUE,fac=NULL)
plot(configSpace.PCA,cex=3, pos.shp="range_axes",labelspoints=TRUE,
     abbreviate.labelspoints=FALSE)

configSpace.varExpl<-rbind(
  SD = sqrt(configSpace.PCA$eig),
  Proportion = configSpace.PCA$eig/sum(configSpace.PCA$eig),
  Cumulative = cumsum(configSpace.PCA$eig)/sum(configSpace.PCA$eig))
plot(1:ncol(configSpace.varExpl),
     configSpace.varExpl[2,],pch=19);abline(h=mean(configSpace.varExpl[2,]))
plot(1:ncol(configSpace.varExpl),configSpace.varExpl[3,],
     pch=19,ylim=c(0,1));abline(h=0.95)
#rownames(configSpace.PCA$x)


############################# max extension frames #############################
#the following functions find the max sum of elbow and
#manus angle (which corresponds to max extension)
obj<-list()
ROMmaxExtensionFrames<-NULL
for (i in 1:length(dorsalROMs.list)){
  obj[[i]]<-matrix(nrow=dim(dorsalROMs.list[[i]])[1])
}
for (i in 1:length(dorsalROMs)){
  for (j in 1:dim(dorsalROMs.list[[i]])[1]){
    obj[[i]][j,]<-sum(dorsalROMs.list[[i]][j,2],dorsalROMs.list[[i]][j,3])
  }
  ROMmaxExtensionFrames<-c(ROMmaxExtensionFrames,which.max(obj[[i]]))
}
ROMmaxExtensionInfo<-data.frame()
for (q in 1:length(dorsalROMs.list)){
  ROMmaxExtensionInfo[q,1]<-as.character(
    dorsalROMs.list[[q]][ROMmaxExtensionFrames[q],1])
  ROMmaxExtensionInfo[q,2]<-dorsalROMs.list[[q]][ROMmaxExtensionFrames[q],2]
  ROMmaxExtensionInfo[q,3]<-dorsalROMs.list[[q]][ROMmaxExtensionFrames[q],3]
  ROMmaxExtensionInfo[q,4]<-dorsalROMs.list[[q]][ROMmaxExtensionFrames[q],4]
}
colnames(ROMmaxExtensionInfo)<-c("filename","elbowAngle","manusAngle","frame")
rownames(ROMmaxExtensionInfo)<-names(dorsalROMs)
ROMmaxExtensionInfo$phylo<-names(dorsalROMs)

