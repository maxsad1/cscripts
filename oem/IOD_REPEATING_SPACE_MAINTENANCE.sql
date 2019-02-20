----------------------------------------------------------------------------------------
--
-- File name:   OEM IOD_REPEATING_SPACE_MAINTENANCE
--
-- Purpose:     Purge Recyclebin and performs Online Table Redefinition
--
-- Frequency:   Mondays at 4PM UTC
--
-- Author:      Carlos Sierra
--
-- Version:     2019/02/04
--
-- Usage:       Execute connected into CDB 
--
-- Example:     $ sqlplus / as sysdba
--              SQL> @IOD_REPEATING_SPACE_MAINTENANCE.sql
--
-- Notes:       Table Redefinition is only done on tables within a size range.
--              Some tables are excluded as per exceptions_black_list.
--              Exclude one specific table: 
--                INSERT INTO c##iod.exceptions_black_list (iod_api, pdb_name, owner, table_name, reference) 
--                VALUES ('TABLE_REDEFINITION', 'FLAMINGO_OPS', 'KIEVUSER', 'HISTORICALASSIGNMENT', 'IOD-12345');
--              Exclude one specific owner: 
--                INSERT INTO c##iod.exceptions_black_list (iod_api, pdb_name, owner, reference) 
--                VALUES ('TABLE_REDEFINITION', 'FLAMINGO_OPS', 'KIEVUSER', 'IOD-12345');
--              Exclude one specific pdb: 
--                INSERT INTO c##iod.exceptions_black_list (iod_api, pdb_name, reference) 
--                VALUES ('TABLE_REDEFINITION', 'FLAMINGO_OPS', 'IOD-12345');
--              Exclude one table for all pdbs: 
--                INSERT INTO c##iod.exceptions_black_list (iod_api, table_name, reference) 
--                VALUES ('TABLE_REDEFINITION', 'HISTORICALASSIGNMENT', 'IOD-12345');
--
---------------------------------------------------------------------------------------
--
-- to use these parameters below, uncomment also the call to c##iod.iod_space.purge_recyclebin and c##iod.iod_space.table_redefinition that references them
DEF report_only = 'N';
DEF only_if_ref_by_full_scans = 'Y';
DEF min_size_mb = '10';
DEF max_size_gb = '100';
DEF min_savings_perc = '25';
DEF min_ts_used_percent = '85';
DEF preserve_recyclebin_days = '8';
DEF min_obj_age_days = '8';
DEF sleep_seconds = '120';
DEF timeout_hours = '4';
DEF pdb_name = '';
--
-- exit graciously if executed on standby
WHENEVER SQLERROR EXIT SUCCESS;
DECLARE
  l_open_mode VARCHAR2(20);
BEGIN
  SELECT open_mode INTO l_open_mode FROM v$database;
  IF l_open_mode <> 'READ WRITE' THEN
    raise_application_error(-20000, 'Not PRIMARY');
  END IF;
END;
/
-- exit graciously if executed on excluded host
WHENEVER SQLERROR EXIT SUCCESS;
DECLARE
  l_host_name VARCHAR2(64);
BEGIN
  SELECT host_name INTO l_host_name FROM v$instance;
  IF LOWER(l_host_name) LIKE CHR(37)||'casper'||CHR(37) OR 
     LOWER(l_host_name) LIKE CHR(37)||'control-plane'||CHR(37) OR 
     LOWER(l_host_name) LIKE CHR(37)||'omr'||CHR(37) OR 
     LOWER(l_host_name) LIKE CHR(37)||'oem'||CHR(37) OR 
     LOWER(l_host_name) LIKE CHR(37)||'telemetry'||CHR(37)
  THEN
    raise_application_error(-20000, '*** Excluded host: "'||l_host_name||'" ***');
  END IF;
END;
/
-- exit graciously if executed on unapproved database
WHENEVER SQLERROR EXIT SUCCESS;
DECLARE
  l_db_name VARCHAR2(9);
