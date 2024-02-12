------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
----------------------------------------------BLUESPACES----------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--River
ALTER TABLE bgs.wales_mm_abp_bluespace
    ADD COLUMN e_objectid integer;

ALTER TABLE bgs.wales_mm_abp_bluespace
    ADD COLUMN river_name character(254);

ALTER TABLE bgs.wales_mm_abp_bluespace
    ADD COLUMN f_objectid integer;

ALTER TABLE bgs.wales_mm_abp_bluespace
    ADD COLUMN river_status character(254);

---- (06/02/24: Add 2 new columns cause missing from code but needed immediately after this. Called column geom_blue due to ambiguity)

ALTER TABLE bgs.wales_mm_abp_bluespace
	ADD COLUMN geom_blue geometry;
	
ALTER TABLE bgs.wales_mm_abp_bluespace
	ADD COLUMN tier_3 character(20);

-----(06/02/2024: removed dst in code cause not found in layers and not sure what it is. st_intersects is a function that hasn't been explained so removing from code).
-----(06/02/2024: completely removed WHERE st_intersects line.)

--UPDATE bgs.wales_mm_abp_bluespace dst
--    SET e_objectid = objectid, river_name = wcrs_name, tier_3 = 'river'
--FROM lle.main_rivers src
--WHERE st_intersects(src.geom, dst.geom);

------ (06/02/2024: new code I made from OG (above). Have to use INSERT INTO cause wales_mm_abp_bluespace is an empty TABLE.)
INSERT INTO bgs.wales_mm_abp_bluespace (e_objectid, river_name, geom_blue, tier_3)
    SELECT objectid, wcrs_name, geom, 'river' AS tier_3
FROM lle.main_rivers src;


--UPDATE bgs.wales_mm_abp_bluespace dst
--    SET f_objectid = "OBJECTID", river_name = "WB_NAME", tier_3 = 'river', river_status = "OverallStatus"
--FROM lle.river_waterbodies src
--WHERE st_intersects(src.geom, dst.geom);

---- (06/02/2024: new code from OG (above). No column called WB_NAME so changed to name.)
INSERT INTO bgs.wales_mm_abp_bluespace (f_objectid, river_name, geom_blue, river_status, tier_3)
    SELECT OBJECTID, name, geom, overallsta, 'river' AS tier_3
FROM lle.river_waterbodies src;

----- (07/02/2024: theme and descriptivegroup only found in topo datasets. So replacing wales_mm_abp_bluespace with topographicarea. )
----- (07/02/2024: because when creating wales_mm_abp_bluespace with LLE data, there is no field to join with topographicarea. )
----- (07/02/2024: So wales_mm_abp_bluespace can't be created from both LLE and topo cause I don't know what field to link it with.)


--TEST
--SELECT * FROM bgs.wales_mm_abp_bluespace dst
--WHERE tier_3 = 'river' AND
--      "theme" IN ( '{Land,Structures,Water}' , '{Land,Water}' , '{Roads Tracks And Paths,Water}' ,
--                   '{Structures,Water}' , '{Water}') AND descriptivegroup = '{Inland Water}';

--Create a final table
--CREATE VIEW bgs.rivers AS SELECT * FROM bgs.wales_mm_abp_bluespace
--WHERE tier_3 = 'river' AND
--      "theme" IN ( '{Land,Structures,Water}' , '{Land,Water}' , '{Roads Tracks And Paths,Water}' ,
--                  '{Structures,Water}' , '{Water}') AND descriptivegroup = '{Inland Water}';


---(07/02/2024: created bgs.rivers with topo instead of wales_mm_sbp_bluespace)

CREATE VIEW bgs.rivers AS SELECT *, 'rivers' AS tier_3
FROM osmm_topo.topographicarea
WHERE "theme" IN ( 'Land,Structures,Water' , 'Land,Water' , 'Roads Tracks And Paths,Water' ,
                   'Structures,Water' , 'Water') AND descriptivegroup = 'Inland Water';


--Canal
ALTER TABLE bgs.wales_mm_abp_bluespace
    ADD COLUMN g_objectid integer;

ALTER TABLE bgs.wales_mm_abp_bluespace
    ADD COLUMN canal_name character(254);

--spatially index lle.canals
CREATE INDEX sidx_canals ON lle.canals USING GIST (geom);
VACUUM ANALYZE lle.canals;
CLUSTER  lle.canals using sidx_canals;


--UPDATE bgs.wales_mm_abp_bluespace dst
--    SET e_objectid = objectid, canal_name = wb_name, tier_3 = 'canal'
--FROM lle.canals src
--WHERE st_intersects(src.geom, dst.geom);

--- (07/02/2024: add canals tier_3. Only 9 canals in lle.canals.)

INSERT INTO bgs.wales_mm_abp_bluespace (e_objectid, canal_name, geom_blue, tier_3)
    SELECT objectid, wb_name, geom, 'canal' AS tier_3
FROM lle.canals src;


--TEST
--SELECT * FROM bgs.wales_mm_abp_bluespace dst
--WHERE tier_3 = 'canal' AND
--      "theme" IN ( '{Land,Structures,Water}' , '{Land,Water}' , '{Roads Tracks And Paths,Water}' ,
--                   '{Structures,Water}' , '{Water}');

--CREATE VIEW bgs.canal AS SELECT * from bgs.wales_mm_abp_bluespac WHERE tier_3 = 'canal' AND
--      "theme" IN ( '{Land,Structures,Water}' , '{Land,Water}' , '{Roads Tracks And Paths,Water}' ,
--                   '{Structures,Water}' , '{Water}');

--- (07/02/2024: swapped wales_mm_abp_bluespace with topo because wales_mm_abp_bluespace has joining issue with topo layer so can't join.)
--- (07/02/2024: topo layer has theme field.)

CREATE VIEW bgs.canal AS SELECT *, 'canal' AS tier_3
FROM osmm_topo.topographicarea
WHERE "theme" IN ( 'Land,Structures,Water' , 'Land,Water' , 'Roads Tracks And Paths,Water' ,
                   'Structures,Water' , 'Water');


--ALTER TABLE bgs.wales_mm_abp_bluespace ALTER COLUMN versiondate

--- (07/02/2024: wales_mm_abp_bluespace does not have colum versiondate. That is only found in topo layer which has not been joining in wales_mm_abp_bluespace )
--- (07/02/2024: this is cause not clear what the joining field is for wales_mm_abp_bluespace (created from lle) and topo layer)

---- (07/02/2024: Entered this new code to create greenspace_no_private_gardens)

CREATE TABLE os.greenspace_no_private_gardens AS SELECT * 
FROM bgs."os_greenspace_mm_wales_2018_Apr"
WHERE prifunc NOT IN ('Private Garden');

ALTER TABLE os.greenspace_no_private_gardens
RENAME COLUMN "id_GS_2018_Apr" TO id_no_private_gardens;

--ALTER TABLE os.greenspace_no_private_gardens
--	ADD COLUMN id_no_private_gardens integer;

--UPDATE os.greenspace_no_private_gardens 
--	SET id_no_private_gardens = "id_GS_2018_Apr"
--FROM bgs."os_greenspace_mm_wales_2018_Apr";


--- (07/02/2024: there is no greenspace_site_id column, so choose id column cause toid column is only specific to OS datasets).
--- (07/02/2024: then change column id cause ambigious to id_GS_2018_Apr)
--- (07/02/2024: Have to change id column in greenspace_no_private_gardens to id_no_private_gardens cause id too ambiguos)
--- (12/02/2024: Altered name of column in newly created os.greenspace_no_private_gardens to id_no_private_gardens)


--Transport corridors
CREATE TABLE bgs.amenity_transport AS SELECT * FROM os.greenspace_no_private_gardens
WHERE prifunc = 'Amenity - Transport' AND secfunc IS NULL;

ALTER TABLE bgs.amenity_transport ADD COLUMN tier_3 character(20);
UPDATE bgs.amenity_transport SET tier_3 = 'amenity_transport'
--Add in versiondate, changedate and reason for change cols from MM
ALTER TABLE bgs.amenity_transport ADD COLUMN versiondate varchar;
UPDATE bgs.amenity_transport SET versiondate = topographicarea.versiondate FROM osmm_topo.topographicarea WHERE amenity_transport.toid = topographicarea.fid
ALTER TABLE bgs.amenity_transport ADD COLUMN changedate character varying[];
UPDATE bgs.amenity_transport SET changedate = topographicarea.changedate FROM osmm_topo.topographicarea WHERE amenity_transport.toid = topographicarea.fid
ALTER TABLE bgs.amenity_transport ADD COLUMN reasonforchange character varying[];
UPDATE bgs.amenity_transport SET reasonforchange = topographicarea.reasonforchange FROM osmm_topo.topographicarea WHERE amenity_transport.toid = topographicarea.fid

--Cliffs
CREATE TABLE bgs.mm_cliffs AS
SELECT * FROM osmm_topo.topographicarea WHERE descriptiveterm = '{Cliff}';

CREATE INDEX cliff_indx ON bgs.mm_cliffs USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.mm_cliffs;
CLUSTER cliff_indx ON bgs.mm_cliffs;
VACUUM ANALYZE bgs.mm_cliffs;

UPDATE bgs.wales_mm_abp_bluespace as a
  SET tier_3 = 'cliff'
    FROM bgs.mm_cliffs
        WHERE st_intersects(geom,wkb_geometry);

CREATE VIEW bgs.cliff AS SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.wales_mm_abp_bluespace WHERE tier_3 = 'cliff'
--Beach
UPDATE bgs.wales_mm_abp_bluespace
SET tier_3 = 'beach'
WHERE descriptiveterm IN ('{Sand}',  '{Boulders,Sand}'  ,'{Boulders,Foreshore,Sand}', '{Boulders,Foreshore,Shingle}' ,
    '{Boulders,Foreshore}', '{Foreshore}' , '{Foreshore,Mud}' , '{Foreshore,Mud,Rock}' , '{Foreshore,Mud,Sand}' ,
    '{Foreshore,Mud,Sand,Shingle}' , '{Foreshore,Mud,Shingle}' , '{Foreshore,Rock}' , '{Foreshore,Rock (Scattered)}' ,
    '{Foreshore,Rock (Scattered)}','{Foreshore,Rock,Sand}', '{Foreshore,Sand}', '{Foreshore,Sand,Shingle}' ,
    '{Foreshore,Shingle}' , '{Foreshore,Slipway}' , '{Foreshore,Sloping Masonry}' , '{Foreshore,Step}', '{Mud,Sand}' ,
    '{Sand,Shingle}' , '{Shingle}');

CREATE VIEW bgs.beach AS SELECT * FROM bgs.wales_mm_abp_bluespace Where tier_3 = 'beach';


--Marina
--See harbour

--Docklands
--See harbour

--Estuary
UPDATE bgs.wales_mm_abp_bluespace dst
    SET tier_3 = 'estuary'
FROM bgs.os_open_rivers src
WHERE form = 'tidalRiver' AND st_intersects(src.geom, dst.geom);

CREATE VIEW bgs.estuary AS SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.wales_mm_abp_bluespace WHERE tier_3 = 'estuary'

--Harbour
CREATE TABLE bgs.harbour AS SELECT * FROM osmm_topo.cartographictext WHERE
    textstring LIKE '%harbour%' OR textstring LIKE '%Harbour%' OR textstring LIKE '%Dock%' OR textstring LIKE '%Marina%';

--Delete cold harbours from the view that have been incorrectly included
DELETE FROM bgs.harbour
WHERE textstring LIKE '%harbour%' AND textstring LIKE '%Cold%'
OR textstring LIKE '%Harbour%' AND textstring LIKE '%Cold%'
OR textstring LIKE '%Pad%' AND textstring LIKE '%pad%';

--Manually check harbour. Remove these inland locations that have been incorrectly labelled as harbours
DELETE FROM bgs.harbour WHERE ogc_fid IN (385822, 377515, 900774, 867475, 862566, 900722, 886267, 627184, 604462);

--Select from topo mm layer the descriptivegroup = inland water OR tidal water polygons within 300m from point?
--Spatial index harbour table
CREATE INDEX sidx_harbour ON bgs.harbour USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.harbour;
CLUSTER sidx_harbour ON bgs.harbour;

--Select polygons from mm topographic layer that contain point allotments from cartographic text
CREATE TABLE bgs.harbour_polygon_with_pt AS SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.style_code, c.style_description, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, b.style_code, b.style_description, ST_DWithin(a.wkb_geometry, b.wkb_geometry,300) as within
FROM bgs.harbour as a, osmm_topo.topographicarea as b) as c
WHERE within = 'TRUE' AND c.descriptivegroup = '{Inland Water}'
OR within = 'TRUE' AND c.descriptivegroup = '{Tidal Water}';

ALTER TABLE bgs.harbour_polygon_with_pt ADD COLUMN tier_3 character(20);
UPDATE bgs.harbour_polygon_with_pt SET tier_3 = 'harbour/dock/marina'

CREATE VIEW bgs.harbour_dock_marina AS SELECT wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.harbour_polygon_with_pt

--Lake
CREATE TABLE bgs.lake_a AS SELECT * FROM osmm_topo.cartographictext
WHERE textstring LIKE '%Lake%'  AND make = 'Natural';

CREATE TABLE bgs.lake_polygons AS SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.style_code, c.style_description, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, b.style_code, b.style_description, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.lake_a as a, osmm_topo.topographicarea as b) as c
WHERE within = 'TRUE' AND descriptivegroup = '{Inland Water}';

