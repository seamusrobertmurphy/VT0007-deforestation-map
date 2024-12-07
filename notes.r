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
