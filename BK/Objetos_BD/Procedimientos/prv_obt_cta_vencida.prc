create or replace procedure it.prv_obt_cta_vencida (
  p_nro_cta_origen in ov_cta_vencidas.nro_cta_origen%type,
  rp_cta_vencidas  out ov_cta_vencidas%rowtype)
is
begin
  begin
    select *
    into   rp_cta_vencidas
    from   ov_cta_vencidas v
    where  v.nro_cta_origen = p_nro_cta_origen;
  exception
    when others then
      raise_application_error(-20000,'Error al obtener Cuenta Vencida '||p_nro_cta_origen);
  end;
end;
/

