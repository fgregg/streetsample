# streetsample
This Makefile builds a shapefile that samples from a cells from Chicago and then selects 30 streets segments randomly, weighed by population

# Requirements
- PostGIS
- Python3
- csvkit

# To build
Change the database settings in `config.mk.example` and save the modified file as `config.mk`.

```bash
> make createdb
> make 
```

To change the size of the sample use the command line argument `SAMPLE_SIZE`. The default is 30
```bash
> make SAMPLE_SIZE=40
```

# To cleanup shapefiles
```bash
> make cleanup_shapefiles
```
