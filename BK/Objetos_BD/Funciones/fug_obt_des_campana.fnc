create or replace function it.fug_obt_des_campana(p_cod_campana in number) --- codigo de campaña
 return varchar2 is
  v_campana cr_campanas.descripcion%type;
  -- Devuelve la descripción de la campaña
begin
  select descripcion
    into v_campana
    from cr_campanas
   where cod_campana = p_cod_campana;
  return(v_campana);
exception
  when no_data_found then
    return null;
  when too_many_rows then
    return null;
  when others then
    return null;
end fug_obt_des_campana;
/

