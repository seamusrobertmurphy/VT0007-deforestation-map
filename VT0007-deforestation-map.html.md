---
title: "VT0007 Jurisdictional Deforestation Risk Maps"
date: 2024-11-04
author: 
  - name: Seamus Murphy
    orcid: 0000-0002-1792-0351 
    email: seamusrobertmurphy@gmail.com
    degrees:
      - PhD
abstract: > 
  The following workflow provides a starter script for deriving deforestation 
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
---







## Summary

Two workflow approaches are detailed below.
Workflow-2 is coded using Python and Google Earth Engine functions that are more suited to larger areas of interest.
For comparison purposes, both workflows derive outputs from the same image collection of STAC-formatted analysis-ready-data of Landsat scenes, following steps outlined in Verra's recommended sequence of deforestation risk map development @verraVT0007UnplannedDeforestation2021 .
Workflow-1, which is coded using the R ecosystem, allows additional model tuning functions suited to analysis of smaller areas.

![Figure 1: Verra's recommended risk map development sequence (VT0007:6)](VT0007-risk-map-development-sequence.png)

# 1. Workflow in R

## Process data cube

For shawcasing purposes, we import a training dataset from the `sitsdata` package from a study of Brazil's Samuel Hydroelectric Dam in Rondonia State conducted between 2020-06-04 to 2021-08-26.
To evaluate this training sample, we assemble below a data cube of Sentinel-2-L2A-COGS images from the AWS open bucket.
Raster normalization is implemented with `sits_regularize` functions to apply a cloud masking and back-filling of missing pixels by cloudless ranking and global median values across 16-day intervals.




::: {.cell}

```{.r .cell-code}
# build irregular data cube from single sentinel tile
s2_cube_ro <- sits_cube(
  source = "AWS",
  collection = "SENTINEL-S2-L2A-COGS",
  tiles = "20LMR",
  bands = c("B02", "B8A", "B11", "SCL"),
  start_date = as.Date("2020-06-01"),
  end_date = as.Date("2021-09-01"),
  progress = FALSE)
```

::: {.cell-output .cell-output-stdout}

```

  |                                                                            
  |======================================================================| 100%
```


:::

```{.r .cell-code}
# select aoi inside the tile
roi <- c(
  lon_max = -63.25790, lon_min = -63.6078,
  lat_max = -8.72290, lat_min = -8.95630)

# regularize the aoi filtered cube
s2_reg_cube_ro <- sits_regularize(
  cube = s2_cube_ro,
  output_dir = "./cubes/01_reg",
  res = 30,
  roi = roi,
  period = "P16D",
  memsize = 16,
  multicores = 4,
  progress = FALSE)
```
:::




## Review data cube




::: {.cell layout-ncol="3"}

```{.r .cell-code}
plot(s2_reg_cube_ro,
  red = "B11",
  green = "B8A",
  blue = "B02",
  date = "2020-07-04"
  )
```

::: {.cell-output-display}
![](VT0007-deforestation-map_files/figure-html/unnamed-chunk-2-1.png){width=672}
:::

```{.r .cell-code}
plot(s2_reg_cube_ro,
  red = "B11",
  green = "B8A",
  blue = "B02",
  date = "2020-11-09"
  )
```

::: {.cell-output-display}
![](VT0007-deforestation-map_files/figure-html/unnamed-chunk-2-2.png){width=672}
:::

```{.r .cell-code}
plot(s2_reg_cube_ro, 
     red = "B11", 
     green = "B8A", 
     blue = "B02", 
     date = "2021-08-08"
     )
```

::: {.cell-output-display}
![](VT0007-deforestation-map_files/figure-html/unnamed-chunk-2-3.png){width=672}
:::
:::




## Classify data cube

We import a training set of 480 times series points specifically designed to detect deforestation, which comprise of four classes (`Burned_Area`, `Forest`, `Highly_Degraded`, and `Cleared_Area`).
Training samples are fitted to a Random Forest model and post-processed with a Bayesian smoothing.




::: {.cell}

```{.r .cell-code}
# Load the training set
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

::: {.cell-output-display}
![](VT0007-deforestation-map_files/figure-html/unnamed-chunk-3-1.png){width=672}
:::
:::




## Map uncertainty

To improve model performance, we estimate class uncertainty and plot these pixel error metrics.
Results below reveal highest uncertainty levels in classification of wetland and water areas.




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

::: {.cell-output-display}
![](VT0007-deforestation-map_files/figure-html/unnamed-chunk-4-1.png){width=672}
:::
:::




As expected, the places of highest uncertainty are those covered by surface water or associated with wetlands.
These places are likely to be misclassified.
For this reason, sits provides `sits_uncertainty_sampling()`, which takes the uncertainty cube as its input and produces a tibble with locations in WGS84 with high uncertainty [@camaraUncertaintyActiveLearning].




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

::: {.cell-output-display}
preserveb95623e2dda56049
:::
:::




## Add training samples

We can then use these points of high-uncertainty as new samples to add to our current training dataset.
Once we identify their feature classes and relabel them correctly, we append them to derive an augmented `samples_round_2`.




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

::: {.cell-output-display}
![](VT0007-deforestation-map_files/figure-html/unnamed-chunk-6-1.png){width=672}
:::
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

::: {.cell-output-display}
![](VT0007-deforestation-map_files/figure-html/unnamed-chunk-7-1.png){width=672}
:::
:::




## Accuracy assessment

To select a validation subset of the map, `sits` recommends Cochran’s method for stratified random sampling [@cochran1977sampling].
The method divides the population into homogeneous subgroups, or strata, and then applying random sampling within each stratum.
Alternatively, ad-hoc parameterization is suggested as follows.




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

::: {.cell-output .cell-output-stdout}

```
                prop       expected_ua std_dev equal alloc_120 alloc_100
Burned_Area     0.01001252 0.75        0.433   408   120       100      
Cleared_Area    0.3680405  0.7         0.458   408   702       717      
Forest          0.2445099  0.75        0.433   408   466       477      
Highly_Degraded 0.04600642 0.7         0.458   408   120       100      
Wetland         0.3314307  0.7         0.458   408   632       646      
                alloc_prop
Burned_Area     20        
Cleared_Area    751       
Forest          499       
Highly_Degraded 94        
Wetland         676       
```


:::
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
```

::: {.cell-output .cell-output-stdout}

```

  |                                                                            
  |                                                                      |   0%
  |                                                                            
  |======================================================================| 100%
Deleting layer `ro_samples' using driver `ESRI Shapefile'
Writing layer `ro_samples' to data source 
  `./samples/ro_samples.shp' using driver `ESRI Shapefile'
Writing 2450 features with 1 fields and geometry type Point.
```


:::

```{.r .cell-code}
sf::st_write(ro_samples_sf,
  "./samples/ro_samples.csv",
  layer_options = "GEOMETRY=AS_XY",
  append = FALSE # TRUE if editing existing sample
)
```

::: {.cell-output .cell-output-stdout}

```
Deleting layer `ro_samples' using driver `CSV'
Writing layer `ro_samples' to data source 
  `./samples/ro_samples.csv' using driver `CSV'
options:        GEOMETRY=AS_XY 
Updating existing layer ro_samples
Writing 2450 features with 1 fields and geometry type Point.
```


:::
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
```

::: {.cell-output .cell-output-stdout}

```
Area Weighted Statistics
Overall Accuracy = 1

Area-Weighted Users and Producers Accuracy
                User Producer
Burned_Area        1        1
Cleared_Area       1        1
Forest             1        1
Highly_Degraded    1        1
Wetland            1        1

Mapped Area x Estimated Area (ha)
                Mapped Area (ha) Error-Adjusted Area (ha) Conf Interval (ha)
Burned_Area               993.51                   993.51                  0
Cleared_Area            36519.48                 36519.48                  0
Forest                  24261.93                 24261.93                  0
Highly_Degraded          4565.07                  4565.07                  0
Wetland                 32886.81                 32886.81                  0
```


:::

```{.r .cell-code}
# Print the confusion matrix
area_acc$error_matrix
```

::: {.cell-output .cell-output-stdout}

```
                 
                  Burned_Area Cleared_Area Forest Highly_Degraded Wetland
  Burned_Area             144            0      0               0       0
  Cleared_Area              0          843      0               0       0
  Forest                    0            0    560               0       0
  Highly_Degraded           0            0      0             144       0
  Wetland                   0            0      0               0     759
```


:::
:::




## Times series visualization




::: {.cell}

```{.r .cell-code}
summary(as.data.frame(ro_samples_sf))
```

::: {.cell-output .cell-output-stdout}

```
    label                    geometry   
 Length:2450        POINT        :2450  
 Class :character   epsg:4326    :   0  
 Mode  :character   +proj=long...:   0  
```


:::
:::




#### Housekeeping




::: {.cell}

```{.r .cell-code}
# convert markdown to script.R 
knitr::purl("VT0007-deforestation-risk-map.qmd")
```

::: {.cell-output .cell-output-error}

```
Error in file(con, "r"): cannot open the connection
```


:::

```{.r .cell-code}
# display environment setup
devtools::session_info()
```

::: {.cell-output .cell-output-stdout}

```
─ Session info ───────────────────────────────────────────────────────────────
 setting  value
 version  R version 4.4.2 (2024-10-31)
 os       macOS Sequoia 15.1.1
 system   aarch64, darwin20
 ui       X11
 language (EN)
 collate  en_US.UTF-8
 ctype    en_US.UTF-8
 tz       America/Vancouver
 date     2024-11-30
 pandoc   3.5 @ /usr/local/bin/ (via rmarkdown)

─ Packages ───────────────────────────────────────────────────────────────────
 package            * version    date (UTC) lib source
 abind              * 1.4-8      2024-09-12 [1] CRAN (R 4.4.1)
 animation          * 2.7        2021-10-07 [1] CRAN (R 4.4.0)
 ape                  5.8        2024-04-11 [1] CRAN (R 4.4.0)
 assertthat           0.2.1      2019-03-21 [1] CRAN (R 4.4.0)
 backports            1.5.0      2024-05-23 [1] CRAN (R 4.4.0)
 base64enc            0.1-3      2015-07-28 [1] CRAN (R 4.4.0)
 BIOMASS            * 2.1.11     2023-09-29 [1] CRAN (R 4.4.0)
 bit                  4.5.0      2024-09-20 [1] CRAN (R 4.4.1)
 bit64                4.5.2      2024-09-22 [1] CRAN (R 4.4.1)
 bitops               1.0-9      2024-10-03 [1] CRAN (R 4.4.1)
 boot                 1.3-31     2024-08-28 [1] CRAN (R 4.4.2)
 brio                 1.1.5      2024-04-24 [1] CRAN (R 4.4.0)
 cachem               1.1.0      2024-05-16 [1] CRAN (R 4.4.0)
 callr                3.7.6      2024-03-25 [1] CRAN (R 4.4.0)
 caret              * 6.0-94     2023-03-21 [1] CRAN (R 4.4.0)
 class                7.3-22     2023-05-03 [1] CRAN (R 4.4.2)
 classInt             0.4-10     2023-09-05 [1] CRAN (R 4.4.0)
 cli                * 3.6.3      2024-06-21 [1] CRAN (R 4.4.0)
 clue                 0.3-66     2024-11-13 [1] CRAN (R 4.4.1)
 cluster              2.1.6      2023-12-01 [1] CRAN (R 4.4.2)
 coda                 0.19-4.1   2024-01-31 [1] CRAN (R 4.4.0)
 codetools            0.2-20     2024-03-31 [1] CRAN (R 4.4.2)
 colorspace           2.1-1      2024-07-26 [1] CRAN (R 4.4.0)
 cols4all           * 0.8        2024-10-16 [1] CRAN (R 4.4.1)
 contfrac             1.1-12     2018-05-17 [1] CRAN (R 4.4.0)
 coro                 1.1.0      2024-11-05 [1] CRAN (R 4.4.1)
 corpcor              1.6.10     2021-09-16 [1] CRAN (R 4.4.0)
 covr               * 3.6.4      2023-11-09 [1] CRAN (R 4.4.0)
 cowplot            * 1.1.3      2024-01-22 [1] CRAN (R 4.4.0)
 crayon               1.5.3      2024-06-20 [1] CRAN (R 4.4.0)
 crosstalk            1.2.1      2023-11-23 [1] CRAN (R 4.4.0)
 cubature             2.1.1      2024-07-14 [1] CRAN (R 4.4.0)
 curl                 6.0.1      2024-11-14 [1] CRAN (R 4.4.1)
 cyclocomp            1.1.1      2023-08-30 [1] CRAN (R 4.4.0)
 data.table           1.16.2     2024-10-10 [1] CRAN (R 4.4.1)
 DBI                  1.2.3      2024-06-02 [1] CRAN (R 4.4.0)
 deldir               2.0-4      2024-02-28 [1] CRAN (R 4.4.0)
 dendextend         * 1.19.0     2024-11-15 [1] CRAN (R 4.4.1)
 desc                 1.4.3      2023-12-10 [1] CRAN (R 4.4.0)
 deSolve              1.40       2023-11-27 [1] CRAN (R 4.4.0)
 devtools             2.4.5      2022-10-11 [1] CRAN (R 4.4.0)
 DiagrammeR         * 1.0.11     2024-02-02 [1] CRAN (R 4.4.0)
 dichromat            2.0-0.1    2022-05-02 [1] CRAN (R 4.4.0)
 digest             * 0.6.37     2024-08-19 [1] CRAN (R 4.4.1)
 distances            0.1.11     2024-07-31 [1] CRAN (R 4.4.0)
 dplyr              * 1.1.4      2023-11-17 [1] CRAN (R 4.4.0)
 dtw                * 1.23-1     2022-09-19 [1] CRAN (R 4.4.0)
 dtwclust           * 6.0.0      2024-07-23 [1] CRAN (R 4.4.0)
 e1071              * 1.7-16     2024-09-16 [1] CRAN (R 4.4.1)
 easypackages         0.1.0      2016-12-05 [1] CRAN (R 4.4.0)
 ellipsis             0.3.2      2021-04-29 [1] CRAN (R 4.4.0)
 elliptic             1.4-0      2019-03-14 [1] CRAN (R 4.4.0)
 evaluate             1.0.1      2024-10-10 [1] CRAN (R 4.4.1)
 exactextractr      * 0.10.0     2023-09-20 [1] CRAN (R 4.4.0)
 extrafont          * 0.19       2023-01-18 [1] CRAN (R 4.4.0)
 extrafontdb          1.0        2012-06-11 [1] CRAN (R 4.4.0)
 fansi                1.0.6      2023-12-08 [1] CRAN (R 4.4.0)
 fastmap              1.2.0      2024-05-15 [1] CRAN (R 4.4.0)
 flexclust            1.4-2      2024-04-27 [1] CRAN (R 4.4.0)
 FNN                * 1.1.4.1    2024-09-22 [1] CRAN (R 4.4.1)
 forcats            * 1.0.0      2023-01-29 [1] CRAN (R 4.4.0)
 foreach              1.5.2      2022-02-02 [1] CRAN (R 4.4.0)
 fs                   1.6.5      2024-10-30 [1] CRAN (R 4.4.1)
 future             * 1.34.0     2024-07-29 [1] CRAN (R 4.4.0)
 future.apply         1.11.3     2024-10-27 [1] CRAN (R 4.4.1)
 FuzzyNumbers         0.4-7      2021-11-15 [1] CRAN (R 4.4.0)
 FuzzyNumbers.Ext.2   3.2        2017-09-05 [1] CRAN (R 4.4.0)
 gdalcubes          * 0.7.0      2024-03-07 [1] CRAN (R 4.4.0)
 gdalUtilities      * 1.2.5      2023-08-10 [1] CRAN (R 4.4.0)
 generics             0.1.3      2022-07-05 [1] CRAN (R 4.4.0)
 geojsonsf          * 2.0.3      2022-05-30 [1] CRAN (R 4.4.0)
 ggplot2            * 3.5.1      2024-04-23 [1] CRAN (R 4.4.0)
 ggrepel              0.9.6      2024-09-07 [1] CRAN (R 4.4.1)
 globals              0.16.3     2024-03-08 [1] CRAN (R 4.4.0)
 glue                 1.8.0      2024-09-30 [1] CRAN (R 4.4.1)
 gmm                  1.8        2023-06-06 [1] CRAN (R 4.4.0)
 gower                1.0.1      2022-12-22 [1] CRAN (R 4.4.0)
 gridExtra            2.3        2017-09-09 [1] CRAN (R 4.4.0)
 gtable               0.3.6      2024-10-25 [1] CRAN (R 4.4.1)
 hardhat              1.4.0      2024-06-02 [1] CRAN (R 4.4.0)
 hdf5r              * 1.3.11     2024-07-07 [1] CRAN (R 4.4.0)
 hexbin               1.28.5     2024-11-13 [1] CRAN (R 4.4.1)
 hms                  1.1.3      2023-03-21 [1] CRAN (R 4.4.0)
 htmltools          * 0.5.8.1    2024-04-04 [1] CRAN (R 4.4.0)
 htmlwidgets          1.6.4      2023-12-06 [1] CRAN (R 4.4.0)
 httpuv               1.6.15     2024-03-26 [1] CRAN (R 4.4.0)
 httr               * 1.4.7      2023-08-15 [1] CRAN (R 4.4.0)
 httr2              * 1.0.7      2024-11-26 [1] CRAN (R 4.4.1)
 hypergeo             1.2-13     2016-04-07 [1] CRAN (R 4.4.0)
 interp               1.1-6      2024-01-26 [1] CRAN (R 4.4.0)
 ipred                0.9-15     2024-07-18 [1] CRAN (R 4.4.0)
 iterators            1.0.14     2022-02-05 [1] CRAN (R 4.4.0)
 jpeg                 0.1-10     2022-11-29 [1] CRAN (R 4.4.0)
 jquerylib            0.1.4      2021-04-26 [1] CRAN (R 4.4.0)
 jsonlite           * 1.8.9      2024-09-20 [1] CRAN (R 4.4.1)
 kableExtra         * 1.4.0      2024-01-24 [1] CRAN (R 4.4.0)
 KernSmooth           2.23-24    2024-05-17 [1] CRAN (R 4.4.2)
 knitr              * 1.49       2024-11-08 [1] CRAN (R 4.4.1)
 kohonen            * 3.0.12     2023-06-09 [1] CRAN (R 4.4.0)
 later                1.4.1      2024-11-27 [1] CRAN (R 4.4.1)
 lattice            * 0.22-6     2024-03-20 [1] CRAN (R 4.4.2)
 latticeExtra         0.6-30     2022-07-04 [1] CRAN (R 4.4.0)
 lava                 1.8.0      2024-03-05 [1] CRAN (R 4.4.0)
 lazyeval             0.2.2      2019-03-15 [1] CRAN (R 4.4.0)
 leafem             * 0.2.3      2023-09-17 [1] CRAN (R 4.4.0)
 leaflet              2.2.2      2024-03-26 [1] CRAN (R 4.4.0)
 leaflet.providers    2.0.0      2023-10-17 [1] CRAN (R 4.4.0)
 leafsync             0.1.0      2019-03-05 [1] CRAN (R 4.4.0)
 libgeos            * 3.11.1-2   2023-11-29 [1] CRAN (R 4.4.0)
 lifecycle            1.0.4      2023-11-07 [1] CRAN (R 4.4.0)
 lintr              * 3.1.2      2024-03-25 [1] CRAN (R 4.4.0)
 listenv              0.9.1      2024-01-29 [1] CRAN (R 4.4.0)
 lubridate          * 1.9.3      2023-09-27 [1] CRAN (R 4.4.0)
 luz                * 0.4.0      2023-04-17 [1] CRAN (R 4.4.0)
 lwgeom               0.2-14     2024-02-21 [1] CRAN (R 4.4.0)
 magrittr             2.0.3      2022-03-30 [1] CRAN (R 4.4.0)
 mapedit            * 0.6.0      2020-02-02 [1] CRAN (R 4.4.0)
 maptiles           * 0.8.0      2024-10-22 [1] CRAN (R 4.4.1)
 mapview            * 2.11.2     2023-10-13 [1] CRAN (R 4.4.0)
 MASS                 7.3-61     2024-06-13 [1] CRAN (R 4.4.2)
 Matrix               1.7-1      2024-10-18 [1] CRAN (R 4.4.2)
 matrixcalc           1.0-6      2022-09-14 [1] CRAN (R 4.4.0)
 MCMCglmm             2.36       2024-05-06 [1] CRAN (R 4.4.0)
 memoise              2.0.1      2021-11-26 [1] CRAN (R 4.4.0)
 mgcv               * 1.9-1      2023-12-21 [1] CRAN (R 4.4.2)
 mime                 0.12       2021-09-28 [1] CRAN (R 4.4.0)
 miniUI               0.1.1.1    2018-05-18 [1] CRAN (R 4.4.0)
 minpack.lm           1.2-4      2023-09-11 [1] CRAN (R 4.4.0)
 ModelMetrics         1.2.2.2    2020-03-17 [1] CRAN (R 4.4.0)
 modeltools           0.2-23     2020-03-05 [1] CRAN (R 4.4.0)
 MomTrunc             6.1        2024-10-28 [1] CRAN (R 4.4.1)
 munsell              0.5.1      2024-04-01 [1] CRAN (R 4.4.0)
 mvtnorm              1.3-2      2024-11-04 [1] CRAN (R 4.4.1)
 ncdf4              * 1.23       2024-08-17 [1] CRAN (R 4.4.0)
 nlme               * 3.1-166    2024-08-14 [1] CRAN (R 4.4.2)
 nnet               * 7.3-19     2023-05-03 [1] CRAN (R 4.4.2)
 openxlsx           * 4.2.7.1    2024-09-20 [1] CRAN (R 4.4.1)
 palette            * 0.0.2      2024-03-15 [1] CRAN (R 4.4.0)
 parallelly           1.39.0     2024-11-07 [1] CRAN (R 4.4.1)
 pillar               1.9.0      2023-03-22 [1] CRAN (R 4.4.0)
 pkgbuild             1.4.5      2024-10-28 [1] CRAN (R 4.4.1)
 pkgconfig            2.0.3      2019-09-22 [1] CRAN (R 4.4.0)
 pkgload              1.4.0      2024-06-28 [1] CRAN (R 4.4.0)
 plyr                 1.8.9      2023-10-02 [1] CRAN (R 4.4.0)
 png                  0.1-8      2022-11-29 [1] CRAN (R 4.4.0)
 prettyunits          1.2.0      2023-09-24 [1] CRAN (R 4.4.0)
 pROC                 1.18.5     2023-11-01 [1] CRAN (R 4.4.0)
 processx             3.8.4      2024-03-16 [1] CRAN (R 4.4.0)
 prodlim              2024.06.25 2024-06-24 [1] CRAN (R 4.4.0)
 profvis              0.4.0      2024-09-20 [1] CRAN (R 4.4.1)
 progress             1.2.3      2023-12-06 [1] CRAN (R 4.4.0)
 promises             1.3.2      2024-11-28 [1] CRAN (R 4.4.1)
 proxy              * 0.4-27     2022-06-09 [1] CRAN (R 4.4.0)
 ps                   1.8.1      2024-10-28 [1] CRAN (R 4.4.1)
 purrr              * 1.0.2      2023-08-10 [1] CRAN (R 4.4.0)
 R.cache              0.16.0     2022-07-21 [1] CRAN (R 4.4.0)
 R.methodsS3          1.8.2      2022-06-13 [1] CRAN (R 4.4.0)
 R.oo                 1.27.0     2024-11-01 [1] CRAN (R 4.4.1)
 R.utils              2.12.3     2023-11-18 [1] CRAN (R 4.4.0)
 R6                   2.5.1      2021-08-19 [1] CRAN (R 4.4.0)
 randomForest       * 4.7-1.2    2024-09-22 [1] CRAN (R 4.4.1)
 rappdirs             0.3.3      2021-01-31 [1] CRAN (R 4.4.0)
 raster             * 3.6-30     2024-10-02 [1] CRAN (R 4.4.1)
 rasterVis          * 0.51.6     2023-11-01 [1] CRAN (R 4.4.0)
 rbibutils            2.3        2024-10-04 [1] CRAN (R 4.4.1)
 RColorBrewer       * 1.1-3      2022-04-03 [1] CRAN (R 4.4.0)
 Rcpp               * 1.0.13-1   2024-11-02 [1] CRAN (R 4.4.1)
 RcppArmadillo      * 14.2.0-1   2024-11-18 [1] CRAN (R 4.4.1)
 RcppCensSpatial    * 0.3.0      2022-06-27 [1] CRAN (R 4.4.0)
 RcppEigen          * 0.3.4.0.2  2024-08-24 [1] CRAN (R 4.4.1)
 RcppParallel       * 5.1.9      2024-08-19 [1] CRAN (R 4.4.1)
 RCurl                1.98-1.16  2024-07-11 [1] CRAN (R 4.4.0)
 Rdpack               2.6.2      2024-11-15 [1] CRAN (R 4.4.1)
 readr              * 2.1.5      2024-01-10 [1] CRAN (R 4.4.0)
 recipes              1.1.0      2024-07-04 [1] CRAN (R 4.4.0)
 relliptical          1.3.0      2024-02-07 [1] CRAN (R 4.4.0)
 remotes              2.5.0      2024-03-17 [1] CRAN (R 4.4.0)
 reshape2             1.4.4      2020-04-09 [1] CRAN (R 4.4.0)
 rex                  1.2.1      2021-11-26 [1] CRAN (R 4.4.0)
 rlang                1.1.4      2024-06-04 [1] CRAN (R 4.4.0)
 rmarkdown            2.29       2024-11-04 [1] CRAN (R 4.4.1)
 rpart                4.1.23     2023-12-05 [1] CRAN (R 4.4.2)
 rsconnect          * 1.3.3      2024-11-19 [1] CRAN (R 4.4.1)
 RSpectra             0.16-2     2024-07-18 [1] CRAN (R 4.4.0)
 rstac                1.0.1      2024-07-18 [1] CRAN (R 4.4.0)
 RStoolbox          * 1.0.0      2024-04-25 [1] CRAN (R 4.4.0)
 rstudioapi           0.17.1     2024-10-22 [1] CRAN (R 4.4.1)
 rts                * 1.1-14     2023-10-01 [1] CRAN (R 4.4.0)
 Rttf2pt1             1.3.12     2023-01-22 [1] CRAN (R 4.4.0)
 Ryacas0              0.4.4      2023-01-12 [1] CRAN (R 4.4.0)
 s2                   1.1.7      2024-07-17 [1] CRAN (R 4.4.0)
 sandwich             3.1-1      2024-09-15 [1] CRAN (R 4.4.1)
 satellite            1.0.5      2024-02-10 [1] CRAN (R 4.4.0)
 scales             * 1.3.0      2023-11-28 [1] CRAN (R 4.4.0)
 sessioninfo          1.2.2      2021-12-06 [1] CRAN (R 4.4.0)
 settings             0.2.7      2021-05-07 [1] CRAN (R 4.4.0)
 sf                 * 1.0-19     2024-11-05 [1] CRAN (R 4.4.1)
 shiny                1.9.1      2024-08-01 [1] CRAN (R 4.4.0)
 shinyjs              2.1.0      2021-12-23 [1] CRAN (R 4.4.0)
 sits               * 1.5.1      2024-08-19 [1] CRAN (R 4.4.1)
 sitsdata           * 1.2        2024-11-30 [1] Github (e-sensing/sitsdata@222dda8)
 slider               0.3.2      2024-10-25 [1] CRAN (R 4.4.1)
 sp                 * 2.1-4      2024-04-30 [1] CRAN (R 4.4.0)
 spacesXYZ            1.3-0      2024-01-23 [1] CRAN (R 4.4.0)
 spData             * 2.3.3      2024-09-02 [1] CRAN (R 4.4.1)
 spdep              * 1.3-7      2024-11-25 [1] CRAN (R 4.4.1)
 stars              * 0.6-7      2024-11-07 [1] CRAN (R 4.4.1)
 StempCens            1.1.0      2020-10-21 [1] CRAN (R 4.4.0)
 stringi              1.8.4      2024-05-06 [1] CRAN (R 4.4.0)
 stringr            * 1.5.1      2023-11-14 [1] CRAN (R 4.4.0)
 styler             * 1.10.3     2024-04-07 [1] CRAN (R 4.4.0)
 supercells         * 1.0.0      2024-02-11 [1] CRAN (R 4.4.0)
 survival             3.7-0      2024-06-05 [1] CRAN (R 4.4.2)
 svglite              2.1.3      2023-12-08 [1] CRAN (R 4.4.0)
 systemfonts          1.1.0      2024-05-15 [1] CRAN (R 4.4.0)
 tensorA              0.36.2.1   2023-12-13 [1] CRAN (R 4.4.0)
 terra              * 1.7-78     2024-05-22 [1] CRAN (R 4.4.0)
 testthat           * 3.2.1.1    2024-04-14 [1] CRAN (R 4.4.0)
 tibble             * 3.2.1      2023-03-20 [1] CRAN (R 4.4.0)
 tidyr              * 1.3.1      2024-01-24 [1] CRAN (R 4.4.0)
 tidyselect           1.2.1      2024-03-11 [1] CRAN (R 4.4.0)
 tidyverse          * 2.0.0      2023-02-22 [1] CRAN (R 4.4.0)
 timechange           0.3.0      2024-01-18 [1] CRAN (R 4.4.0)
 timeDate             4041.110   2024-09-22 [1] CRAN (R 4.4.1)
 tinytex            * 0.54       2024-11-01 [1] CRAN (R 4.4.1)
 tlrmvnmvt            1.1.2      2022-06-09 [1] CRAN (R 4.4.0)
 tmap               * 3.3-4      2023-09-12 [1] CRAN (R 4.4.0)
 tmaptools          * 3.1-1      2021-01-19 [1] CRAN (R 4.4.0)
 tmvtnorm             1.6        2023-12-05 [1] CRAN (R 4.4.0)
 torch                0.13.0     2024-05-21 [1] CRAN (R 4.4.0)
 tzdb                 0.4.0      2023-05-12 [1] CRAN (R 4.4.0)
 units                0.8-5      2023-11-28 [1] CRAN (R 4.4.0)
 urlchecker           1.0.1      2021-11-30 [1] CRAN (R 4.4.0)
 usethis              3.1.0      2024-11-26 [1] CRAN (R 4.4.1)
 utf8                 1.2.4      2023-10-22 [1] CRAN (R 4.4.0)
 vctrs                0.6.5      2023-12-01 [1] CRAN (R 4.4.0)
 viridis              0.6.5      2024-01-29 [1] CRAN (R 4.4.0)
 viridisLite          0.4.2      2023-05-02 [1] CRAN (R 4.4.0)
 visNetwork           2.1.2      2022-09-29 [1] CRAN (R 4.4.0)
 warp                 0.2.1      2023-11-02 [1] CRAN (R 4.4.0)
 withr                3.0.2      2024-10-28 [1] CRAN (R 4.4.1)
 wk                   0.9.4      2024-10-11 [1] CRAN (R 4.4.1)
 xfun                 0.49       2024-10-31 [1] CRAN (R 4.4.1)
 xgboost            * 1.7.8.1    2024-07-24 [1] CRAN (R 4.4.0)
 XML                  3.99-0.17  2024-06-25 [1] CRAN (R 4.4.0)
 xml2                 1.3.6      2023-12-04 [1] CRAN (R 4.4.0)
 xtable               1.8-4      2019-04-21 [1] CRAN (R 4.4.0)
 xts                * 0.14.1     2024-10-15 [1] CRAN (R 4.4.1)
 yaml                 2.3.10     2024-07-26 [1] CRAN (R 4.4.0)
 zeallot              0.1.0      2018-01-28 [1] CRAN (R 4.4.0)
 zip                  2.3.1      2024-01-27 [1] CRAN (R 4.4.0)
 zoo                * 1.8-12     2023-04-13 [1] CRAN (R 4.4.0)

 [1] /Library/Frameworks/R.framework/Versions/4.4-arm64/Resources/library

──────────────────────────────────────────────────────────────────────────────
```


:::
:::
