rgm_vic_overlay.point <- function(srfDEM,
                                  bedDEM,
                                  soilPoly,
                                  basin,
                                  cellFile,
                                  zref=0,
                                  deltaz=200,
                                  mindepth=1.0,
                                  bffr=0.0,
                                  agg=1.0,
                                  row.fromtop=TRUE,
                                  logging=TRUE)
{
  ###################################################################################################
  #DESCRIPTION: Construct union of RGM pixel raster and VIC model cells based on VIC sub-domain
  # specified by list of VIC cells
  
  #ARGUMENTS:
  # srfDEM -      reference surface DEM as SpatRaster object
  # bedDEM -      reference bed DEM as SpatRaster object
  # soilPoly -    VIC soil cells as SpatVector object
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
  suppressPackageStartupMessages(require("terra"))
  
  #Load and check input arguments/data
  if(logging) print("Reading input data")
  if(!is(srfDEM, 'SpatRaster')) stop("Argument 'srfDEM' must be a SpatRaster object.")
  if(!is(bedDEM, 'SpatRaster')) stop("Argument 'bedDEM' must be a SpatRaster object.")
  if(!is(soilPoly, "SpatVector")) stop("Argument 'soilPoly' must be a SpatVector object.")
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
    cat("... VIC cells SpatVector object: \n")
    print(soilPoly)
    cat("\n")
  }
  
  #Sub-set soil polygon based on basin and cellFile
  if(logging) print("Sub-setting VIC soil polygon.")
  celldf <- read.csv(cellFile, stringsAsFactors = FALSE)
  cells  <- unlist(celldf$CELL_ID[which(celldf$NAME == basin)])
  if(length(cells)==0) stop(paste("No cells in cell map match name ", basin, sep=""))
  soilp <- subset(soilPoly, soilPoly$CELL_ID %in% cells)
  
  #Re-project polygon - set to same CRS as rgm_raster
  if(logging) print("Projecting sub-setted soil polygons.")
  soilpt <- project(soilp, srfDEM)
  
  #Crop domain-wide rgm_rasters to extent of subsetted soil polygon with buffer; conduct QA/QC
  if(logging) print(paste("Cropping RGM raster with ", bffr, "-m buffer and aggregation factor of ", agg, sep=""))
  rsn <- xres(srfDEM)
  if(agg != 1){
    c_rs<- aggregate(crop(srfDEM, buffer(soilpt, 5000), snap="out"), fact=agg, fun=mean)
    c_rb<- aggregate(crop(bedDEM, buffer(soilpt, 5000), snap="out"), fact=agg, fun=mean)
  } else {
    c_rs<- crop(srfDEM, buffer(soilpt, 5000), snap="out")
    c_rb<- crop(bedDEM, buffer(soilpt, 5000), snap="out")
  }
  qrst <- check_elevation_rasters(c_rs, c_rb, mindepth)
  
  #Create glacier mask
  if(logging) print("Generating glacier mask.")
  mask <- make_glacier_mask(qrst$sfc, qrst$bed, mindepth)
  
  #Convert raster to SpatVector object
  if(logging) print("Converting sub-setted RGM raster to SpatVector")
  crs.SPDF <- as.points(qrst$sfc)
  names(crs.SPDF) <- "ELEV"
  crs.SPDF$ID <- 1:length(crs.SPDF)
  
  #Take overlay of RGM pixels and VIC cells over sub-setted domain
  if(logging) print("Taking overlay of RGM and VIC soil polygons.")
  #over_temp <- crs.SPDF %over% soilpt  #TODO
  over_temp <- intersect(crs.SPDF, soilpt)
  overPoints <- merge(crs.SPDF, over_temp, by.x="ID", by.y="ID", all.x = TRUE)
  
  #Add metadata to overlay data frame
  if(logging) print("Building RGM-VIC overlay data frame.")
  pixels <- 1:length(crs.SPDF)
  ncols <- dim(qrst$sfc)[2]
  nrows <- dim(qrst$sfc)[1]
  prows <- ceiling(pixels/ncols)-1  #pixel rows indexed from 0...nrows-1
  pcols <- pixels-prows*ncols-1     #pixel cols indexed from 0...ncols-1
  if(row.fromtop) prows <- (nrows-prows)-1
  bands <- floor((crs.SPDF$ELEV-zref)/deltaz)
  overDF <- cbind(data.frame(PIXEL_ID=pixels, ROW=prows, COL=pcols, BAND=bands), round(crs.SPDF$ELEV, digits=0), overPoints$CELL_ID)
  #Sort overlay data frame into ascending ROWs then ascending COLs
  overDF <- overDF[order(overDF$ROW, overDF$COL),]
  names(overDF)[5:6] <- c("ELEV", "CELL_ID")
  
  return(list(sub_poly=soilpt, sfc_raster=qrst$sfc, bed_raster=qrst$bed, glac_mask=mask, overDF=overDF))
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
  sfc <- values(sfcrst)
  bed <- values(bedrst)
  
  #Create glacier mask
  glc <- sfc - bed
  glc[which(glc <= dth)] <- 0
  glc[which(glc > dth)] <- 1
  
  #Create glacier mask raster
  mask <- rast(ncols=dim(sfcrst)[2], nrows=dim(sfcrst)[1], nlyrs=1,
               ext(sfcrst), crs(sfcrst))
  values(mask) <- glc
  
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
  # sfcrst - surface DEM as SpatRaster object
  # bedrst - bed DEM as SpatRaster object
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
  sfc <- values(sfcrst)
  bed <- values(bedrst)
  
  #Filter for 0 or negative values
  sfc[which(sfc <= 0)] <- 0.1
  bed[which(bed <= 0)] <- 0.1
  
  #Filter for sfc-bed errors and noise
  index <- which((sfc-bed) <= dth) #both checks combined
  sfc[index] <- (sfc[index] + bed[index])/2
  bed[index] <- (sfc[index] + bed[index])/2
  
  #Update elevation surfaces
  values(sfcrst) <- sfc
  values(bedrst) <- bed
  
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

  
  library('terra')
  
  con <- file(description=outFile, open="w")
  rst <- flip(x)
  write(sprintf("DSAA"), con)
  write(sprintf("%d  %d", dim(rst)[2], dim(rst)[1]), con)
  write(sprintf("%f  %f", ext(rst)[1] + res(rst)[1]/2, ext(rst)[2] - res(rst)[1]/2), con)
  write(sprintf("%f  %f", ext(rst)[3] + res(rst)[2]/2, ext(rst)[4] - res(rst)[2]/2), con)
  write(sprintf("%f  %f", min(values(rst), na.rm = TRUE), max(values(rst), na.rm = TRUE)), con)
  for(r in 1:dim(rst)[1]) write(sprintf("%.1f", values(rst, mat=FALSE, row=r, nrows=1, col=1)), file=con, ncolumns=dim(rst)[2], sep=" ")
  close(con)
  
  return()
  
}
