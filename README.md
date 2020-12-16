# Lead in Tap Water Tests and socioeconomic data in the United States

The Rockefeller Foundation is releasing a series of datasets of lead in tap water test results. The raw data was obtained from the [Safe Drinking Water Information System](https://ofmpub.epa.gov/apex/sfdw/f?p=108:35:::::P35_REPORT2:LCR) (SDWIS) Federal Reporting System and we have coupled it with socioeconomic variables from the American Community Survey. The datasets have been cleaned and code to reproduce will be included in this repository.

This data powers our [dashboard](https://public.tableau.com/profile/rf.data#!/vizhome/IllustrativeLeadDashExtracted/DataWithThumbnail) tracking the lead tests results at the county and Public Water System levels which is also available for the public.

<center>
![Lead_dashboard in Tableau](https://github.com/datasciencerf/lead_water_acs_data/blob/main/lead_dashboard.gif)
</center>
## Datasets

- `lead_acs_data_2012_2019.csv` contains lead tests at the public water system level from 2012 through 2019. The column `area_served` indicates the county the water system serves. The dataset also includes county-level socioeconomic data from the American Community Survey (ACS). The ACS data comes from the [2014 - 2018 ACS 5-year estimates](https://www.census.gov/programs-surveys/acs/technical-documentation/table-and-geography-changes/2018/5-year.html).  

- `water_system_summary_active.csv` includes information on active water systems across the United States, counties served, category of water system and number of violations to the Safe Drinking Water Act from 1991 to 2019.

- `data_dictionary.csv` includes definition of all variables in the `lead_acs_data_2012_2019.csv` and `water_system_summary_active.csv` files.

## Attribution and License

The datasets in this repository are publicly available for noncommerical purposes including use by academics, nonprofits and the general public.

Using this data requires attribution to "The Rockefeller Foundation" in any publication or report. We are currently using Creative Commons Attribution-NonCommercial 4.0 International license. You can read the terms in the [LICENSE](https://github.com/datasciencerf/lead_water_acs_data/blob/main/LICENSE).


## Contact Us

If you have questions about the data or licensing conditions, please contact us

## Contributors

Sue Marquez, Data Science Manager\
Michelle Leonard, Data Visualization consultant
