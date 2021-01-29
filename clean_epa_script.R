################################################
######## CODE TO CLEAN EPA INFORMATION #########
################################################

# Load utils and packages
source("utils.R")

# Ingest raw data
# Lead testing data was downloaded on Jan 6th 2021
leadtest_raw_data <- map_df(
  list.files(path = "data/", pattern = "lead_samples*", full.names = TRUE),
  fread
) %>%
  clean_names()

# Data on violations to the Lead and Copper Rule
violations_raw_data <- fread("data/violation_report.csv") %>%
  clean_names()

# Data on geographic coverage of water systems
geo_raw_data <- map_df(
  list.files(path = "data/", pattern = "water_system_geo*", full.names = TRUE),
  fread
) %>%
  clean_names()

# Extract the Public Water System (PWS) ID that have lead samples historically
pws_id_leadsamples <- (unique(leadtest_raw_data$pws_id))

# Extract water system-county-state
# This will be the list of counties to match to ACS data
# The focus of this analysis is mainland US including HI and AK
geographic_coverage <- geo_raw_data %>%
  select(pws_id, primacy_agency, state_code, area_type, county_served, city_served, zip_code_served, tribal_code) %>%
  filter(pws_id %in% pws_id_leadsamples) %>%
  mutate(
    state_abb = state.abb[match(primacy_agency, state.name)],
    state_abb = ifelse(primacy_agency == "District of Columbia", "DC", state_abb),
    state_abb = ifelse(is.na(state_abb), state_code, state_abb)
  ) %>%
  filter(state_abb %in% c(state.abb, "DC"))

geographic_coverage[geographic_coverage == "-"] <- NA
geographic_coverage <- geographic_coverage %>%
  # filter is the middle columns are NA in all the following columns
  filter(!across(c(state_code, area_type, county_served, city_served, zip_code_served, tribal_code), ~ is.na(.))) %>%
  # check the missmatches in the states
  mutate(match_state = ifelse(state_code == state_abb, 1, 0)) %>%
  # remove EPA regions with no county. Need a separate analysis for large tribal regions
  filter(is.na(tribal_code)) %>%
  select(state_abb, county_served, city_served, zip_code_served) %>%
  filter(!duplicated(.)) %>%
  mutate(
    city_served_cleaned = gsub("\\(T\\)|[[:space:]]{,2}\\(T\\)", "", city_served, ignore.case = TRUE),
    city_served_cleaned = gsub("\\(V\\)|[[:space:]]{,2}\\(V\\)", "", city_served_cleaned, ignore.case = TRUE),
    city_served_cleaned = gsub("\\(C\\)|[[:space:]]{,2}\\(C\\)", "", city_served_cleaned, ignore.case = TRUE),
    city_served_cleaned = gsub("TWP", "Township", city_served_cleaned, ignore.case = TRUE),
    city_served_cleaned = gsub("[[:digit:][:punct:]]", "", city_served_cleaned),
    city_served_cleaned = gsub("[[:space:]]{2,}", " ", city_served_cleaned),
    city_served_cleaned = gsub("[[:space:]]+$", "", city_served_cleaned),
    city_served_cleaned = str_to_title(city_served_cleaned),
    # Remove the village, city, township, boro, town strings
    city_served_geolook = gsub("\\(T\\)|[[:space:]]{,2}\\(T\\)|\\(V\\)|[[:space:]]{,2}\\(V\\)|\\(C\\)|[[:space:]]{,2}\\(C\\)|TWP|City|[[:space:]]Boro|Town", "", city_served, ignore.case = TRUE),
    city_served_geolook = gsub("[[:digit:][:punct:]]", "", city_served_geolook),
    city_served_geolook = gsub("[[:space:]]{2,}", " ", city_served_geolook),
    city_served_geolook = gsub("[[:space:]]+$", "", city_served_geolook),
    city_served_geolook = gsub("^Saint[[:space:]]|^St[[:space:]]", "St. ", city_served_geolook, ignore.case = TRUE),
    city_served_geolook = gsub("[[:space:]]St[[:space:]]", " St. ", city_served_geolook, ignore.case = TRUE),
    city_served_geolook = str_to_title(city_served_geolook)
  )

