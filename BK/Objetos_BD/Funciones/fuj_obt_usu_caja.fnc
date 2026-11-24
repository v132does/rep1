create or replace function it.fuj_obt_usu_caja(p_nro_caja in number) return varchar2 is
  v_cod_usuario varchar2(10);
begin
  select a.cod_usuario
    into v_cod_usuario
    from cj_cajas a
   where a.nro_caja = p_nro_caja;
  return v_cod_usuario;
exception
when others then
     raise_application_error(-20000,'Error en fuj_obt_usu_caja :'||sqlerrm);
end fuj_obt_usu_caja;
/

