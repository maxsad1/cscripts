WHENEVER SQLERROR EXIT FAILURE;

/* ------------------------------------------------------------------------------------ */

-- create repository with exceptions (black list)
DECLARE
  l_exists NUMBER;
  l_sql_statement VARCHAR2(32767) := q'[
CREATE TABLE &&1..exceptions_black_list (
  iod_api                        VARCHAR2(30), -- TABLE_REDEFINITION | FPZ
  pdb_name                       VARCHAR2(30),
  owner                          VARCHAR2(30),
  table_name                     VARCHAR2(30),
  reference                      VARCHAR2(128),
  created                        DATE DEFAULT SYSDATE 
)
TABLESPACE IOD
]';
  l_sql_statement2 VARCHAR2(32767) := q'[BEGIN
INSERT INTO &&1..exceptions_black_list (iod_api, table_name, reference) VALUES ('TABLE_REDEFINITION', 'KIEVTRANSACTIONS', 'Until KaaS is implemented and KT and KTK are purged and GC');
INSERT INTO &&1..exceptions_black_list (iod_api, table_name, reference) VALUES ('TABLE_REDEFINITION', 'KIEVTRANSACTIONKEYS', 'Until KaaS is implemented and KT and KTK are purged and GC');
INSERT INTO &&1..exceptions_black_list (iod_api, table_name, reference) VALUES ('TABLE_REDEFINITION', 'TIMERS', 'Until we get ORA-600 from IOD-9949 fixed');
INSERT INTO &&1..exceptions_black_list (iod_api, table_name, reference) VALUES ('TABLE_REDEFINITION', 'MAPUPDATES_AD', 'Until KIEV implements "OR" predicates at the application layer CHANGE-77522');
END;
]';
BEGIN
  SELECT COUNT(*) INTO l_exists FROM dba_tables WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('exceptions_black_list');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement;
    EXECUTE IMMEDIATE l_sql_statement2;
    DBMS_STATS.gather_table_stats(UPPER(TRIM('&&1.')), UPPER('exceptions_black_list'));
    COMMIT; 
  END IF;
END;
/

SET LONG 40000;
SET LONGC 400 ;
SET PAGES 100;
SET LINE 200;
SET HEA OFF;
SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('exceptions_black_list'), UPPER('&&1.')) rsrc_mgr_plan_config FROM DUAL
/
SET HEA ON;
SELECT * FROM &&1..exceptions_black_list
/

/* ------------------------------------------------------------------------------------ */

-- table_stats_hist
-- create repository, partitioned and compressed
-- code preserves 2 months of data
DECLARE
  l_exists NUMBER;
  l_sql_statement VARCHAR2(32767) := q'[
CREATE TABLE &&1..table_stats_hist (
  pdb_name                       VARCHAR2(128),
  owner                          VARCHAR2(128),
  table_name                     VARCHAR2(128),
  last_analyzed                  DATE,
  blocks                         NUMBER,
  num_rows                       NUMBER,
  sample_size                    NUMBER,
  avg_row_len                    NUMBER,
  con_id                         NUMBER,
  object_id                      NUMBER
)
PARTITION BY RANGE (last_analyzed)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
PARTITION before_2017_12_01 VALUES LESS THAN (TO_DATE('2017-12-01', 'YYYY-MM-DD')),
PARTITION before_2018_01_01 VALUES LESS THAN (TO_DATE('2018-01-01', 'YYYY-MM-DD')),
PARTITION before_2018_02_01 VALUES LESS THAN (TO_DATE('2018-02-01', 'YYYY-MM-DD')),
PARTITION before_2018_03_01 VALUES LESS THAN (TO_DATE('2018-03-01', 'YYYY-MM-DD')),
PARTITION before_2018_04_01 VALUES LESS THAN (TO_DATE('2018-04-01', 'YYYY-MM-DD'))
)
ROW STORE COMPRESS ADVANCED
TABLESPACE IOD
]';
BEGIN
  SELECT COUNT(*) INTO l_exists FROM dba_tables WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('table_stats_hist');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement;
  END IF;
END;
/

