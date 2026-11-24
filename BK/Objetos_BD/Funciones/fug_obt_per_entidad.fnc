CREATE OR REPLACE FUNCTION IT.FUG_OBT_PER_ENTIDAD
 RETURN VARCHAR2
 IS
v_cod_persona ge_par_generales.cod_persona%type;
BEGIN
   select cod_persona
   into v_cod_persona
   from ge_par_generales;
   return v_cod_persona;
exception
   when no_data_found then
     raise_application_error(-20000, 'Pers. no registrada en Par.Gral');
   when too_many_rows then
     raise_application_error(-20000, 'Par.Gral duplicado');
END;
/

