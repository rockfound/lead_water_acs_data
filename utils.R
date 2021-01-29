# Utilities and libraries

## Libraries
packages <- c("tidyverse",
              "tidycensus",
              "janitor",
              "data.table",
              "futile.logger",
              "tidyselect",
              "stringr",
              "lubridate",
              "purrr",
              "sf",
              "acs",
              "reshape2",
              "rgeos")

lapply(packages, library, character.only = TRUE)
