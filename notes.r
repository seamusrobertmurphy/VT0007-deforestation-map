# RGEEEEEEEEEEE
EE_geom <- ee$Geometry$Point(c(-70.06240, -6.52077))$buffer(5000)

l8img <- ee$ImageCollection$Dataset$LANDSAT_LC08_C02_T2_L2 %>% 
  ee$ImageCollection$filterDate('2021-06-01', '2021-12-01') %>% 
  ee$ImageCollection$filterBounds(EE_geom) %>% 
  ee$ImageCollection$first()

gcs_l8_name  <- "l8demo2" 

task <- ee_image_to_gcs(
  image = l8img$select(sprintf("SR_B%s",1:5)),
  region = EE_geom,
  fileNamePrefix = gcs_l8_name,
  timePrefix = FALSE,
  bucket = "deforisk_bucket_1",
  scale = 10,
  formatOptions = list(cloudOptimized = TRUE) #COG formatting
)
task$start()
ee_monitoring()


# Make PUBLIC the GCS object 
googleCloudStorageR::gcs_update_object_acl(
  object_name = paste0(gcs_l8_name, ".tif"),
  bucket = "deforisk_bucket_1",
  entity_type = "allUsers"
)

img_id <- sprintf("https://storage.googleapis.com/%s/%s.tif", "deforisk_bucket_1", gcs_l8_name)
visParams <- list(bands=c("SR_B4","SR_B3","SR_B2"), min = 8000, max = 20000, nodata = 0)
Map$centerObject(img_id)

first = Map$addLayer(
      eeObject = img_id, 
      visParams = visParams,
      name = "My_first_COG",
      titiler_server = "https://api.cogeo.xyz/"
 )

first |> leaflet::addProviderTiles("Esri.WorldImagery") 
















cloud_mask = function(image){
  qa = image$select('QA_PIXEL')
  saturation_mask    = image$select('QA_RADSAT') == 0
  cloudShadowBitMask = bitwShiftL(1,3)
  cloudsBitMask      = bitwShiftL(1,5)
  waterBitMask       = bitwShiftL(1,2)
    image$updateMask(mask)}

    
# reduce neighborhood for faster runtime
reduceFunction = function(image) {
  image$reduceNeighborhood(
    reducer = ee$Reducer$mean(),
    kernel  = ee$Kernel$square(4)
  )
}

collection = ee$ImageCollection('LANDSAT/LC08/C02/T1_L2')
bands      = list("SR_B4", "SR_B3", "SR_B2")

cube_raw   = collection$select(bands)$
  filterBounds(aoi_target_ee)$
  filterDate("2018-01-01", "2018-02-01")$
  aside(ee_print)$ # Useful for debugging.
  map(reduceFunction)$
  reduce('mean')$
  rename(bands)

viz <- list(bands = bands, min = 0, max = 10000)
Map$addLayer(cube_raw, viz, "cube_raw")




#| eval: false
cloud_mask <- function(image){
  cloudShadowBitMask <- bitwShiftL(1,3)
  cloudsBitMask <- bitwShiftL(1,5)
  waterBitMask <- bitwShiftL(1,2)
  qa <- image$select('QA_PIXEL')
    mask <- qa$bitwise_and(cloudShadowBitMask)$eq(0)$
    And(qa$bitwise_and(cloudsBitMask)$eq(0))$
    And(qa$bitwise_and(waterBitMask)$eq(0))
    image$updateMask(mask)}

vizParams <- list(bands = list("SR_B4", "SR_B3", "SR_B2"), max = 0.4)







qa <- image$select('QA_PIXEL')



getQABits <- function(image, qa) { # pixel quality subfilter   
  qa <- sum(2^(which(rev(unlist(strsplit(as.character(qa), "")) == 1))-1))
  image$bitwiseAnd(qa)$lt(1)
}
l8_clean <- function(image) {
  ndvi_values <- image$normalizedDifference(c("SR_B5","SR_B4"))
  ndvi_qa <- image$select("QA_PIXEL")
  quality_mask <- getQABits(ndvi_qa, "00000100001")
  ndvi_values %>%
    ee$Image$updateMask(quality_mask) %>%
    ee$Image$copyProperties(img, list("system:time_start"))
}

















# Define a function that scales and masks Landsat 8 surface reflectance images.
def prep_sr_l8(image):
  qa_mask = image$select('QA_PIXEL')$bitwiseAnd(0b11111)$eq(0)
  saturation_mask = image$select('QA_RADSAT')$eq(0)

  # Apply the scaling factors to the appropriate bands.
  def _get_factor_img(factor_names):
    factor_list = image.toDictionary().select(factor_names).values()
    return ee.Image.constant(factor_list)

  scale_img = _get_factor_img([
      'REFLECTANCE_MULT_BAND_.|TEMPERATURE_MULT_BAND_ST_B10'])
  offset_img = _get_factor_img([
      'REFLECTANCE_ADD_BAND_.|TEMPERATURE_ADD_BAND_ST_B10'])
  scaled = image.select('SR_B.|ST_B10').multiply(scale_img).add(offset_img)

  # Replace original bands with scaled bands and apply masks.
  return image.addBands(scaled, None, True).updateMask(
      qa_mask).updateMask(saturation_mask)


# Make a cloud-free Landsat 8 surface reflectance composite.
l8_image = (
    ee.ImageCollection('LANDSAT/LC08/C02/T1_L2')
    .filterDate('2021-03-01', '2021-07-01')
    .map(prep_sr_l8)
    .median())

# Use these bands for prediction.
bands = ['SR_B2', 'SR_B3', 'SR_B4', 'SR_B5', 'SR_B6', 'SR_B7', 'ST_B10']

# Load training points. The numeric property 'class' stores known labels.
points = ee.FeatureCollection('GOOGLE/EE/DEMOS/demo_landcover_labels')

# This property stores the land cover labels as consecutive
# integers starting from zero.
label = 'landcover'

# Overlay the points on the imagery to get training.
training = l8_image.select(bands).sampleRegions(
    collection=points, properties=[label], scale=30
)

# Train a CART classifier with default parameters.
trained = ee.Classifier.smileCart().train(training, label, bands)

# Classify the image with the same bands used for training.
classified = l8_image.select(bands).classify(trained)

# Display the inputs and the results.
m = geemap.Map()
m.set_center(-122.0877, 37.7880, 11)
m.add_layer(
    l8_image,
    {'bands': ['SR_B4', 'SR_B3', 'SR_B2'], 'min': 0, 'max': 0.25},
    'image',
)
m.add_layer(
    classified,
    {'min': 0, 'max': 2, 'palette': ['orange', 'green', 'blue']},
    'classification',
)
m