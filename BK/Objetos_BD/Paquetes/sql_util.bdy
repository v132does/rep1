CREATE OR REPLACE PACKAGE BODY IT.sql_util IS
  procedure inicializa_estructura(p_estructura in out t_array,p_inicio number) is
  begin
   for i in p_inicio..20 loop
     p_estructura(i) := null;
    end loop;
  end ;
  procedure ejecute_consulta(p_sql varchar2,p_columnas number,p_filas in out number,p_ref_cursor in out T_cursor_tab,p_error out varchar2) is
    reg   t_array;
    v_result boolean;
    v_cursor number;
    v_rows   number(10) := 1;
    v_encabezado         varchar2(200) := 'encabezado';
    v_col_varchar2     varchar2(120);
    v_col_etiqueta       varchar2(200);
    v_col_informacion    varchar2(200);
    v_col_fec_vento    varchar2(200);
    v_cont            number(5) := 1;
  begin
    p_error := null;
    p_filas := 0;
    if p_columnas > 20 then
      p_error := 'El maximo nzmero de columnas para la consulta es 20';
      return;
    end if;
    if p_sql is not null and p_columnas > 0 then
    v_result := dbms_sql.is_open(v_cursor);
    if not v_result then
      v_cursor     := dbms_sql.open_cursor;
      v_result := dbms_sql.is_open(v_cursor);
      if v_result then
         dbms_sql.parse(v_cursor,p_sql,dbms_sql.native); --1 = NATIVE, 2 = V7 Y 0 = V6
         --Variables en el cursors
         for i in 1..p_columnas loop
            dbms_sql.define_column(v_cursor,i,v_col_varchar2,200);
         end loop;
         v_rows := dbms_sql.execute(v_cursor);
      end if;
    end if;
      v_rows :=  dbms_sql.fetch_rows(v_cursor);
      loop exit when v_rows = 0;
        p_filas := p_filas + 1;
        for i in 1..p_columnas loop
         dbms_sql.column_value(v_cursor,i,reg(i));
        end loop;
       inicializa_estructura(reg,p_columnas+1);
       p_ref_cursor(p_filas).columna1 := reg(1);
       p_ref_cursor(p_filas).columna2 := reg(2);
       p_ref_cursor(p_filas).columna3 := reg(3);
       p_ref_cursor(p_filas).columna4 := reg(4);
       p_ref_cursor(p_filas).columna5 := reg(5);
       p_ref_cursor(p_filas).columna6 := reg(6);
       p_ref_cursor(p_filas).columna7 := reg(7);
       p_ref_cursor(p_filas).columna8 := reg(8);
       p_ref_cursor(p_filas).columna9 := reg(9);
       p_ref_cursor(p_filas).columna10 := reg(10);
       p_ref_cursor(p_filas).columna11 := reg(11);
       p_ref_cursor(p_filas).columna12 := reg(12);
       p_ref_cursor(p_filas).columna13 := reg(13);
       p_ref_cursor(p_filas).columna14 := reg(14);
       p_ref_cursor(p_filas).columna15 := reg(15);
       p_ref_cursor(p_filas).columna16 := reg(16);
       p_ref_cursor(p_filas).columna17 := reg(17);
       p_ref_cursor(p_filas).columna18 := reg(18);
       p_ref_cursor(p_filas).columna19 := reg(19);
       p_ref_cursor(p_filas).columna20 := reg(20);
        v_rows :=  dbms_sql.fetch_rows(v_cursor);
      end loop;
     dbms_sql.close_cursor(v_cursor);
    end if;
   exception
    when others then
      dbms_sql.close_cursor(v_cursor); --- Cerrar cursor
      p_error := 'SQL_UTIL.EJECUTE_CONSULTA '||sqlerrm;
   end;
  procedure ejecute_dml(p_sql varchar2,p_error out varchar2) is
    v_cursor number;
    v_rows   number(10) := 1;
    v_result boolean;
  begin
    v_cursor     := dbms_sql.open_cursor;
    v_result := dbms_sql.is_open(v_cursor);
    if v_result then
     dbms_sql.parse(v_cursor,p_sql,dbms_sql.native); --1 = NATIVE, 2 = V7 Y 0 = V6
     v_rows := dbms_sql.execute(v_cursor);
     dbms_sql.close_cursor(v_cursor);
      null;
    else
     p_error := 'SQL_UTIL.EJECUTE_DML Imposible Abrir el Cursor';
    end if;
  exception
    when others then
       dbms_sql.close_cursor(v_cursor); --- Cerrar cursor por error
       p_error := 'SQL_UTIL.EJECUTE_DML '||sqlerrm;
  end;
  -- para ejecutar funciones dinamicas que devuelvan varchar2
  function ejecute_funcion(p_sql in varchar2)
   return long is
    /* Procesa la funcion dinamica y devuelve el valor alfanumerico */
    v_resultado        char(32767) := ''; -- debe ser definido como char (32767 es el tope).
    v_result           boolean;
    v_rows             number(10) := 1;
    v_cursor           number;
  begin
      v_cursor     := dbms_sql.open_cursor;
      v_result := dbms_sql.is_open(v_cursor);
      if v_result then
       dbms_sql.parse(v_cursor,p_sql,dbms_sql.native); --1 = NATIVE, 2 = V7 Y 0 = V6
       dbms_sql.bind_variable(v_cursor, 'r', v_resultado);
       v_rows := dbms_sql.execute(v_cursor);
       dbms_sql.variable_value(v_cursor, 'r',v_resultado);
       dbms_sql.close_cursor(v_cursor);
      else
        raise_application_error(-20000,'SQL_UTIL.EJECUTE_FUNCION: Imposible abrir el cursor. ');
      end if;
      return trim(v_resultado);
  exception
      when others then
         dbms_sql.close_cursor(v_cursor); --- Cerrar cursor por error
         raise_application_error(-20000,'SQL_UTIL.EJECUTE_FUNCION '||p_sql||' - '||sqlerrm);
  end ejecute_funcion;  
END;
/

