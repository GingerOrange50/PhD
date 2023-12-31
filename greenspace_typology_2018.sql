-----------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------GREENSPACES------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--Bringing together vector datasets to create a national GBS dataset
------------------------------------------------------------------------------------------------------------------------

-------
---- Made changes to os_greenspace_mm_wales aka combined MasterMap Greenspace layer
------ PROBLEM 1: Changed column in table (bgs.os_greenspace_mm_wales) from 'priFunc' to 'prifunc' like Amy's code.
ALTER TABLE bgs.os_greenspace_mm_wales
  RENAME COLUMN "priFunc" TO "prifunc";
 ------ PROBLEM 2: Changed column in table (bgs.os_greenspace_mm_wales) from 'secFunc' to 'secfunc' like Amy's code. 
ALTER TABLE bgs.os_greenspace_mm_wales
  RENAME COLUMN "secFunc" TO "secfunc";
------ PROBLEM 3: Changed column in table (bgs.os_greenspace_mm_wales) from 'priForm' to 'priform' like Amy's code. 
ALTER TABLE bgs.os_greenspace_mm_wales
  RENAME COLUMN "priForm" TO "priform";
------ PROBLEM 4: Changed column in table (bgs.os_greenspace_mm_wales) from 'secForm' to 'secform' like Amy's code. 
ALTER TABLE bgs.os_greenspace_mm_wales
  RENAME COLUMN "secForm" TO "secform";

----------------------------
----STEP 1: make os_mm_private_gardens from greenspace_mm_wales cause for now, consider gs_unified_spaces same and need this dataset to make gs_unified_spaces layer on in code. 
---------------------------

CREATE TABLE os.os_mm_private_gardens AS SELECT * FROM bgs.os_greenspace_mm_wales
WHERE prifunc = 'Private Garden';

CREATE INDEX sidx_garden ON os.os_mm_private_gardens USING GIST (geom);
VACUUM ANALYZE os.os_mm_private_gardens;
CLUSTER sidx_garden ON os.os_mm_private_gardens;


---------------------------
----STEP 2: make os.greenspace_no_private_gardens from greenspace_mm_wales instead of mm_gs_unified_spaces
----- code creates a 'greenspace_site_id' column as replicate of 'id' column.
---------------------------

CREATE TABLE os.greenspace_no_private_gardens AS SELECT *, id as greenspace_site_id FROM bgs.os_greenspace_mm_wales
WHERE prifunc NOT IN ('Private Garden');


-------------------------
---- STEP 3: make os.greenspace_site_id_lookup
------------------------

CREATE TABLE os.greenspace_site_id_lookup AS SELECT distinct greenspace_site_id, prifunc as primary_function
FROM os.greenspace_no_private_gardens
WHERE greenspace_site_id IS NOT NULL;

---------- PROBLEM: no column greenspace_site_id in os.greenspace_no_private_gardens.
---------- Replidcated column 'id' to 'greenspace_site_id' in os.greenspace_no_private_gardens. 


------------------
---- STEP 4: make os.greenspace_with_site_id
-----------------

CREATE TABLE os.greenspace_with_site_id AS SELECT * FROM os.greenspace_no_private_gardens
WHERE greenspace_site_id IS NOT NULL;


-----------------
---- STEP 5: make VIEW os_greenspace_dissolved_by_site_id from os.greenspace_with_site_id
-----------------

CREATE MATERIALIZED VIEW os.os_greenspace_dissolved_by_site_id AS SELECT st_union(geom) as geom, greenspace_site_id FROM os.greenspace_with_site_id WHERE greenspace_site_id IS NOT NULL GROUP BY greenspace_site_id;

CREATE INDEX spatial_geom_idx ON os.os_greenspace_dissolved_by_site_id USING GIST (geom);
VACUUM ANALYZE os.os_greenspace_dissolved_by_site_id;
CLUSTER spatial_geom_idx ON os.os_greenspace_dissolved_by_site_id;


-----------------
--- STEP 6: make VIEW os_gs_unified_spaces.
--- aka greenspace_mm_wales aka the combined MasterMap Greenspace
---Ignore lookup_table as we are looking at only 1 year for now to try. 
--------------------

CREATE VIEW os.os_mm_gs_unified_spaces AS SELECT a.id, a.geom, a.toid, a.version, a.prifunc, a.secfunc, a.priform, a.secform as greenspace_site_id FROM bgs.os_greenspace_mm_wales as a;

--------PROBLEM: b."GREENSPACESITEID" comes from greenspace_lookuptable_2019_08. So took out. 


-----------------
----- STEP ?: IGNORING FOR NOW.  make VIEW os_mm_gs_extent_function
-----------------

CREATE VIEW os.os_mm_gs_extent_function AS SELECT a.greenspace_site_id, a.geom, b.primary_function FROM os.greenspace_with_site_id_extent as a
LEFT JOIN os.greenspace_site_id_lookup as b
ON a.greenspace_site_id = b.greenspace_site_id;

