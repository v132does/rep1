create or replace function it.FUJ_PRO_VAL_POSIBLES
  (p_sql in varchar2, p_con_cabecera in varchar2 default 'S')
 return long is
  /* Procesa la sentencia sql y devuela el mensaje armado con los datos */
  v_resultado long := '';
  v_result           boolean;
  v_cursor           number;
  v_rows             number(10) := 1;
  v_filas            number(9) := 0;
  v_val_campo        varchar2(200);    -- contendra el valor del campo
  v_columnas         number(2) := 2;   -- cantidad de columnas a leer
  v_col_varchar2     varchar2(200);
  v_encabezado       varchar2(400) := ''; -- contendra el encabezado
  v_pos              number := InStr(upper(p_sql), 'FROM');
  desc_t             sys.dbms_sql.desc_tab2;
begin
    if p_sql is null or instr(p_sql,'&') > 0 then
       return ('X'); -- sin datos o con valores no reemplazados
    end if;
    --  obtengo la cantidad de columnas de la sentencia select y el encabezado formateado
    prj_obt_tit_columnas(p_sql, v_columnas, v_encabezado);
    if v_columnas <= 0 then -- retorno sin datos
      return('X');
    end if;
    if p_sql is not null and v_columnas > 0 then
    v_result := dbms_sql.is_open(v_cursor);
    if not v_result then
      v_cursor     := dbms_sql.open_cursor;
      v_result := dbms_sql.is_open(v_cursor);
      if v_result then
       dbms_sql.parse(v_cursor,replace(substr(p_sql,1,v_pos),'%','')||substr(p_sql,v_pos+1),dbms_sql.native); --1 = NATIVE, 2 = V7 Y 0 = V6
       v_rows := dbms_sql.execute(v_cursor);
       dbms_sql.describe_columns2(v_cursor, v_columnas, desc_t);
       --Variables en el cursors
       for i in 1..v_columnas loop
         dbms_sql.define_column(v_cursor,i,v_col_varchar2,200);
       end loop;
     end if;
    end if;
      -- ciclo de lectura de registros
      v_rows :=  dbms_sql.fetch_rows(v_cursor);
      loop exit when v_rows = 0;
        v_filas := v_filas + 1;
        for i in 1..v_columnas loop
         dbms_sql.column_value(v_cursor,i,v_val_campo);
         v_resultado := v_resultado || '#' || nvl(v_val_campo,' ');
        end loop;
        -- leo el sigte registro
        v_rows :=  dbms_sql.fetch_rows(v_cursor);
      end loop;
     dbms_sql.close_cursor(v_cursor);
    end if;
    -- agrego los datos de cantidad de columnas y filas al resultado
    if v_filas = 0 then
       v_resultado := 'X';
    else
       if NVL(p_con_cabecera,'S') = 'S' then
         v_resultado := ltrim(to_char(v_columnas,'99')) || '#' || -- cant de columnas
                        ltrim(to_char(v_filas,'9999'))  || -- cant de filas
                        v_encabezado || -- titulos formateado
                        v_resultado;  -- datos de los registros
       else
         v_resultado := v_resultado;  -- solo los datos de los registros
       end if;
    end if;
    -- retorna el resultado
    return(v_resultado);
exception
   when others then
      return ('X'); -- se retorna como si no existiera
      --return ('SQL_UTIL.EJECUTE_CONSULTA '||sqlerrm);
end FUJ_PRO_VAL_POSIBLES;
/

