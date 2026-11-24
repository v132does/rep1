CREATE OR REPLACE FUNCTION IT."FUG_OBT_NOM_CAMPANA"
  (P_COD_PERSONA IN VARCHAR2)     --- Persona
  return varchar2 is
v_campana cr_campanas.descripcion%type;
-- Devuelve el nombre de la campaña asignada al cliente
begin
  select VAL_PARAMETRO
    into v_campana
    from ba_per_dat_adicionales
   where parametro='NOM_CAMPANA'
     and cod_persona = p_cod_persona;

  return(v_campana);
exception
  when no_data_found then
    return null;
  when too_many_rows then
    return null;
  when others then
     return null;
end FUG_OBT_NOM_CAMPANA;
/

