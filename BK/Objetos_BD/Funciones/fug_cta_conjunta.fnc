create or replace function it.fug_cta_conjunta(p_nro_cuenta varchar2)
  return varchar2 is
  v_conjunta varchar2(1);
begin
  begin
    select 'S'
      into v_conjunta
      from it.ge_cta_clientes p
     where p.nro_cuenta = p_nro_cuenta
       and p.relacion = 'Y';
  exception
    when no_data_found then
      return 'N';
    when too_many_rows then
      return 'S';
    when others then
      return 'N';
  end;
  return(v_conjunta);
end fug_cta_conjunta;
/

