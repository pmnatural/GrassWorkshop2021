
# 1. Create a new Mapset under Location posgar_faja5

g.mapset -c mapset=mod13q1

# 2. Download MODIS data

i.modis.download settings=$HOME/gisdata/NASA_SETTING.txt \
  product=ndvi_terra_sixteen_250 \
  tile=h13v12 \
  startday=2020-01-01 endday=2020-12-31 \
  folder=/tmp

# Import NDVI, EVI and VI Quality bands

i.modis.import files=/tmp/listfileMOD13Q1.006.txt \
  spectral="( 1 1 1 0 0 0 0 0 0 0 0 0 )"

# Set region to map extension and resolution

g.region -p raster=MOD13Q1.A2020001.h13v12.single_250m_16_days_NDVI

# Create the STRDS (time series) for NDVI, EVI and QA and register their lists of images
# Create the STRDS for NDVI and register

t.create type=strds temporaltype=absolute output=ndvi \
  title="NDVI" \
  description="NDVI 16 days MOD13Q1" 
t.register -i input=ndvi  maps=`g.list type=raster pattern="MOD13Q1*NDVI*" separator=comma`  start="2020-01-01" increment="16 days" 

# Create the STRDS for EVI and register

t.create type=strds temporaltype=absolute output=evi \
  title="EVI" \
  description="EVI 16 days MOD13Q1" 
t.register -i input=evi  maps=`g.list type=raster pattern="MOD13Q1*EVI*" separator=comma`  start="2020-01-01" increment="16 days"

# Create the STRDS for pixel QA and register

t.create output=QA type=strds temporaltype=absolute title="QA 16 days" description="Calidad del pixel"
t.register -i input=QA  maps=`g.list type=raster pattern="MOD13Q1*VI_Quality*" separator=comma`  start="2020-01-01" increment="16 days"

# Generate a mask for each bitcode flag

t.rast.mapcalc inputs=QA output=QA_f1 basename=QA_f1 expression="QA & 0x03" 
t.rast.mapcalc inputs=QA output=QA_f2 basename=QA_f2 expression="QA & 0x3c" 
t.rast.mapcalc inputs=QA output=QA_f3 basename=QA_f3 expression="QA & 0xc0" 
t.rast.mapcalc inputs=QA output=QA_f4 basename=QA_f4 expression="QA & 0x100" 
t.rast.mapcalc inputs=QA output=QA_f5 basename=QA_f5 expression="QA & 0x200" 
t.rast.mapcalc inputs=QA output=QA_f6 basename=QA_f6 expression="QA & 0x400" 
t.rast.mapcalc inputs=QA output=QA_f7 basename=QA_f7 expression="QA & 0x3800" 
t.rast.mapcalc inputs=QA output=QA_f8 basename=QA_f8 expression="QA & 0x4000" 
t.rast.mapcalc inputs=QA output=QA_f9 basename=QA_f9 expression="QA & 0x8000"

# Create a mask for each date using flags' information
t.rast.mapcalc inputs=QA_f1,QA_f2,QA_f3,QA_f4,QA_f5,QA_f6,QA_f7,QA_f8,QA_f9 output=QA_mask basename=QA_mask expression="if(QA_f1 == 0 && QA_f2 < 20 && QA_f4 < 192 && QA_f6 == 0 && QA_f8 == 0 && QA_f9 ==  0, 0, 1)"

# Mask low quality pixels in ndvi serie
t.rast.mapcalc inputs=QA_mask,ndvi expression="if(QA_mask==0,ndvi,null())" output=ndvi_masked basename=ndvi_masked

# Create a ndvi time series using spatial interpolation (by neighborhood analysis)
#Vecindad
t.rast.neighbors input=ndvi output=ndvi_nb method=average basename=ndvi_nb size=3

# Create a series of smoothed images from a moving average for the ndvi
#Temporal
t.rast.algebra expression="ndvi_smooth = 0.5*(ndvi[1]+ndvi[-1])" basename=ndvi_smooth

# Create a series of images smoothed taking into account the spatio-temporal context for the ndvi
#Espacio-temporal
t.rast.algebra expression="ndvi_smooth_spacetime=0.3*ndvi[1]+0.3*ndvi[-1]+0.10*(ndvi[0,-1]+ndvi[0,1]+ndvi[-1,0]+ndvi[1,0])" basename=ndvi_smooth_spacetime

# Replace the masked pixels according to the "neighborhood" images
# Por vecindad
t.rast.mapcalc inputs=QA_mask,ndvi,ndvi_nb expression="if(QA_mask==0,ndvi,ndvi_nb)" output=ndvi_filter_nb basename=ndvi_filter_nb

# Replace pixels masked according to temporal moving average smoothing
# Por temporal
t.rast.mapcalc inputs=QA_mask,ndvi,ndvi_smooth expression="if(QA_mask==0,ndvi,ndvi_smooth)" output=ndvi_filter_smooth basename=ndvi_filter_smooth

# Replace the masked pixels according to the space-time context
# Por espacio-temporal
t.rast.mapcalc inputs=QA_mask,ndvi,ndvi_smooth_spacetime expression="if(QA_mask==0,ndvi,ndvi_smooth_spacetime)" output=ndvi_filter_smooth_spacetime basename=ndvi_filter_smooth_spacetime

###REPEAT STEPS FOR EVI TIME SERIES###


