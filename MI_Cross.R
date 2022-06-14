#Multiple Imputation for Cross-Sectional Data
install.packages("mice"); install.packages("broom.mixed")
require(mice); require(broom.mixed)

#1.Check the data distributions and pattern
data <- nhanes2; attach(data); summary(data)
par(mfrow = c(1,2)); hist(bmi); hist(chl)
md.pattern(data)

#2.Imputation with default setting (m=5)
imp_data1 <- mice(data=data)

#Plot
plot(imp_data1)
densityplot(imp_data1)

#3.Imputation with original setting
imp_data2 <- mice(data=data, m=20, maxit=5, meth=c("", "pmm", "logreg", "pmm"))

#Plot
plot(imp_data2)
densityplot(imp_data2)


  