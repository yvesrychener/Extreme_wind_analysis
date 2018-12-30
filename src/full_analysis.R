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




