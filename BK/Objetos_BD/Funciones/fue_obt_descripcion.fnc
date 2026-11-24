create or replace function it.fue_obt_descripcion(p_tab_o_sql in varchar2, p_campo in varchar2, p_valor in varchar2)
return varchar2 is
  v_resultado        varchar2(300);
  v_sentencia        varchar(500);
  v_cursor           number;
  v_rows             number(10) := 1;
  v_filas            number(9) := 0;
  v_val_campo        varchar2(200);    -- contendra el valor del campo
  v_columnas         number(2) := 1;   -- cantidad de columnas a leer
  v_col_varchar2     varchar2(200);
  desc_t             sys.dbms_sql.desc_tab2;
  v_result           boolean;
begin
    v_sentencia := 'select descripcion from ('||p_tab_o_sql||') where '||p_campo||'='''||p_valor||'''';
    if v_sentencia is not null then
      v_result := dbms_sql.is_open(v_cursor);
      if not v_result then
        v_cursor     := dbms_sql.open_cursor;
        v_result := dbms_sql.is_open(v_cursor);
        if v_result then
         dbms_sql.parse(v_cursor,v_sentencia,dbms_sql.native); --1 = NATIVE, 2 = V7 Y 0 = V6
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
         v_resultado := /*v_resultado || '#' ||*/ nvl(v_val_campo,' ');
        end loop;
        -- leo el sigte registro
        v_rows :=  dbms_sql.fetch_rows(v_cursor);
      end loop;
      dbms_sql.close_cursor(v_cursor);
    end if;
    return v_resultado;
end;
/