SET LONG 40000;
SET LONGC 400 ;
SET PAGES 100;
SET LINE 200;
SET HEA OFF;
SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('table_stats_hist'), UPPER('&&1.')) table_stats_hist FROM DUAL
/
SET HEA ON;

/* ------------------------------------------------------------------------------------ */

-- tab_modifications_hist
-- create repository, partitioned and compressed
-- code preserves 2 months of data
DECLARE
  l_exists NUMBER;
  l_sql_statement VARCHAR2(32767) := q'[
CREATE TABLE &&1..tab_modifications_hist (
  pdb_name                       VARCHAR2(128),
  owner                          VARCHAR2(128),
  table_name                     VARCHAR2(128),
  last_analyzed                  DATE,
  num_rows                       NUMBER,
  timestamp                      DATE,
  inserts                        NUMBER,
  updates                        NUMBER,
  deletes                        NUMBER,
  truncated                      VARCHAR2(3),
  drop_segments                  NUMBER,
  con_id                         NUMBER
)
PARTITION BY RANGE (timestamp)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
PARTITION before_2017_12_01 VALUES LESS THAN (TO_DATE('2017-12-01', 'YYYY-MM-DD')),
PARTITION before_2018_01_01 VALUES LESS THAN (TO_DATE('2018-01-01', 'YYYY-MM-DD')),
PARTITION before_2018_02_01 VALUES LESS THAN (TO_DATE('2018-02-01', 'YYYY-MM-DD')),
PARTITION before_2018_03_01 VALUES LESS THAN (TO_DATE('2018-03-01', 'YYYY-MM-DD')),
PARTITION before_2018_04_01 VALUES LESS THAN (TO_DATE('2018-04-01', 'YYYY-MM-DD'))
)
ROW STORE COMPRESS ADVANCED
TABLESPACE IOD
]';
BEGIN
  SELECT COUNT(*) INTO l_exists FROM dba_tables WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('tab_modifications_hist');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement;
  END IF;
END;
/

SET LONG 40000;
SET LONGC 400 ;
SET PAGES 100;
SET LINE 200;
SET HEA OFF;
SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('tab_modifications_hist'), UPPER('&&1.')) tab_modifications_hist FROM DUAL
/
SET HEA ON;

/* ------------------------------------------------------------------------------------ */

-- segments_hist
-- create repository, partitioned and compressed
-- code preserves 2 months of data
DECLARE
  l_exists NUMBER;
  l_sql_statement VARCHAR2(32767) := q'[
CREATE TABLE &&1..segments_hist (
  pdb_name                       VARCHAR2(128),
  owner                          VARCHAR2(128),
  segment_name                   VARCHAR2(128),
  partition_name                 VARCHAR2(128),
  segment_type                   VARCHAR2(18),
  tablespace_name                VARCHAR2(30),
  bytes                          NUMBER,
  blocks                         NUMBER,
  extents                        NUMBER,
  snap_time                      DATE,
  con_id                         NUMBER
)
PARTITION BY RANGE (snap_time)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
PARTITION before_2017_12_01 VALUES LESS THAN (TO_DATE('2017-12-01', 'YYYY-MM-DD')),
PARTITION before_2018_01_01 VALUES LESS THAN (TO_DATE('2018-01-01', 'YYYY-MM-DD')),
PARTITION before_2018_02_01 VALUES LESS THAN (TO_DATE('2018-02-01', 'YYYY-MM-DD')),
PARTITION before_2018_03_01 VALUES LESS THAN (TO_DATE('2018-03-01', 'YYYY-MM-DD')),
PARTITION before_2018_04_01 VALUES LESS THAN (TO_DATE('2018-04-01', 'YYYY-MM-DD'))
)
ROW STORE COMPRESS ADVANCED
TABLESPACE IOD
]';
BEGIN
  SELECT COUNT(*) INTO l_exists FROM dba_tables WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('segments_hist');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement;
  END IF;
END;
/

SET LONG 40000;
SET LONGC 400 ;
SET PAGES 100;
SET LINE 200;
SET HEA OFF;
SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('segments_hist'), UPPER('&&1.')) segments_hist FROM DUAL
/
SET HEA ON;

