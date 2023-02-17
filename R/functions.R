
get_walkscore <- function(lat, lon, apikey){

  Sys.sleep(.2)
  url <- sprintf("https://api.walkscore.com/score?format=json&lat=%s&lon=%s&transit=1&bike=1&wsapikey=%s", lat, lon, apikey)

  test <- httr::GET(url)

  httr::content(test) %>%
    unlist() %>%
    tibble::as_tibble(rownames = "name") %>%
    tidyr::pivot_wider(names_from = "name", values_from = "value") %>%
    dplyr::select(-tidyselect::any_of(c("more_info_icon", "more_info_link", "help_link", "logo_url", "ws_link")))

}

get_walkscore_tidy <- function(df){
  apikey <- "1a268ff01a519b00ad6ee974caaae248"
  inputdf <- dplyr::tibble(lat = df$Latitude, lon = df$Longitude, apikey = apikey)
  walkscores <- purrr::pmap_dfr(inputdf, get_walkscore)

  dplyr::bind_cols(df, walkscores)

}


# function gets walkscores for given number of phhs within a set of regions
process_tranche <- function(tranche, ottawa_phhs, num_to_score = 5, apikey){

  results <- dplyr::tibble()

  for (i in 1:nrow(tranche)) {

    shp <- tranche[i,]
    message("tranche ", i, "/",nrow(tranche), " - ", shp$ONS_Name)

    shp_info <- dplyr::select(shp, ONS_ID, ONS_Name, ONS_Region) %>% sf::st_set_geometry(NULL)

    # get the phhs that intersect this region, then shuffle them randomly
    tranche_phhs <-  ottawa_phhs %>%
      dplyr::filter(as.logical(sf::st_intersects(geometry, shp))) %>%
      dplyr::slice_sample(n = nrow(.))  %>%
      dplyr::bind_cols(shp_info)

    # now we get up to num_to_score walkscores. not all phhs will give valid responses
    j <- 0
    num_scored <- 0
    while ((num_scored < num_to_score) & (j < nrow(tranche_phhs))) {
      j <- j + 1
      message("walkscore ", j)
      phh <- tranche_phhs[j,]
      walkscore <- get_walkscore(lat = phh$Latitude, lon = phh$Longitude, apikey = apikey)

      print(walkscore)
      # if we get a good response with a non-null status
      if (!is.null(walkscore$status)) {
        if (walkscore$status == 1) {
          num_scored <- num_scored + 1
          message("good result, have scored ", num_scored, " / ", num_to_score)
          result <- dplyr::bind_cols(phh, walkscore)
          results <- rbind(results, result)
        } # if walkscore$status == 1
      } # if (!is.null(walkscore$status))

    } # while (num_scored < num_to_score) & (j < nrow(tranche_phhs))

  } # for (i in 1:nrow(tranche))

  return(results)
}


