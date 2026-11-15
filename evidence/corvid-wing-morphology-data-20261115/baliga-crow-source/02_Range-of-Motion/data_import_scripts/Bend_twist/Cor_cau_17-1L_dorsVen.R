source('./data_import_scripts/Config_space/ConfigSpace_Corvus_caurinus.R')
path<-"./data/Corvus_caurinus/Bend_Twist/2018-05-15_Cor_bra_17-1L_pdsv/"

################################ import data ###################################
#data will be imported from the "...xyzpts.csv" DLTdv6 file
#point 1 - head of the humerus
#point 2 - elbow
#point 3 - wrist
#point 4 - distal point on carpometacarpus
filelist.xyz<-list.files(path=path,pattern=paste('*',"xyzpts.csv",sep=""),
                             full.names=TRUE)
dorsVen.xyz<-NULL
for (i in 1:length(filelist.xyz)){
  filename = filelist.xyz[i] 
  dorsVen.xyz[[i]]<-read.csv(filename,stringsAsFactors=FALSE)
  dorsVen.xyz[[i]]<-dorsVen.xyz[[i]][,c(1:12)]
  dorsVen.xyz[[i]]$frame <- seq.int(nrow(dorsVen.xyz[[i]]))
  dorsVen.xyz[[i]]<-cbind(filelist.xyz[i],
                          dorsVen.xyz[[i]][complete.cases(dorsVen.xyz[[i]]),])
  #names(dorsVen.xyz[[i]])<-filelist.xyz[i]
}
dorsVen.xyz<-ldply(dorsVen.xyz)

############################### compute angles #################################
#calculate the 3D elbow and manus angles
#calculate the 2D elbow and manus angles
#calculate the xyz plane angles between the hand-wing and arm-wing
dorsVen.three.d.angles<-data.frame(dorsVen.xyz[,1],
                  xyzangles(dorsVen.xyz[,2],dorsVen.xyz[,3],dorsVen.xyz[,4],
                            dorsVen.xyz[,5],dorsVen.xyz[,6],dorsVen.xyz[,7],
                            dorsVen.xyz[,8],dorsVen.xyz[,9],dorsVen.xyz[,10]),
                  xyzangles(dorsVen.xyz[,5],dorsVen.xyz[,6],dorsVen.xyz[,7],
                            dorsVen.xyz[,8],dorsVen.xyz[,9],dorsVen.xyz[,10],
                            dorsVen.xyz[,11],dorsVen.xyz[,12],dorsVen.xyz[,13]),
                  dorsVen.xyz$frame)
colnames(dorsVen.three.d.angles)<-c("filename","elbowAngle","manusAngle",
                                    "frame")

dorsVen.twod.angles<-matrix(nrow=nrow(dorsVen.xyz),ncol=2)
for (i in 1:nrow(dorsVen.xyz)){
  dorsVen.twod.angles[i,1]<-xyangles(dorsVen.xyz[i,2],dorsVen.xyz[i,3],
                                     dorsVen.xyz[i,5],dorsVen.xyz[i,6],
                                     dorsVen.xyz[i,8],dorsVen.xyz[i,9])
  dorsVen.twod.angles[i,2]<-xyangles(dorsVen.xyz[i,5],dorsVen.xyz[i,6],
                                     dorsVen.xyz[i,8],dorsVen.xyz[i,9],
                                     dorsVen.xyz[i,11],dorsVen.xyz[i,12])
}
as.data.frame(dorsVen.twod.angles)->dorsVen.twod.angles
colnames(dorsVen.twod.angles)<-c("elbowAngle2d","manusAngle2d")

dorsVen.planeAngles<-data.frame()
for (i in 1:nrow(dorsVen.xyz)){
  dorsVen.planeAngles[i,1]<-xyzplaneangles(dorsVen.xyz[i,2],
                                           dorsVen.xyz[i,3],
                                           dorsVen.xyz[i,4],
                                           dorsVen.xyz[i,5],
                                           dorsVen.xyz[i,6],
                                           dorsVen.xyz[i,7],
                                           dorsVen.xyz[i,8],
                                           dorsVen.xyz[i,9],
                                           dorsVen.xyz[i,10],
                                           dorsVen.xyz[i,5],
                                           dorsVen.xyz[i,6],
                                           dorsVen.xyz[i,7],
                                           dorsVen.xyz[i,8],
                                           dorsVen.xyz[i,9],
                                           dorsVen.xyz[i,10],
                                           dorsVen.xyz[i,11],
                                           dorsVen.xyz[i,12],
                                           dorsVen.xyz[i,13]
                                           )
}