/* ------------------------------------------------------------------------------------ */

-- lob_hist
-- create repository, partitioned and compressed
-- code preserves 2 months of data
DECLARE
  l_exists NUMBER;
  l_sql_statement VARCHAR2(32767) := q'[
 CREATE TABLE &&1..lobs_hist (   
    pdb_name                    VARCHAR2(128),
    OWNER						            VARCHAR2(128),
    TABLE_NAME				          VARCHAR2(128),
    COLUMN_NAME			            VARCHAR2(4000),
    SEGMENT_NAME			          VARCHAR2(128),
    TABLESPACE_NAME	            VARCHAR2(30),
    INDEX_NAME				          VARCHAR2(128),
    CHUNK						            NUMBER,
    PCTVERSION				          NUMBER,
    RETENTION				            NUMBER,
    FREEPOOLS				            NUMBER,
    CACHE						            VARCHAR2(10),
    LOGGING					            VARCHAR2(7),
    ENCRYPT					            VARCHAR2(4),
    COMPRESSION			            VARCHAR2(6),
    DEDUPLICATION		            VARCHAR2(15),
    IN_ROW 					            VARCHAR2(3),
    FORMAT 					            VARCHAR2(15),
    PARTITIONED			            VARCHAR2(3),
    SECUREFILE				          VARCHAR2(3),
    SEGMENT_CREATED	            VARCHAR2(3),
    RETENTION_TYPE 	            VARCHAR2(7),
    RETENTION_VALUE	            NUMBER,
    snap_time                    DATE,
    CON_ID 					            NUMBER
)
PARTITION BY RANGE (snap_time)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
PARTITION before_2017_12_01 VALUES LESS THAN (TO_DATE('2017-12-01', 'YYYY-MM-DD')),
PARTITION before_2018_01_01 VALUES LESS THAN (TO_DATE('2018-01-01', 'YYYY-MM-DD')),
PARTITION before_2018_02_01 VALUES LESS THAN (TO_DATE('2018-02-01', 'YYYY-MM-DD')),
PARTITION before_2018_03_01 VALUES LESS THAN (TO_DATE('2018-03-01', 'YYYY-MM-DD')),
PARTITION before_2018_04_01 VALUES LESS THAN (TO_DATE('2018-04-01', 'YYYY-MM-DD'))
)
ROW STORE COMPRESS ADVANCED
TABLESPACE IOD
]';
BEGIN
  SELECT COUNT(*) INTO l_exists FROM dba_tables WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('lobs_hist');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement;
  END IF;
END;
/

SET LONG 40000;
SET LONGC 400 ;
SET PAGES 100;
SET LINE 200;
SET HEA OFF;
SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('lobs_hist'), UPPER('&&1.')) lobs_hist FROM DUAL
/
SET HEA ON;

/* ------------------------------------------------------------------------------------ */

-- tablespaces_hist
-- create repository, partitioned and compressed
-- code preserves 2 months of data
DECLARE
  l_exists NUMBER;
  l_sql_statement VARCHAR2(32767) := q'[
CREATE TABLE &&1..tablespaces_hist (
  pdb_name                       VARCHAR2(128),
  tablespace_name                VARCHAR2(30),
  contents                       VARCHAR2(9),
  oem_allocated_space_mbs        NUMBER,
  oem_used_space_mbs             NUMBER,
  oem_used_percent               NUMBER, -- as per allocated space
  met_max_size_mbs               NUMBER,
  met_used_space_mbs             NUMBER,
  met_used_percent               NUMBER, -- as per maximum size (considering auto extend)
  snap_time                      DATE,
  con_id                         NUMBER
)
PARTITION BY RANGE (snap_time)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
PARTITION before_2017_12_01 VALUES LESS THAN (TO_DATE('2017-12-01', 'YYYY-MM-DD')),
PARTITION before_2018_01_01 VALUES LESS THAN (TO_DATE('2018-01-01', 'YYYY-MM-DD')),
PARTITION before_2018_02_01 VALUES LESS THAN (TO_DATE('2018-02-01', 'YYYY-MM-DD')),
PARTITION before_2018_03_01 VALUES LESS THAN (TO_DATE('2018-03-01', 'YYYY-MM-DD')),
PARTITION before_2018_04_01 VALUES LESS THAN (TO_DATE('2018-04-01', 'YYYY-MM-DD'))
)
ROW STORE COMPRESS ADVANCED
TABLESPACE IOD
]';
BEGIN
  SELECT COUNT(*) INTO l_exists FROM dba_tables WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('tablespaces_hist');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement;
  END IF;
