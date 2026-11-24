CREATE OR REPLACE PACKAGE IT.sql_util IS
  type ref_cursor is record(
    columna1   varchar2(220),
    columna2   varchar2(220),
    columna3   varchar2(220),
    columna4   varchar2(220),
    columna5   varchar2(220),
    columna6   varchar2(220),
    columna7   varchar2(220),
    columna8   varchar2(220),
    columna9   varchar2(220),
    columna10   varchar2(220),
    columna11   varchar2(220),
    columna12   varchar2(220),
    columna13   varchar2(220),
    columna14   varchar2(220),
    columna15   varchar2(220),
    columna16   varchar2(220),
    columna17   varchar2(220),
    columna18   varchar2(220),
    columna19   varchar2(220),
    columna20   varchar2(220)
 );
  type T_cursor is ref cursor return ref_cursor;
  type T_array is table of varchar2(220) index by binary_integer;
  type T_cursor_tab is table of ref_cursor index by binary_integer;
  procedure ejecute_consulta(p_sql varchar2,p_columnas number,p_filas in out number,p_ref_cursor in out T_cursor_tab,p_error out varchar2);
  procedure ejecute_dml(p_sql varchar2,p_error out varchar2);
  function ejecute_funcion(p_sql in varchar2) return long;
END;
/