-------- PROBLEM: OG dataset os.greenspace_with_site_id_extent is missing. os_mm_gs_extent_function is never mentioned again. 
------- So will ignore and not create for now. 



--------------------------------
-----IGNORE CAUSE THIS PARK ONLY TO SHOW IN PAPER, NOT SPECIAL----------------------------
------------------------------------------

---51.61304141982028, -3.9810142102405677- is coordinate of Singleton Park 
---- placeholder
CREATE TABLE bgs.singleton_park AS SELECT * FROM os.os_mm_gs_unified_spaces
WHERE toid in ('osgb1000000333168396','osgb1000000333168432', 'osgb1000000333168827', 'osgb1000000333169567', 'osgb5000005126318034');


--Add in Singleton Park
UPDATE os.greenspace_no_private_gardens
SET greenspace_site_id = '8F5BF6CA-685E-2245-E053-A03BA40AA829'
FROM bgs.singleton_park --Don't know what BGS is. maybe LA info. Skip to line 26
WHERE greenspace_no_private_gardens.toid = singleton_park.toid;

--------------------------------


------------------------------------------------------------------------------------------------------------------------
--From the dataset, we create access points for each space. Based on NESW points for each boundary.
--First of all, need to create separate tables for each tier 3 classification

SELECT COUNT (DISTINCT greenspace_site_id) FROM os.greenspace_with_site_id;
SELECT COUNT (DISTINCT geom) FROM os.os_greenspace_dissolved_by_site_id;

--Parks
CREATE TABLE bgs.parks_18 AS SELECT a.toid, a.version, a.prifunc, a.secfunc, a.priform, a.secform, a.greenspace_site_id, geom FROM (SELECT DISTINCT greenspace_site_id, toid, version, prifunc, secfunc, priform, secform, geom FROM os.greenspace_with_site_id WHERE prifunc = 'Public Park Or Garden' AND secfunc IS NULL) as a;


--parks_18 exported to qgis and geometries dissolved, imported back as all_parks


------ NEED to be revised if geom dissolved needs a grouping variable. 
CREATE TABLE bgs.all_parks AS SELECT toid, st_union(geom) AS geom
FROM bgs.parks_18 GROUP BY toid;

ALTER TABLE bgs.all_parks ADD COLUMN tier_3 character(20);
UPDATE bgs.all_parks SET tier_3 = 'park';

SELECT COUNT (greenspace_site_id) FROM bgs.parks_18;


-------------------------
----STEP 8: Import the cartographictext and topographicarea into os_tmp schema from QGIS into SQL.
----- make sure to fix the geometry in QGIS before importing SQL. 
----- -----------

---------PROBLEM os_tmp.cartographictext missing column 'ogc_fid' so replicated from fid. same with 'wkb_geometry' from 'geom'

--- Add a new column named wkb_geometry to cartographictext
ALTER TABLE os_tmp.cartographictext
ADD COLUMN wkb_geometry GEOMETRY;

-- Update the new column with values from the existing geom column
UPDATE os_tmp.cartographictext
SET wkb_geometry = geom;

------------------------------------------------------------------------------------------------------------------------
--Recreation Spaces
--DROP TABLE bgs.recreation_spaces CASCADE
CREATE TABLE bgs.recreation_spaces AS SELECT * FROM os.greenspace_with_site_id
WHERE prifunc = 'Tennis Court' OR
prifunc = 'Bowling Green' OR
prifunc = 'Golf Course' OR
secfunc = 'Tennis Court' OR
secfunc = 'Bowling Green' OR
secfunc = 'Golf Course';

DROP MATERIALIZED VIEW bgs.recreation_spaces_b CASCADE;
----PROBLEM: at this point this VIEW doesn't exist yet. So can ignore this line.


CREATE MATERIALIZED VIEW bgs.recreation_spaces_b AS SELECT * FROM os_tmp.cartographictext
WHERE textstring LIKE '%Tennis%' OR textstring LIKE '%tennis%' OR
textstring LIKE '%Bowling%' OR textstring LIKE '%bowling%' OR
textstring LIKE '%Picnic%';

----- PROBLEM: Replicated 'geom' column to make 'wkb_geometry' for VIEW.  

--Spatial index recreation_spaces_b table
CREATE INDEX sidx_recreation_spaces_b ON bgs.recreation_spaces_b USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.recreation_spaces_b;
CLUSTER sidx_recreation_spaces_b ON bgs.recreation_spaces_b;
VACUUM ANALYZE bgs.recreation_spaces_b;


---------PROBLEM os_tmp.topographicarea missing column 'ogc_fid' so replicated from fid. same with 'wkb_geometry' from 'geom'

-- Add a new column named ogc_fid to topographicarea
ALTER TABLE os_tmp.topographicarea
ADD COLUMN ogc_fid CHARACTER VARYING;

-- Update the new column with values from the existing fid column
UPDATE os_tmp.topographicarea
SET ogc_fid = fid;