END;
/

SET LONG 40000;
SET LONGC 400 ;
SET PAGES 100;
SET LINE 200;
SET HEA OFF;
SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('tablespaces_hist'), UPPER('&&1.')) tablespaces_hist FROM DUAL
/
SET HEA ON;

/* ------------------------------------------------------------------------------------ */

-- index_rebuild_hist
-- create repository, partitioned and compressed
-- code preserves 2 months of data
DECLARE
  l_exists NUMBER;
  l_sql_statement VARCHAR2(32767) := q'[
CREATE TABLE &&1..index_rebuild_hist (
  pdb_name                       VARCHAR2(128),
  owner                          VARCHAR2(128),
  index_name                     VARCHAR2(128),
  tablespace_name                VARCHAR2(30),
  full_scan                      VARCHAR2(1),
  ddl_statement                  VARCHAR2(512),
  error_message                  VARCHAR2(512),
  size_mbs_before                NUMBER,
  size_mbs_after                 NUMBER,  
  ddl_begin_time                 DATE,
  ddl_end_time                   DATE,
  snap_time                      DATE,
  con_id                         NUMBER
)
PARTITION BY RANGE (snap_time)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
PARTITION before_2017_12_01 VALUES LESS THAN (TO_DATE('2017-12-01', 'YYYY-MM-DD')),
PARTITION before_2018_01_01 VALUES LESS THAN (TO_DATE('2018-01-01', 'YYYY-MM-DD')),
PARTITION before_2018_02_01 VALUES LESS THAN (TO_DATE('2018-02-01', 'YYYY-MM-DD')),
PARTITION before_2018_03_01 VALUES LESS THAN (TO_DATE('2018-03-01', 'YYYY-MM-DD')),
PARTITION before_2018_04_01 VALUES LESS THAN (TO_DATE('2018-04-01', 'YYYY-MM-DD'))
)
ROW STORE COMPRESS ADVANCED
TABLESPACE IOD
]';
BEGIN
  SELECT COUNT(*) INTO l_exists FROM dba_tables WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('index_rebuild_hist');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement;
  END IF;
END;
/

SET LONG 40000;
SET LONGC 400 ;
SET PAGES 100;
SET LINE 200;
SET HEA OFF;
SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('index_rebuild_hist'), UPPER('&&1.')) index_rebuild_hist FROM DUAL
/
SET HEA ON;

/* ------------------------------------------------------------------------------------ */

-- table_redefinition_hist
-- create repository, partitioned and compressed
-- code preserves 2 months of data
DECLARE
  l_exists NUMBER;
  l_sql_statement VARCHAR2(32767) := q'[
CREATE TABLE &&1..table_redefinition_hist (
  pdb_name                       VARCHAR2(128),
  owner                          VARCHAR2(128),
  table_name                     VARCHAR2(128),
  tablespace_name                VARCHAR2(30),
  full_scan                      VARCHAR2(1),
  ddl_statement                  VARCHAR2(512),
  error_message                  VARCHAR2(512),
  table_size_mbs_before          NUMBER,
  table_size_mbs_after           NUMBER,
  index_count                    NUMBER,
  all_index_size_mbs_before      NUMBER,
  all_index_size_mbs_after       NUMBER,
  top_index_size_mbs_before      NUMBER,
  top_index_size_mbs_after       NUMBER,
  lobs_count                     NUMBER,
  all_lobs_size_mbs_before       NUMBER,
  all_lobs_size_mbs_after        NUMBER,
  ddl_begin_time                 DATE,
  ddl_end_time                   DATE,
  snap_time                      DATE,
  con_id                         NUMBER
)
PARTITION BY RANGE (snap_time)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
PARTITION before_2017_12_01 VALUES LESS THAN (TO_DATE('2017-12-01', 'YYYY-MM-DD')),
PARTITION before_2018_01_01 VALUES LESS THAN (TO_DATE('2018-01-01', 'YYYY-MM-DD')),
PARTITION before_2018_02_01 VALUES LESS THAN (TO_DATE('2018-02-01', 'YYYY-MM-DD')),
PARTITION before_2018_03_01 VALUES LESS THAN (TO_DATE('2018-03-01', 'YYYY-MM-DD')),
PARTITION before_2018_04_01 VALUES LESS THAN (TO_DATE('2018-04-01', 'YYYY-MM-DD'))
)
ROW STORE COMPRESS ADVANCED
TABLESPACE IOD
]';
  l_sql_statement2 VARCHAR2(32767) := q'[
