CREATE OR REPLACE FUNCTION IT.fug_obt_nom_grupo
  (P_COD_GRUPO IN NUMBER)     --- Grupo
  return varchar2 is
v_grupo wf_grupos.descripcion%type;
--- Devuelve el nombre del grupo
begin
  select descripcion
    into v_grupo
    from wf_grupos
   where cod_grupo = p_cod_grupo;

  return(v_grupo);
exception
  when no_data_found then
    return null;
  when too_many_rows then
    return null;
  when others then
     return null;
end FUG_OBT_NOM_GRUPO;
/

