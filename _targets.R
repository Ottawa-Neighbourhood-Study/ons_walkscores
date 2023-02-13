library(targets)
library(tarchetypes)

# tell targets which packages we need to load to do the analysis
tar_option_set(packages = c("tidyverse",
                            "tidytransit",
                            "leaflet",
                            "sf",
                            "neighbourhoodstudy"
))

source("./R/functions.R")

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

 targets::tar_target(tranche2,
                     ons_gen3 %>%
                       dplyr::filter(ONS_Region == "OTTAWA") %>%
                       dplyr::filter(!ONS_ID %in% tranche1$ONS_ID) %>%
                       dplyr::slice(1:20) %>%
                       sf::st_make_valid()
  ),

 targets::tar_target(tranche2Walkscores,
                     process_tranche(tranche = tranche2, ottawa_phhs = ottawa_phhs, num_to_score = 100, apikey = apikey )
 ),

 targets::tar_target(tranche3,
                     ons_gen3 %>%
                       dplyr::filter(ONS_Region == "OTTAWA") %>%
                       dplyr::filter(!ONS_ID %in% tranche1$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche2$ONS_ID) %>%
                       dplyr::slice(1:45) %>%
                       sf::st_make_valid()
                     ),

 targets::tar_target(tranche3Walkscores,
                     process_tranche(tranche = tranche3, ottawa_phhs = ottawa_phhs, num_to_score = 100, apikey = apikey )
 ),

 targets::tar_target(tranche4,
                     ons_gen3 %>%
                       dplyr::filter(ONS_Region == "OTTAWA") %>%
                       dplyr::filter(!ONS_ID %in% tranche1$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche2$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche3$ONS_ID) %>%
                       dplyr::slice(1:10) %>%
                       sf::st_make_valid()
                     ),

 targets::tar_target(tranche5,
                     ons_gen3 %>%
                       dplyr::filter(ONS_Region == "OTTAWA") %>%
                       dplyr::filter(!ONS_ID %in% tranche1$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche2$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche3$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche4$ONS_ID) %>%
                       dplyr::slice(1:7) %>%
                       sf::st_make_valid()
 ),

 targets::tar_target(tranche6,
                     ons_gen3 %>%
                       dplyr::filter(ONS_Region == "OTTAWA") %>%
                       dplyr::filter(!ONS_ID %in% tranche1$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche2$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche3$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche4$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche5$ONS_ID) %>%
                       dplyr::slice(1:10) %>%
                       sf::st_make_valid()
 ),

 # NOTE!! ERROR IN RICHMOND NEIHGBOURHOOD!!
 targets::tar_target(tranche7,
                     ons_gen3 %>%
                       dplyr::filter(ONS_Region == "OTTAWA") %>%
                       dplyr::filter(!ONS_ID %in% tranche1$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche2$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche3$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche4$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche5$ONS_ID) %>%
                       dplyr::filter(!ONS_ID %in% tranche6$ONS_ID) %>%
                       dplyr::filter(ONS_Name != "RICHMOND") %>%
                       sf::st_make_valid()
 ),

 targets::tar_target(tranche4Walkscores,
                     process_tranche_errorhandling(tranche = tranche4, ottawa_phhs = ottawa_phhs, num_to_score = 100, apikey = apikey )
 ),

 targets::tar_target(tranche5Walkscores,
                     process_tranche_errorhandling(tranche = tranche5, ottawa_phhs = ottawa_phhs, num_to_score = 100, apikey = apikey )
 ),

 targets::tar_target(tranche6Walkscores,
                     process_tranche_errorhandling(tranche = tranche6, ottawa_phhs = ottawa_phhs, num_to_score = 100, apikey = apikey )
 ),

 targets::tar_target(tranche7Walkscores,
                     process_tranche_errorhandling(tranche = tranche7, ottawa_phhs = ottawa_phhs, num_to_score = 100, apikey = apikey )
 ),

 targets::tar_target(walkscore_points,
                     dplyr::bind_rows(tranche1Walkscores,
                                      tranche2Walkscores,
                                      tranche3Walkscores,
                                      tranche4Walkscores,
                                      tranche5Walkscores,
                                      tranche6Walkscores,
                                      tranche7Walkscores) %>%
                       dplyr::filter(ONS_Region == "OTTAWA")
                     ),

 targets::tar_target(walkscore_regions,
                     walkscore_points %>%
                       sf::st_set_geometry(NULL) %>%
                       dplyr::group_by(ONS_ID, ONS_Name) %>%
                     dplyr::summarise(walkscore_mean = mean(as.numeric(walkscore))) %>%
                       dplyr::left_join(ons_gen3, .) %>%
                       dplyr::filter(ONS_Region == "OTTAWA")
                     ),


 targets::tar_target(walkscore_points_plot,
                     ggplot2::ggplot(walkscore_points) +
                       ggplot2::geom_sf(ggplot2::aes(colour = as.numeric(walkscore)))
                     ),

 targets::tar_target(walkscore_points_fancy,
                     walkscore_points_plot +
                       theme_void() +
                       theme(legend.position="none", plot.background = element_rect(fill="black")) +
                       scale_colour_viridis_c()),


 targets::tar_target(walkscore_regions_plot,
                     ggplot2::ggplot(walkscore_regions) +
                       ggplot2::geom_sf(ggplot2::aes(fill = as.numeric(walkscore_mean)), colour = NULL) +
                       ggplot2::theme_void() +
                       ggplot2::theme(legend.position="none", plot.background = element_rect(fill="black")) +
                       ggplot2::scale_fill_viridis_c()
 ),

 targets::tar_target(save_results,
                    {
                      # points: save sf and csv files
                      walkscore_points %>%
                        sf::write_sf(sprintf("outputs/walkscore-points-%s.shp", Sys.Date())) %>%
                        sf::st_set_geometry(NULL) %>%
                        readr::write_csv(sprintf("outputs/walkscore-points-%s.csv", Sys.Date()))

                      # regions: save sf and csv files
                      walkscore_regions %>%
                        sf::write_sf(sprintf("outputs/walkscore-hoods-%s.shp", Sys.Date())) %>%
                        sf::st_set_geometry(NULL) %>%
                        readr::write_csv(sprintf("outputs/walkscore-hoods-%s.csv", Sys.Date()))

                      # readr::write_csv(sf::st_set_geometry(walkscore_points, NULL), sprintf("outputs/walkscore-points-%s.csv", Sys.Date))
                      # readr::write_csv(sf::st_set_geometry(walkscore_regions, NULL), sprintf("outputs/walkscore-regions-%s.csv", Sys.Date))
                      #
                      # # save shapefiles
                      # sf::write_sf(walkscore_points, sprintf("outputs/walkscore-points-%s.shp", Sys.Date))
                      # sf::write_sf(walkscore_regions, sprintf("outputs/walkscore-regions-%s.s.shp", Sys.Date))

                    }
                    ),

 NULL
)
