path<-"./MiroM120_digitization/2018-06-14_CH-VB_LLT_partII/2018-06-14_Cor_cau_18-2_Sweep/"

################################ import data ###################################
#data will be imported from the "...xyzpts.csv" DLTdv6 file
#point 1 - head of the humerus
#point 2 - elbow
#point 3 - wrist
#point 4 - distal point on carpometacarpus
filelist.xyz<-list.files(path=path,pattern = paste('*',"xyzpts.csv",sep=""),
                         full.names=TRUE)
dorsrom.xyz<-NULL
for (i in 1:length(filelist.xyz)){
  filename = filelist.xyz[i] 
  dorsrom.xyz[[i]]<-read.csv(filename,stringsAsFactors=FALSE)
  dorsrom.xyz[[i]]<-dorsrom.xyz[[i]][,c(1:12)]
  dorsrom.xyz[[i]]$frame <- seq.int(nrow(dorsrom.xyz[[i]]))
  dorsrom.xyz[[i]]<-cbind(filelist.xyz[i],
                          dorsrom.xyz[[i]][complete.cases(dorsrom.xyz[[i]]),])
  #names(dorsrom.xyz[[i]])<-filelist.xyz[i]
}
dorsrom.xyz<-ldply(dorsrom.xyz)

twod.angles<-matrix(nrow=nrow(dorsrom.xyz),ncol=2)
for (i in 1:nrow(dorsrom.xyz)){
  twod.angles[i,1]<-xyangles(dorsrom.xyz[i,2],dorsrom.xyz[i,3],
                             dorsrom.xyz[i,5],dorsrom.xyz[i,6],
                             dorsrom.xyz[i,8],dorsrom.xyz[i,9])
  twod.angles[i,2]<-xyangles(dorsrom.xyz[i,5],dorsrom.xyz[i,6],
                             dorsrom.xyz[i,8],dorsrom.xyz[i,9],
                             dorsrom.xyz[i,11],dorsrom.xyz[i,12])
}
as.data.frame(twod.angles)->twod.angles
colnames(twod.angles)<-c("elbowAngle2d","manusAngle2d")

####calculate angles and store in a common data frame####
#angles that are calculated from 3D data
#elbowAngle - uses points 1, 2, 3
#manusAngle - uses points 2, 3, 4
#angles that are caluclated from 2D data
#elbowAngle2d - uses pts 1, 2, 3 but from the X-Y plane only
#manusAngle2d - uses pts 2, 3, 4 but from the X-Y plane only
angle.data <-data.frame(dorsrom.xyz[,1],
                  xyzangles(dorsrom.xyz[,2],dorsrom.xyz[,3],dorsrom.xyz[,4],
                            dorsrom.xyz[,5],dorsrom.xyz[,6],dorsrom.xyz[,7],
                            dorsrom.xyz[,8],dorsrom.xyz[,9],dorsrom.xyz[,10]),
                  xyzangles(dorsrom.xyz[,5],dorsrom.xyz[,6],dorsrom.xyz[,7],
                            dorsrom.xyz[,8],dorsrom.xyz[,9],dorsrom.xyz[,10],
                            dorsrom.xyz[,11],dorsrom.xyz[,12],dorsrom.xyz[,13]),
                  dorsrom.xyz$frame)
colnames(angle.data)<-c("filename","elbowAngle","manusAngle","frame")

#configuration space
.Cor_cau_18_2.configSpace<-cbind(angle.data,
                                  dorsrom.xyz[,2:13],
                                  twod.angles$elbowAngle2d,
                                  twod.angles$manusAngle2d)
colnames(.Cor_cau_18_2.configSpace)[17]<-"elbowAngle2d"
colnames(.Cor_cau_18_2.configSpace)[18]<-"manusAngle2d"
