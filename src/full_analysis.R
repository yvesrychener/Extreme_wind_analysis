#####
#Important:
#  Producing the rlargest diagnostic plot creates an error with the other plots, so
#  if it has to be plotted, uncomment it on line 153 & 164.
#  But then, the other plots will be faulty


### IMPORTS ####
library(evd); 
library(evdbayes);
library(coda);
library(ismev);
library(xts);
library(ggplot2);

### DATA LOAD ####
load("../data/CAPE_Minder_Rychener_Malsot.RData")
load("../data/NINO34.RData")
load("../data/SRH_Minder_Rychener_Malsot.RData")

# Generate prod
prod = sqrt(cape)*srh

# Generate Time Series Objects
dates <- seq.Date(as.Date("1979-1-1"), as.Date("2015-12-31"), by=1)
feb29ix <- format(as.Date(dates), "%m-%d") == "02-29"
dates <- dates[!feb29ix]

prod_ts = xts(prod, order.by = rep(dates, each=8))

#####
### PRELIMINARY ANALYSIS ####
# Create plots of time series, save them in plot folder
ts_plot = autoplot(prod_ts) + xlab("Time") + ylab("PROD")
ggsave("../plots/full_time_series.pdf", plot=ts_plot, width = 6, height = 3)
ggsave("../plots/full_time_series.png", plot=ts_plot, width = 3, height = 1.5)

prod_full_monthly_max = apply.monthly(prod_ts, max)
max_ts_plot = autoplot(prod_full_monthly_max) +
  xlab("Time") + ylab("PROD") +
  geom_line(size=.5)
ggsave("../plots/monthly_max_series.pdf", plot=max_ts_plot, width = 6, height = 3)
ggsave("../plots/monthly_max_series.png", plot=max_ts_plot, width = 3, height = 1.5)

nino34_plot = ggplot() + geom_line(aes(index(prod_full_monthly_max), nino34)) +
  xlab("Time") + ylab("NINO 3.4")
ggsave("../plots/nino34_plot.pdf", plot=nino34_plot, width = 6, height = 3)
ggsave("../plots/nino34_plot.png", plot=nino34_plot, width = 3, height = 1.5)



### GROUP BY MONTHLY ####
# Utilities for grouping statistics by month, to yield a list with the statistic
# for every month seperately
month_names = c("jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec")
get_monthly = function(x) {
  output = list()
  len = nrow(x)
  
  # Get month of element
  month = time(x)
  month = gsub("....-", "", month)
  month = gsub("-..", "", month)
  monthlist = unique(month)
  for (i in 1:12) {
    output[[i]] = x[month == monthlist[i],]
  }
  names(output) = month_names
  return(output)
}

monthly_max = get_monthly(apply.monthly(prod_ts, max))
r = 2
r_monthly_max = get_monthly(apply.monthly(prod_ts, function(x) order(x, decreasing=T)[1:r]))





# Plot and save monthly maxima time series
for (i in 1:12) {
  tmp = autoplot(monthly_max[[i]]) + xlab("Time") + ylab("PROD")
  ggsave(paste("../plots/monthly_max_series/", sprintf("%02d", i), "monthly_max_series.pdf", sep=""), 
         plot=tmp, width = 6, height = 3)
}

#####
### FITTING GEV ####
# Fitting GEV using different methods

### MLE ####
monthly_fits = list()
error_cases = c(9, 12) # Months for which information matrix not invertible
for (i in 1:length(monthly_max)) {
  if (i %in% error_cases) {
    monthly_fits[[i]] = fgev(as.data.frame(monthly_max[[i]])$V1, 
                             method = "Nelder-Mead",
                             std.err = FALSE)
  }
  else {
    monthly_fits[[i]] = fgev(as.data.frame(monthly_max[[i]])$V1, 
                             method = "Nelder-Mead")
  }
}
names(monthly_fits) = names(monthly_max)