ALTER TABLE bgs.lake_polygons ALTER COLUMN wkb_geometry type geometry(MultiPolygon, 27700) using ST_Multi(wkb_geometry);

CREATE TABLE bgs.all_lakes AS SELECT wkb_geometry as geom FROM bgs.lake_polygons UNION SELECT geom FROM lle.lakes;

ALTER TABLE bgs.all_lakes ADD COLUMN tier_3 character(20);
UPDATE bgs.all_lakes SET tier_3 = 'lake';

ALTER TABLE bgs.all_lakes ADD COLUMN versiondate varchar;
UPDATE bgs.all_lakes SET versiondate = lake_polygons.versiondate FROM bgs.lake_polygons WHERE all_lakes.geom = lake_polygons.wkb_geometry
ALTER TABLE bgs.all_lakes ADD COLUMN changedate character varying[];
UPDATE bgs.all_lakes SET changedate = lake_polygons.changedate FROM bgs.lake_polygons WHERE all_lakes.geom = lake_polygons.wkb_geometry;
ALTER TABLE bgs.all_lakes ADD COLUMN reasonforchange character varying[];
UPDATE bgs.all_lakes SET reasonforchange = lake_polygons.reasonforchange FROM bgs.lake_polygons WHERE all_lakes.geom = lake_polygons.wkb_geometry;