ALTER TABLE &&1..table_redefinition_hist ADD (
  lobs_count                     NUMBER,
  all_lobs_size_mbs_before       NUMBER,
  all_lobs_size_mbs_after        NUMBER
)
]';
BEGIN
  SELECT COUNT(*) INTO l_exists FROM dba_tables WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('table_redefinition_hist');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement;
  END IF;
  SELECT COUNT(*) INTO l_exists FROM dba_tab_columns WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('table_redefinition_hist') AND column_name = UPPER('lobs_count');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement2;
  END IF;
END;
/

SET LONG 40000;
SET LONGC 400 ;
SET PAGES 100;
SET LINE 200;
SET HEA OFF;
SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('table_redefinition_hist'), UPPER('&&1.')) table_redefinition_hist FROM DUAL
/
SET HEA ON;

/* ------------------------------------------------------------------------------------ */

-- tablespace_resize_hist
-- create repository, partitioned and compressed
-- code preserves 2 months of data
DECLARE
  l_exists NUMBER;
  l_sql_statement VARCHAR2(32767) := q'[
CREATE TABLE &&1..tablespace_resize_hist (
  pdb_name                       VARCHAR2(128),
  tablespace_name                VARCHAR2(30),
  oem_allocated_gbs              NUMBER,
  oem_used_space_gbs             NUMBER,
  oem_used_percent               NUMBER, -- as per allocated space
  met_max_size_gbs               NUMBER,
  met_used_space_gbs             NUMBER,
  met_used_percent               NUMBER, -- as per maximum size (considering auto extend)
  ddl_statement                  VARCHAR2(512),
  error_message                  VARCHAR2(512),
  snap_time                      DATE,
  con_id                         NUMBER
)
PARTITION BY RANGE (snap_time)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
PARTITION before_2017_12_01 VALUES LESS THAN (TO_DATE('2017-12-01', 'YYYY-MM-DD')),
PARTITION before_2018_01_01 VALUES LESS THAN (TO_DATE('2018-01-01', 'YYYY-MM-DD')),
PARTITION before_2018_02_01 VALUES LESS THAN (TO_DATE('2018-02-01', 'YYYY-MM-DD')),
PARTITION before_2018_03_01 VALUES LESS THAN (TO_DATE('2018-03-01', 'YYYY-MM-DD')),
PARTITION before_2018_04_01 VALUES LESS THAN (TO_DATE('2018-04-01', 'YYYY-MM-DD'))
)
ROW STORE COMPRESS ADVANCED
TABLESPACE IOD
]';
BEGIN
  SELECT COUNT(*) INTO l_exists FROM dba_tables WHERE owner = UPPER(TRIM('&&1.')) AND table_name = UPPER('tablespace_resize_hist');
  IF l_exists = 0 THEN
    EXECUTE IMMEDIATE l_sql_statement;
  END IF;
END;
/

SET LONG 40000;
SET LONGC 400 ;
SET PAGES 100;
SET LINE 200;
SET HEA OFF;
SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('tablespace_resize_hist'), UPPER('&&1.')) tablespace_resize_hist FROM DUAL
/
SET HEA ON;

/* ------------------------------------------------------------------------------------ */