BEGIN
  SELECT name INTO l_db_name FROM v$database;
  IF UPPER(l_db_name) LIKE 'DBE'||CHR(37) OR 
     UPPER(l_db_name) LIKE 'DBTEST'||CHR(37) OR 
     UPPER(l_db_name) LIKE 'IOD'||CHR(37) OR 
     UPPER(l_db_name) LIKE 'KIEV'||CHR(37) OR 
     UPPER(l_db_name) LIKE 'LCS'||CHR(37)
  THEN
    NULL;
  ELSE
    raise_application_error(-20000, '*** Unapproved database: "'||l_db_name||'" ***');
  END IF;
END;
/
-- exit graciously if executed on a PDB
WHENEVER SQLERROR EXIT SUCCESS;
BEGIN
  IF SYS_CONTEXT('USERENV', 'CON_NAME') <> 'CDB$ROOT' THEN
    raise_application_error(-20000, '*** Within PDB "'||SYS_CONTEXT('USERENV', 'CON_NAME')||'" ***');
  END IF;
END;
/
-- exit not graciously if any error
WHENEVER SQLERROR EXIT FAILURE;
--
ALTER SESSION SET nls_date_format = 'YYYY-MM-DD"T"HH24:MI:SS';
ALTER SESSION SET nls_timestamp_format = 'YYYY-MM-DD"T"HH24:MI:SS';
ALTER SESSION SET tracefile_identifier = 'iod_space_maintenance';
ALTER SESSION SET STATISTICS_LEVEL = 'ALL';
ALTER SESSION SET EVENTS '10046 TRACE NAME CONTEXT FOREVER, LEVEL 8';
--
SET ECHO OFF VER OFF FEED OFF HEA OFF PAGES 0 TAB OFF LINES 300 TRIMS ON SERVEROUT ON SIZE UNLIMITED;
COL zip_file_name NEW_V zip_file_name;
COL output_file_name NEW_V output_file_name;
SELECT '/tmp/iod_space_maintenance_'||LOWER(name)||'_'||LOWER(REPLACE(SUBSTR(host_name, 1 + INSTR(host_name, '.', 1, 2), 30), '.', '_')) zip_file_name FROM v$database, v$instance;
SELECT '&&zip_file_name._'||TO_CHAR(SYSDATE, '"d"d"_h"hh24') output_file_name FROM DUAL;
COL trace_file NEW_V trace_file;
--
SPO &&output_file_name..txt;
SELECT value trace_file FROM v$diag_info WHERE name = 'Default Trace File';
PRO
PRO &&output_file_name..txt;
PRO
PRO /* ------------------------------------------------------------------------------------ */
PRO
SET RECSEP OFF;
PRO
CLEAR BREAK COMPUTE;
COL pdb_tablespace_name1 FOR A35 HEA 'PDB|TABLESPACE_NAME';
COL pdb_tablespace_name2 FOR A35 HEA 'PDB|TABLESPACE_NAME';
COL used_space_gbs1 FOR 999,990.000 HEA 'USED_SPACE|(GBs)';
COL used_space_gbs2 FOR 999,990.000 HEA 'USED_SPACE|(GBs)';
COL used_space_gbs FOR 999,990.000;
COL max_size_gbs1 FOR 999,990.000 HEA 'MAX_SIZE|(GBs)';
COL max_size_gbs2 FOR 999,990.000 HEA 'MAX_SIZE|(GBs)';
COL used_percent1 FOR 990.000 HEA 'USED|PERCENT';
COL used_percent2 FOR 990.000 HEA 'USED|PERCENT';
PRO
BREAK ON REPORT;
COMPUTE SUM LABEL 'TOTAL' OF used_space_gbs1 max_size_gbs1 used_space_gbs2 max_size_gbs2 ON REPORT; 
PRO
WITH 
t AS (
SELECT c.name||'('||c.con_id||')' pdb,
       m.tablespace_name,
       ROUND(m.used_percent, 3) used_percent, -- as per maximum size (considering auto extend)
       ROUND(m.used_space * t.block_size / POWER(2, 30), 3) used_space_gbs,
       ROUND(m.tablespace_size * t.block_size / POWER(2, 30), 3) max_size_gbs,
       ROW_NUMBER() OVER (ORDER BY c.name, m.tablespace_name) row_number1,
       ROW_NUMBER() OVER (ORDER BY m.used_percent DESC, m.used_space * t.block_size DESC, m.tablespace_size * t.block_size DESC) row_number2
  FROM cdb_tablespace_usage_metrics m,
       cdb_tablespaces t,
       v$containers c
 WHERE t.con_id = m.con_id
   AND t.tablespace_name = m.tablespace_name
   AND t.status = 'ONLINE'
   AND t.contents = 'PERMANENT'
   AND t.tablespace_name NOT IN ('SYSTEM', 'SYSAUX')
   AND c.con_id = m.con_id
   AND c.open_mode = 'READ WRITE'
)
SELECT t1.pdb||CHR(10)||'   '||
       t1.tablespace_name pdb_tablespace_name1,
       t1.used_percent used_percent1,
       t1.used_space_gbs used_space_gbs1,
       t1.max_size_gbs max_size_gbs1,
       '|'||CHR(10)||'|' "|",
       t2.used_percent used_percent2,
       t2.used_space_gbs used_space_gbs2,
       t2.max_size_gbs max_size_gbs2,
       t2.pdb||CHR(10)||'   '||
       t2.tablespace_name pdb_tablespace_name2
  FROM t t1, t t2
 WHERE t1.row_number1 = t2.row_number2
 ORDER BY
       t1.row_number1