# List of cities need to match to county
city_county_geolook_list <- geographic_coverage %>%
  select(state_abb, city_served_geolook) %>%
  filter(!is.na(city_served_geolook))

# Initialize log for city-county
file.create("city_geolook.log")
flog.appender(appender.file("city_geolook.log"))


# Function to store city-county matches
fx_geolook <- function() {
  city_list <- list()
  for (i in 1:nrow(city_county_geolook_list)) {
    tryCatch(
      {
        dat <- geo.lookup(state = city_county_geolook_list[i, state_abb], place = city_county_geolook_list[i, city_served_geolook])
        n_cols <- ncol(dat)
        if (n_cols < 5) {
          stop(sprintf("ERROR: %s, %s in row %d was not found", city_county_geolook_list[i, city_served_geolook], city_county_geolook_list[i, state_abb], i))
        }
        # Normal behaviour
        flog.info("Row %d was found", i)
        city_list[[i]] <- dat
      },
      error = function(e) {
        print(conditionMessage(e))
        flog.error(conditionMessage(e))
      }
    )
  }
  return(city_list)
}

city_county_lookup <- fx_geolook()

# Clean data to match city-counties
city_county_matches <- do.call(rbind, city_county_lookup) %>%
  clean_names() %>%
  filter(!across(c(county_name, place, place_name), ~ is.na(.))) %>%
  select(state_name, county_name, place_name) %>%
  mutate(
    state_abb = state.abb[match(state_name, state.name)],
    state_abb = ifelse(state_name == "District of Columbia", "DC", state_abb)
  ) %>%
  rename(city_served_geolook = place_name) %>%
  mutate(
    city_served_geolook = gsub("[[:space:]]township|[[:space:]]city|[[:space:]]CDP|[[:space:]]borough|[[:space:]]municipality|[[:space:]]village|[[:space:]]town|[[:space:]]Reservation", "", city_served_geolook, ignore.case = TRUE),
    county_name = gsub("[[:space:]]County|[[:space:]]Census Area|[[:space:]]Borough|[[:space:]]Municipality|[[:space:]]City and Borough|[[:space:]]city", "", county_name, ignore.case = TRUE)
  ) %>%
  filter(!duplicated(.)) %>%
  select(state_abb, city_served_geolook, county_name)

# Max number of counties matched to cities
ncol_split <- max(str_count(city_county_matches$county_name, pattern = ","))
counties_split <- data.frame(str_split_fixed(city_county_matches$county_name, pattern = ",", n = ncol_split + 1))

city_county_matches <- cbind(city_county_matches, counties_split) %>%
  select(-county_name) %>%
  gather(number, county, -state_abb, -city_served_geolook) %>%
  select(-number) %>%
  mutate(county = ifelse(nchar(county) == 0, NA, gsub("^[[:space:]]{1,}|[[:space:]]{1,}$", "", county))) %>%
  filter(!is.na(county)) %>%
  filter(!duplicated(.))

city_county_geolook_list <- city_county_geolook_list %>%
  left_join(city_county_matches) %>%
  filter(!is.na(county)) %>%
  filter(!duplicated(.))

# Include the counties found through geolook to the list of geographical coverage of water systems
# This is to ensure as many matches as possible at the county level
geographic_coverage <- geographic_coverage %>%
  left_join(city_county_geolook_list) %>%
  mutate(county_acs_lookup = ifelse(is.na(county_served), county, county_served))

# Look for county info on the latest ACS
county_acs_lookup <- geographic_coverage %>%
  select(state_abb, county_acs_lookup) %>%
  mutate(county_acs_lookup = gsub("[[:space:]]Borough|[[:space:]]Census Area|[[:space:]]Parish|[[:space:]]City and Borough|[[:space:]]Municipality", "", county_acs_lookup, ignore.case = TRUE)) %>%
  filter(!duplicated(.))

