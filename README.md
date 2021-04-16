# hydroConductorParameters
Generate the necessary parameter files to run glacier dynamics using the fully coupled VICGL-RGM model, which is wrapped in the HydroConductor application. These scripts produce the following paraemter files for the specified domain:
  + bed digitial elevation model
  + surface digital elevation model
  + glacier mask
  + pixel mapping file

Parameter files are produced by running the either the wrapper script wrapper_rgm.vic.overlay.point.r from the command line, which has the following options:

	-r RDATA, --rdata=RDATA
		Source data as *.RData file. which must contain a SDEM RasterLayer object, a BDEM RasterLayer object and a PLYGN SpatialDataFrameObject [required]

	-s SDEM, --sdem=SDEM
		Surface DEM RasterLayer object in RDATA [required]

	-b BDEM, --bdem=BDEM
		Bed DEM RasterLayer object in RDATA [required]

	-p PLYGN, --plygn=PLYGN
		VIC computational grid as SpatialPolygonDataFrame object in RDATA [required]

	-w BASIN, --basin=BASIN
		Sub-basin short name [required]

	-c CELLF, --cellf=CELLF
		Name of text file mapping cell IDs to basin name [required]

	-z ZREF, --zref=ZREF
		Reference elevation (i.e. bottom elevation of lowest band) [default is 0]

	-d DELTAZ, --deltaz=DELTAZ
		Band relief (i.e. zband2-zband1) [default is 200]

	-m MINDEP, --mindep=MINDEP
		Threshold depth (m) for glacier presence [default is 2.0]

	-y REFYEAR, --refyear=REFYEAR
		Reference year of surface DEM and glacier mask [default is NULL]

	-x BUFFER, --buffer=BUFFER
		Buffer (in metres) to increase extent of rasters beyond soil polygon extent [default is 0]

	-a AGGREG, --aggreg=AGGREG
		DEM aggregation factor [default is 1.0]

	-t, --fromtop
		Count rows from top of map to bottom (i.e. ymax to ymin) [default is TRUE]

	-o OUTDIR, --outdir=OUTDIR
		Output directory [default is ./]

	-M, --nomap
		Do not write pixel map to file

	-S, --nosurf
		Do not write surface DEM to file

	-B, --nobed
		Do not write bed DEM to file

	-G, --nomask
		Do not write glacier mask to file

	-v, --verbose
		Print progress messages

	-h, --help
		Show this help message and exit

or by using the function call_rgm.vic.overlay.point from an R environment, which has the following usage

call_rgm.vic.overlay.point(sdem, bdem, plygn, basin, cellf, zref=0, deltaz=200, mindep=2.0, refyear-NULL,
                                         buffer=0.0, aggreg=1.0, fromtop=TRUE, outdir="./", nomap=FALSE, nosurf=FALSE,
                                         nobed=FALSE, nomask=FALSE, verbose=FALSE)

with arguments:

    sdem    Surface DEM RasterLayer object

    bdem    Bed DEM RasterLayer object

    plygn   VIC computational grid as SpatialPolygonDataFrame object

    basin   Sub-basin short name

    cellf   Name of CSV file mapping cell IDs to basin name

    zref    Reference elevation (i.e. bottom elevation of lowest band)

    delta   Band relief (i.e. zband2-zband1)

    mindep  Threshold depth (m) for glacier presence

    refyear Reference year of surface DEM and glacier mask

    buffer  Buffer (in metres) to increase extent of rasters beyond soil polygon extent

    aggreg  DEM aggregation factor

    fromtop Count rows from top of map to bottom (i.e. ymax to ymin)

    outdir  Output directory

    nomap   Do not write pixel map to file

    nosurf  Do not write surface DEM to file

    nobed   Do not write bed DEM to file

    nomask  Do not write glacier mask to file

    verbose Print progress messages


The supplied bed DEM (BDEM) and surface DEM (SDEM) are cropped to the study domain, the spatial extent of which is defined by extracting the relevant computational cells from PLYGN based on the mapping given in CELLF. A buffer (BUFFER; given in metres) can be included to extend the surface DEM, bed DEM, and glacier mask beyond the limits of the VICGL model domain. The glacier mask is calculated as the difference between SDEM and BDEM. The defualt is to write the bed DEM, surface DEM and glacier mask as GSA raster files to OUTDIR.

A pixel mapping file is generated based on the overlap of the surface/bed DEMs and the VICGL computational grid. The default is to write the pixel map as a text file to OUTDIR.

Note that BDEM and SDEM must have the same native resolution and structure (i.e. projection) and must completely overlap the desired VICGL study domain. All output rasters will have the same resolution and structure as SDEM and BDEM.
