create or replace function it.fug_obt_des_servicio(p_cod_servicio in varchar2)
  return varchar2 is
  result varchar2(500);
begin
  begin
    select initcap(t.significado)
      into result
      from ba_cod_referencias t
     where t.dominio = 'DES_OPE_COB_SER'
       and t.val_minimo = p_cod_servicio;
  exception
    when others then
      result := null;
  end;
  return(result);
exception
  when others then
    result := null;
    return(result);
end fug_obt_des_servicio;
/

