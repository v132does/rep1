CREATE OR REPLACE FUNCTION IT.FUG_OBT_PLZ_CONTABLE
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 )
 RETURN INTEGER
 IS
v_cod_plazo ge_plz_contables.cod_plazo%type;
BEGIN
   select cod_plazo
   into v_cod_plazo
   from ge_plz_contables
   where can_dias = (select min(can_dias) from ge_plz_contables
                     where can_dias >= (p_can_dias));

   return v_cod_plazo;
EXCEPTION
    when no_data_found then
    raise_application_error(-20000,'No existe plazo contable para ese rango de fecha');
END;
/