# Plot diagnostics for MLE, save
for (i in 1:12) {
  pdf(paste("../plots/monthly_mle_diag/", sprintf("%02d", i), "_monthly_mle_diag.pdf", sep=""),
      width=7, height=7)
  par(mfrow=c(2,2))
  plot(monthly_fits[[i]])
  dev.off()
}

# Get standard error and parameter estimates
get_se = function(x, ix) {
  if (is.null(x$std.err)) 0
  else x$std.err[ix]
}
mle_loc = unlist(lapply(monthly_fits, function(x) x$estimate[1]))
mle_loc_se = unlist(lapply(monthly_fits, get_se, 1))
mle_scale = unlist(lapply(monthly_fits, function(x) x$estimate[2]))
mle_scale_se = unlist(lapply(monthly_fits, get_se, 2))
mle_shape = unlist(lapply(monthly_fits, function(x) x$estimate[3]))
mle_shape_se = unlist(lapply(monthly_fits, get_se, 3))

### r largest order statistic ####
month = 1 # Find good r for january
zeros = 0*(2:10)
se_df_jan = data.frame(2:10,zeros,zeros,zeros,zeros)
colnames(se_df_jan) = c("r","SE-mu","SE-sig","SE-sh","2l")
colnames_dat = c("V1","V2")
for (i in 2:10){
  largest_i = get_monthly(apply.monthly(prod_ts, function(x) x[order(x, decreasing=T)[1:i]]))
  rlarg_df = as.data.frame(largest_i[month])
  colnames(rlarg_df) = colnames_dat
  x = cbind(rlarg_df$V1, rlarg_df$V2, rlarg_df$V3, rlarg_df$V4, rlarg_df$V5, rlarg_df$V6)
  fit = rlarg.fit(x,show=FALSE)
  se_df_jan[i-1,2:4]=fit$se
  se_df_jan[i-1,5]=fit$nllh
  colnames_dat = c(colnames_dat,sprintf("V%d",i+1))
}
print(se_df_jan)

# Plot diagnostics for may
i=5 # Month
largest_2 = get_monthly(apply.monthly(prod_ts, function(x) x[order(x, decreasing=T)[1:2]]))
rlarg_df = as.data.frame(largest_2[i])
colnames(rlarg_df) = c("V1", "V2")
x = cbind(rlarg_df$V1, rlarg_df$V2)
fit = rlarg.fit(x,show=FALSE)
#tryCatch({
#  rlarg.diag(fit)},
#  error=function(e){});

# Plot Diagnostics for July
i = 7 # Month
largest_2 = get_monthly(apply.monthly(prod_ts, function(x) x[order(x, decreasing=T)[1:2]]))
rlarg_df = as.data.frame(largest_2[i])
colnames(rlarg_df) = c("V1", "V2")
x = cbind(rlarg_df$V1, rlarg_df$V2)
fit = rlarg.fit(x,show=FALSE)
#tryCatch({
#  rlarg.diag(fit)},
#  error=function(e){});

# Fit all
largest_2 = get_monthly(apply.monthly(prod_ts, function(x) x[order(x, decreasing=T)[1:2]]))
largest_2_fit = lapply(largest_2, function(x) rlarg.fit(x[ , 1:2],show=FALSE))


### Bayesian ####
# Fits GEV distribution with bayesian method for given parameters
bayes_fitter = function(x, 
                        init = c(1e3, 1e3, 0.1), # Initial values
                        mat = diag(c(10000,10000,100)),
                        psd = c(500,0.1,0.1), # Proposed SDev
                        nit = 3000, # Nb Iterations
                        thinning = 50, # Thinning Factor
                        do_diagn = FALSE, # Bool whether to show diagnostic plots
                        do_autoreg = FALSE, # Bool whether to show autoreg plots
                        seed = 42 # Seed 
) {
  set.seed(seed)                
  pn = prior.norm(mean=c(0,0,0),cov=mat)
  post = posterior(nit, init=init, prior=pn, lh="gev", data=x, psd=psd)
  
  if(do_diagn) {
    MCMC<-mcmc(post[1:nit %% thinning == 0, ]) 
    plot(MCMC) 
  }
  if(do_autoreg) {
    acf(mcmc(post[1:nit %% thinning == 0, ]))
  }
  list(posterior = post, 
       acceptance_rate = attr(mcmc(post),"ar"))
}



