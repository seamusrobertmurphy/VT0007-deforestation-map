---
title: "VT0007 Jurisdictional Deforestation Risk Maps"
date: 2024-11-04
author: 
  - name: Seamus Murphy
    orcid: 0000-0002-1792-0351 
    email: seamusrobertmurphy@gmail.com
    degrees:
      - PhD
      - MSc
      - MA
      - BA
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
    theme: [minimal, ./R/styles.scss]
highlight-style: github
df-print: kable
keep-md: true
prefer-html: true
output-dir: docs
bibliography: references.bib
---




::: {.cell}
<style type="text/css">
div.column {
    display: inline-block;
    vertical-align: top;
    width: 50%;
}

#TOC::before {
  content: "";
  display: block;
  height:200px;
  width: 200px;
  background-size: contain;
  background-position: 50% 50%;
  padding-top: 80px !important;
  background-repeat: no-repeat;
}
</style>
:::




## Summary

Two workflow approaches are detailed below.
Workflow-1, which is coded using the R ecosystem, allows additional model tuning functions suited to analysis of smaller areas.
Workflow-2 is coded using Python and Google Earth Engine functions that are more suited to larger areas of interest.
For comparison purposes, both workflows derive outputs from the same image collection of STAC-formatted analysis-ready-data of Landsat scenes, following steps outlined in Verra's recommended sequence of deforestation risk map development @verraVT0007UnplannedDeforestation2021 .

![Figure 1: Sequence of deforestation risk map development (VT0007:6)](R/VT0007-risk-map-development-sequence.png)




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
  progress = FALSE
)

# select aoi inside the tile
roi <- c(
  lon_max = -63.25790, lon_min = -63.6078,
  lat_max = -8.72290, lat_min = -8.95630
)

# regularize the aoi filtered cube
s2_reg_cube_ro <- sits_regularize(
  cube = s2_cube_ro,
  output_dir = "./cubes/",
  res = 30,
  roi = roi,
  period = "P16D",
  memsize = 16,
  multicores = 4,
  progress = FALSE
)

# visualize regularized cube
plot(s2_reg_cube_ro,
  red = "B11",
  green = "B8A",
  blue = "B02",
  date = "2020-07-04"
)
```
:::




## Housekeeping




::: {.cell}

```{.r .cell-code}
# convert markdown to script.R 
knitr::purl("VT0007-deforestation-risk-map.qmd")

# display environment setup
devtools::session_info()

# check for syntax errors // lintr::use_lintr(type = "tidyverse")
#lintr::lint("VT0007-deforestation-risk-map.qmd")
```
:::
