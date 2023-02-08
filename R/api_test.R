apikey <- "1a268ff01a519b00ad6ee974caaae248"


lat <- 45.381007
lon <- -75.665540

df <- test

get_walkscore_tidy <- function(df){
  apikey <- "1a268ff01a519b00ad6ee974caaae248"
  inputdf <- dplyr::tibble(lat = df$Latitude, lon = df$Longitude, apikey = apikey)
  walkscores <- purrr::pmap_dfr(inputdf, get_walkscore)

  dplyr::bind_cols(df, walkscores)

}

get_walkscore <- function(lat, lon, apikey){

  Sys.sleep(.2)

  url <- sprintf("https://api.walkscore.com/score?format=json&lat=%s&lon=%s&transit=1&bike=1&wsapikey=%s", lat, lon, apikey)

  done <- FALSE
  tries <- 0
  test <- httr::GET(url)

  apiresult <- httr::content(test) %>%
    unlist() %>%
    tibble::as_tibble(rownames = "name") %>%
    tidyr::pivot_wider(names_from = "name", values_from = "value")

  apiresult <- apiresult %>%
    dplyr::select(-tidyselect::any_of(c("more_info_icon", "more_info_link", "help_link", "logo_url", "ws_link")))

  message(apiresult)

  return(apiresult)

}



#### testing tranche processing

tranche <- tranche_0

# function gets walkscores for given number of phhs within a set of regions
process_tranche <- function(tranche, ottawa_phhs, num_to_score = 5){

  results <- dplyr::tibble()

  for (i in 1:nrow(tranche)) {
    message("tranche ", i, "/",nrow(tranche))
    shp <- tranche[i,]

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
      message("walkscore ", j)
      j <- j + 1
      phh <- tranche_phhs[j,]
      walkscore <- get_walkscore(lat = phh$Latitude, lon = phh$Longitude, apikey = apikey)

      # if we get a good response with a non-null status
      if (!is.null(walkscore$status)) {
        if (walkscore$status == 1) {
          num_scored <- num_scored + 1
          result <- dplyr::bind_cols(phh, walkscore)
          results <- rbind(results, result)
        } # if walkscore$status == 1
      } # if (!is.null(walkscore$status))

    } # while (num_scored < num_to_score) & (j < nrow(tranche_phhs))

  } # for (i in 1:nrow(tranche))

  return(results)
}

testt <- process_tranche(tranche_0)
testt
