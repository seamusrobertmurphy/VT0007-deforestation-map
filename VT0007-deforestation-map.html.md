---
title: "JNR Deforestation Risk Maps"
date: 2024-11-04
author: 
  - name: Seamus Murphy
    orcid: 0000-0002-1792-0351 
    email: seamusrobertmurphy@gmail.com
    degrees:
      - PhD
abstract: > 
  The following starter script documents two workflows for deriving deforestation 
  risk maps in accordance with Verra's new methodology for unplanned 
  deforestation allocation in jurisdictional nested REDD+ projects using the 
  [VT0007 toolset](https://verra.org/wp-content/uploads/2024/02/VT0007-Unplanned-Deforestation-Allocation-v1.0.pdf).
keywords:
  - REDD+
  - VCS
  - Verra
  - Carbon verification
  - Jurisdictional
format: 
  html:
    toc: true
    toc-location: right
    toc-title: "**Contents**"
    toc-depth: 5
    toc-expand: 4
    theme: [minimal, styles.scss]
highlight-style: github
df-print: kable
keep-md: true
prefer-html: true
bibliography: references.bib
engine: knitr
---





## Summary

The following details two workflow approaches to Verra's recommended sequence of deforestation risk map development @verraVT0007UnplannedDeforestation2021. For comparison purposes, both workflows use the same training sample [@stanimirovaGlobalLandCover2023] and STAC-formatted Landsat Collection-2 Level-2 [imagery](https://www.usgs.gov/landsat-missions/landsat-science-products).

Workflow-1 is coded in R and is recommended for smaller areas of analysis, as it offers additional functions for model tuning and classifer evaluation. Workflow-2, which is coded in Python and Google Earth Engine functions, is recommended for larger areas of interest (***Update java link here***).

![Figure 1: Verra's recommended risk map development sequence (VT0007:6)](VT0007-risk-map-development-sequence.png)

# 1. Workflow in R -\> `sits`

## 1.1 Testing phase


::: {.cell}

```{.python .cell-code}
import numpy as np
import sys 
print()
```
:::


### Jurisdictional boundaries


::: {.cell}

```{.r .cell-code}
# assign master crs
crs_master  = sf::st_crs("epsg:4326")
aoi_country = geodata::gadm(country="GUY", level=0, path=tempdir()) |>
  sf::st_as_sf() |> sf::st_cast() |> sf::st_transform(crs_master)
aoi_states = geodata::gadm(country="GUY", level=1, path=tempdir()) |>
  sf::st_as_sf() |> sf::st_cast() |> sf::st_transform(crs_master) |>
  dplyr::rename(State = NAME_1)
aoi_target = dplyr::filter(aoi_states, State == "Barima-Waini")

tmap::tmap_mode("view")
tmap::tm_shape(aoi_states) + tmap::tm_borders(col = "white", lwd = 0.5) +
  tmap::tm_text("State", col = "white", size = 1, alpha = 0.3, just = "bottom") +
  tmap::tm_shape(aoi_country) + tmap::tm_borders(col = "white", lwd = 1) +
  tmap::tm_shape(aoi_target) + tmap::tm_borders(col = "red", lwd = 2) +
  tmap::tm_text("State", col = "red", size = 1.3) +
  tmap::tm_basemap("Esri.WorldImagery")
```

::: {.cell-output-display}
preservea3083add96f21a5c
:::
:::


### Assemble HRP time series

We assemble and process a data cube representing a historical reference period (HRP) between 2013-01-01 and 2023-01-01 for the country of Suriname. Using the `sits_regularize` functions, we apply a cloud masking and pixel back-filling based on cloudless ranking and median-normalization across 5-year intervals to derive three dry-season mosaics for 2013, 2018 and 2023.


::: {.cell}

```{.r .cell-code}
# 2014 -------------------
# cloud-assemble data cube
cube_raw_2014 = sits::sits_cube(
  source      = "MPC",
  collection  = "LANDSAT-C2-L2",
  bands       = c("RED", "GREEN", "BLUE", "NIR08", "SWIR16", "CLOUD"),
  roi         = aoi_target,
  start_date  = as.Date("2014-01-01"),
  end_date    = as.Date("2014-07-01"),
  progress    = T
  )

# regularize data cube
cube_reg_2014 = sits::sits_regularize(
  cube        = cube_raw_2014,
  roi         = aoi_target,
  res         = 60,
  period      = "P180D",
  output_dir  = here::here("cubes", "reg", "2014"),
  memsize     = 16,
  multicores  = 8,
  progress    = T
  )

# 2019 -------------------
# cloud-assemble data cube
cube_raw_2019 = sits::sits_cube(
  source      = "MPC",
  collection  = "LANDSAT-C2-L2",
  bands       = c("RED", "GREEN", "BLUE", "NIR08", "SWIR16", "CLOUD"),
  roi         = aoi_target,
  start_date  = as.Date("2019-01-01"),
  end_date    = as.Date("2019-07-01"),
  progress    = T
  )

# regularize data cube
cube_reg_2019 = sits::sits_regularize(
  cube        = cube_raw_2019,
  roi         = aoi_target,
  res         = 60,
  period      = "P180D",
  output_dir  = here::here("cubes", "reg", "2019"),
  memsize     = 16,
  multicores  = 8,
  progress    = T
  )

# 2024 -------------------
# cloud-assemble data cube
cube_raw_2024 = sits::sits_cube(
  source      = "MPC",
  collection  = "LANDSAT-C2-L2",
  bands       = c("RED", "GREEN", "BLUE", "NIR08", "SWIR16", "CLOUD"),
  roi         = aoi_target,
  start_date  = as.Date("2024-01-01"),
  end_date    = as.Date("2024-07-01"),
  progress    = T
  )

# regularize data cube
cube_reg_2024 = sits::sits_regularize(
  cube        = cube_raw_2024,
  roi         = aoi_target,
  res         = 60,
  period      = "P180D",
  output_dir  = here::here("cubes", "reg", "2024"),
  memsize     = 16,
  multicores  = 8,
  progress    = T
  )
```
:::

::: {.cell layout-ncol="3"}

```{.r .cell-code}
# plot cube timelines
sits_timeline(cube_reg_2014)
sits_timeline(cube_reg_2019)
sits_timeline(cube_reg_2024)
plot(cube_reg_2014,
  red         = "RED",
  green       = "GREEN",
  blue        = "BLUE",
  date        = "2014-01-03"
  )

plot(cube_reg_2019,
  red         = "RED",
  green       = "GREEN",
  blue        = "BLUE",
  date        = "2019-01-08"
  )

plot(cube_reg_2024,
  red         = "RED",
  green       = "GREEN",
  blue        = "BLUE",
  date        = "2024-01-07"
  )
```
:::


### Classify HRP time series

We import the GLanCE training dataset of annual times series points that includes 7 land cover classes (Figure 2; [@woodcockGlobalLandCover]). Training samples are fitted to a Random Forest model and post-processed with a Bayesian smoothing and then evaluated using confusion matrix. The classifier is then calibrated by mapping pixel uncertainty, adding new samples in areas of high uncertainty, reclassifying with improved samples and re-evaluated using confusion matrix.

![Figure 2: Land cover classes included in the GLanCE Level 1 classification scheme (Woodcock et al 2022)](training/glance_training_classes.png)


::: {.cell}

```{.r .cell-code}
# Extract training set from gee to drive & import: https://gee-community-catalog.org/projects/glance_training/?h=training 
glance_training_url = "https://drive.google.com/file/d/1CgBP2J2OdOhmOiVS4hGibLEMyVLTe1_P/view?usp=drive_link"
# file_name = "glance_training.csv"
# download.file(url = url, path = here::here("training"), destfile = file_name)
glance_training = read.csv(here::here("training", "glance_training.csv"))

data("samples_prodes_4classes")
# Select the same three bands used in the data cube
samples_4classes_3bands <- sits_select(
  data = samples_prodes_4classes,
  bands = c("B02", "B8A", "B11")
  )

# Train a random forest model
rfor_model <- sits_train(
  samples = samples_4classes_3bands,
  ml_method = sits_rfor()
  )

# Classify the small area cube
s2_cube_probs <- sits_classify(
  data = s2_reg_cube_ro,
  ml_model = rfor_model,
  output_dir = "./cubes/02_class/",
  memsize = 15,
  multicores = 5
  )

# Post-process the probability cube
s2_cube_bayes <- sits_smooth(
  cube = s2_cube_probs,
  output_dir = "./cubes/02_class/",
  memsize = 16,
  multicores = 4
  )

# Label the post-processed  probability cube
s2_cube_label <- sits_label_classification(
  cube = s2_cube_bayes,
  output_dir = "./cubes/02_class/",
  memsize = 16,
  multicores = 4
  )

plot(s2_cube_label)
```
:::


## Map uncertainty

To improve model performance, we estimate class uncertainty and plot these pixel error metrics. Results below reveal highest uncertainty levels in classification of wetland and water areas.


::: {.cell}

```{.r .cell-code}
# Calculate the uncertainty cube
s2_cube_uncert <- sits_uncertainty(
  cube = s2_cube_bayes,
  type = "margin",
  output_dir = "./cubes/03_error/",
  memsize = 16,
  multicores = 4
)

plot(s2_cube_uncert)
```
:::


As expected, the places of highest uncertainty are those covered by surface water or associated with wetlands. These places are likely to be misclassified. For this reason, sits provides `sits_uncertainty_sampling()`, which takes the uncertainty cube as its input and produces a tibble with locations in WGS84 with high uncertainty [@camaraUncertaintyActiveLearning].


::: {.cell}

```{.r .cell-code}
# Find samples with high uncertainty
new_samples <- sits_uncertainty_sampling(
  uncert_cube = s2_cube_uncert,
  n = 20,
  min_uncert = 0.5,
  sampling_window = 10
  )

# View the location of the samples
sits_view(new_samples)
```
:::


## Add training samples

We can then use these points of high-uncertainty as new samples to add to our current training dataset. Once we identify their feature classes and relabel them correctly, we append them to derive an augmented `samples_round_2`.


::: {.cell}

```{.r .cell-code}
# Label the new samples
new_samples$label <- "Wetland"

# Obtain the time series from the regularized cube
new_samples_ts <- sits_get_data(
  cube = s2_reg_cube_ro,
  samples = new_samples
  )

# Add new class to original samples
samples_round_2 <- dplyr::bind_rows(
  samples_4classes_3bands,
  new_samples_ts
  )

# Train a RF model with the new sample set
rfor_model_v2 <- sits_train(
  samples = samples_round_2,
  ml_method = sits_rfor()
  )

# Classify the small area cube
s2_cube_probs_v2 <- sits_classify(
  data = s2_reg_cube_ro,
  ml_model = rfor_model_v2,
  output_dir = "./cubes/02_class/",
  version = "v2",
  memsize = 16,
  multicores = 4
  )

# Post-process the probability cube
s2_cube_bayes_v2 <- sits_smooth(
  cube = s2_cube_probs_v2,
  output_dir = "./cubes/04_smooth/",
  version = "v2",
  memsize = 16,
  multicores = 4
  )

# Label the post-processed  probability cube
s2_cube_label_v2 <- sits_label_classification(
  cube = s2_cube_bayes_v2,
  output_dir = "./cubes/05_tuned/",
  version = "v2",
  memsize = 16,
  multicores = 4
  )

# Plot the second version of the classified cube
plot(s2_cube_label_v2)
```
:::


## Remap uncertainty


::: {.cell}

```{.r .cell-code}
# Calculate the uncertainty cube
s2_cube_uncert_v2 <- sits_uncertainty(
  cube = s2_cube_bayes_v2,
  type = "margin",
  output_dir = "./cubes/03_error/",
  version = "v2",
  memsize = 16,
  multicores = 4
)

plot(s2_cube_uncert_v2)
```
:::


## Accuracy assessment

To select a validation subset of the map, `sits` recommends Cochran’s method for stratified random sampling [@cochran1977sampling]. The method divides the population into homogeneous subgroups, or strata, and then applying random sampling within each stratum. Alternatively, ad-hoc parameterization is suggested as follows.


::: {.cell}

```{.r .cell-code}
ro_sampling_design <- sits_sampling_design(
  cube = s2_cube_label_v2,
  expected_ua = c(
    "Burned_Area"       = 0.75,
    "Cleared_Area"      = 0.70,
    "Forest"            = 0.75,
    "Highly_Degraded"   = 0.70,
    "Wetland"           = 0.70
  ),
  alloc_options         = c(120, 100),
  std_err               = 0.01,
  rare_class_prop       = 0.1
)
# show sampling desing
ro_sampling_design
```
:::


## Split train/test data


::: {.cell}

```{.r .cell-code}
ro_samples_sf <- sits_stratified_sampling(
  cube                  = s2_cube_label_v2,
  sampling_design       = ro_sampling_design,
  alloc                 = "alloc_120",
  multicores            = 4,
  shp_file              = "./samples/ro_samples.shp"
)

sf::st_write(ro_samples_sf,
  "./samples/ro_samples.csv",
  layer_options = "GEOMETRY=AS_XY",
  append = FALSE # TRUE if editing existing sample
)
```
:::


## Confusion matrix


::: {.cell}

```{.r .cell-code}
# Calculate accuracy according to Olofsson's method
area_acc <- sits_accuracy(s2_cube_label_v2,
  validation = ro_samples_sf,
  multicores = 4
)
# Print the area estimated accuracy
area_acc

# Print the confusion matrix
area_acc$error_matrix
```
:::


## Times series visualization


::: {.cell}

```{.r .cell-code}
summary(as.data.frame(ro_samples_sf))
```
:::


## Deforestation binary map

## Deforestation risk map

# 2. Workflow in Python -\> `GEE`


::: {.cell}

```{.r .cell-code}
# Set your Python ENV
Sys.setenv("RETICULATE_PYTHON" = "/usr/bin/python3")
# Set Google Cloud SDK 
Sys.setenv("EARTHENGINE_GCLOUD" = "~/seamus/google-cloud-sdk/bin/")

library(rgee) 
ee_Authenticate()
ee_install_upgrade()
ee_Initialize()
```
:::


#### Housekeeping


::: {.cell}

```{.r .cell-code}
# convert markdown to script.R 
knitr::purl("VT0007-deforestation-risk-map.qmd")

# display environment setup
devtools::session_info()
```
:::