# Look for variables in the ACS at the county level

file.create("county_acs_lookup.log")
flog.appender(appender.file("county_acs_lookup.log"))


fx_countylook <- function(df) {
  acs_list <- list()
  for (i in 1:nrow(df)) {
    tryCatch(
      {
        acs_dat <- get_acs(
          geography = "county",
          year = 2018,
          geometry = TRUE,
          survey = "acs5",
          county = df[i, county_acs_lookup],
          state = df[i, state_abb],
          variables = c(
            Total_pop = "B01003_001",
            Total_black = "B01001B_001",
            Total_hisp = "B01001I_001",
            Total_white = "B01001H_001",
            Total_asian = "B01001D_001",
            Total_pac = "B01001E_001",
            Total_native = "B01001C_001",
            Median_income = "B25099_001",
            Total_house = "B22003_001",
            Total_snap = "B22003_002",
            Total_pov = "B06012_002",
            Total_structures = "B25034_001",
            Total_str_80_89 = "B25034_006",
            Total_str_70_79 = "B25034_007",
            Total_str_60_69 = "B25034_008",
            Total_str_50_59 = "B25034_009",
            Total_str_40_49 = "B25034_010",
            Total_str_39_less = "B25034_011",
            Median_house_age = "B25035_001"
          )
        )
        # Normal behaviour
        flog.info("Row %d was found", i)
        acs_list[[i]] <- acs_dat
      },
      error = function(e) {
        print(conditionMessage(e))
        flog.error(conditionMessage(e))
      }
    )
  }
  return(acs_list)
}

# Large df containing shapefile for counties
acs_data_list <- fx_countylook(county_acs_lookup)

# Check logs for additional cities that can be matched
# Info from the logs
acs_log_errors <- data.frame(readLines("county_acs_lookup.log")) %>%
  rename(log_message = 1) %>%
  mutate(line_no = row_number()) %>%
  filter(grepl(pattern = "Your county string matches", log_message))

county_acs_lookup_plus <- county_acs_lookup[acs_log_errors$line_no, ] %>%
  mutate(county_acs_lookup = paste0(county_acs_lookup, " County"))

county_acs_list_missing <- fx_countylook(county_acs_lookup_plus)

# Covert lists into data frames and then bind rows
acs_data <- do.call(rbind, acs_data_list) %>% clean_names()
acs_data_missing <- do.call(rbind, county_acs_list_missing) %>% clean_names()

# ACS data from 2014-2018 survey
acs_data <- rbind(acs_data, acs_data_missing)

# Match Public water system to geographic data

pws_geo_coverage <- geo_raw_data %>%
  select(pws_id, primacy_agency, state_code, area_type, county_served, city_served, zip_code_served, tribal_code) %>%
  mutate(
    state_abb = state.abb[match(primacy_agency, state.name)],
    state_abb = ifelse(primacy_agency == "District of Columbia", "DC", state_abb),
    state_abb = ifelse(is.na(state_abb), state_code, state_abb)
  ) %>%
  filter(state_abb %in% c(state.abb, "DC"))

pws_geo_coverage[pws_geo_coverage == "-"] <- NA
pws_geo_coverage <- pws_geo_coverage %>%
  filter(!across(c(state_code, area_type, county_served, city_served, zip_code_served, tribal_code), ~ is.na(.))) %>%
  filter(is.na(tribal_code)) %>%
  filter(!duplicated(.)) %>%
  select(-primacy_agency, -state_code, -area_type, -tribal_code) %>%
  gather(area_type, area_name, -pws_id) %>%
  filter(!is.na(area_name)) %>%
  filter(!duplicated(.)) %>%
  group_by(pws_id, area_type) %>%
  mutate(obs = row_number()) %>%
  ungroup() %>%
  spread(area_type, area_name) %>%
  left_join(geographic_coverage %>%
    select(city_served, county_served, state_abb, zip_code_served, county_acs_lookup),
  by = c(
    "city_served" = "city_served",
    "county_served" = "county_served",
    "state_abb" = "state_abb",
    "zip_code_served" = "zip_code_served"
  )) %>%
  filter(!duplicated(.)) %>%
  mutate(county_match = case_when(
    county_served == county_acs_lookup ~ county_acs_lookup,
    is.na(county_acs_lookup) & !is.na(county_served) ~ county_served,
    !is.na(county_acs_lookup) & is.na(county_served) ~ county_acs_lookup
  ))