CREATE VIEW bgs.lakes AS SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.all_lakes WHERE tier_3 = 'lake'

--Reservoir
CREATE TABLE bgs.reservoir AS SELECT * FROM osmm_topo.cartographictext
WHERE textstring LIKE '%Reservoir%'  AND descriptivegroup = '{Inland Water}'
OR textstring LIKE '%reservoir%' AND descriptivegroup = '{Inland Water}';

--Spatial index botanical_gardens table
CREATE INDEX sidx_res ON bgs.reservoir USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.reservoir;
CLUSTER sidx_res ON bgs.reservoir;

--Select polygons from mm topographic layer that contain point allotments from cartographic text
CREATE TABLE bgs.reservoir_polygons AS SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.style_code, c.style_description, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, b.style_code, b.style_description, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.reservoir as a, osmm_topo.topographicarea as b) as c
WHERE within = 'TRUE'

ALTER TABLE bgs.reservoir_polygons ADD COLUMN tier_3 character(20);
UPDATE bgs.reservoir_polygons SET tier_3 = 'reservoir'

CREATE VIEW bgs.reservoirs AS SELECT wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.reservoir_polygons

--Pond
CREATE TABLE bgs.pond AS SELECT * FROM osmm_topo.cartographictext
WHERE textstring LIKE '%pond%'  AND descriptivegroup = '{Inland Water}'
OR textstring LIKE '%Pond%' AND descriptivegroup = '{Inland Water}';

