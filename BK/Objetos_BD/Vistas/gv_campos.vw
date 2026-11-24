CREATE OR REPLACE FORCE VIEW IT.GV_CAMPOS AS
SELECT a.TABLE_NAME TABLA, a.COLUMN_ID COD_COLUMNA, A.COLUMN_NAME columna, A.DATA_TYPE tipo_de_dato,
DECODE(A.DATA_TYPE,'NUMBER',A.DATA_PRECISION,
                   'VARCHAR2',A.CHAR_LENGTH,
                   'DATE',8,
                   A.DATA_LENGTH) longitud,
A.DATA_SCALE decimales, decode(A.NULLABLE,'N','N','S') soporta_nulo, b.COMMENTS Comentario
FROM   ALL_TAB_COLUMNS A, all_col_comments b
WHERE  a.OWNER = 'IT'
and    a.TABLE_NAME = b.TABLE_NAME
and    a.OWNER = b.OWNER
and    a.COLUMN_NAME = b.COLUMN_NAME
order by a.TABLE_NAME, a.COLUMN_ID;