#sin(theta)= ((point4-Z)-(point3-Z)) / (dist from 3 to 4)
dorsVen.angle.rad<-asin(((dorsVen.xyz$pt4_Z)-(dorsVen.xyz$pt3_Z))/
                          (sqrt(((dorsVen.xyz$pt3_X-dorsVen.xyz$pt4_X)^2)+
                                ((dorsVen.xyz$pt3_Y-dorsVen.xyz$pt4_Y)^2)+
                                ((dorsVen.xyz$pt3_Z-dorsVen.xyz$pt4_Z)^2))))
dorsVen.angle.deg<-rad2deg(dorsVen.angle.rad)

#collect everything
.dorsVenAngleData.Cor_cau_17_1L<-data.frame(dorsVen.three.d.angles,
                                            dorsVen.twod.angles,
                                            dorsVen.planeAngles,
                                            dorsVen.angle.deg)
colnames(.dorsVenAngleData.Cor_cau_17_1L)[7]<-"planeAngles"
colnames(.dorsVenAngleData.Cor_cau_17_1L)[8]<-"elevDepAngle"

#make convex hulls for elbow ang vs eledep and manusangl vs eledep
#elbowAngle2d vs elevDepAngle
.dorsVenElbowHull.Cor_cau_17_1L<-convexhull.xy(.dorsVenAngleData.Cor_cau_17_1L$elbowAngle2d,
                                               .dorsVenAngleData.Cor_cau_17_1L$elevDepAngle)

#elbowAngle2d vs elevDepAngle
.dorsVenManusHull.Cor_cau_17_1L<-convexhull.xy(.dorsVenAngleData.Cor_cau_17_1L$manusAngle2d,
                                               .dorsVenAngleData.Cor_cau_17_1L$elevDepAngle)

#alphahulls
bemb<-matrix(nrow=nrow(.dorsVenAngleData.Cor_cau_17_1L),ncol=3)
bemb[,1]<-.dorsVenAngleData.Cor_cau_17_1L$elbowAngle2d
bemb[,2]<-.dorsVenAngleData.Cor_cau_17_1L$manusAngle2d
bemb[,3]<-.dorsVenAngleData.Cor_cau_17_1L$elevDepAngle
colnames(bemb)<-c("elbowAngle","manusAngle","elevDepAngle")

.dorsVenAlphaHull.Cor_cau_17_1L<-ashape3d(bemb,alpha=100)
#plot(.dorsVenAlphaHull.Cor_cau_17_1L)
#axes3d(labels = T)
#title3d(xlab='elbowAngle',ylab='manusAngle',zlab='elevDepAngle')


data.frame(.dorsVenAlphaHull.Cor_cau_17_1L$edge)->tri
trifilt<-dplyr::filter(tri,on.ch>0)

k<-unique(
  unique(trifilt[,1]),
  unique(trifilt[,2]),
  unique(trifilt[,3]))
g<-data.frame(.dorsVenAlphaHull.Cor_cau_17_1L$x)[k,]
ele<-dplyr::filter(g,elevDepAngle>=0)
dep<-dplyr::filter(g,elevDepAngle<=5);dep$elevDepAngle-5->dep$elevDepAngle


#p<-ggplot(ele,aes(elbowAngle,manusAngle))
#p+geom_point(size=4,aes(colour=elevDepAngle)) +
#  coord_fixed(ratio=1/1) +
#  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
#  scale_color_viridis(discrete=FALSE) +
#  theme_bw()

testhull<-convexhull.xy(x=Cor_cau.configSpace$elbowAngle,
                        y=Cor_cau.configSpace$manusAngle)
chull2d<-cbind(testhull$bdry[[1]][[1]],testhull$bdry[[1]][[2]])