--- Add a new column named wkb_geometry to topographicarea
ALTER TABLE os_tmp.topographicarea
ADD COLUMN wkb_geometry GEOMETRY;

-- Update the new column with values from the existing geom column
UPDATE os_tmp.topographicarea
SET wkb_geometry = geom;



--DROP TABLE bgs.recreation_polygon_with_pt CASCADE
--Select polygons from mm topographic layer that contain point recreation areas from cartographic text table
--Bring together distinct polygons derived from MM and os_greenspace
CREATE MATERIALIZED VIEW bgs.recreation_test AS
SELECT * FROM
(SELECT d.fid, st_intersects(d.wkb_geometry, geom) FROM
(SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.recreation_spaces_b as a, os_tmp.topographicarea as b) as c
WHERE within = 'TRUE') as d, bgs.recreation_spaces) as foo
WHERE st_intersects = 'TRUE';

---------PROBLEM: Not sure which 'fid' column selected in 3rd line. Chose d. to try. 


--- PROBLEM: bgs.recreation_test is an OG dataset. Unknown from where. So create bgs.creation_spaces without for now. 

----IGNORE FOR NOW----
--Add carto polygons in to recreation_spacestable
INSERT INTO bgs.recreation_spaces (toid)
SELECT DISTINCT fid FROM bgs.recreation_test

----------------
----UPDATED the below code to be more clear where each column come from-----
-------------

UPDATE bgs.recreation_spaces 
SET geom = st_force3d(ta.wkb_geometry)
FROM os_tmp.topographicarea AS ta
WHERE bgs.recreation_spaces.geom IS NULL AND bgs.recreation_spaces.toid = ta.fid;

ALTER TABLE bgs.recreation_spaces ADD COLUMN tier_3 character(20);
UPDATE bgs.recreation_spaces SET tier_3 = 'recreational';

--Join MM info to table based on
CREATE MATERIALIZED VIEW bgs.all_recreation_spaces_18 AS SELECT a.toid, a.geom, a.tier_3, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue as area, b.changedate, b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make FROM bgs.recreation_spaces as a LEFT JOIN (SELECT fid, featurecode, version, versiondate, theme, calculatedareavalue, changedate, reasonforchange, descriptivegroup, descriptiveterm, make, wkb_geometry FROM os_tmp.topographicarea) as b ON a.toid = b.fid




------------------------------------------------------------------------------------------------------------------------

--Sports pitches
CREATE TABLE bgs.sports_pitches_18 AS SELECT * FROM os.greenspace_with_site_id
WHERE prifunc = 'Playing Field' OR
prifunc = 'Public Park Or Garden' AND secfunc = 'Playing Field';


------CHANGED to make variable type clearer. 
ALTER TABLE bgs.sports_pitches_18
ALTER COLUMN geom TYPE geometry(MultiLineStringZ)
USING st_force3d(geom);

--FROM cartographic text
CREATE MATERIALIZED VIEW bgs.sports_pitches_b_18 AS SELECT * FROM os_tmp.cartographictext
WHERE textstring LIKE '%Playing Field%' OR textstring LIKE '%playing field%'
OR textstring LIKE '%Sport%' AND textstring LIKE '%Field%';

--Spatial index sports_b table
CREATE INDEX sidx_sports_pitches_b_18 ON bgs.sports_pitches_b_18 USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.sports_pitches_b_18;
CLUSTER sidx_sports_pitches_b_18 ON bgs.sports_pitches_b_18;

--Select polygons from mm topographic layer that contain points from cartographic text
--Bring together distinct polygons derived from MM and os_greenspace
CREATE MATERIALIZED VIEW bgs.sports_pitches_polygon_with_pt_18 AS
SELECT DISTINCT fid FROM
(SELECT d.fid, st_intersects(d.wkb_geometry, geom) FROM
(SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.sports_pitches_b_18 as a, os_tmp.topographicarea as b) as c
WHERE within = 'TRUE') as d, bgs.sports_pitches_18) as foo
WHERE st_intersects = 'TRUE';

---------PROBLEM: Not sure which 'fid' column selected in 3rd line. Chose d. to try.


--Add carto polygons in to rec spaces table
INSERT INTO bgs.sports_pitches_18 (toid)
SELECT DISTINCT fid FROM bgs.sports_pitches_polygon_with_pt_18;

----------------
----UPDATED the below code to be more clear where each column come from-----
-------------

UPDATE bgs.sports_pitches_18
SET geom = st_force3d(ta.wkb_geometry)
FROM os_tmp.topographicarea AS ta
WHERE bgs.sports_pitches_18.geom IS NULL AND bgs.sports_pitches_18.toid = ta.fid;

----------------
------------------
---- NEED TO delete double counted rows.
---- HAVE NOT SORTED!!
-----------------
----------------

ALTER TABLE bgs.sports_pitches_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.sports_pitches_18 SET tier_3 = 'sports pitches';

