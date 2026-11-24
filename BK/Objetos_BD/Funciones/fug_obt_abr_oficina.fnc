create or replace function it.fug_obt_abr_oficina(p_cod_oficina in number) return varchar2 is
  v_abr_oficina ba_oficinas.sigla%type;
begin
  select a.sigla
    into v_abr_oficina
    from ba_oficinas a
   where a.cod_oficina = p_cod_oficina;
  return v_abr_oficina;
exception
when others then
     raise_application_error(-20000,'Error en fug_obt_abr_oficina :'||sqlerrm);
end fug_obt_abr_oficina;
/

