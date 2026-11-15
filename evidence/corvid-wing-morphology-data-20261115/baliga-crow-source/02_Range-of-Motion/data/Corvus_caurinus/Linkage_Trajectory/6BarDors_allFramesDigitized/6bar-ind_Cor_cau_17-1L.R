path<-"./data/Corvus_caurinus/Linkage_Trajectory/6BarDors_allFramesDigitized/"

####data import####
#data will be imported from the "...xyzpts.csv" DLTdv6 file
#point 1 - head of the humerus
#point 2 - elbow
#point 3 - wrist
#point 4 - distal point on carpometacarpus
filelist.xyz   <- list.files(path=path,pattern = paste('*',"xyzpts.csv",sep=""),
                             full.names=TRUE)
sixbar.xyz<-NULL
for (i in 1:length(filelist.xyz)){
  filename = filelist.xyz[i] 
  sixbar.xyz[[i]]<-read.csv(filename,stringsAsFactors=FALSE)
  sixbar.xyz[[i]]<-sixbar.xyz[[i]][,c(1:12)]
  sixbar.xyz[[i]]$frame <- seq.int(nrow(sixbar.xyz[[i]]))
  sixbar.xyz[[i]]<-cbind(filelist.xyz[i],sixbar.xyz[[i]][complete.cases(sixbar.xyz[[i]]), ])
  #names(sixbar.xyz[[i]])<-filelist.xyz[i]
}
sixbar.xyz<-ldply(sixbar.xyz)

####calculate angles and store in a common data frame####
#angles are calculated from 3D data
#elbowAngle - uses points 1, 2, 3
#manusAngle - uses points 2, 3, 4
angle.data.three.d <-data.frame(sixbar.xyz[,1],
                      xyzangles(sixbar.xyz[,2],sixbar.xyz[,3],sixbar.xyz[,4],
                                sixbar.xyz[,5],sixbar.xyz[,6],sixbar.xyz[,7],
                                sixbar.xyz[,8],sixbar.xyz[,9],sixbar.xyz[,10]),
                      xyzangles(sixbar.xyz[,5],sixbar.xyz[,6],sixbar.xyz[,7],
                                sixbar.xyz[,8],sixbar.xyz[,9],sixbar.xyz[,10],
                                sixbar.xyz[,11],sixbar.xyz[,12],sixbar.xyz[,13]),
                      sixbar.xyz$frame)
colnames(angle.data.three.d)<-c("filename","elbowAngle","manusAngle","frame")

#plot(angle.data.three.d[,c(2,3)],pch=19,col=as.factor(angle.data.three.d[,1]),
#     xlim=c(0,180),ylim=c(0,180))
#identify(angle.data.three.d$elbowAngle,angle.data.three.d$manusAngle,labels = angle.data.three.d$frame, plot=TRUE)

#####select frames#####
#use plotting and visual inspection of the videos to determine the best cycles
#quick plot of all the cycles
#plot(angle.data.three.d$elbowAngle,ylim=c(0,180),pch=19,col="black")
#points(angle.data.three.d$manusAngle,pch=19,col="red")
#identify(1:nrow(angle.data.three.d),angle.data.three.d$elbowAngle,labels = angle.data.three.d$frame, plot=TRUE)

#plot(angle.data.three.d[245:382,c(2,3)],pch=19,col=as.factor(angle.data.three.d[,1]),xlim=c(0,180),ylim=c(0,180))
#plot(angle.data.three.d[383:525,c(2,3)],pch=19,col=as.factor(angle.data.three.d[,1]),xlim=c(0,180),ylim=c(0,180))
#plot(angle.data.three.d[526:668,c(2,3)],pch=19,col=as.factor(angle.data.three.d[,1]),xlim=c(0,180),ylim=c(0,180))

#extensions:
EXTframes_Cor_cau_17_1L<-c(3:34,99:130,164:188,221:242,322:345)
.Cor_cau_17_1L.ext<-cbind(angle.data.three.d[EXTframes_Cor_cau_17_1L,],
                        sixbar.xyz[EXTframes_Cor_cau_17_1L,])
plot(.Cor_cau_17_1L.ext[,c(2,3)],pch=19,col=as.factor(angle.data.three.d[,1]),
     xlim=c(0,180),ylim=c(0,180))

#flexions:
FLXframes_Cor_cau_17_1L<-c(34:84,130:164,194:221,274:318)
.Cor_cau_17_1L.flx<-cbind(angle.data.three.d[FLXframes_Cor_cau_17_1L,],
                        sixbar.xyz[FLXframes_Cor_cau_17_1L,])
#plot(.Cor_cau_17_1L.flx[,c(2,3)],pch=19,col=as.factor(angle.data.three.d[,1]),
#     xlim=c(0,180),ylim=c(0,180))

#verification
#plot(Cor_cau_17_1L.flx$elbowAngle,ylim=c(0,180),pch=19,col="black")
#points(Cor_cau_17_1L.flx$manusAngle,pch=19,col="red")