--------- TO CREATE OG dataset bgs.sports_pitches to make materialized view bgs.all_sports_pitches_18
CREATE TABLE bgs.sports_pitches AS SELECT toid, tier_3, st_union(geom) AS geom 
FROM bgs.sports_pitches_18 GROUP BY toid, tier_3;


--Join MM info to table based on
CREATE MATERIALIZED VIEW bgs.all_sports_pitches_18 AS SELECT a.toid, a.geom, a.tier_3, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue as area, b.changedate, b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make FROM bgs.sports_pitches as a LEFT JOIN (SELECT fid, featurecode, version, versiondate, theme, calculatedareavalue, changedate, reasonforchange, descriptivegroup, descriptiveterm, make, wkb_geometry FROM os_tmp.topographicarea) as b ON a.toid = b.fid


----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Play areas

CREATE TABLE bgs.play_areas_18 AS SELECT * FROM os.greenspace_with_site_id
WHERE prifunc = 'Play Space' OR
secfunc = 'Play Space';

------CHANGED to make variable type clearer. 
ALTER TABLE bgs.play_areas_18
ALTER COLUMN geom TYPE geometry(MultiPolygonZ)
USING st_force3d(geom);


CREATE MATERIALIZED VIEW bgs.play_areas_b_18 AS SELECT * FROM (SELECT * FROM os_tmp.cartographictext
WHERE textstring LIKE '%Play%' OR textstring LIKE '%Playground%') as a
WHERE a.textstring NOT LIKE '%Field%' AND
a.textstring NOT LIKE '%field%' AND
a.textstring NOT LIKE '%School%' AND
a.textstring NOT LIKE '%school%' AND
a.textstring NOT LIKE '%Players lndustrial Estate%' AND
a.textstring NOT LIKE '%Playas%';

--Spatial index play_areas_b table
CREATE INDEX sidx_play_areas_b_18 ON bgs.play_areas_b_18 USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.play_areas_b_18;
CLUSTER sidx_play_areas_b_18 ON bgs.play_areas_b_18;

--Select polygons from mm topographic layer that contain points from cartographic text
--Bring together distinct polygons derived from MM and os_greenspace
CREATE MATERIALIZED VIEW bgs.play_areas_polygon_with_pt_18 AS
SELECT DISTINCT fid FROM
(SELECT d.fid, st_intersects(d.wkb_geometry, geom) FROM
(SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.play_areas_b_18 as a, os_tmp.topographicarea as b) as c
WHERE within = 'TRUE') as d, bgs.play_areas_18) as foo
WHERE st_intersects = 'TRUE';

---------PROBLEM: Not sure which 'fid' column selected in 3rd line. Chose d. to try.


--Add carto polygons in to rec spaces table
INSERT INTO bgs.play_areas_18 (toid)
SELECT DISTINCT fid FROM bgs.play_areas_polygon_with_pt_18;


UPDATE bgs.play_areas_18
SET geom = st_force3d(ta.wkb_geometry)
FROM os_tmp.topographicarea AS ta
WHERE bgs.play_areas_18.geom IS NULL AND bgs.play_areas_18.toid = ta.fid;


ALTER TABLE bgs.play_areas_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.play_areas_18 SET tier_3 = 'play_areas';

--Join MM info to table based on
CREATE MATERIALIZED VIEW bgs.all_play_areas_18 AS SELECT a.toid, a.geom, a.tier_3, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue as area, b.changedate, b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make FROM bgs.play_areas_18 as a LEFT JOIN (SELECT fid, featurecode, version, versiondate, theme, calculatedareavalue, changedate, reasonforchange, descriptivegroup, descriptiveterm, make, wkb_geometry FROM os_tmp.topographicarea) as b ON a.toid = b.fid

------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Domestic Gardens
--see code above for creating the table os.os_mm_private_gardens

--City Farms--NO DATA

------------------------------------------------------------------------------------------------------------------------
--Allotments
CREATE TABLE bgs.allotments_18 AS SELECT * FROM os.greenspace_with_site_id
WHERE prifunc = 'Allotments Or Community Growing Spaces' OR
prifunc = 'Public Park Or Garden' AND secfunc = 'Allotments Or Community Growing Spaces' OR
prifunc = 'Amenity - Transport' AND secfunc = 'Allotments Or Community Growing Spaces';

CREATE MATERIALIZED VIEW bgs.allotments_b_18 AS SELECT * FROM os_tmp.cartographictext
WHERE textstring LIKE '%Allot%' AND make = 'Natural';

--Spatial index allotments_b table
CREATE INDEX sidx_allotments_b_18 ON bgs.allotments_b_18 USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.allotments_b_18;
CLUSTER sidx_allotments_b_18 ON bgs.allotments_b_18;

---------
------PROBLEM topographicarea and allotments_b_18 does not have column 'style_code' or 'style_description'
----- Looks like no existing OG datasets don't have 'style_code' or 'style_description'
------ So DELETE for now. 
----- Not seen in other same-ish code.


