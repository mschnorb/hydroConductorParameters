#!/bin/bash -u

module load R

WORKDIR=/storage/data/projects/hydrology/vic_gen2/input/rgm
domain=fraser
LOGFILE=$WORKDIR/"${domain}_$(date +%F\ %H:%M:%S)".log
echo -n >| "${LOGFILE}"

## Loop through sub-basins
basins='NECHC STUAR QUESL QUESQ BIGCR CHILK CLEAO SEYMO EAGLE ADAMS FRSHP HARRI FRSMT'
for basin in $basins; do

  echo $(date +%F\ %H:%M:%S): Processing basin $basin

  RSLT=$(Rscript $WORKDIR/code/R-git/wrapper_rgm.vic.overlay.point.r \
    -r $WORKDIR/input/bed.surf45.soil_poly.RData \
    -s surf45 \
    -b bed \
    -p soil_poly \
    -w $basin \
    -c $WORKDIR/input/fraser_v3_cell_map.csv \
    -y 1945 \
    -x 5000 \
    -o $WORKDIR/output/$domain \
    --verbose)
  echo $RSLT
  
  if [ "$RSLT" = 'TRUE' ]; then
    echo "$(date +%F\ %H:%M:%S): ${basin} completed" >> "${LOGFILE}"
  else
    echo "$(date +%F\ %H:%M:%S): Error in ${basin}" >> "${LOGFILE}" ; continue
  fi

done

echo "$(date +%F\ %H:%M:%S): Processing of domain ${domain} complete" >> "${LOGFILE}"