# Iteratively fits GEV with bayesian methods, until the fit has 
# acceptable acceptance rates (i.e. 0.2 < AR < 0.4). If the AR is too high, 
# the proposed SDev for the parameter is multiplied with 1.5. If it's too small,
# the proposed SDev is divided by 2. This is repeated until the acceptance rate
# is good for all parameters, or max_it is reached. Then, a final model is fitted
# with more iterations. 
bayes_fitter_param_search = function(x,
                                     psd_init = c(500,0.1,0.1), # Initial proposed SDev
                                     nit_full = 3000, # Nb Iterations for final model
                                     nit_search = 150, # Nb Iterations for param search
                                     do_diagn = FALSE, # Bool whether to show diagnostic plots
                                     do_autoreg = FALSE, # Bool whether to show autoreg plots
                                     max_it = 20,
                                     ... # Additional params passed to bayes_fitter
) 
{
  # Iterate until desired acceptance rate is obtained
  cont = TRUE
  psd = psd_init
  it = 0
  while(cont) {
    it = it+1
    if (it > max_it) {
      warning("The ")
    }
    fit = bayes_fitter(x, psd=psd, nit=nit_search, do_diagn=FALSE, 
                       do_autoreg=FALSE,...)
    acc_rates = fit$acceptance_rate[1, 1:3]
    
    too_high = acc_rates > .4
    too_low = acc_rates < .2
    
    if (all(!too_high) && all(!too_low)) { # All acceptance rates lie within threshold
      cont=FALSE
    } else if (it > max_it) { # max_it is reached
      cont=FALSE
      warning("max_it was reached")
    } else { # Correct values which have wrong threshold
      psd[too_high] = psd[too_high] * 1.5
      psd[too_low] = psd[too_low] / 2
    }
  }
  
  # Fit final model
  bayes_fitter(x, psd=psd, nit=nit_full, do_diagn=do_diagn, 
               do_autoreg=do_autoreg, ...)
  
}


monthly_bayes_fit = lapply(monthly_max, bayes_fitter_param_search, do_diagn = FALSE, 
                           do_autoreg = FALSE,
                           nit_full=30000, nit_search = 30000,
                           thinning = 300, mat = diag(c(100000,100000,100)),
                           init = c(1e4, 1e3, 0.1))
acceptance_rates = lapply(monthly_bayes_fit, function(x) x$acceptance_rate[1, ])
print(acceptance_rates)
bayes_params = lapply(monthly_bayes_fit, function(x) apply(x$posterior, 2, median))
bayes_stderr = lapply(monthly_bayes_fit, function(x) apply(x$posterior, 2, sd))



### Plot parameters ####
pdf(paste("../plots/evolution_eta.pdf"), width = 7, height = 5)
plot(1:12, mle_loc, col="blue", ylim=c(0, 20000),
     main="Location Parameter", pch=19, ylab="Location", xlab="Month")
points(1:12, 
       lapply(bayes_params, function (x) x["mu"]), 
       col="red", pch=19)
points(1:12, 
       lapply(largest_2_fit, function(x) x$mle[1]), 
       col="green", pch=19)
legend("topright", c("MLE", "r-Largest", "Bayesian"), 
       fill=c("blue","green","red"))
dev.off()


pdf(paste("../plots/evolution_tao.pdf"), width = 7, height = 5)
plot(1:12, mle_scale, col="blue", ylim=c(0, 40000),
     main="Scale Parameter", pch=19, ylab="Scale", xlab="Month")
points(1:12, 
       lapply(bayes_params, function (x) x["sigma"]), 
       col="red", pch=19)
points(1:12, 
       lapply(largest_2_fit, function(x) x$mle[2]), 
       col="green", pch=19)