# Clean lead testing data
# Note to self: 1 ppb = 0.001 mg/l

leadtest_data_clean <- leadtest_raw_data
leadtest_data_clean[leadtest_data_clean == "-"] <- NA
leadtest_data_clean <- leadtest_data_clean %>%
  filter(!duplicated(.)) %>%
  mutate(
    ppb = sample_measure_mg_l * 1000,
    sampling_start_date = mdy(sampling_start_date),
    sampling_end_date = mdy(sampling_end_date),
    pws_deactivation_date = dmy(pws_deactivation_date)
  )

col_order <- c(c("pws_id", "pws_name"), colnames(leadtest_data_clean[, -c("pws_id", "pws_name", "address_line1", "address_line2", "zip_code")]))
leadtest_data_clean <- leadtest_data_clean %>%
  select(all_of(col_order)) %>%
  filter(!state_code %in% c("PR", "GU", "VI", "MP", "AS", "PQ")) %>%
  left_join(pws_geo_coverage %>%
              select(pws_id, state_abb, city_served, county_match),
            by = c("pws_id" = "pws_id"))

# The missing rows with counties are less than 3%, we can ignore those for now since it's a very small number
# length(which(is.na(leadtest_data_clean$county_match)))/nrow(leadtest_data_clean)

leadtest_data_clean <- leadtest_data_clean %>%
  filter(!is.na(county_match)) %>%
  select(-state_code) %>%
  rename(county_served = county_match)


# YOU CAN SAVE THE RESULT LOCALLY BY UNCOMMETING THE LINE BELOW
#write.csv(leadtest_data_clean, file = "lead_samples_historical.csv")

################################################
######## CODE TO MATCH ACS AND LEAD TESTING ####
################################################

leadtest_14_18 <- leadtest_data_clean %>%
filter(sampling_start_date >= date("2014-01-01") & sampling_end_date <= date("2018-12-31"))

acs_data_wide <- acs_data %>%
  data.frame() %>%
  select(-moe, -geometry) %>%
  filter(!duplicated(.)) %>%
  spread(variable, estimate) %>%
  mutate(
    county = gsub(pattern = ",.*", "", name),
    county = gsub("[[:space:]]County", "", county),
    state = gsub(pattern = ".*,[[:space:]]", "", name),
    state_abb = ifelse(state == "District of Columbia", "DC", state.abb[match(state, state.name)])
  )

leadtest_acs_14_18 <- leadtest_14_18 %>%
  select(-city_name) %>%
  left_join(acs_data_wide %>% select(-state, -name), by = c(
    "state_abb" = "state_abb",
    "county_served" = "county"
  ))

geoid_geometry <- acs_data %>%
  select(geoid, geometry) %>%
  filter(!duplicated(.))


leadtest_acs_14_18 <- leadtest_14_18 %>%
  select(-city_name) %>%
  left_join(acs_data_wide %>% select(-state, -name), by = c(
    "state_abb" = "state_abb",
    "county_served" = "county"
  )) %>%
  left_join(geoid_geometry, by = "geoid") %>%
  st_as_sf()

# YOU CAN SAVE THE RESULT LOCALLY BY UNCOMMETING THE LINE BELOW
# write_sf(leadtest_acs_14_18, "leadtest_acs_14_18.geojson")