--Select polygons from mm topographic layer that contain point allotments from cartographic text
CREATE TABLE bgs.allot_polygon_with_pt AS SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.allotments_b_18 as a, os_tmp.topographicarea as b) as c
WHERE within = 'TRUE';

--Select polygons from bgs.allot_polygon_with_pt that are not recorded in allotments table. Did this in QGIS using select by location.
--Exported polygons that did not intersect with OS GS allotment polygons n=345 table name = allot_cartotext_polygon
--Then 'Unioned' the two polygon dataset in QGIS allot_cartotext_polygon and allotments to create a table with 3133 polygons

---------
-----PROBLEM: where does bgs.all_allotments come from?
---------

--------- TO CREATE OG dataset bgs.all_allotments to make materialized view bgs.allotments_18
CREATE TABLE bgs.all_allotments AS SELECT toid, st_union(geom) AS geom 
FROM bgs.allotments_18 GROUP BY toid;


ALTER TABLE bgs.all_allotments ADD COLUMN tier_3 character(20);
UPDATE bgs.all_allotments SET tier_3 = 'allotments';

------------------------------------------------------------------------------------------------------------------------
--Cemeteries
CREATE TABLE bgs.cemeteries_18 AS SELECT * FROM os.greenspace_with_site_id
WHERE prifunc = 'Cemetery' OR
prifunc = 'Amenity - Transport' AND secfunc = 'Cemetery' OR
prifunc = 'School Grounds' AND secfunc = 'Cemetery' OR
prifunc = 'Institutional Grounds' AND secfunc = 'Cemetery' OR
prifunc = 'Public Park Or Garden' AND secfunc = 'Cemetery';

------CHANGED to make variable type clearer. 
ALTER TABLE bgs.cemeteries_18
ALTER COLUMN geom TYPE geometry(MultiPolygonZ)
USING st_force3d(geom);


--Add in '%cemetary%' from carto text
CREATE MATERIALIZED VIEW bgs.cemetery_b_18 AS SELECT * FROM os_tmp.cartographictext
WHERE textstring LIKE '%Burial%' AND make = 'Natural' OR
textstring LIKE '%Graveyard%' AND make = 'Natural' OR
textstring LIKE '%Cemetery' AND make = 'Natural' OR
textstring LIKE '%Cemetery' AND make = 'Manmade' OR
textstring LIKE '%Cemetery' AND make = 'Multiple' OR
textstring LIKE '%Cemetery' AND make = 'Multipl';

--Spatial index allotments_b table
CREATE INDEX sidx_cemetery_b_18 ON bgs.cemetery_b_18 USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.cemetery_b_18;
CLUSTER sidx_cemetery_b_18 ON bgs.cemetery_b_18;


---------PROBLEM: Not sure which 'fid' column selected in 3rd line. Chose d. to try.

--Select polygons from mm topographic layer that contain points from cartographic text
--Bring together distinct polygons derived from MM and os_greenspace
CREATE MATERIALIZED VIEW bgs.cemetery_polygon_with_pt_18 AS
SELECT DISTINCT fid FROM
(SELECT d.fid, st_intersects(d.wkb_geometry, geom) FROM
(SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.cemetery_b_18 as a, os_tmp.topographicarea as b) as c
WHERE within = 'TRUE') as d, bgs.cemeteries_18) as foo
WHERE st_intersects = 'TRUE';

--Add carto polygons in to rec spaces table
INSERT INTO bgs.cemeteries_18 (toid)
SELECT DISTINCT fid FROM bgs.cemetery_polygon_with_pt_18;

UPDATE bgs.cemeteries_18
SET geom = st_force3d(ta.wkb_geometry)
FROM os_tmp.topographicarea AS ta
WHERE bgs.cemeteries_18.geom IS NULL AND bgs.cemeteries_18.toid = ta.fid;

ALTER TABLE bgs.cemeteries_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.cemeteries_18 SET tier_3 = 'play_areas';

--Join MM info to table based on
CREATE MATERIALIZED VIEW bgs.all_cemeteries_18 AS SELECT a.toid, a.geom, a.tier_3, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue as area, b.changedate, b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make FROM bgs.cemeteries_18 as a LEFT JOIN (SELECT fid, featurecode, version, versiondate, theme, calculatedareavalue, changedate, reasonforchange, descriptivegroup, descriptiveterm, make, wkb_geometry FROM os_tmp.topographicarea) as b ON a.toid = b.fid



------------------------------------------------------------------------------------------------------------------------
--Religious_grounds
CREATE TABLE bgs.religious_grounds AS SELECT * FROM os.greenspace_with_site_id
WHERE prifunc = 'Religious Grounds' OR
prifunc = 'Amenity - Transport' AND secfunc = 'Religious Grounds' OR
prifunc = 'Public Park Or Garden' AND secfunc = 'Religious Grounds';

ALTER TABLE bgs.religious_grounds ADD COLUMN tier_3 character(20);
UPDATE bgs.religious_grounds SET tier_3 = 'religious_grounds';
------------------------------------------------------------------------------------------------------------------------

