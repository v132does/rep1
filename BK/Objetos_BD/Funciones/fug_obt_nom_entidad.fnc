CREATE OR REPLACE FUNCTION IT.FUG_OBT_NOM_ENTIDAD
 RETURN VARCHAR2
 IS
v_nom_entidad ge_par_generales.nom_entidad%type;
BEGIN
   select nom_entidad
   into v_nom_entidad
   from ge_par_generales;
   return v_nom_entidad;
exception
   when no_data_found then
     raise_application_error(-20000,
     'Parámetro general no registrado');
   when too_many_rows then
     raise_application_error(-20000,
     'Parámetro general duplicado');
END;
/

