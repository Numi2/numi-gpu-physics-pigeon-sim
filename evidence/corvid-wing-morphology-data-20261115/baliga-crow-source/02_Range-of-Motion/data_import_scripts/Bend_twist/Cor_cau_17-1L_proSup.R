source('./data_import_scripts/Config_space/ConfigSpace_Corvus_caurinus.R')
path<-"./data/Corvus_caurinus/Bend_Twist/2018-05-15_Cor_bra_17-1L_pdsv/proSup/"

################################ import data ###################################
#data will be imported from the "...xyzpts.csv" DLTdv6 file
#point 1 - head of the humerus
#point 2 - elbow
#point 3 - wrist
#point 4 - distal point on carpometacarpus
#point 5 - leading edge point, perpendicular to point 4 and length axis of cmc
filelist.xyz<-list.files(path=path,pattern=paste('*',"xyzpts.csv",sep=""),
                             full.names=TRUE)
proSup.xyz<-NULL
for (i in 1:length(filelist.xyz)){
  filename = filelist.xyz[i] 
  proSup.xyz[[i]]<-read.csv(filename,stringsAsFactors=FALSE)
  proSup.xyz[[i]]<-proSup.xyz[[i]][,c(1:15)]
  proSup.xyz[[i]]$frame <- seq.int(nrow(proSup.xyz[[i]]))
  proSup.xyz[[i]]<-cbind(filelist.xyz[i],
                          proSup.xyz[[i]][complete.cases(proSup.xyz[[i]]),])
  #names(proSup.xyz[[i]])<-filelist.xyz[i]
}
proSup.xyz<-ldply(proSup.xyz)

############################### compute angles #################################
#calculate the 3D elbow and manus angles
#calculate the 2D elbow and manus angles
#calculate the xyz plane angles between the hand-wing and arm-wing
proSup.three.d.angles<-data.frame(proSup.xyz[,1],
                  xyzangles(proSup.xyz[,2],proSup.xyz[,3],proSup.xyz[,4],
                            proSup.xyz[,5],proSup.xyz[,6],proSup.xyz[,7],
                            proSup.xyz[,8],proSup.xyz[,9],proSup.xyz[,10]),
                  xyzangles(proSup.xyz[,5],proSup.xyz[,6],proSup.xyz[,7],
                            proSup.xyz[,8],proSup.xyz[,9],proSup.xyz[,10],
                            proSup.xyz[,11],proSup.xyz[,12],proSup.xyz[,13]),
                  proSup.xyz$frame)
colnames(proSup.three.d.angles)<-c("filename","elbowAngle","manusAngle",
                                    "frame")

proSup.twod.angles<-matrix(nrow=nrow(proSup.xyz),ncol=2)
for (i in 1:nrow(proSup.xyz)){
  proSup.twod.angles[i,1]<-xyangles(proSup.xyz[i,2],proSup.xyz[i,3],
                                     proSup.xyz[i,5],proSup.xyz[i,6],
                                     proSup.xyz[i,8],proSup.xyz[i,9])
  proSup.twod.angles[i,2]<-xyangles(proSup.xyz[i,5],proSup.xyz[i,6],
                                     proSup.xyz[i,8],proSup.xyz[i,9],
                                     proSup.xyz[i,11],proSup.xyz[i,12])
}
as.data.frame(proSup.twod.angles)->proSup.twod.angles
colnames(proSup.twod.angles)<-c("elbowAngle2d","manusAngle2d")

proSup.planeAngles<-data.frame(xyzangles(proSup.xyz[,14],proSup.xyz[,15],proSup.xyz[,13],
                                         proSup.xyz[,11],proSup.xyz[,12],proSup.xyz[,13],
                                         proSup.xyz[,14],proSup.xyz[,15],proSup.xyz[,16]))

#collect everything
.proSupAngleData.Cor_cau_17_1R<-data.frame(proSup.three.d.angles,
                                           proSup.twod.angles,
                                           proSup.planeAngles,
                                           proSup.xyz[,2:16])
colnames(.proSupAngleData.Cor_cau_17_1R)[7]<-"proSupAngles"
#update based on Z-axis values of points 4 and 5
.proSupAngleData.Cor_cau_17_1R->df
df$proSupAngles[df$pt5_Z >= df$pt4_Z] <- (-1*df$proSupAngles[df$pt5_Z >= df$pt4_Z])
df[complete.cases(df), ]->df
.proSupAngleData.Cor_cau_17_1R<-df

#make convex hulls for elbow ang vs eledep and manusangl vs eledep
#elbowAngle2d vs proSupAngles
.proSupElbowHull.Cor_cau_17_1R<-convexhull.xy(.proSupAngleData.Cor_cau_17_1R$elbowAngle2d,
                                              .proSupAngleData.Cor_cau_17_1R$proSupAngles)

#elbowAngle2d vs proSupAngles
.proSupManusHull.Cor_cau_17_1R<-convexhull.xy(.proSupAngleData.Cor_cau_17_1R$manusAngle2d,
                                              .proSupAngleData.Cor_cau_17_1R$proSupAngles)

#alphahulls
bemb<-matrix(nrow=nrow(.proSupAngleData.Cor_cau_17_1R),ncol=3)
bemb[,1]<-.proSupAngleData.Cor_cau_17_1R$elbowAngle
bemb[,2]<-.proSupAngleData.Cor_cau_17_1R$manusAngle
bemb[,3]<-.proSupAngleData.Cor_cau_17_1R$proSupAngles+9
colnames(bemb)<-c("elbowAngle","manusAngle","proSupAngles")

.proSupAlphaHull.Cor_cau_17_1R<-ashape3d(bemb,alpha=100)
#plot(.proSupAlphaHull.Cor_cau_17_1R)
#axes3d(labels = T)
#title3d(xlab='elbowAngle',ylab='manusAngle',zlab='proSupAngles')