--School Grounds
CREATE TABLE bgs.school_grounds AS SELECT * FROM os.greenspace_with_site_id
WHERE prifunc = 'School Grounds' OR secfunc = 'School Grounds';

ALTER TABLE bgs.school_grounds ADD COLUMN tier_3 character(20);
UPDATE bgs.school_grounds SET tier_3 = 'school_grounds';
------------------------------------------------------------------------------------------------------------------------

--Other Grounds
CREATE TABLE bgs.other_grounds AS SELECT * FROM os.greenspace_with_site_id
WHERE prifunc = 'Institutional Grounds';

ALTER TABLE bgs.other_grounds ADD COLUMN tier_3 character(20);
UPDATE bgs.other_grounds SET tier_3 = 'other_grounds';
------------------------------------------------------------------------------------------------------------------------

--Botanical Gardens
CREATE MATERIALIZED VIEW bgs.botanical_gardens_18 AS SELECT * FROM os_tmp.cartographictext
WHERE textstring LIKE '%Botanic%'
OR textstring LIKE '%Nursery%' AND theme = 'Land';

--Spatial index botanical_gardens table
CREATE INDEX sidx_botanical_gardens_18 ON bgs.botanical_gardens_18 USING GIST (wkb_geometry);
CLUSTER  bgs.botanical_gardens_18 using sidx_botanical_gardens_18;
VACUUM ANALYZE bgs.botanical_gardens_18;

---------------------------------------------
-------------- lookuptable to show how dif year relate to this data year
---------------------------------------------

--Select polygons from mm topographic layer that contain point allotments from cartographic text
CREATE TABLE bgs.all_botanical_18 AS SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.botanical_gardens_18 as a, os_tmp.topographicarea as b) as c
WHERE within = 'TRUE';

ALTER TABLE bgs.all_botanical_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.all_botanical_18 SET tier_3 = 'botanical_gardens';
------------------------------------------------------------------------------------------------------------------------
--Marsh land
CREATE TABLE bgs.marsh_18 AS SELECT * FROM os_tmp.topographicarea
WHERE descriptiveterm LIKE '%Marsh%';

ALTER TABLE bgs.marsh_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.marsh_18 SET tier_3 = 'marsh';

ALTER TABLE bgs.marsh_18 ADD COLUMN toid varchar(20);

------------------------------------------------------------------------------------------------------------------------

--Deciduous
CREATE TABLE bgs.deciduous_18 AS SELECT * FROM os_tmp.topographicarea
WHERE descriptiveterm LIKE '%Nonconiferous%';

ALTER TABLE bgs.deciduous_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.deciduous_18 SET tier_3 = 'deciduous';

---------------------------------------------------

--Coniferous
CREATE TABLE bgs.coniferous_18 AS SELECT * FROM os_tmp.topographicarea
WHERE descriptiveterm LIKE '%Coniferous%';

ALTER TABLE bgs.coniferous_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.coniferous_18 SET tier_3 = 'coniferous';
------------------------------------------------------------------------------------------------------------------------
--Mixed
CREATE TABLE bgs.mixed_18 AS SELECT * FROM os_tmp.topographicarea
WHERE descriptiveterm LIKE '%Coniferous%' AND descriptiveterm LIKE '%Nonconiferous%' OR 
descriptiveterm LIKE '%Nonconiferous%' AND descriptiveterm LIKE '%Coniferous%';

ALTER TABLE bgs.mixed_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.mixed_18 SET tier_3 = 'mixed';
------------------------------------------------------------------------------------------------------------------------

--Moor/heath
CREATE TABLE bgs.moor_heath_18 AS SELECT * FROM os_tmp.topographicarea
WHERE descriptiveterm LIKE '%Scrub%' OR descriptiveterm LIKE '%Heath%';

ALTER TABLE bgs.moor_heath_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.moor_heath_18 SET tier_3 = 'moor_heath';
------------------------------------------------------------------------------------------------------------------------
--Grassland
CREATE TABLE bgs.grassland_18 AS SELECT * FROM os_tmp.topographicarea
WHERE descriptiveterm LIKE '%Grassland%';

ALTER TABLE bgs.grassland_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.grassland_18 SET tier_3 = 'grassland';
------------------------------------------------------------------------------------------------------------------------
--02/06/18:15
--Quarry
CREATE TABLE bgs.quarry_18 AS SELECT * FROM os_tmp.cartographictext
WHERE textstring LIKE '%Quarry%';

--Spatial index quarry table
CREATE INDEX sidx_quarry_18 ON bgs.quarry_18 USING GIST (wkb_geometry);
CLUSTER bgs.quarry_18 using sidx_quarry_18;
VACUUM ANALYZE bgs.quarry_18;


--Select polygons from mm topographic layer that contain point allotments from cartographic text
CREATE TABLE bgs.all_quarry_18 AS SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.quarry_18 as a, os_tmp.topographicarea as b) as c
WHERE within = 'TRUE';

