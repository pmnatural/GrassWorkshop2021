# GrassWorkshop2021
GrassGIS Workshop 2021 - Taller Grass 2021


Aqui esta nuestro proyecto final de trabajo del Taller de Grass 2021 del Instituto Gulich dictado por Verónica Andreo.  This is the repository of our final proyect of the GRASS GIS wrokshop given by Veronica Andreo at Instituto Gulich

Los objetivos de este tutorial son los siguientes:

* Aprender a descargar productos de MODIS directamente desde GRASS
* Controlar la calidad de la serie de tiempo
* Generar series de tiempo donde los datos faltantes por mala calidad han sido reemplazados mediate interpolacion espacia y/o temporal

## Requerimientos para realizar este tutorial
Tener la ultima versión de i.modis instalada ya que si no no puede descargar los productos MOD13A3, que fueron recientemente agregados.
Tener creado un nuevo mapset con el SRC deseado (en este ejemplo posgar_faja5)
...
Estas instrucciones estan escritas y han sido probadas para correr en ... (windows xx, ubuntu xx)

El script completo se encuentra aqui (no subi el script como .sh)

### 1. Crear el nuevo Mapset dentro del Location posgar_faja5
```
g.mapset -c mapset=mod13a3
```
### 2. Download MODIS NDVI data
```
i.modis.download settings=$HOME/gisdata/NASA_SETTING.txt \
  product=ndvi_terra_monthly_1000 \
  tile=h13v12 \
  startday=2019-01-01 endday=2020-12-31 \
  folder=/tmp
```
## 3. Import NDVI , EVI and VI Quality bands
```
i.modis.import files=/tmp/listfileMOD13A3.006.txt \
  spectral="( 1 1 1 0 0 0 0 0 0 0 0 )"
```
## 4. Set region to map extension and resolution
```
g.region -p raster=MOD13A3.A2020001.h13v12.single_1_km_monthly_NDVI
```
## 5. Create the STRDS (time series) for NDVI (EVI) and QA bands and register maps
```
t.create type=strds temporaltype=absolute output=ndvi \
  title="NDVI" \
  description="NDVI Monthly MOD13A3" 
t.register -i input=ndvi  maps=`g.list type=raster pattern="MOD13A3*NDVI*" separator=comma`  start="2019-01-01" increment="1 months" 
t.create type=strds temporaltype=absolute output=evi \
  title="EVI" \
  description="EVI Monthly MOD13A3" 
t.register -i input=evi  maps=`g.list type=raster pattern="MOD13A3*EVI*" separator=comma`  start="2019-01-01" increment="1 months"
t.create output=QA type=strds temporaltype=absolute title="QA 16 days" description="Calidad del pixel"
t.register -i input=QA  maps=`g.list type=raster pattern="MOD13A3*VI_Quality*" separator=comma`  start="2019-01-01" increment="1 months"
```
## 6. Generate a mask for each bitcode flag
```
t.rast.mapcalc inputs=QA output=QA_f1 basename=QA_f1 expression="QA & 0x03" 
t.rast.mapcalc inputs=QA output=QA_f2 basename=QA_f2 expression="QA & 0x3c" 
t.rast.mapcalc inputs=QA output=QA_f3 basename=QA_f3 expression="QA & 0xc0" 
t.rast.mapcalc inputs=QA output=QA_f4 basename=QA_f4 expression="QA & 0x100" 
t.rast.mapcalc inputs=QA output=QA_f5 basename=QA_f5 expression="QA & 0x200" 
t.rast.mapcalc inputs=QA output=QA_f6 basename=QA_f6 expression="QA & 0x400" 
t.rast.mapcalc inputs=QA output=QA_f7 basename=QA_f7 expression="QA & 0x3800" 
t.rast.mapcalc inputs=QA output=QA_f8 basename=QA_f8 expression="QA & 0x4000" 
t.rast.mapcalc inputs=QA output=QA_f9 basename=QA_f9 expression="QA & 0x8000"
```
## 7. Realizo una máscara por cada fecha teniendo en cuenta la información de los flags
```
t.rast.mapcalc inputs=QA_f1,QA_f2,QA_f3,QA_f4,QA_f5,QA_f6,QA_f7,QA_f8,QA_f9 output=QA_mask basename=QA_mask expression="if(QA_f1 == 0 && QA_f2 < 20 && QA_f4 < 192 && QA_f6 == 0 && QA_f8 == 0 && QA_f9 ==  0, 0, 1)"
```
## 8. Enmascaro los pixeles con problemas en la serie de ndvi
```
t.rast.mapcalc inputs=QA_mask,ndvi expression="if(QA_mask==0,ndvi,null())" output=ndvi_masked basename=ndvi_masked
```
## 9. Creo una serie de imágenes teniendo en cuenta la vecindad para el ndvi
```
t.rast.neighbors input=ndvi output=ndvi_nb method=average basename=ndvi_nb size=3
```
## 10. Creo una serie de imágenes suavizada a partir de una media móvil para el ndvi
```
t.rast.algebra expression="ndvi_smooth = 0.5*(ndvi[1]+ndvi[-1])" basename=ndvi_smooth
```
## 11. Creo una serie de imágenes suavizada teniendo en cuenta el contexto espacio-temporal para el ndvi 
```
t.rast.algebra expression="ndvi_smooth_spacetime=0.3*ndvi[1]+0.3*ndvi[-1]+0.10*(ndvi[0,-1]+ndvi[0,1]+ndvi[-1,0]+ndvi[1,0])" basename=ndvi_smooth_spacetime
```
##  12. Reemplazo los pixeles enmascarados de acuerdo a las imágenes de "vecindad"
``` 
t.rast.mapcalc inputs=QA_mask,ndvi,ndvi_nb expression="if(QA_mask==0,ndvi,ndvi_nb)" output=ndvi_filter_nb basename=ndvi_filter_nb
```
## 13.  Reemplazo los pixeles enmascarados de acuerdo al suavizado por media móvil temporal
```
t.rast.mapcalc inputs=QA_mask,ndvi,ndvi_smooth expression="if(QA_mask==0,ndvi,ndvi_smooth)" output=ndvi_filter_smooth basename=ndvi_filter_smooth
```
## 14.  Reemplazo los pixeles enmascarados de acuerdo al contexto espacio-temporal
```
t.rast.mapcalc inputs=QA_mask,ndvi,ndvi_smooth_spacetime expression="if(QA_mask==0,ndvi,ndvi_smooth_spacetime)" output=ndvi_filter_smooth_spacetime basename=ndvi_filter_smooth_spacetime
```

