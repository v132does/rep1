CREATE OR REPLACE FORCE VIEW IT.GV_TABLAS AS
SELECT a.table_name tabla, a.comments comentario
  FROM sys.all_tab_comments a
 WHERE a.owner = 'IT'
   AND a.table_type = 'TABLE'
   AND EXISTS (SELECT 1
          FROM sys.all_tab_columns b
         WHERE b.owner = 'IT'
           AND b.table_name = a.table_name
           AND b.column_name = 'COD_PERSONA')
   AND a.table_name NOT LIKE 'MI_%'
   AND a.table_name NOT LIKE 'BIN$%'
   AND a.table_name NOT LIKE 'SIMGIA%';