# function gets walkscores for given number of phhs within a set of regions
process_tranche_errorhandling <- function(tranche, ottawa_phhs, num_to_score = 5, apikey){

  results <- dplyr::tibble()

  for (i in 1:nrow(tranche)) {

    shp <- tranche[i,]
    message("tranche ", i, "/",nrow(tranche), " - ", shp$ONS_Name)

    shp_info <- dplyr::select(shp, ONS_ID, ONS_Name, ONS_Region) %>% sf::st_set_geometry(NULL)

    # get the phhs that intersect this region, then shuffle them randomly
    tranche_phhs <-  ottawa_phhs %>%
      dplyr::filter(as.logical(sf::st_intersects(geometry, shp))) %>%
      dplyr::slice_sample(n = nrow(.))  %>%
      dplyr::bind_cols(shp_info)

    # now we get up to num_to_score walkscores. not all phhs will give valid responses
    j <- 0
    num_scored <- 0
    while ((num_scored < num_to_score) & (j < nrow(tranche_phhs))) {
      j <- j + 1
      message("walkscore ", j)
      phh <- tranche_phhs[j,]
      walkscore <- get_walkscore(lat = phh$Latitude, lon = phh$Longitude, apikey = apikey)

      print(walkscore)
      # if we get a good response with a non-null status
      if (!is.null(walkscore$status)) {
        if (walkscore$status == 1) {

          result <- dplyr::bind_cols(phh, walkscore)

          # using rbind here chokes if a future result doesn't have the same
          # number of column (e.g. missing bike score) and then subsequent
          # results also choke with error "Arguments have different crs"
          # trying <- try (rbind(results, result))
          # so trying dplyr::bind_rows isntead. can't remember why i didn't in the
          # first place?
          if (nrow(results) == 0){
            trying <- try(result)
          } else{
            trying <- try (dplyr::bind_rows(results, result))
          }

          if (!"try-catch" %in% class (trying)){
            num_scored <- num_scored + 1
            message("good result, have scored ", num_scored, " / ", num_to_score)
            results <- trying
          } else {
            message("ERROR with row binding! ")
            print(head(results))
            print(result)
          }


        } # if walkscore$status == 1
      } # if (!is.null(walkscore$status))

    } # while (num_scored < num_to_score) & (j < nrow(tranche_phhs))

  } # for (i in 1:nrow(tranche))

  return(results)
}



process_results <- function(walkscore_points){

  df <- sf::st_set_geometry(walkscore_points, NULL)

  walkscores_method <- "Neighbourhood-level means for walkscores for approximately 100 randomly selected points on roads in each neighbourhood. Origin points were taken from the Pseudo-Household Demographic Distribution (PHH) data file produced by the Government of Canada, filtered to point types 3 and 4 (points on non-highway roads). Then, for each neighbourhood, either 100 PHHs or the maximum number available within their boundaries were selected. These points were then scored using the Walkscore API in several batches between February 9 and February 16, 2023. Means and standard deviations were calculated for each neighbourhood."
  walkscores_popmean_method <- "Neighbourhood-level means for walkscores for approximately 100 randomly selected points on roads in each neighbourhood. Origin points were taken from the Pseudo-Household Demographic Distribution (PHH) data file produced by the Government of Canada, filtered to point types 3 and 4 (points on non-highway roads). Then, for each neighbourhood, either 100 PHHs or the maximum number available within their boundaries were selected. These points were then scored using the Walkscore API in several batches between February 9 and February 16, 2023. Population-weighted means and standard deviations were then calculated for each neighbourhood. Each PHH in the PHH dataset comes assigned a population based on its Statistics Canada dissemination block (DB). We multiplied each PHH's walkscore by its population, then calculated neighbourhood-level values as, for each PHH i, sum(PHH_walkscore * PHH_population) / sum(PHH_population)."

  walkscores <- df %>%
    dplyr::mutate(walkscore = as.numeric(walkscore)) %>%
    dplyr::group_by(ONS_ID) %>%
    dplyr::summarise(walkscore_mean = mean(walkscore),
                     walkscore_sd = sd(walkscore)) %>%
    tidyr::pivot_longer(cols = -ONS_ID) %>%
    tidyr::pivot_wider(names_from = "ONS_ID", values_from = "value") %>%
    dplyr::mutate(method = walkscores_method)

  walkscores_popweighted <- df %>%
    dplyr::mutate(walkscore = as.numeric(walkscore)) %>%
    dplyr::mutate(walkscore_weighted = walkscore * Pop2016) %>%
    dplyr::group_by(ONS_ID) %>%
    dplyr::summarise(walkscore_popweighted_mean = sum(walkscore_weighted) / sum(Pop2016)) %>%
    tidyr::pivot_longer(cols = -ONS_ID) %>%
    tidyr::pivot_wider(names_from = "ONS_ID", values_from = "value") %>%
    dplyr::mutate(method = walkscores_popmean_method)


  dplyr::bind_rows(walkscores, walkscores_popweighted) %>%
    dplyr::mutate(date_updated = Sys.Date())

}