ALTER TABLE bgs.all_quarry_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.all_quarry_18 SET tier_3 = 'quarry';
------------------------------------------------------------------------------------------------------------------------

------------I took out the make ='Natural' cause in QGIS its all null or manmade make.
-----------------------------------------------------
--Meadow
CREATE TABLE bgs.meadow_18 AS SELECT * FROM os_tmp.cartographictext
WHERE textstring LIKE '%Meadow%';

--Spatial index botanical_gardens table
CREATE INDEX sidx_meadow_18 ON bgs.meadow_18 USING GIST (wkb_geometry);
VACUUM ANALYZE bgs.meadow_18;
CLUSTER sidx_meadow_18 ON bgs.meadow_18;


--Select polygons from mm topographic layer that contain point allotments from cartographic text
CREATE TABLE bgs.all_meadow_18 AS SELECT c.ogc_fid, c.wkb_geometry, c.fid, c.featurecode, c.version, c.versiondate, c.theme, c.calculatedareavalue,
c.changedate, c.reasonforchange, c.descriptivegroup, c.descriptiveterm, c.make, c.within FROM
(SELECT  b.ogc_fid, b.wkb_geometry, b.fid, b.featurecode, b.version, b.versiondate, b.theme, b.calculatedareavalue, b.changedate,
 b.reasonforchange, b.descriptivegroup, b.descriptiveterm, b.make, ST_Within(a.wkb_geometry, b.wkb_geometry) as within
FROM bgs.meadow_18 as a, os_tmp.topographicarea as b) as c
WHERE within = 'TRUE';

ALTER TABLE bgs.all_meadow_18 ADD COLUMN tier_3 character(20);
UPDATE bgs.all_meadow_18 SET tier_3 = 'meadow';

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--BRINGING GREENSPACES TOGETHER
--BRING ALL VIEWS TOGETHER
CREATE VIEW bgs.green_a_18 AS SELECT fid, wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.coniferous_18
UNION SELECT fid, wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.deciduous_18
UNION SELECT fid, wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.mixed_18
UNION SELECT fid, wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.moor_heath_18
UNION SELECT fid, wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.all_quarry_18
UNION SELECT fid, wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.grassland_18
UNION SELECT fid, wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.all_meadow_18
UNION SELECT fid, wkb_geometry as geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.all_botanical_18;

--Add in versiondate, changedate, reasonforchange from MM from toid
-- alter table bgs.marsh_18 rename column wkb_geometry to geom

CREATE VIEW bgs.green_b_18 AS
SELECT a.geom, a.toid,a.tier_3, b.versiondate, b.changedate, b.reasonforchange FROM
(SELECT geom, toid, tier_3 FROM bgs.all_sports_pitches_18
UNION SELECT geom, toid, tier_3 FROM bgs.all_play_areas_18
UNION SELECT geom, toid, tier_3 FROM bgs.all_allotments
UNION SELECT geom, toid, tier_3 FROM bgs.all_cemeteries_18
UNION SELECT geom, toid, tier_3 FROM bgs.marsh_18
UNION SELECT geom, toid, tier_3 FROM bgs.all_recreation_spaces_18) as a
LEFT JOIN (SELECT fid, versiondate, changedate, reasonforchange FROM os_tmp.topographicarea) as b
ON (a.toid = b.fid);


--Stopped here 20/05/20
CREATE VIEW bgs.green_c_18 AS
SELECT a.geom, a.toid,a.tier_3, b.versiondate, b.changedate, b.reasonforchange FROM
(SELECT geom, toid, tier_3 FROM bgs.religious_grounds
UNION SELECT geom, toid, tier_3 FROM bgs.school_grounds
UNION SELECT geom, toid, tier_3 FROM bgs.other_grounds
UNION SELECT geom, toid, tier_3 FROM bgs.all_parks) as a
LEFT JOIN (SELECT fid, versiondate, changedate, reasonforchange FROM os_tmp.topographicarea) as b
ON (a.toid = b.fid);

----------------------------------
-----------what is bgs.green_a?---------------------
----------what is bgs.green_a_12?--------
---------- same for green_b and green_c-------
----------based on years, could be historical data?--------------
---------------------------------

--Greenspace table
CREATE TABLE bgs.final_greenspace AS SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_a UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_b UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_c;

--2nd Run
--DROP TABLE bgs.final_greenspace CASCADE;
CREATE TABLE bgs.final_greenspace_b AS SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_a UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_b UNION SELECT geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_c;

--3rd run
CREATE view bgs.final_greenspace_12_fid AS SELECT fid, geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_a_12 UNION SELECT toid, geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_b_12 UNION SELECT  toid, geom, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_c_12;

--4th run
CREATE table bgs.final_greenspace_18_toid AS SELECT geom, fid, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_a_18 UNION SELECT geom, toid, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_b_18 UNION SELECT geom, toid, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_c_18;


CREATE table bgs.final_greenspace_12_toid AS SELECT geom, fid, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_a_12 UNION SELECT geom, toid, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_b_12 UNION SELECT geom, toid, versiondate, changedate, reasonforchange, tier_3 FROM bgs.green_c_12;





