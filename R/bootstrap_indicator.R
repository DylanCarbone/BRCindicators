#' Bootstrapping indicator
#' 
#' This function takes in a dataframe of multi-species data that have been scaled
#' and adds confidence intervals to the indicator value.
#' 
#' @param Data A matrix where each named column give the species' values
#'        for each year in rows.
#' @param iterations The number of bootstrap iterations to use.
#' @param CI_limits The confidence limits to return as a vector of two
#'        numbers. This default to c(0.025, 0.975) the 95 percent conficence intervals.
#' @param verbose If \code{TRUE} then progress is printed to screen.
#' @return A matrix. In each row we have the year, the species and the
#'         scaled value. There is also an additional column, 'geomean' giving
#'         the geometric mean for each year.
#' @export

bootstrap_indicator <-  function(Data, iterations = 10000, CI_limits = c(0.025, 0.975),
                                 verbose = TRUE){

  if(!is.matrix(Data)){
    stop("the Data parameter must be a matrix object.")
  }

  if(!all(is.numeric(Data))){
   stop("Matrix values must all be numeric.") 
  }
  
  ### bootstrap to estimate 95% CI around the geometric mean ###
  nSpecies <- ncol(Data)
  bootstrap_values <- matrix(data = NA, nrow = nrow(Data), ncol = iterations)
  bootstrap_data <- as.data.frame(Data)

  pb <- txtProgressBar(min = 0, max = iterations, style = 3)

  # Run bootstrapping
  CIData <- sapply(1:iterations, simplify = TRUE, function(iteration) {

  if(verbose){setTxtProgressBar(pb, iteration)}

  # Randomly sample species 
  samp <- sample(bootstrap_data, size = ncol(bootstrap_data), replace = TRUE)
 
  apply(samp, 1, function(x){
    exp(mean(log(x), na.rm = T))
    })
})

  close(pb)

  # Extract the 2.5 97.5% CI around the geometric mean (from the bootstrapped resamples)
  CIs <- as.data.frame(t(apply(X = CIData, MARGIN = 1, FUN = quantile,
                               probs = CI_limits, na.rm = TRUE)))
  names(CIs) <- c(paste('quant_', gsub('0\\.', '', as.character(CI_limits[1])), sep = ''),
                  paste('quant_', gsub('0\\.', '', as.character(CI_limits[2])), sep = ''))

  return(as.matrix(CIs))
}