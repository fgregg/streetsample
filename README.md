# streetsample
This Makefile builds a shapefile that is population weighted random sample of Chicago street segments.

# Requirements
- PostGIS
- Python3
- csvkit

# To build
Change the database settings in `config.mk.example` and save the modified file as `config.mk`.

> make createdb
> make 

To change the size of the sample use the command line argument `SAMPLE_SIZE`. The default is 1000
> make SAMPLE_SIZE=3000

# To cleanup shapefiles
> make cleanup_shapefiles