ele[,1]->x1;ele[,2]->x2;ele[,3]->y;elelmdat<-data.frame(x1,x2,y)
set.seed(123)
loes.elev<-train(x=elelmdat[,1:2],y=elelmdat[,3],method='brnn',normalize=TRUE)
x1<-seq(ceiling(min(chull2d[,1])),floor(max(chull2d[,1])),by=4)
x2<-seq(ceiling(min(chull2d[,2])),floor(max(chull2d[,2])),by=4)
d1<-expand.grid(x1,x2);colnames(d1)<-c("x1","x2")
elev.preds<-predict(loes.elev,newdata=data.frame(d1))
elev.plotdat<-data.frame(d1,elev.preds)
colnames(ele)->colnames(elev.plotdat)
#hist(ele$elevDepAngle);hist(elev.plotdat$elevDepAngle)

dep[,1]->x1;dep[,2]->x2;dep[,3]->y;deplmdat<-data.frame(x1,x2,y)
set.seed(123)
loes.depr<-train(x=deplmdat[,1:2],y=deplmdat[,3],method='brnn',normalize=TRUE)
x1<-seq(ceiling(min(chull2d[,1])),floor(max(chull2d[,1])),by=4)
x2<-seq(ceiling(min(chull2d[,2])),floor(max(chull2d[,2])),by=4)
d1<-expand.grid(x1,x2);colnames(d1)<-c("x1","x2")
depr.preds<-predict(loes.depr,newdata=data.frame(d1))
depr.plotdat<-data.frame(d1,depr.preds)
colnames(dep)->colnames(depr.plotdat)
#hist(dep$elevDepAngle);hist(depr.plotdat$elevDepAngle)

elev.plotdat$elevDepAngle[elev.plotdat$elevDepAngle<0]<-0
elev.plotdat$elevDepAngle[elev.plotdat$elevDepAngle=='NA']<-0
elev.plotdat$elevDepAngle<-scales::rescale(elev.plotdat$elevDepAngle,
                                           to=c(min(ele$elevDepAngle),
                                                max(ele$elevDepAngle)))
depr.plotdat$elevDepAngle[depr.plotdat$elevDepAngle>0]<-0
depr.plotdat$elevDepAngle[depr.plotdat$elevDepAngle=='NA']<-0
depr.plotdat$elevDepAngle<-scales::rescale(depr.plotdat$elevDepAngle,
                                           to=c(min(dep$elevDepAngle),
                                                max(dep$elevDepAngle)))

#p<-ggplot(elev.plotdat,aes(elbowAngle,manusAngle))
#p+geom_point(size=4,aes(colour=elevDepAngle)) +
#  coord_fixed(ratio=1/1) +
#  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
#  scale_color_viridis(discrete=FALSE) +
#  theme_bw()

filtele<-pip2d(as.matrix(chull2d),as.matrix(elev.plotdat[,1:2]))
a<-elev.plotdat[filtele==1,]
colnames(a)<-c("elbowAngle","manusAngle","maxElevation")
.maxElevation.Cor_cau_17_1L<-dplyr::filter(a,maxElevation>=0)

filtdep<-pip2d(as.matrix(chull2d),as.matrix(depr.plotdat[,1:2]))
a<-depr.plotdat[filtdep==1,]
colnames(a)<-c("elbowAngle","manusAngle","maxDepression")
.maxDepression.Cor_cau_17_1L<-dplyr::filter(a,maxDepression<=0)

p<-ggplot(.maxElevation.Cor_cau_17_1L,aes(elbowAngle,manusAngle))
p+geom_point(size=4,aes(colour=maxElevation)) +
  coord_fixed(ratio=1/1) +
  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
  scale_color_viridis(discrete=FALSE) +
  theme_bw()

p<-ggplot(.maxDepression.Cor_cau_17_1L,aes(elbowAngle,manusAngle))
p+geom_point(size=4,aes(colour=maxDepression)) +
  coord_fixed(ratio=1/1) +
  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
  scale_color_viridis(discrete=FALSE,direction=-1,option="B") +
  theme_bw()

o<-inner_join(.maxDepression.Cor_cau_17_1L,.maxElevation.Cor_cau_17_1L)
o[,"eleDepCapability"]<-o$maxElevation+abs(o$maxDepression)
o[,"id"]<-"Corvus_caurinus"
o->rangeElevDep.Cor_cau_17_1L
p<-ggplot(rangeElevDep.Cor_cau_17_1L,aes(elbowAngle,manusAngle))
p+geom_point(size=4,aes(colour=eleDepCapability)) +
  coord_fixed(ratio=1/1) +
  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
  scale_color_viridis(discrete=FALSE,option="A") +
  theme_bw()