legend("topright", c("MLE", "r-Largest", "Bayesian"), 
       fill=c("blue","green","red"))
dev.off()


pdf(paste("../plots/evolution_xi.pdf"), width = 7, height = 5)
plot(1:12, mle_shape, col="blue", ylim=c(-1, 1),
     main="Shape parameter", pch=19, ylab="Shape", xlab="Month")
points(1:12, 
       lapply(bayes_params, function (x) x["xi"]), 
       col="red", pch=19)
points(1:12, 
       lapply(largest_2_fit, function(x) x$mle[3]), 
       col="green", pch=19)
legend("topright", c("MLE", "r-Largest", "Bayesian"), 
       fill=c("blue","green","red"))
dev.off()


#####
### DEPENDENCE TESTS ####
### Linear on Time ####
ratios = list()
trend = 1:length(as.data.frame(monthly_max[[12]])$V1)
trend = (trend-mean(trend))/sd(trend) # scale and center covariates as recommended
error_cases = c(9, 12)
for (i in 1:length(monthly_max)) {
  print(i)
  
  fit_const = fgev(as.data.frame(monthly_max[[i]])$V1, 
                   method = "Nelder-Mead",
                   std.err = FALSE)
  fit_dependant = fgev(as.data.frame(monthly_max[[i]])$V1, 
                       method = "Nelder-Mead",
                       nsloc = trend,
                       std.err = FALSE)
  
  ratios[[i]] = fit_const$dev-fit_dependant$dev 
}
names(ratios) = names(monthly_max)
chi_95level = qchisq(1-0.05/12,1)

plot(unlist(ratios),main="95% confidence test for time independance, \nBonferroni multiple Testing", xlab="Month",ylab="Likelihood Ratio Statistic")
abline(a=chi_95level,b=0,col="red")


### Linear on ENSO ####
ratios = list()
# split nino data into months
n = nino34
dim(n)=c(12,length(as.data.frame(monthly_max[[12]])$V1))
error_cases = c(9, 12)
for (i in 1:length(monthly_max)) {
  print(i)
  trend = n[i,]
  
  trend = (trend-mean(trend))/sd(trend) # scale and center covariates as recommended
  fit_const = fgev(as.data.frame(monthly_max[[i]])$V1, 
                   method = "Nelder-Mead",
                   std.err = FALSE)
  fit_dependant = fgev(as.data.frame(monthly_max[[i]])$V1, 
                       method = "Nelder-Mead",
                       nsloc = trend,
                       std.err = FALSE)
  
  ratios[[i]] = fit_const$dev-fit_dependant$dev 
}
names(ratios) = names(monthly_max)
chi_95level = qchisq(1-0.05/12,1)

plot(unlist(ratios),main="95% confidence test for independance from ENSO, \nBonferroni multiple testing", xlab="Month",ylab="Likelyhood Ratio Statistic")
abline(a=chi_95level,b=0,col="red")

### Step on ENSO ####
ratios = list()
# split nino data into months
n = nino34
dim(n)=c(12,length(as.data.frame(monthly_max[[12]])$V1))
error_cases = c(9, 12)
for (i in 1:length(monthly_max)) {
  print(i)
  trend = n[i,]
  trend = as.integer(trend>0)
  
  trend = (trend-mean(trend))/sd(trend) # scale and center covariates as recommended
  fit_const = fgev(as.data.frame(monthly_max[[i]])$V1, 
                   method = "Nelder-Mead",
                   std.err = FALSE)
  fit_dependant = fgev(as.data.frame(monthly_max[[i]])$V1, 
                       method = "Nelder-Mead",
                       nsloc = trend,
                       std.err = FALSE)
  
  ratios[[i]] = fit_const$dev-fit_dependant$dev 
}
names(ratios) = names(monthly_max)
chi_95level = qchisq(1-0.05/12,1)

