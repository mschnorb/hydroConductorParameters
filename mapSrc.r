rgm_vic_overlay.point <- function(srfDEM,
                                  bedDEM,
                                  soilPoly,
                                  basin,
                                  cellFile,
                                  zref=0,
                                  deltaz=200,
                                  mindepth=2.0,
                                  bffr=0.0,
                                  agg=1.0,
                                  row.fromtop=TRUE,
                                  logging=TRUE)
{
  ###################################################################################################
  #DESCRIPTION: Construct union of RGM pixel raster and VIC model cells based on VIC sub-domain
  # specified by list of VIC cells
  
  #ARGUMENTS:
  # srfDEM -      reference surface DEM as RasterLayer object
  # bedDEM -      reference bed DEM as RasterLayer object
  # soilPoly -    VIC soil cells as SpatialPolygonDataFrame object
  # basin -       sub-basin short name
  # cellFile -    file mapping VIC cell IDs to sub-basins (csv)
  # zref -        reference elevation (i.e. bottom elevation of lowest band); default is 0
  # deltaz -      band relief (i.e. zband2-zband1); default is 200
  # mindepth -    depth threshold for glacier occurrence; default is 1.0
  # row.fromtop - count rows from top of DEM file to bottom (i.e. ymin to ymax); default is TRUE
  # logging -     write progress messages to standard output, default is TRUE
  
  #VALUE: Function outputs a list containing the following:
  # sub_poly -   SpatialPolygonsDataFrame object representing sub-setted VIC soil polygons
  # sfc_raster - RasterLayer object representing sub-setted RGM surface DEM
  # bed_raster - RasterLayer object representing sub-setted RGM bed DEM
  # glac_mask -  RasterLayer object representing glacier mask (1 = TRUE; 0 = FALSE)
  # overDF -     Data frame representing overlay of RGM pixels and VIC cells
  ###################################################################################################
  
  #Load required packages
  suppressPackageStartupMessages(require("sp"))
  suppressPackageStartupMessages(require("raster"))
  suppressPackageStartupMessages(require("rgeos"))
  suppressPackageStartupMessages(require("rgdal"))
  
  #Load and check input arguments/data
  if(logging) print("Reading input data")
  if(!is(srfDEM, 'RasterLayer')) stop("Argument 'srfDEM' must be a RasterLayer object.")
  if(!is(bedDEM, 'RasterLayer')) stop("Argument 'bedDEM' must be a RasterLayer object.")
  if(!is(soilPoly, "SpatialPolygonsDataFrame")) stop("Argument 'soilPoly' must be a SpatialPolygonsDataFrame object.")
  if(!file.exists(cellFile)) stop(paste("File ", cellFile, " does not exist."))
  
  #Log input details
  if(logging) {
    cat("\n")
    cat("... surface DEM raster object: \n")
    print(srfDEM)
    cat("\n")
    cat("... bed DEM raster object: \n")
    print(bedDEM)
    cat("\n")
    cat("... VIC cells SpatialPolygonDataFrame object: \n")
    print(soilPoly)
    cat("\n")
  }
  
  #Sub-set soil polygon based on basin and cellFile
  if(logging) print("Sub-setting VIC soil polygon.")
  celldf <- read.csv(cellFile, stringsAsFactors = FALSE)
  cells  <- unlist(celldf$CELL_ID[which(celldf$NAME == basin)])
  if(length(cells)==0) stop(paste("No cells in cell map match name ", basin, sep=""))
  soilp <-select_soil_polygons(soilPoly, cells)
  
  #Re-project polygon - set to same CRS as rgm_raster
  if(logging) print("Projecting sub-setted soil polygons.")
  soilpt <- spTransform(soilp, srfDEM@crs)
  
  #Crop domain-wide rgm_rasters to extent of subsetted soil polygon with buffer; conduct QA/QC
  if(logging) print(paste("Cropping RGM raster with ", bffr, "-m buffer and aggregation factor of ", agg, sep=""))
  rsn <- xres(srfDEM)
  if(agg != 1){
    c_rs<- aggregate(crop(srfDEM, extend(extent(soilpt),bffr/rsn), snap="out"), fact=agg, fun=mean, expand=TRUE)
    c_rb<- aggregate(crop(bedDEM, extend(extent(soilpt),bffr/rsn), snap="out"), fact=agg, fun=mean, expand=TRUE)
  } else {
    c_rs<- crop(srfDEM, extend(extent(soilpt),bffr/rsn), snap="out")
    c_rb<- crop(bedDEM, extend(extent(soilpt),bffr/rsn), snap="out")
  }
  qrst <- check_elevation_rasters(c_rs, c_rb, mindepth)
  
  #Create glacier mask
  if(logging) print("Generating glacier mask.")
  mask <- make_glacier_mask(qrst$sfc, qrst$bed, mindepth)
  
  #Convert raster to SpatialPoints* object
  if(logging) print("Converting sub-setted RGM raster to SpatialPointsDataFrame.")
  crs.SPDF <- as(qrst$sfc, 'SpatialPointsDataFrame')
  names(crs.SPDF@data) <- "ELEV"
  
  #Take overlay of RGM pixels and VIC cells over sub-setted domain
  if(logging) print("Taking overlay of RGM and VIC soil polygons.")
  over_temp <- crs.SPDF %over% soilpt
  
  #Add metadata to overlay data frame
  if(logging) print("Building RGM-VIC overlay data frame.")
  pixels <- 1:length(crs.SPDF)
  ncols <- qrst$sfc@ncols
  nrows <- qrst$sfc@nrows
  prows <- ceiling(pixels/ncols)-1  #pixel rows indexed from 0...nrows-1
  pcols <- pixels-prows*ncols-1     #pixel cols indexed from 0...ncols-1
  if(row.fromtop) prows <- (nrows-prows)-1
  bands <- floor((crs.SPDF@data$ELEV-zref)/deltaz)
  overDF <- cbind(data.frame(PIXEL_ID=pixels, ROW=prows, COL=pcols, BAND=bands), round(crs.SPDF@data, digits=0), over_temp[1])
  #Sort overlay data frame into ascending ROWs then ascending COLs
  overDF <- overDF[order(overDF$ROW, overDF$COL),]
  
  return(list(sub_poly=pt, sfc_raster=qrst$sfc, bed_raster=qrst$bed, glac_mask=mask, overDF=overDF))
}