data.frame(.proSupAlphaHull.Cor_cau_17_1R$triang)->tri
trifilt<-dplyr::filter(tri,on.ch>0)

k<-unique(
  unique(trifilt[,1]),
  unique(trifilt[,2]),
  unique(trifilt[,3]))
g<-data.frame(.proSupAlphaHull.Cor_cau_17_1R$x)[k,]
pro<-dplyr::filter(g,proSupAngles>=0)
sup<-dplyr::filter(g,proSupAngles<=0)

#p<-ggplot(pro,aes(elbowAngle,manusAngle))
#p+geom_point(size=4,aes(colour=proSupAngles)) +
#  coord_fixed(ratio=1/1) +
#  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
#  scale_color_viridis(discrete=FALSE) +
#  theme_bw()

testhull<-convexhull.xy(x=Cor_cau.configSpace$elbowAngle,
                        y=Cor_cau.configSpace$manusAngle)
chull2d<-cbind(testhull$bdry[[1]][[1]],testhull$bdry[[1]][[2]])

pro[,1]->x1;pro[,2]->x2;pro[,3]->y;prolmdat<-data.frame(x1,x2,y)
loes.pron<-lm(y~x1+x2,data=prolmdat)
x1<-seq(ceiling(min(chull2d[,1])),floor(max(chull2d[,1])),by=4)
x2<-seq(ceiling(min(chull2d[,2])),floor(max(chull2d[,2])),by=4)
d1<-expand.grid(x1,x2);colnames(d1)<-c("x1","x2")
pron.preds<-predict(loes.pron,newdata=data.frame(d1))
pron.plotdat<-data.frame(d1,pron.preds)
colnames(pro)->colnames(pron.plotdat)
#hist(pro$proSupAngles);hist(pron.plotdat$proSupAngles)


sup[,1]->x1;sup[,2]->x2;sup[,3]->y;suplmdat<-data.frame(x1,x2,y)
loes.supn<-lm(y~x1+x2,data=suplmdat)
x1<-seq(ceiling(min(chull2d[,1])),floor(max(chull2d[,1])),by=4)
x2<-seq(ceiling(min(chull2d[,2])),floor(max(chull2d[,2])),by=4)
d1<-expand.grid(x1,x2);colnames(d1)<-c("x1","x2")
supn.preds<-predict(loes.supn,newdata=data.frame(d1))
supn.plotdat<-data.frame(d1,supn.preds)
colnames(sup)->colnames(supn.plotdat)
#hist(sup$proSupAngles);hist(supn.plotdat$proSupAngles)

pron.plotdat$proSupAngles[pron.plotdat$proSupAngles<0]<-0
pron.plotdat$proSupAngles[pron.plotdat$proSupAngles=='NA']<-0
pron.plotdat$proSupAngles<-scales::rescale(pron.plotdat$proSupAngles,
                                           to=c(min(pro$proSupAngles),
                                                max(pro$proSupAngles)))
supn.plotdat$proSupAngles[supn.plotdat$proSupAngles>0]<-0
supn.plotdat$proSupAngles[supn.plotdat$proSupAngles=='NA']<-0
supn.plotdat$proSupAngles<-scales::rescale(supn.plotdat$proSupAngles,
                                           to=c(min(sup$proSupAngles),
                                                max(sup$proSupAngles)))
#p<-ggplot(pron.plotdat,aes(elbowAngle,manusAngle))
#p+geom_point(size=4,aes(colour=proSupAngles)) +
#  coord_fixed(ratio=1/1) +
#  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
#  scale_color_viridis(discrete=FALSE) +
#  theme_bw()

filtpro<-pip2d(as.matrix(chull2d),as.matrix(pron.plotdat[,1:2]))
a<-pron.plotdat[filtpro==1,]
colnames(a)<-c("elbowAngle","manusAngle","maxpronation")
.maxpronation.Cor_cau_17_1R<-dplyr::filter(a,maxpronation>=0)

filtsup<-pip2d(as.matrix(chull2d),as.matrix(supn.plotdat[,1:2]))
a<-supn.plotdat[filtsup==1,]
colnames(a)<-c("elbowAngle","manusAngle","maxsupination")
.maxsupination.Cor_cau_17_1R<-dplyr::filter(a,maxsupination<=0)

p<-ggplot(.maxpronation.Cor_cau_17_1R,aes(elbowAngle,manusAngle))
p+geom_point(size=4,aes(colour=maxpronation)) +
  coord_fixed(ratio=1/1) +
  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
  scale_color_viridis(discrete=FALSE) +
  theme_bw()

p<-ggplot(.maxsupination.Cor_cau_17_1R,aes(elbowAngle,manusAngle))
p+geom_point(size=4,aes(colour=maxsupination)) +
  coord_fixed(ratio=1/1) +
  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
  scale_color_viridis(discrete=FALSE,direction=-1,option="B") +
  theme_bw()

o<-inner_join(.maxsupination.Cor_cau_17_1R,.maxpronation.Cor_cau_17_1R)
o[,"prosupCapability"]<-o$maxpronation+abs(o$maxsupination)
o[,"id"]<-"Corvus_caurinus"
o->rangepronsup.Cor_cau_17_1R
p<-ggplot(rangepronsup.Cor_cau_17_1R,aes(elbowAngle,manusAngle))
p+geom_point(size=4,aes(colour=prosupCapability)) +
  coord_fixed(ratio=1/1) +
  coord_cartesian(xlim=c(0,200),ylim=c(0,200)) +
  scale_color_viridis(discrete=FALSE,option="A") +
  theme_bw()