plot(unlist(ratios),main="95% confidence test for independance from ENSO, \nBonferroni multiple testing", xlab="Month",ylab="Likelyhood Ratio Statistic")
abline(a=chi_95level,b=0,col="red")


### Step on time ####
#monthly_fits = lapply(monthly_max, 
#                      function(x) fgev(data.frame(x)[,1], method="Nelder-Mead"))
ratios = list()
trend = 1:length(as.data.frame(monthly_max[[12]])$V1)
trend = (trend-mean(trend))/sd(trend) # scale and center covariates as recommended
trend = as.integer(trend>0)
error_cases = c(9, 12)
for (i in 1:length(monthly_max)) {
  print(i)
  
  fit_const = fgev(as.data.frame(monthly_max[[i]])$V1, 
                   method = "Nelder-Mead",
                   std.err = FALSE)
  fit_dependant = fgev(as.data.frame(monthly_max[[i]])$V1, 
                       method = "Nelder-Mead",
                       nsloc = trend,
                       std.err = FALSE)
  
  ratios[[i]] = fit_const$dev-fit_dependant$dev 
}
names(ratios) = names(monthly_max)
chi_95level = qchisq(1-0.05/12,1)

plot(unlist(ratios),main="95% confidence test for time independance, \nBonferroni multiple Testing", xlab="Month",ylab="Likelihood Ratio Statistic")
abline(a=chi_95level,b=0,col="red")





#####
### EXTREMAL INDEX ####
# define a function for getting the extremal indices for each month for a given threshold
monthly_eindex <- function(data, threshold_p, r=0){
  ei = list()
  for (i in 1:length(data)) {
    threshold = quantile(as.data.frame(data[[i]])$V1, threshold_p)
    ei[[i]]=exi(as.data.frame(data[[i]])$V1, threshold, r)
  }
  names(ei) = names(data)
  
  return(ei)
}

ei = monthly_eindex(get_monthly(prod_ts), 0.95)
plot(unlist(ei), main="Extremal Index by Month", xlab="Month", ylab="Extremal index")
#####
### CHI-CHIBAR ####
# plot the chi plot for dependance analysis
data_overall_ts = xts(cbind(cape,srh), order.by = rep(dates, each=8))
data_monthly_bivariate = get_monthly(data_overall_ts)

for (i in 1:length(data_monthly_bivariate)) {
  cape.local = as.numeric(data_monthly_bivariate[[i]]$cape)
  srh.local = as.numeric(data_monthly_bivariate[[i]]$srh)
  dat.cape_srh = cbind(cape.local,srh.local);
  par(mfrow=c(1,2))
  label_chi = sprintf("Chi plot Month %s",i)
  label_chibar = sprintf("Chi Bar plot Month %s",i)
  chiplot(dat.cape_srh, main1 = label_chi, which=1);
  abline(a=0,b=0,col="red")
  chiplot(dat.cape_srh, main2 = label_chibar, which=2);
}
#####
### BIVARIATE ####
# prepare the data
monthly_max.cape = get_monthly(apply.monthly(data_overall_ts$cape, max))
monthly_max.srh = get_monthly(apply.monthly(data_overall_ts$srh, max))

# fit the different models
zeros = 0*(1:12)
AIC_df = data.frame(zeros,zeros,zeros,zeros,zeros,zeros)
dep.estimate = zeros
dep.sd = zeros

bv_evd_models = c("log","alog","neglog","bilog","ct","negbilog")
colnames(AIC_df) = bv_evd_models

