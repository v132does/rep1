create or replace function it.FUG_CAR_TAB_TMP(p_cadena    clob,
                                               p_msj_number number)  return varchar2  IS

BEGIN
  begin 
    insert into TABLE_TMP (MSJ_NUMBER, row_num, column_val)
      (Select p_msj_number, rownum nro_linea,
                    column_value linea
               from table(fug_obt_tab_registro(replace(p_cadena, chr(13)), chr(10))));
      return 'ok';
   exception
   when others then
      return '00|'||'Error al leer la cadena: '||sqlerrm;
    end;
END;
/

