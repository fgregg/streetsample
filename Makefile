include config.mk

SAMPLE_SIZE = 1000

all : sample.shp

sample.shp : street_pop.table
	pgsql2shp -f $@ -h $(PG_HOST) -u $(PG_USER) -P $(PG_USER) $(PG_DB) \
	"`{ echo 'SELECT * FROM transportation WHERE gid IN'; \
	  psql -d streets -c 'COPY street_pop to STDOUT WITH CSV HEADER' |\
          python3 weighted_sample.py $(SAMPLE_SIZE); } | tr '\n' ' '`"

.INTERMEDIATE : street_pop.table 
street_pop.table : blocks.table population.table transportation.table 
	psql -d $(PG_DB) -c \
	"CREATE TABLE street_pop \
         AS (SELECT transportation.gid, \
                    COALESCE(SUM(ST_LENGTH(ST_INTERSECTION(transportation.geom, \
                                                           blocks.geom)) \
                                 * \"TOTAL POPULATION\"::FLOAT) \
                             / SUM(ST_LENGTH(ST_INTERSECTION(transportation.geom, blocks.geom))), \
                             0) AS pop \
             FROM transportation INNER JOIN blocks \
             ON ST_INTERSECTS(transportation.geom, blocks.geom) \
             LEFT JOIN population \
             ON right(geoid10, 10) = LPAD(\"CENSUS BLOCK\", 10, '0') \
             WHERE transportation.class = '4' \
             GROUP BY transportation.gid)"
	touch $@

.INTERMEDIATE : blocks.table transportation.table 
%.table : %.shp
	shp2pgsql -I -s 3435 -d $< $* | psql -d $(PG_DB)
	touch $@

.INTERMEDIATE : transportation.shp
transportation.shp : transportation.zip
	unzip $<
	rename 's/$(basename $<)/$(basename $@)/' *.*

.INTERMEDIATE : blocks.shp
blocks.shp : blocks.zip
	unzip $<
	rename 's/CensusBlockTIGER2010/$(basename $@)/' *.*

.INTERMEDIATE : blocks.zip
blocks.zip :
	wget -O $@ "https://data.cityofchicago.org/api/geospatial/mfzt-js4n?method=export&format=Original"

.INTERMEDIATE : transportation.zip
transportation.zip :
	wget -O $@ "https://data.cityofchicago.org/api/geospatial/6imu-meau?method=export&format=Original"

.INTERMEDIATE : population.table
%.table : %.csv
	csvsql --db "postgresql://$(PG_USER):$(PG_PASS)@$(PG_HOST):$(PG_PORT)/$(PG_DB)" \
        -y 1000 --no-inference --tables $* --insert $<
	touch $@

.INTERMEDIATE : population.csv
population.csv :
	wget -O $@ "https://data.cityofchicago.org/api/views/5yjb-v3mj/rows.csv?accessType=DOWNLOAD"

createdb :
	createdb $(PG_DB)
	psql -d $(PG_DB) -c "CREATE EXTENSION postgis"


clean_shapefiles :
	rm blocks.* transportation.*