--add indexes
create index tier3_idx on bgs.final_greenspace_18_toid(tier_3);
create index geom_idx_18_toid on bgs.final_greenspace_18_toid using gist(geom);
cluster bgs.final_greenspace_18_toid using geom_idx_18_toid;
vacuum analyse bgs.final_greenspace_18_toid;

ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN id SERIAL PRIMARY KEY;

ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2008" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2009" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2010" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2011" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2012" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2013" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2014" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2015" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2016" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2017" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2018" integer;
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN "2019" integer;


-- 2012 data
create index tier3_2012_idx on bgs.final_greenspace_12_toid(tier_3);
create index geom_idx_12_toid on bgs.final_greenspace_12_toid using gist(geom);
cluster bgs.final_greenspace_12_toid using geom_idx_12_toid;
vacuum analyse bgs.final_greenspace_12_toid;

ALTER TABLE bgs.final_greenspace_12_toid ADD COLUMN id SERIAL PRIMARY KEY;

UPDATE bgs.final_greenspace_12_toid SET tier_2 = 'recreation space' WHERE tier_3 IN('park','recreational','sports pitches', 'play_areas');
UPDATE bgs.final_greenspace_12_toid SET tier_2 = 'productive' WHERE tier_3 IN('allotments');
UPDATE bgs.final_greenspace_12_toid SET tier_2 = 'burial grounds' WHERE tier_3 IN('cemeteries', 'religious_grounds');
UPDATE bgs.final_greenspace_12_toid SET tier_2 = 'institutional' WHERE tier_3 IN('school_grounds', 'other_grounds');
UPDATE bgs.final_greenspace_12_toid SET tier_2 = 'gardens' WHERE tier_3 IN('botanical');
UPDATE bgs.final_greenspace_12_toid SET tier_2 = 'wetland' WHERE tier_3 IN('marsh');
UPDATE bgs.final_greenspace_12_toid SET tier_2 = 'woodland' WHERE tier_3 IN('deciduous', 'coniferous', 'mixed');
UPDATE bgs.final_greenspace_12_toid SET tier_2 = 'other habitats' WHERE tier_3 IN('moor_heath', 'grassland', 'quarry','meadow');





--UPDATE bgs.final_greenspace SET 2008 =

--Add in tier 1 & 2 classifications
ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN tier_2 character(20);

--21/05/20
UPDATE bgs.final_greenspace_18_toid SET tier_2 = 'recreation space' WHERE tier_3 IN('park','recreational','sports pitches', 'play_areas');
UPDATE bgs.final_greenspace_18_toid SET tier_2 = 'productive' WHERE tier_3 IN('allotments');
UPDATE bgs.final_greenspace_18_toid SET tier_2 = 'burial grounds' WHERE tier_3 IN('cemeteries', 'religious_grounds');
UPDATE bgs.final_greenspace_18_toid SET tier_2 = 'institutional' WHERE tier_3 IN('school_grounds', 'other_grounds');
UPDATE bgs.final_greenspace_18_toid SET tier_2 = 'gardens' WHERE tier_3 IN('botanical');
UPDATE bgs.final_greenspace_18_toid SET tier_2 = 'wetland' WHERE tier_3 IN('marsh');
UPDATE bgs.final_greenspace_18_toid SET tier_2 = 'woodland' WHERE tier_3 IN('deciduous', 'coniferous', 'mixed');
UPDATE bgs.final_greenspace_18_toid SET tier_2 = 'other habitats' WHERE tier_3 IN('moor_heath', 'grassland', 'quarry','meadow');

--create indexes
create index tier2_idx on bgs.final_greenspace_18_toid(tier_2);
vacuum analyse bgs.final_greenspace_18_toid;

ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN tier_1 character(20);
UPDATE bgs.final_greenspace_18_toid SET tier_1 = 'amenity' WHERE tier_2 IN('recreation space');
UPDATE bgs.final_greenspace_18_toid SET tier_1 = 'functional' WHERE tier_2 IN('productive','burial grounds', 'institutional','gardens');
UPDATE bgs.final_greenspace_18_toid SET tier_1 = 'seminatural habitat' WHERE tier_2 IN('wetland','woodland','other habitats');

ALTER TABLE bgs.final_greenspace_18_toid ADD COLUMN area float;

UPDATE bgs.final_greenspace_18_toid set area = round(st_area(geom)::numeric, 2);


-- extract access points
create materialized view bgs.final_access_points_18_toid as (select id, fid as toid, area, tier_1, tier_2, tier_3, (st_dumppoints(st_orientedenvelope((st_dump(geom)).geom))).geom as geom  from bgs.final_greenspace_18_toid);
create materialized view  bgs.final_access_points_18_toid_wales as (select gs.* from bgs.final_access_points_18_toid gs, ons.wales_lsoa_2011 lsoa where st_intersects(lsoa.geom, gs.geom));