/
PRO
CLEAR BREAK COMPUTE;
SET RECSEP WR;
PRO
PRO /* ------------------------------------------------------------------------------------ */
PRO
PRO Application Tablespaces pro-active resizing
PRO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--EXEC c##iod.iod_space.tablespaces_resize;
PRO
PRO /* ------------------------------------------------------------------------------------ */
PRO
PRO CDB Application Space (begin)
PRO ~~~~~~~~~~~~~~~~~~~~~
SELECT ROUND(SUM(m.used_space * t.block_size) / POWER(2, 30), 3) used_space_gbs
  FROM cdb_tablespace_usage_metrics m,
       cdb_tablespaces t,
       v$containers c
 WHERE t.con_id = m.con_id
   AND t.tablespace_name = m.tablespace_name
   AND t.status = 'ONLINE'
   AND t.contents = 'PERMANENT'
   AND t.tablespace_name NOT IN ('SYSTEM', 'SYSAUX')
   AND c.con_id = m.con_id
   AND c.open_mode = 'READ WRITE'
/
PRO
PRO /* ------------------------------------------------------------------------------------ */
PRO
PRO c##iod.iod_space.purge_recyclebin
PRO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PRO
PRO Segments in recyclebin (before)
PRO ~~~~~~~~~~~~~~~~~~~~~~
SELECT COUNT(*) 
  FROM cdb_segments
 WHERE segment_name LIKE 'BIN$'||CHR(37)
/
PRO
--EXEC c##iod.iod_space.purge_recyclebin(p_preserve_recyclebin_days => '&&preserve_recyclebin_days.', p_timeout => SYSDATE + (&&timeout_hours./24));
EXEC c##iod.iod_space.purge_recyclebin;
PRO
PRO Segments in recyclebin (after)
PRO ~~~~~~~~~~~~~~~~~~~~~~
SELECT COUNT(*) 
  FROM cdb_segments
 WHERE segment_name LIKE 'BIN$'||CHR(37)
