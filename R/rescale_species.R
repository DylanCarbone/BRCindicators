#' Rescale species values for indicator
#' 
#' This function takes in a dataframe of multi-species data and rescales them
#' so that the value in the starting year is the same. This function accounts
#' for species that have no data at the beginning of the period or those that
#' have no data at teh end of the period.
#' 
#' @param Data A matrix, the first column, named year, gives the year. Subsequent named
#'        columns give the species. Values in the table are the yearly values
#'        to be rescaled.
#' @param index The index value for the first year, defaults to 100.
#' @param max The upper limit allowed for scaled values. Values greater than 
#'        this will be set equal to \code{max}.
#' @param min The upper limit allowed for scaled values. Values greater than 
#'        this will be set equal to \code{min}.
#' @return A matrix. In each row we have the year, the species and the
#'         scaled value. There is also an additional column, 'geomean' giving
#'         the geometric mean for each year.
#' 
#' @export
#' 
#' @examples
#' 
#' # We will create fake data which will mimic a summarised output from a sparta package occupancy detection model. Please see the vignette for more details.
#' 
#' # Create a matrix with random data using set.seed for reproducibility
#' set.seed(123)
#' data <- matrix(rnorm(50 * 27), nrow = 50, ncol = 27)
#' 
#' # Assign column names
#' col_names <- c("year", letters[1:26])
#' dimnames(data) <- list(NULL, col_names)
#' 
#' # Create the 'trends_summary' object
#' trends_summary <- data
#' 
#' # Re-scale the data so that the value for all species in the first year is the same (all defaults used).
#' # This function accounts for species that have no data at the beginning of the dataset by entering them at the geometric mean for that year, this stops them dramatically changing the indicator value in the year they join the dataset.
#' # It also accounts for species that leave the dataset before the end by holding them at their last value.
#' # Finally it limits the species values that can be given, preventing extremely high or low values biasing the indicator.
#' rescale_species(Data = trends_summary)
#' 
#' # Now, I have 'messed up' the data a bit by including two species with data missing at the beginning and one species with data missing at the end. We also have one species with some very high values.
#' trends_summary[1:3, 'a'] <- NA
#' trends_summary[1:5, 'b'] <- NA
#' trends_summary[2:4, 'c'] <- 1000
#' trends_summary[45:50, 'd'] <- NA
#' 
#' # Let's run this data again through our scaling function (all defaults used)
#' rescale_species(Data = trends_summary)

rescale_species <-  function(Data, index = 100, max = 10000,
                             min = 1){
  geomean <- function(x) exp(mean(log(x), na.rm = T))
  
  if(!inherits(Data, 'matrix')){
    if(inherits(Data, 'data.frame')){
      Data <- data.matrix(Data)
    } else {
      stop('Data must be a matrix')  
    }
  } 
  
  # Get the multipliers neede to achieved the index value
  multipliers <- index / Data[1,2:ncol(Data)] 
  
  # Apply these multipliers
  indicator_scaled <- t(t(Data[,2:ncol(Data)]) * multipliers)

  # Make values over max == max, and < min == min
  indicator_scaled[indicator_scaled < min & !is.na(indicator_scaled)] <- min
  indicator_scaled[indicator_scaled > max & !is.na(indicator_scaled)] <- max
  
  # Species with missing values are now in here with all NA rows
  # We want to calculate the geomean from this data first
  geomean_vals <- apply(X = indicator_scaled, MARGIN = 1, FUN = geomean)
  
  indicator_scaled <- cbind(indicator_scaled, geomean_vals)
  colnames(indicator_scaled)[ncol(indicator_scaled)] <- 'geomean'
  
  # Now we need to add back in the NA species and scale them all so that
  # their first value is the same as the geomean for that year
  # These have NAs at the beggining
  NAtop <- colnames(Data)[is.na(Data[1,])]

  # These need to be sorted into the order in which they enter the dataset for
  # this method to work (else assigning geomean values goes wrong)
  firstYear <- function(x) min(which(!is.na(x)))
  # re-order if there is more than one
  if(length(NAtop) > 1) NAtop <- names(sort(apply(X = Data[,NAtop], MARGIN = 2, FUN = firstYear)))
  
  if(length(NAtop) > 0){
    # Deal with ones at the beggining first
    for(i in 1:length(NAtop)){# Create a column of T/F if NA or not
      
      # Create a temporary dataframe for this species
      temp_col <- data.frame(species = !is.na(Data[,NAtop[i]]), row = 1:nrow(indicator_scaled))
      
      # index of first good year
      first_year <- min(temp_col$row[temp_col$species])
      
      # get geomean for this year 
      temp_gm <- indicator_scaled[first_year,'geomean']
      
      # Calculate multiplier needed
      multi <- temp_gm / Data[first_year, NAtop[i]]
      
      # Apply this...
      d <- Data[,NAtop[i]]*multi
      
      # ...make sure non are under 1 or over 10000...
      d[d < min & !is.na(d)] <- min
      d[d > max & !is.na(d)] <- max
      
      # ...and put it in the table
      indicator_scaled[,NAtop[i]] <- d
      
      # Recalculate the geomean before the next species
      indicator_scaled[,'geomean'] <- apply(X = indicator_scaled[,!colnames(indicator_scaled) %in% 'geomean'], MARGIN = 1, FUN = geomean)
      
    }
  }
  
  # If a species drops out hold at last value
  fillTailNAs <- function(x){
    
    # Get trues and falses for locations of NAs
    na_true_false <- is.na(x)
    
    # Get the position of all falses
    na_position <- grep(FALSE, na_true_false)
    
    # If the max false is hte last year dont do anything...
    if(!max(na_position) == length(x)){
      
      # else give all the last years the value at the last false
      x[(max(na_position)+1):length(x)] <- x[max(na_position)]
    }
    return(x)    
  }

  # apply tail function
  temp_indicator_scaled <- apply(X = indicator_scaled[,-ncol(indicator_scaled)],
                            MARGIN = 2, FUN = fillTailNAs)

  
  # Recalculate geomean and bind to the species indicies
  indicator_scaled <- cbind(temp_indicator_scaled, apply(X = temp_indicator_scaled, MARGIN = 1, FUN = geomean))
  
  # Format the columns
  colnames(indicator_scaled)[ncol(indicator_scaled)] <- "indicator"
  indicator_scaled <- cbind(Data[, "year"], indicator_scaled)
  colnames(indicator_scaled)[1] <- "year"
  
  return(indicator_scaled)
}