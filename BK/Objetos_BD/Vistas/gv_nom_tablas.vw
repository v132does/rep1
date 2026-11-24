CREATE OR REPLACE FORCE VIEW IT.GV_NOM_TABLAS AS
SELECT a.table_name tabla,
       a.comments comentario
FROM   sys.all_tab_comments a
WHERE  a.owner = 'IT'
AND a.table_type IN ('TABLE','VIEW')
AND a.table_name NOT LIKE 'MI_%'
AND a.table_name NOT LIKE 'BIN$%'
AND a.table_name NOT LIKE 'SIMGIA%';

