args <- commandArgs(trailingOnly=TRUE)
root <- if (length(args)) args[1] else "."
data <- read.csv(file.path(root,"crow_17_1L_linkage-angles.csv"))
train <- subset(data,source_frame_1based<=350); test <- subset(data,source_frame_1based>=351)
fit <- lm(manus_deg ~ elbow_deg + I(elbow_deg^2),data=train)
res <- predict(fit,newdata=test)-test$manus_deg
rms <- sqrt(mean(res^2)); baseline <- sqrt(mean((mean(train$manus_deg)-test$manus_deg)^2))
stopifnot(nrow(train)==309,nrow(test)==97,abs(rms-3.2695600427499087)<1e-8,abs(baseline-47.19252099825559)<1e-8)
cat("R independent least squares RMS",rms,"baseline",baseline,"coefficients",coef(fit),"\n")
