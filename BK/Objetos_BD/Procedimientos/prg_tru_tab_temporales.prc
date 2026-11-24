CREATE OR REPLACE PROCEDURE IT.PRG_TRU_TAB_TEMPORALES IS
  -- CROMEEXO-1 NAF FEB/2019
  -- Procedimiento para truncar automaticamente tablas temporales cargadas en la referencia
  v_mensaje VARCHAR2(250);
  CURSOR c_tablas is select val_minimo as tabla
      from ba_cod_referencias
      where dominio = 'TAB_TMP_ELIMINAR';
BEGIN
  FOR tab IN c_tablas LOOP
    v_mensaje := null;
    sql_util.ejecute_dml('truncate table ' || tab.tabla, v_mensaje);
    if v_mensaje is not null then
       raise_application_error(-20000, v_mensaje);
    end if;
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
     raise_application_error(-20000,'Error en PRG_TRU_TAB_TEMPORALES '|| sqlerrm);
END;
/

