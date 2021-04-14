#!/usr/bin/env Rscript

#####################################################################################################
#USAGE: Rcsript [options] wrapper_rgm.vic.overlay.point.r [ARGUMENTS]

#DESCRIPTION: Build and write all necessary input files for the Regional Glaciation Model

#ARGUMENTS:
# -r, --rdata -    RData file containing objects 'sdem', 'bdem' and 'plygn'
# -s, --sdem -     RasterLayer object representing surface DEM (found in rdata)
# -b, --bdem -     RasterLayer object representing bed DEM (found in rdata)
# -p, --plygn -    VIC cells SpatialPolygonDataFrame object (found in rdata)
# -w, --basin -    sub basin short name identifier
# -c, --cellf -    filename of VIC grid cell IDs; must contain CELL_ID and NAME fields
# -z, --zref -     reference elevation (i.e. bottom elevation of lowest band) [default is 0]
# -d, --deltaz -   band relief (i.e. zband2-zband1) [defaut is 200]
# -m, --mindep -   depth threshold for glacier occurrence [default is 2.0]
# -y, --refyear -  reference year for surface dem and glacier mask [default is NULL]
# -x  --buffer -   Buffer width (in metres) to add to output raster files
# -a  --aggreg -   Aggregate original DEM by factor given
# -t, --fromtop -  count rows from top of map to bottom (i.e. ymax to ymin) [default]
# -o, --outdir -   output directory [default is ./]
# -M, --nomap -    do not write pixel map to file
# -S, --nosurf -   do not write surface DEM to file
# -B, --nobed -    do not write bed DEM to file
# -G, --nomask -   do not write glacier mask to file
# -v, --verbose -  write progress messages to standard output
# -h, --help -     print help message

#DETAILS: Wrapper script processes and writes several files to the working directory. These files include:
# 1) a mapping of RGM pixels to VIC grid cells
# 2) a surface topography DEM in GSA format
# 3) a bed topography DEM in GSA format
# 4) a glacier mask raster in GSA format
#
# Script uses tryCatch() to print 'result', which will either be TRUE (if successful), or an error/
# warning (if not successful). A side effect of the script is to write various text files.
#####################################################################################################

#Parse arguments
library('optparse')
option_list <- list(
  make_option(c("-r", "--rdata"),   action="store", type="character", help="Source data as *.RData file [required]"),
  make_option(c("-s", "--sdem"),    action="store", type="character", help="Surface DEM RasterLayer object in rdata [required]"),
  make_option(c("-b", "--bdem"),    action="store", type="character", help="Bed DEM RasterLayer object in rdata [required]"),
  make_option(c("-p", "--plygn"),   action="store", type="character", help="VIC polygons SpatialPolygonDataFrame object rdaat [required]"),
  make_option(c("-w", "--basin"),   action="store", type="character", help="Sub-basin short name [required]"),
  make_option(c("-c", "--cellf"),   action="store", type="character", help="Name of text file mapping cell IDs to basin name; must contain CELL_ID and NAME fields [required]"),
  make_option(c("-z", "--zref"),    action="store", type="double", default=0.0,   help="Reference elevation (i.e. bottom elevation of lowest band) [default is 0]"),
  make_option(c("-d", "--deltaz"),  action="store", type="double", default=200.0, help="Band relief (i.e. zband2-zband1) [default is 200]"),
  make_option(c("-m", "--mindep"),  action="store", type="double", default=2.0,   help="Threshold depth (m) for glacier presence [default is 2.0]"),
  make_option(c("-y", "--refyear"), action="store", type="double", default=NULL,  help="Reference year of surface DEM and glacier mask [default is NULL]"),
  make_option(c("-x", "--buffer"),  action="store", type="double", default=0.0,   help="Buffer (in metres) to increase extent of rasters beyond soil polygon extent [default is 0]"),
  make_option(c("-a", "--aggreg"),  action="store", type="double", default=1.0,   help="DEM aggregation factor [default is 1.0]"),
  make_option(c("-t", "--fromtop"), action="store_true", default=TRUE, help="Count rows from top of map to bottom (i.e. ymax to ymin) [default is TRUE]"),
  make_option(c("-o", "--outdir"),  action="store", type="character", default=".", help="Output directory [default is ./]"),
  make_option(c("-M", "--nomap"),   action="store_true", default=FALSE, help="Do not write pixel map to file"),
  make_option(c("-S", "--nosurf"),  action="store_true", default=FALSE, help="Do not write surface DEM to file"),
  make_option(c("-B", "--nobed"),   action="store_true", default=FALSE, help="Do not write bed DEM to file"),
  make_option(c("-G", "--nomask"),  action="store_true", default=FALSE, help="Do not write glacier mask to file"),
  make_option(c("-v", "--verbose"), action="store_true", default=FALSE, help="Print progress messages")
)
opt <- parse_args(OptionParser(option_list=option_list))
if(is.null(opt$rdata)) stop("Missing argument for 'rdata'. Use -h or --help flag for usage.")
if(is.null(opt$sdem))  stop("Missing argument for 'sdem'. Use -h or --help flag for usage.")
if(is.null(opt$bdem))  stop("Missing argument for 'bdem'. Use -h or --help flag for usage.")
if(is.null(opt$plygn)) stop("Missing argument for 'plygn'. Use -h or --help flag for usage.")
if(is.null(opt$basin)) stop("Missing argument for 'basin'. Use -h or --help flag for usage.")
if(is.null(opt$cellf)) stop("Missing argument for 'cellf'. Use -h or --help flag for usage.")
refyr <- NULL
if(!is.null(opt$refyear)) refyr <- paste(opt$refyear, "_", sep="")