bv_fits = list()
for (i in 1:12) {
  print(i)
  # fit the data
  monthly_max_bivariate = cbind(as.numeric(monthly_max.cape[[i]]),
                                as.numeric(monthly_max.srh[[i]]))
  
  fit1 = fbvevd(monthly_max_bivariate,model = "log", method = "Nelder-Mead")
  fit2 = fbvevd(monthly_max_bivariate,model = "alog", method = "Nelder-Mead", std.err = FALSE)
  fit3 = fbvevd(monthly_max_bivariate,model="neglog",  method = "Nelder-Mead") 
  fit4 = fbvevd(monthly_max_bivariate,model="bilog",  method = "Nelder-Mead", std.err = FALSE) 
  fit5 = fbvevd(monthly_max_bivariate,model="ct",  method = "Nelder-Mead", std.err = FALSE) 
  fit6 = fbvevd(monthly_max_bivariate,model="negbilog", method = "Nelder-Mead", std.err = FALSE)
  
  bv_fits[[i]] = list(fit1, fit2, fit3, fit4, fit5, fit6)
  names(bv_fits[[i]]) = bv_evd_models
  
  # plot the fit for diagnostics
  par(mfrow=c(3,2)) 
  #plot(fit1)
  
  # keep track of results
  dep.estimate[i] = as.numeric(fit3$estimate["dep"])
  dep.sd[i] = as.numeric(fit3$std.err["dep"])
  aics = c(AIC(fit1), AIC(fit2), AIC(fit3), AIC(fit4), AIC(fit5), AIC(fit6))
  AIC_df[i,] = aics
  
}
names(bv_fits) = month_names

# show AICs for model selection
print(AIC_df)

# plot depencance values for depenance analysis.
plot_w_err = function(x, y, se, se.conf_mult = 1,title = NULL) {
  upper_error = y+se.conf_mult*se
  lower_error = y-se.conf_mult*se
  
  max_y = max(upper_error)
  min_y = min(lower_error)
  
  plot(x, y,
       ylim = c(min_y, max_y),
       main = title)
  arrows(x,upper_error,x,lower_error, code=3, length=0.02, angle = 90)
}

par(mfrow=c(1,1))
plot_w_err(1:12, dep.estimate, dep.sd, 1.96,"Monthly Dependance Parameter vs Independance (Red)")
abline(a=0,b=0,col="red")




#####
### RETURN LEVELS ####
### Poisson Process ####
# Fit
monthly_fits_pp = list()
monthly_data = get_monthly(prod_ts)
error_cases = c(5, 9)
month_days = c(31,28,31,30,31,30,31,31,30,31,30,31)
for (i in 1:length(monthly_max)) {
  print(i)
  threshold = quantile(as.data.frame(monthly_data[[i]])$V1, 0.95)
  
  if (i %in% error_cases) {
    monthly_fits_pp[[i]] = fpot(as.data.frame(monthly_data[[i]])$V1,
                                threshold = threshold,
                                model="pp",
                                npp = month_days[i]*8,
                                cmax = TRUE,
                                r = 1,
                                std.err = FALSE,
                                method = "Nelder-Mead")
  }
  else {
    monthly_fits_pp[[i]] = fpot(as.data.frame(monthly_data[[i]])$V1,
                                threshold = threshold,
                                model="pp",
                                npp = month_days[i]*8,
                                cmax = TRUE,
                                r = 1,
                                method = "Nelder-Mead")
  }
}
names(monthly_fits_pp) = names(monthly_data)
for(i in 1:12){
  par(mfrow=c(2,2)) 
  plot(monthly_fits_pp[[i]])
}

# Estimate return levels
return_level = function(x,period=20){
  if (is.list(x)) {
    loc = x$estimate[[1]]
    scale = x$estimate[[2]]
    shape = x$estimate[[3]]
  }
  if (is.vector(x)) {
    loc = x[1]
    scale = x[2]
    shape = x[3]
  }
  p = 1/period
  
  level = loc + scale*(((-log(1-p))^-shape-1)/shape)
  return(level)
}
return_level_20 = lapply(monthly_fits_pp, return_level) # 20 for testing
return_level_100 = lapply(monthly_fits_pp, return_level, period=100)
return_level_50 = lapply(monthly_fits_pp, return_level, period=50)
plot(unlist(return_level_100),main="100 Year Return level, estimated with point process", xlab="Month",ylab="Return Level")
plot(unlist(return_level_50),main="50 Year Return level, estimated with point process", xlab="Month",ylab="Return Level")