CREATE INDEX sidx_pond ON bgs.pond USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.pond;
CLUSTER sidx_pond ON bgs.pond;

--Select polygons from mm topographic layer that contain point allotments from cartographic text
CREATE TABLE bgs.pond_polygons AS SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.style_code, c.style_description, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, b.style_code, b.style_description, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.pond as a, osmm_topo.topographicarea as b) as c
WHERE within = 'TRUE' AND descriptivegroup = '{Inland Water}';

ALTER TABLE bgs.pond_polygons ADD COLUMN tier_3 character(20);
UPDATE bgs.pond_polygons SET tier_3 = 'pond';

CREATE VIEW bgs.ponds AS SELECT wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.pond_polygons

--Outdoor swimming pool
--NA


--Lido
CREATE TABLE bgs.lido AS SELECT * FROM osmm_topo.cartographictext
WHERE textstring LIKE '%Paddling%'  AND make = 'Natural';

CREATE INDEX sidx_lido ON bgs.lido USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.lido;
CLUSTER sidx_lido ON bgs.lido;

--Select polygons from mm topographic layer that contain point allotments from cartographic text
CREATE TABLE bgs.lido_polygons AS SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.style_code, c.style_description, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, b.style_code, b.style_description, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.lido as a, osmm_topo.topographicarea as b) as c
WHERE within = 'TRUE';

