# hydroConductorParameters
Generate the necessary parameter files to run glacier dynamics using the fully coupled VICGL-RGM model, which is wrapped in the HydroConductor application. These scripts produce the following paraemter files for the specified domain:
  + bed digitial elevation model
  + surface digital elevation model
  + glacier mask
  + pixel mapping file

Parameter files are produced by running the wrapper script wrapper_rgm.vic.overlay.point.r, which has the following options:

	-r RDATA, --rdata=RDATA
		Source data as *.RData file. which mist contain a SDEM RasterLayer object, a BDEM RasterLayer object and a PLYGN SpatialDataFrameObject [required]

	-s SDEM, --sdem=SDEM
		Surface DEM RasterLayer object in RDATA [required]

	-b BDEM, --bdem=BDEM
		Bed DEM RasterLayer object in RDTA[required]

	-p PLYGN, --plygn=PLYGN
		VIC polygons SpatialPolygonDataFrame object in RDATA [required]

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
