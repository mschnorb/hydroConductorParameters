call_rgm.vic.overlay.point <- function(sdem,            #SpatRaster object representing surface DEM
                                       bdem,            #SpatRaster object representing bed DEM
                                       plygn,           #VIC cells SpatialVector object
                                       basin,           #sub basin short name identifier
                                       cellf,           #filename of VIC grid cell IDs; must contain CELL_ID and NAME fields
                                       zref = 0,        #reference elevation (i.e. bottom elevation of lowest band) [default is 0]
                                       deltaz = 200,    #band relief (i.e. zband2-zband1) [defaut is 200]
                                       mindep = 2.0,    #depth threshold for glacier occurrence [default is 2.0]
                                       refyear = NULL,  #reference year for surface dem and glacier mask [default is NULL]
                                       buffer = 0.0,    #Buffer width (in metres) to add to output raster files
                                       aggreg = 1.0,    #Aggregate original DEM by factor given
                                       fromtop = TRUE,  #count rows from top of map to bottom (i.e. ymax to ymin) [default]
                                       outdir = "./",   #output directory [default is ./]
                                       nomap = FALSE,   #do not write pixel map to file
                                       nosurf = FALSE,  #do not write surface DEM to file
                                       nobed = FALSE,   #do not write bed DEM to file
                                       nomask = FALSE,  #do not write glacier mask to file
                                       verbose = FALSE) #write progress messages to standard output

{
  ###################################################################################################
  #DESCRIPTION: Function to overlay VICGL grid and RGM pixels and crop RGM DEMs to extent of soil file.
  
  #VALUE: TRUE or an error/warning message
  # Function side effect is write the following input files for the Regional Glaciation Model:
  # 1) a mapping of RGM pixels to VIC grid cells
  # 2) a surface topography DEM in GSA format
  # 3) a bed topography DEM in GSA format
  # 4) a glacier mask raster in GSA format
  ###################################################################################################
  
  if(is.null(sdem))  stop("Missing argument for 'sdem'")
  if(is.null(bdem))  stop("Missing argument for 'bdem'")
  if(is.null(plygn)) stop("Missing argument for 'plygn'")
  if(is.null(basin)) stop("Missing argument for 'basin'")
  if(is.null(cellf)) stop("Missing argument for 'cellf'")
  refyr <- NULL
  if(!is.null(refyear)) refyr <- paste(refyear, "_", sep="")
  
  #Load source and input files; initialize output files
  source("mapSrc.r")
  outMap_file   <- file.path(outdir, paste("pixel_map_", basin, ".txt", sep=""))
  srfDEM_file   <- file.path(outdir, paste("srf_dem_", refyr, basin, ".gsa", sep=""))
  bedDEM_file   <- file.path(outdir, paste("bed_dem_", basin, ".gsa", sep=""))
  glacMask_file <- file.path(outdir, paste("glac_mask_", refyr, basin, ".gsa", sep=""))
  
  #Construct RGM-VIC mapping
  result <- tryCatch({
    rslt <- rgm_vic_overlay.point(sdem, bdem, plygn, basin, cellf,
                                  zref=zref, deltaz=deltaz, mindepth=mindep, bffr=buffer,
                                  agg=aggreg, row.fromtop=fromtop, logging=verbose)
    
    #Write pixel mapping to text file
    if(!nomap){
      if(verbose) print("Writing pixel map to file")
      con1 <- file(description=outMap_file, open="w")
      write(sprintf("NCOLS  %d", dim(rslt$sfc_raster)[2]), con1)
      write(sprintf("NROWS  %d", dim(rslt$sfc_raster)[1]), con1)
      write.table(rslt$overDF, file=con1, sep=" ", row.names=FALSE, quote = FALSE)
      close(con1) }
    #Write surface elevation as GSA grid
    if(!nosurf){
      if(verbose) print("Writing surface DEM to file")
      write_GSA_grid(rslt$sfc_raster, srfDEM_file)}
    #Write bed elevation as GSA grid
    if(!nobed){
      if(verbose) print("Writing bed DEM to file")
      write_GSA_grid(rslt$bed_raster, bedDEM_file) }
    #Write glacier mask as GSA grid
    if(!nomask){
      if(verbose) print("Writing glacier mask to file")
      write_GSA_grid(rslt$glac_mask, glacMask_file) }
    
    rslt <- TRUE
    
  }, warning = function(war){
    return(paste("rgm_vic_overlay_WARNING: ", war))
  }, error = function(err){
    return(paste("rgm_vic_overlay_ERROR: ", err))
  }, finally = {
    #do nothing
  }) #End tryCatch
  
  return(result)
}