/
PRO
PRO /* ------------------------------------------------------------------------------------ */
PRO
PRO CDB Application Space (so far)
PRO ~~~~~~~~~~~~~~~~~~~~~
SELECT ROUND(SUM(m.used_space * t.block_size) / POWER(2, 30), 3) used_space_gbs
  FROM cdb_tablespace_usage_metrics m,
       cdb_tablespaces t,
       v$containers c
 WHERE t.con_id = m.con_id
   AND t.tablespace_name = m.tablespace_name
   AND t.status = 'ONLINE'
   AND t.contents = 'PERMANENT'
   AND t.tablespace_name NOT IN ('SYSTEM', 'SYSAUX')
   AND c.con_id = m.con_id
   AND c.open_mode = 'READ WRITE'
/
PRO
PRO /* ------------------------------------------------------------------------------------ */
PRO
PRO c##iod.iod_space.table_redefinition
PRO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PRO
--EXEC c##iod.iod_space.table_redefinition(p_report_only => '&&report_only.', p_only_if_ref_by_full_scans => '&&only_if_ref_by_full_scans.', p_min_size_mb => TO_NUMBER('&&min_size_mb.'), p_max_size_gb => TO_NUMBER('&&max_size_gb.'), p_min_savings_perc => TO_NUMBER('&&min_savings_perc.'), p_min_ts_used_percent => TO_NUMBER('&&min_ts_used_percent.'), p_min_obj_age_days => TO_NUMBER('&&min_obj_age_days.'), p_sleep_seconds => TO_NUMBER('&&sleep_seconds.'), p_timeout => SYSDATE + (&&timeout_hours./24));
EXEC c##iod.iod_space.table_redefinition(p_report_only => '&&report_only.');
PRO
PRO /* ------------------------------------------------------------------------------------ */
PRO
PRO CDB Application Space (so far)
PRO ~~~~~~~~~~~~~~~~~~~~~
SELECT ROUND(SUM(m.used_space * t.block_size) / POWER(2, 30), 3) used_space_gbs
  FROM cdb_tablespace_usage_metrics m,
       cdb_tablespaces t,
       v$containers c
 WHERE t.con_id = m.con_id
   AND t.tablespace_name = m.tablespace_name
   AND t.status = 'ONLINE'
   AND t.contents = 'PERMANENT'
   AND t.tablespace_name NOT IN ('SYSTEM', 'SYSAUX')
   AND c.con_id = m.con_id
   AND c.open_mode = 'READ WRITE'