### Bayesian ####
return_level_mcmc = function(posterior,period=20, plot=F) {
  u = mc.quant(posterior,p=1-1/period,lh="gev")
  label_mcmc_rl = sprintf("%s Year Return Level",period)
  if(plot) hist(u,nclass=20,prob=T,xlab=label_mcmc_rl, main = "Return Level Histogram")
}

lapply(monthly_bayes_fit, function(x) return_level_mcmc(x$posterior, period=50))
lapply(monthly_bayes_fit, function(x) return_level_mcmc(x$posterior, period=100))

bayes_50yr_retlvl = lapply(bayes_params, return_level, period=50)
bayes_100yr_retlvl = lapply(bayes_params, return_level, period=100)



### Bivar ####
# Return levels for model with best AUC for every month
bivar_100yr_retlvl = vector()
bivar_50yr_retlvl = vector()

for (i in 1:12) {
  n_sims = 500000
  mod_ix = c("neglog"=3) #Always use neglog
  #mod_ix = which.min(AIC_df[i, ]) # Index of model with best AIC for given month
  estimate = bv_fits[[i]][[mod_ix]]$estimate
  model=names(mod_ix)
  # Pass appropriate parameters according to model
  if (model %in% c("log", "neglog")) {
    sim_vals = rbvevd(n=n_sims,
                      dep=estimate["dep"],
                      mar1=estimate[c("loc1", "scale1", "shape1")],
                      mar2=estimate[c("loc2", "scale2", "shape2")],
                      model=model)
    
  }
  else if (model %in% c("bilog", "ct", "negbilog")) {
    sim_vals = rbvevd(n=n_sims,
                      alpha=estimate["alpha"],
                      beta=estimate["beta"],
                      mar1=estimate[c("loc1", "scale1", "shape1")],
                      mar2=estimate[c("loc2", "scale2", "shape2")],
                      model=model)
    
  }
  else if (model %in% c("alog")) {
    sim_vals = rbvevd(n=n_sims,
                      dep=estimate["dep"],
                      asy=c(estimate["asy1"], estimate["asy2"]),
                      mar1=estimate[c("loc1", "scale1", "shape1")],
                      mar2=estimate[c("loc2", "scale2", "shape2")],
                      model=model)
  }
  
  # Obtain simulated PROD value, get return levels
  sim_prod = sqrt(sim_vals[ , 1]) * sim_vals[ , 2]
  
  # USE QUANTILES
  bivar_100yr_retlvl[i] = quantile(sim_prod, probs=1-1/100, na.rm = T)
  bivar_50yr_retlvl[i] = quantile(sim_prod, probs =1-1/50, na.rm = T)
  
}

### Return level plot ####
pdf(paste("../plots/100yr_return.pdf"), width = 7, height=5)
plot(1:12, return_level_100, col="blue", ylim=c(0, 140000),
     main="100 Year Return Levels", pch=17, ylab="PROD", xlab="Month")
points(1:12, bivar_100yr_retlvl, col="red", pch=17)
points(1:12, bayes_100yr_retlvl, col="green", pch=17)
points(1:12, 
       lapply(monthly_fits, return_level, period=100),
       col="orange", pch=17)

legend("topleft", c("BAY", "POI", "BIV", "MLE"), 
       fill=c("green","blue","red", "orange"))
dev.off()

pdf(paste("../plots/50yr_return.pdf"), width = 7, height = 5)
plot(1:12, return_level_50, col="blue", ylim=c(0, 80000),
     main="50 Year Return Levels", pch=17, ylab="PROD", xlab="Month")
points(1:12, bivar_50yr_retlvl, col="red", pch=17)
points(1:12, bayes_50yr_retlvl, col="green", pch=17)
points(1:12, 
       lapply(monthly_fits, return_level, period=50),
       col="orange", pch=17)

legend("topleft", c("BAY", "POI", "BIV", "MLE"), 
       fill=c("green","blue","red", "orange"))
dev.off()

#####