select_soil_polygons <- function(soil_poly,
                                 cell_list)
{
  #########################################################################
  #DESCRIPTION: Select sub-set of VIC soil file polygon
  
  #ARGUMENTS:
  # soil_poly - VIC soil cell polygon
  # cell_list - grid cell IDs to subset on
  #########################################################################
  
  index <- match(cell_list, soil_poly@data$CELL_ID)
  if(any(is.na(index))) stop("Some (or all) cells in cell_list not contained in soil_poly. Check the cell IDs.") 
  
  soil_poly@data$SELECT <- 0
  soil_poly@data$SELECT[index] <- 1
  
  poly_select <- soil_poly[soil_poly@data$SELECT==1,]
  
  return(poly_select)
}


make_glacier_mask <- function(sfcrst,
                              bedrst,
                              dth)
{
  ################################################################################
  #DESCRIPTION: Calculate a glacier mask given surface and bed topography
  
  #ARGUMENTS:
  # sfcrst - surface DEM as Raster object
  # bedrst - bed DEM as Raster object
  # dth -    depth threshold for glacier occurrence
  
  #VALUE: A Raster object representing a glacier mask (0 = no glacier; 1 = glacier)
  #################################################################################
  
  #Get raster values
  sfc <- getValues(sfcrst)
  bed <- getValues(bedrst)
  
  #Create glacier mask
  glc <- sfc - bed
  glc[which(glc <= dth)] <- 0
  glc[which(glc > dth)] <- 1
  
  #Create glacier mask raster
  mask <- raster(ncol=sfcrst@ncols, nrow=sfcrst@nrows,
                 xmn=sfcrst@extent@xmin, xmx=sfcrst@extent@xmax,
                 ymn=sfcrst@extent@ymin, ymx=sfcrst@extent@ymax)
  projection(mask) <- sfcrst@crs
  mask <- setValues(mask, glc)
  
  return(mask)
}