/
PRO
PRO /* ------------------------------------------------------------------------------------ */
PRO
--  PRO c##iod.iod_space.index_rebuild
--  PRO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--  PRO
--  PRO Skipping Online Index Rebuild as per CHANGE-85783
--  EXEC c##iod.iod_space.index_rebuild(p_report_only => '&&report_only.', p_only_if_ref_by_full_scans => '&&only_if_ref_by_full_scans.', p_min_size_mb => TO_NUMBER('&&min_size_mb.'), p_max_size_gb => TO_NUMBER('&&max_size_gb.'), p_min_savings_perc => TO_NUMBER('&&min_savings_perc.'), p_min_obj_age_days => TO_NUMBER('&&min_obj_age_days.'), p_sleep_seconds => TO_NUMBER('&&sleep_seconds.'), p_timeout => SYSDATE + (&&timeout_hours./24));
--  PRO
--  PRO /* ------------------------------------------------------------------------------------ */
--  PRO
--  PRO CDB Application Space (end)
--  PRO ~~~~~~~~~~~~~~~~~~~~~
--  SELECT ROUND(SUM(m.used_space * t.block_size) / POWER(2, 30), 3) used_space_gbs
--    FROM cdb_tablespace_usage_metrics m,
--         cdb_tablespaces t,
--         v$containers c
--   WHERE t.con_id = m.con_id
--     AND t.tablespace_name = m.tablespace_name
--     AND t.status = 'ONLINE'
--     AND t.contents = 'PERMANENT'
--     AND t.tablespace_name NOT IN ('SYSTEM', 'SYSAUX')
--     AND c.con_id = m.con_id
--     AND c.open_mode = 'READ WRITE'
--  /
--  PRO
--  PRO /* ------------------------------------------------------------------------------------ */
--  PRO
SET RECSEP OFF;
PRO
CLEAR BREAK COMPUTE;
COL pdb_tablespace_name1 FOR A35 HEA 'PDB|TABLESPACE_NAME';
COL pdb_tablespace_name2 FOR A35 HEA 'PDB|TABLESPACE_NAME';
COL used_space_gbs1 FOR 999,990.000 HEA 'USED_SPACE|(GBs)';
COL used_space_gbs2 FOR 999,990.000 HEA 'USED_SPACE|(GBs)';
COL max_size_gbs1 FOR 999,990.000 HEA 'MAX_SIZE|(GBs)';
COL max_size_gbs2 FOR 999,990.000 HEA 'MAX_SIZE|(GBs)';
COL used_percent1 FOR 990.000 HEA 'USED|PERCENT';
COL used_percent2 FOR 990.000 HEA 'USED|PERCENT';
PRO
BREAK ON REPORT;
COMPUTE SUM LABEL 'TOTAL' OF used_space_gbs1 max_size_gbs1 used_space_gbs2 max_size_gbs2 ON REPORT; 
PRO
WITH 
t AS (
SELECT c.name||'('||c.con_id||')' pdb,
       m.tablespace_name,
       ROUND(m.used_percent, 3) used_percent, -- as per maximum size (considering auto extend)
       ROUND(m.used_space * t.block_size / POWER(2, 30), 3) used_space_gbs,
       ROUND(m.tablespace_size * t.block_size / POWER(2, 30), 3) max_size_gbs,
       ROW_NUMBER() OVER (ORDER BY c.name, m.tablespace_name) row_number1,
       ROW_NUMBER() OVER (ORDER BY m.used_percent DESC, m.used_space * t.block_size DESC, m.tablespace_size * t.block_size DESC) row_number2
  FROM cdb_tablespace_usage_metrics m,
       cdb_tablespaces t,
       v$containers c
 WHERE t.con_id = m.con_id
   AND t.tablespace_name = m.tablespace_name
   AND t.status = 'ONLINE'
   AND t.contents = 'PERMANENT'
   AND t.tablespace_name NOT IN ('SYSTEM', 'SYSAUX')
   AND c.con_id = m.con_id
   AND c.open_mode = 'READ WRITE'
)
SELECT t1.pdb||CHR(10)||'   '||
       t1.tablespace_name pdb_tablespace_name1,
       t1.used_percent used_percent1,
       t1.used_space_gbs used_space_gbs1,
       t1.max_size_gbs max_size_gbs1,
       '|'||CHR(10)||'|' "|",
       t2.used_percent used_percent2,
       t2.used_space_gbs used_space_gbs2,
       t2.max_size_gbs max_size_gbs2,
       t2.pdb||CHR(10)||'   '||
       t2.tablespace_name pdb_tablespace_name2
  FROM t t1, t t2
 WHERE t1.row_number1 = t2.row_number2
 ORDER BY
       t1.row_number1
/
PRO
CLEAR BREAK COMPUTE;
SET RECSEP WR;
PRO
PRO /* ------------------------------------------------------------------------------------ */
PRO
PRO &&output_file_name..txt;
PRO
SELECT value trace_file FROM v$diag_info WHERE name = 'Default Trace File';
SPO OFF;
--
--HOS tkprof &&trace_file. &&output_file_name._tkprof_nosort.txt
HOS tkprof &&trace_file. &&output_file_name._tkprof_sort.txt sort=exeela,fchela
HOS zip -mj &&zip_file_name..zip &&output_file_name.*.txt
HOS unzip -l &&zip_file_name..zip
--
ALTER SESSION SET STATISTICS_LEVEL = 'TYPICAL';
ALTER SESSION SET SQL_TRACE = FALSE;
--
---------------------------------------------------------------------------------------