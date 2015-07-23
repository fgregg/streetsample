include config.mk

SAMPLE_SIZE = 30

all : sample.shp

sample.shp : street_pop.table
	pgsql2shp -f $@ -h $(PG_HOST) -u $(PG_USER) -P $(PG_USER) $(PG_DB) \
	"`{ echo \"SELECT * FROM transportation WHERE gid IN\"; \
	  psql -d streets -c \"COPY (SELECT * FROM street_pop \
                                    INNER JOIN \
                                    (SELECT row, col \
                                     FROM (SELECT * FROM blocks, grid \
                                           WHERE ST_INTERSECTS(grid.geom, blocks.geom)) AS t \
                                     INNER JOIN population \
                                     ON right(geoid10, 10) = LPAD(\\"CENSUS BLOCK\\", 10, '0') \
                                     GROUP BY row, col \
                                     HAVING SUM(\\"TOTAL POPULATION\\"::INT) > 2000 \
                                     ORDER BY RANDOM() LIMIT 20) AS filtered \
                                    USING (row, col)) TO STDOUT WITH CSV HEADER\" |\
          python3 weighted_sample.py $(SAMPLE_SIZE); } | tr '\n' ' '`"

.INTERMEDIATE : street_pop.table 
street_pop.table : blocks.table population.table transportation.table 
	psql -d $(PG_DB) -c \
	"CREATE TABLE street_pop \
         AS (SELECT cell_transportation.gid, \
                    row, col, \
                    COALESCE(SUM(ST_LENGTH(ST_INTERSECTION(cell_transportation.geom, \
                                                           blocks.geom)) \
                                 * \"TOTAL POPULATION\"::FLOAT) \
                             / SUM(ST_LENGTH(ST_INTERSECTION(cell_transportation.geom, blocks.geom))), \
                             0) AS pop \
             FROM (SELECT transportation.*, row, col \
                   FROM transportation, grid \
		   WHERE ST_INTERSECTS(grid.geom, transportation.geom)) as cell_transportation \
             INNER JOIN blocks \
             ON ST_INTERSECTS(cell_transportation.geom, blocks.geom) \
             LEFT JOIN population \
             ON right(geoid10, 10) = LPAD(\"CENSUS BLOCK\", 10, '0') \
             WHERE cell_transportation.class = '4' \
             GROUP BY cell_transportation.gid, row, col)"
	touch $@

grid.table :
	psql -d $(PG_DB) -c "CREATE TABLE grid AS SELECT * FROM ST_CREATEFISHNET(18, 15, 7920, 7920, 1091138, 1813891)"
	psql -d $(PG_DB) -c "select UpdateGeometrySRID('grid', 'geom', 3435)"

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
	cat fishnet.sql | psql -d $(PG_DB)

clean_shapefiles :
	rm blocks.* transportation.*
