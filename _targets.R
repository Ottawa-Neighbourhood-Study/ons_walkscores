library(targets)
library(tarchetypes)

# tell targets which packages we need to load to do the analysis
tar_option_set(packages = c("tidyverse",
                            "tidytransit",
                            "leaflet",
                            "sf",
                            "neighbourhoodstudy"
))

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


list(
  #################################### -
  ## LOAD DATA ----
 targets::tar_target(apikey, "1a268ff01a519b00ad6ee974caaae248"),

 targets::tar_target(ons_gen3, neighbourhoodstudy::ons_shp_gen3 #%>% dplyr::filter(ONS_Region == "OTTAWA")
                     ),
 targets::tar_target(ottawa_phhs, neighbourhoodstudy::ottawa_phhs),

  targets::tar_target(tranche1,
                      ons_gen3 %>%
                        dplyr::slice(1:20)
  ),
 targets::tar_target(tranche1Walkscores,
                       process_tranche(tranche = tranche1, ottawa_phhs = ottawa_phhs, num_to_score = 100, apikey = apikey )
                     ),

 NULL
)
