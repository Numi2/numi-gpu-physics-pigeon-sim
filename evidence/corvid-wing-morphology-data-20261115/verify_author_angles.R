args <- commandArgs(trailingOnly=TRUE)
root <- if (length(args)) args[1] else "."
common <- file.path(root,"baliga-crow-source/02_Range-of-Motion/01_CommonFunctions.R")
lines <- readLines(common,warn=FALSE)
start <- grep("^xyzangles <- function",lines)
stopifnot(length(start)==1)
end <- start + which(lines[(start+1):length(lines)]=="}")[1]
eval(parse(text=paste(lines[start:end],collapse="\n")))
sourceRoot <- file.path(root,"baliga-crow-source/02_Range-of-Motion/MiroM120_digitization")
cases <- list(c("crow_17_1L_linkage","2017-11-09_Cor_bra_17-1L/Cor_bra_17-1L_ROM-pooled/2017-11-09_Cor_bra_17-1L_6BarDors__xyzpts.csv"),c("crow_17_1L_rom","2017-11-09_Cor_bra_17-1L/Cor_bra_17-1L_ROM-pooled/2017-11-09_Cor_bra_17-1L_DorsRom1__xyzpts.csv"),c("crow_18_2_rom","2018-06-14_CH-VB_LLT_partII/2018-06-14_Cor_cau_18-2_Sweep/2018-06-14_Cor_cau_18-2_VentSweepSprinkler1__xyzpts.csv"))
for (case in cases) {
 data <- read.csv(file.path(sourceRoot,case[2]),check.names=FALSE)
 derived <- read.csv(file.path(root,paste0(case[1],"-angles.csv")))
 err <- c()
 for (i in seq_len(nrow(derived))) {
  row <- as.numeric(data[derived$source_frame_1based[i],1:12]); if(any(!is.finite(row))) stop("derived invalid source")
  e <- do.call(xyzangles,as.list(row[1:9])); m <- do.call(xyzangles,as.list(row[4:12]))
  err <- c(err,abs(e-derived$elbow_deg[i]),abs(m-derived$manus_deg[i]))
 }
 stopifnot(all(is.finite(err)),max(err)<1e-8)
 cat(case[1],"samples",nrow(derived),"max abs error degrees",max(err),"\n")
}
