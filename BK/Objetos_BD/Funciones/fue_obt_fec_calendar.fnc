CREATE OR REPLACE FUNCTION IT.FUE_OBT_FEC_CALENDAR
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE
 IS

V_FECHA DATE;

/* Objetiene la fecha de la tabla GE_CALENDARIOS */
FUNCTION LF_OBT_FEC_CALENDAR
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE;
v_tab_calendarios all_objects.object_name%type;

/* Objetiene la fecha de la tabla GE_CALENDARIOS */
FUNCTION LF_OBT_FEC_CALENDAR
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE
 IS
TYPE t_tipo_cursor IS REF CURSOR;
   c_cursor    t_tipo_cursor;
   v_sentencia varchar2(2000);
BEGIN
   v_sentencia := 'select fec_actual from ge_calendarios where cod_modulo = :p_modulo';
   open c_cursor for v_sentencia using p_cod_modulo;
   loop
      fetch c_cursor into v_fecha;
      exit when c_cursor%notfound;
   end loop;
   close c_cursor;
   if v_fecha is null then
      return sysdate;
   else
      return v_fecha;
   end if;
END;
BEGIN
   select object_name
   into v_tab_calendarios
   from all_objects
   where object_name = 'GE_CALENDARIOS'
   and object_type = 'TABLE';

   v_fecha := lf_obt_fec_calendar(p_cod_modulo);
   return v_fecha;
exception
   when no_data_found then
      return sysdate;
   when others then
        raise_application_error(-20000,
        'FUE_OBT_FEC_CALENDAR' || to_char(p_cod_modulo) || '-' || sqlerrm);
END;
/