ALTER TABLE bgs.lido_polygons ADD COLUMN tier_3 character(20);
UPDATE bgs.lido_polygons SET tier_3 = 'lido';

CREATE VIEW bgs.lidos AS SELECT wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.lido_polygons

--Sea
CREATE TABLE bgs.sea AS SELECT st_union(wkb_geometry) as geom FROM osmm_topo.topographicarea WHERE descriptivegroup = '{Tidal Water}' UNION SELECT st_union(geom) as geom FROM lle.coastal;

ALTER TABLE bgs.sea ADD COLUMN tier_3 character(20);
UPDATE bgs.sea SET tier_3 = 'sea';

ALTER TABLE bgs.sea ADD COLUMN versiondate varchar;
ALTER TABLE bgs.sea ADD COLUMN changedate character varying[];
ALTER TABLE bgs.sea ADD COLUMN reasonforchange character varying[];

CREATE VIEW bgs.the_sea AS SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.sea
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--BRING ALL VIEWS TOGETHER
CREATE TABLE bgs.final_bluespace AS SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.beach UNION SELECT geom,versiondate, changedate, reasonforchange, tier_3 FROM bgs.canal UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.amenity_transport UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.cliff UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.estuary UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.harbour_dock_marina UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.lakes UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.lidos UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.ponds UNION SELECT geom,versiondate, changedate, reasonforchange, tier_3 FROM bgs.reservoirs UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.rivers UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.the_sea;

ALTER TABLE bgs.final_bluespace ADD COLUMN id SERIAL PRIMARY KEY;

ALTER TABLE bgs.final_bluespace ADD COLUMN "2008" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2009" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2010" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2011" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2012" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2013" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2014" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2015" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2016" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2017" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2018" integer;
ALTER TABLE bgs.final_bluespace ADD COLUMN "2019" integer;

UPDATE bgs.final_bluespace SET 2008 =


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--Turn each polygon in to a line geometry
CREATE TABLE bgs.blue_lines AS SELECT id,versiondate, changedate, reasonforchange, tier_3, "2008", "2009", "2010", "2011", "2012", "2013", "2014", "2015", "2016", "2017", "2018", "2019", st_boundary(geom) as geom FROM bgs.final_bluespace;

--Add in tier 1 & 2 classifications
ALTER TABLE bgs.blue_lines ADD COLUMN tier_2 character(20);

UPDATE bgs.blue_lines SET tier_2 = 'inland' WHERE tier_3 IN('river','canal','amenity_transport', 'lake', 'reservoir', 'pond');
UPDATE bgs.blue_lines SET tier_2 = 'coastal' WHERE tier_3 IN('estuary','harbour/dock/marina','lido','beach','cliff','sea');

ALTER TABLE bgs.blue_lines ADD COLUMN tier_1 character(20);
UPDATE bgs.blue_lines SET tier_1 = 'linear' WHERE tier_3 IN('river','canal','amenity_transport','beach','cliff','sea','estuary');
UPDATE bgs.blue_lines SET tier_1 = 'enclosed' WHERE tier_3 IN('lido','lake', 'reservoir', 'pond', 'harbour/dock/marina');

-- Create a table that has created points along the linestrings of every bluespace
--1. Select the distinct linestrings from polylinestring column with ST_Dump
--2. Define the measure elements with ST_AddMeasure, starting with 0 (begin of the linestring) and the end of the linestring (same as the length of the linestring). Generate_series creates a series over the this measurement by the step of 10. Here you can define "n metres" (in this example 10 meters). The i value begins anew for every linestring.
--3. With ST_LocateAlong and ST_GeometryN you create a multidimensional point geometry
--4. Extract the X and Y values of this geometry and create a point from it.


--Linear bluespaces, points are 500m apart
CREATE TABLE bgs.points_for_linear_bluespace AS WITH line AS (SELECT (ST_Dump(geom)).geom AS geom, tier_3, tier_2,tier_1, id FROM bgs.blue_lines WHERE tier_1 = 'linear'), linemeasure AS (SELECT tier_3, tier_2,tier_1, id, ST_AddMeasure(line.geom, 0, ST_Length(line.geom)) AS linem,         generate_series(0, ST_Length(line.geom)::int, 500) AS i     FROM line), geometries AS (SELECT i, id, tier_3, tier_2,tier_1, (ST_Dump(ST_GeometryN(ST_LocateAlong(linem, i), 1))).geom AS geom FROM linemeasure) SELECT i, id, tier_3, tier_2,tier_1, ST_SetSRID(ST_MakePoint(ST_X(geom), ST_Y(geom)), 27700) AS geom FROM geometries;

