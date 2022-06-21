# Multiple Imputation with mice 
install.packages("mice")
library(mice)

# Basic 3 steps workflow
imp <- mice(nhanes)                   #Step1 Imputation
fit <- with(imp, lm(chl ~ bmi + age)) #Step2 Analysis
res <- pool(fit)                      #Step3 Pooling
res
summary(res)

##################################### 1. Multiple Imputation single level ###################################
# Preparations: Check the data distributions and patterns
data <- nhanes2; attach(data); summary(data)
par(mfrow = c(2,2)); hist(bmi); hist(chl); plot(age, main="age"); plot(hyp, main="hyp")
par(mfrow = c(1,1));md.pattern(data)


# 1-1.Imputation with the default setting of mice (m=5)
imp1 <- mice(data=data, seed = 1234)

# 1-2.Plot 
plot(imp1)
densityplot(imp1)
stripplot(imp1, pch = 19, xlab = "Imputation number")

# 2. Analysis
fit1 <- with(imp1, lm(chl ~ bmi + age)) 

# 3. Pooling the results
res1 <- pool(fit1)
res1
summary(res1)
summary(res1, "all", conf.int = TRUE)


# 4-1.Imputation with predictive mean matching
require(mice); data <- nhanes2; attach(data)
head(data)
imp2 <- mice(data = data, seed = 1234, m=5, maxit=5,
             method=c("", "pmm", "logreg", "pmm"))

stripplot(imp2, pch = 19, xlab = "Imputation number
          Predictive mean matching (pmm)")


# 4-2.Imputation with Bayesian linear regression 
imp3 <- mice(data = data, seed = 1234, m=5, maxit=5,
             method=c("", "norm", "logreg", "norm"))

stripplot(imp3, pch = 19, xlab = "Imputation number
         Bayesian linear regression (norm)")

# 5-1.Predictor Matrix
imp <- mice(data = data, seed = 1234, print = FALSE)
imp$pred

# 5-2. Make a original predictor matrix for big data set.
pred <- imp$pred
write.csv(pred, file = "test.csv")
pred_2 = read.csv("test.csv", header = T, row.names = 1)
pred_2 <- as.matrix(pred_2); pred_2

imp4 <- mice(data = data, seed = 1234, print = FALSE,
             pred = pred_2)