__REPITO LOS MISMOS PROCEDIMIENTOS PARA EL EVI__

Enmascaro los pixeles con problemas en la serie de evi
t.rast.mapcalc inputs=QA_mask,evi expression="if(QA_mask==0,evi,null())" output=evi_masked basename=evi_masked

Creo una serie de imágenes teniendo en cuenta la vecindad para el evi

t.rast.neighbors input=evi output=evi_nb method=average basename=evi_nb size=3

Creo una serie de imágenes suavizada a partir de una media móvil para el evi

t.rast.algebra expression="evi_smooth = 0.5*(evi[1]+evi[-1])" basename=evi_smooth

Creo una serie de imágenes suavizada teniendo en cuenta el contexto espacio-temporal para el evi 

t.rast.algebra expression="evi_smooth_spacetime=0.3*evi[1]+0.3*evi[-1]+0.10*(evi[0,-1]+evi[0,1]+evi[-1,0]+evi[1,0])" basename=evi_smooth_spacetime

Reemplazo los pixeles enmascarados de acuerdo a las imágenes de "vecindad"

t.rast.mapcalc inputs=QA_mask,evi,evi_nb expression="if(QA_mask==0,evi,evi_nb)" output=evi_filter_nb basename=evi_filter_nb
 
Reemplazo los pixeles enmascarados de acuerdo al suavizado por media móvil

t.rast.mapcalc inputs=QA_mask,evi,evi_smooth expression="if(QA_mask==0,evi,evi_smooth)" output=evi_filter_smooth basename=evi_filter_smooth

Reemplazo los pixeles enmascarados de acuerdo al contexto espacio-temporal

t.rast.mapcalc inputs=QA_mask,evi,evi_smooth_spacetime expression="if(QA_mask==0,evi,evi_smooth_spacetime)" output=evi_filter_smooth_spacetime basename=evi_filter_smooth_spacetime