#Load source and input files; initialize output files
load(opt$rdata)
src_dir <- dirname(scriptName::current_filename())
source(file.path(src_dir, "mapSrc.r"))
outMap_file   <- paste(opt$outdir, "/pixel_map_", opt$basin, ".txt", sep="")
srfDEM_file   <- paste(opt$outdir, "/srf_dem_", refyr, opt$basin, ".gsa", sep="")
bedDEM_file   <- paste(opt$outdir, "/bed_dem_", opt$basin, ".gsa", sep="")
glacMask_file <- paste(opt$outdir, "/glac_mask_", refyr, opt$basin, ".gsa", sep="")
e <- environment()

#Construct RGM-VIC mapping
result <- tryCatch({
  rslt <- rgm_vic_overlay.point(e[[opt$sdem]], e[[opt$bdem]], e[[opt$plygn]], opt$basin, opt$cellf,
                                zref=opt$zref, deltaz=opt$deltaz, mindepth=opt$mindep, bffr=opt$buffer,
                                agg=opt$aggreg, row.fromtop=opt$fromtop, logging=opt$verbose)
  
  #Write pixel mapping to text file
  if(!opt$nomap){
    if(opt$verbose) print("Writing pixel map to file")
    con1 <- file(description=outMap_file, open="w")
    write(sprintf("NCOLS  %d", rslt$sfc_raster@ncols), con1)
    write(sprintf("NROWS  %d", rslt$sfc_raster@nrows), con1)
    write.table(rslt$overDF, file=con1, sep=" ", row.names=FALSE)
    close(con1) }
  #Write surface elevation as GSA grid
  if(!opt$nosurf){
    if(opt$verbose) print("Writing surface DEM to file")
    write_GSA_grid(rslt$sfc_raster, srfDEM_file)}
  #Write bed elevation as GSA grid
  if(!opt$nobed){
    if(opt$verbose) print("Writing bed DEM to file")
    write_GSA_grid(rslt$bed_raster, bedDEM_file) }
  #Write glacier mask as GSA grid
  if(!opt$nomask){
    if(opt$verbose) print("Writing glacier mask to file")
    write_GSA_grid(rslt$glac_mask, glacMask_file) }
  
  rslt <- TRUE
  
}, warning = function(war){
  return(paste("rgm_vic_overlay_WARNING: ", war))
}, error = function(err){
  return(paste("rgm_vic_overlay_ERROR: ", err))
}, finally = {
  #do nothing
}) #End tryCatch

#Print 'result' - potentially used by calling script to test for succesful completion.
cat(result, "\n")