--Enclosed bluespaces, points are 100m apart
CREATE TABLE bgs.points_for_enclosed_bluespace AS WITH line AS (SELECT (ST_Dump(geom)).geom AS geom, tier_3, tier_2,tier_1, id FROM bgs.blue_lines WHERE tier_1 = 'enclosed'), linemeasure AS (SELECT tier_3, tier_2,tier_1, id, ST_AddMeasure(line.geom, 0, ST_Length(line.geom)) AS linem, generate_series(0, ST_Length(line.geom)::int, 100) AS i FROM line), geometries AS (SELECT i, id, tier_3, tier_2,tier_1, (ST_Dump(ST_GeometryN(ST_LocateAlong(linem, i), 1))).geom AS geom FROM linemeasure) SELECT i, id, tier_3, tier_2,tier_1, ST_SetSRID(ST_MakePoint(ST_X(geom), ST_Y(geom)), 27700) AS geom FROM geometries;

--find nearest node from network for LINEAR spaces
ALTER TABLE bgs.points_for_linear_bluespace ADD COLUMN network_node bigint;

UPDATE bgs.points_for_linear_bluespace SET network_node =
(SELECT id FROM access_measures.network_nodes_wales ORDER BY geom <-> points_for_linear_bluespace.geom LIMIT 1)
-- SELECT COUNT (DISTINCT network_node) FROM bgs.points_for_linear_bluespace (106,166 distinct points for linear spaces)

--find nearest node from network for ENCLOSED spaces
ALTER TABLE bgs.points_for_enclosed_bluespace ADD COLUMN network_node bigint;

UPDATE bgs.points_for_enclosed_bluespace SET network_node =
(SELECT id FROM access_measures.network_nodes_wales ORDER BY geom <-> points_for_enclosed_bluespace.geom LIMIT 1);
-- SELECT COUNT(DISTINCT network_node) FROM bgs.points_for_enclosed_bluespace (16,411 distinct points for enclosed spaces)

--LINEAR
--calculate how far the point has moved in being snapped to network and ap produced.
--add in node geometry
SELECT addgeometrycolumn('bgs','points_for_linear_bluespace','network_node_geometry',27700, 'POINT',3);

UPDATE bgs.points_for_linear_bluespace SET network_node_geometry = network_nodes_wales.geom FROM access_measures.network_nodes_wales
WHERE points_for_linear_bluespace.network_node = network_nodes_wales.id;

--add in distance column and populate
ALTER TABLE bgs.points_for_linear_bluespace ADD COLUMN distance_difference integer;

UPDATE bgs.points_for_linear_bluespace SET distance_difference =
(SELECT st_distance(geom, network_node_geometry));

--ENCLOSED
--calculate how far the point has moved in being snapped to network and ap produced.
--add in node geometry
SELECT addgeometrycolumn('bgs','points_for_enclosed_bluespace','network_node_geometry',27700, 'POINT',3);

UPDATE bgs.points_for_enclosed_bluespace SET network_node_geometry = network_nodes_wales.geom FROM access_measures.network_nodes_wales
WHERE points_for_enclosed_bluespace.network_node = network_nodes_wales.id;

--add in distance column and populate
ALTER TABLE bgs.points_for_enclosed_bluespace ADD COLUMN distance_difference integer;

UPDATE bgs.points_for_enclosed_bluespace SET distance_difference =
(SELECT st_distance(geom, network_node_geometry));

--SELECT * FROM bgs.points_for_enclosed_bluespace
--table cols = node_id from network, id from bluespace dataset, distance node has moved
--the resultant table means every BS has an access point(s)

--Merge proxy access point tables together
CREATE TABLE bgs.bgs_proxy_accesspoints AS SELECT DISTINCT id as bgs_id, network_node_geometry as access_point_geom FROM bgs.points_for_greenspace UNION SELECT id as bgs_id, network_node_geometry as access_point_geom FROM bgs.points_for_enclosed_bluespace UNION SELECT id as bgs_id, network_node_geometry as access_point_geom FROM bgs.points_for_linear_bluespace

ALTER TABLE bgs.bgs_proxy_accesspoints ADD COLUMN unique_id SERIAL