check_elevation_rasters <- function(sfcrst,
                                    bedrst,
                                    dth)
{
  ##################################################################################
  #DESCRIPTION: Perform basic quality control/assurance on DEM rasters to ensure
  # some consistency between bed and surface digital elevation models (which may
  # derive from different data sources and methodology)
  
  #ARGUMENTS:
  # sfcrst - surface DEM as Raster object
  # bedrst - bed DEM as Raster object
  # dth -    depth threshold for glacier occurrence
  
  #DETAILS: Functions performs three checks: 1) Bed and/or surface elevations
  # contain zero or negative values (causes error in RGM), 2) if bed elevation
  # exceeds the surface elevation, and 3) if the difference between bed and
  # surface elevations is less than some defined threshold (i.e. should be
  # considered noise). Where the first condition is true, set the elevation to
  # a value of 0.1, when either condition 2 or 3 is true, the resulting bed and
  # surface elevations are set equal to the average of the respective elevation
  # values.
  
  #VALUE: List containing two Raster objects representing the 'corrected' surface
  # and bed DEMs
  #################################################################################

  #Get raster values
  sfc <- getValues(sfcrst)
  bed <- getValues(bedrst)
  
  #Filter for 0 or negative values
  sfc[which(sfc <= 0)] <- 0.1
  bed[which(bed <= 0)] <- 0.1
  
  #Filter for sfc-bed errors and noise
  index <- which((sfc-bed) <= dth) #both checks combined
  sfc[index] <- (sfc[index] + bed[index])/2
  bed[index] <- (sfc[index] + bed[index])/2
  
  #Update elevation surfaces
  sfcrst <- setValues(sfcrst, sfc)
  bedrst <- setValues(bedrst, bed)
  
  return(list(sfc=sfcrst, bed=bedrst))
}


write_GSA_grid <- function(x,
                           outFile)
{
  ##################################################################################
  #DESCRIPTION: Write a RasterLayer object in ASCII Surfer Grid format
  
  #ARGUMENTS:
  # x -       RasterLayer object
  # outFile - filename of GSA grid
  
  #DETAILS: n/a

  #VALUE: Function returns NULL. Side-effect is to write GSA-formatted text file
  #################################################################################

  
  library('raster')
  
  con <- file(description=outFile, open="w")
  rst <- flip(x, 2)
  write(sprintf("DSAA"), con)
  write(sprintf("%d  %d", rst@ncols, rst@nrows), con)
  write(sprintf("%f  %f", rst@extent@xmin + res(rst)[1]/2, rst@extent@xmax - res(rst)[1]/2), con)
  write(sprintf("%f  %f", rst@extent@ymin + res(rst)[2]/2, rst@extent@ymax - res(rst)[2]/2), con)
  write(sprintf("%f  %f", rst@data@min, rst@data@max), con)
  #for(r in 1:rst@nrows) write(getValues(rst, r, 1), file=con, ncolumns=rst@ncols, sep=" ")
  for(r in 1:rst@nrows) write(sprintf("%.1f", getValues(rst, r, 1)), file=con, ncolumns=rst@ncols, sep=" ")
  close(con)
  
  return()
  
}


load_surfer_grid <- function(inFile)
{

  ################################################################################
  #DESCRIPTION: Load ascii surfer grid and convert to Raster object
  
  #ARGUMENT(S):
  # inFile - name of surfer grid
  
  #VALUE: Raster object
  
  #DETAILS: Empty raster object built using meta-data in surfer grid header.
  # Note that extent given in surfer file header measured from grid cell centres,
  # whereas extent expected by raster is from edges - hence must add res/2 to
  # surfer values of xmn, xmx, ymn and ymx. The direction of the northing axis
  # in the surfer grid format is opposite (i.e.upside-down) compared to that for
  # a Raster object, hence the need to 'flip' about the easting axis
  ################################################################################
  
  require("raster")
  
  #Read file
  con <- file(description=inFile, open="r")
  hdr <- scan(file=con, what=numeric(), nmax=9, na.strings = "DSAA", quiet=TRUE)
  vals <- scan(file=con, what=numeric(), quiet=TRUE) #numeric() or numeric?
  close(con)
  
  hdr <- hdr[which(!is.na(hdr))]
  resx <- (hdr[4]-hdr[3])/(hdr[1]-1)
  resy <- (hdr[6]-hdr[5])/(hdr[2]-1)
  x <- raster(ncols=hdr[1], nrows=hdr[2],
              xmn=hdr[3]-resx/2, xmx=hdr[4]+resx/2, ymn=hdr[5]-resy/2, ymx=hdr[6]+resy/2)
  x <- setValues(x, vals)
  
  return(flip(x,2))
}
