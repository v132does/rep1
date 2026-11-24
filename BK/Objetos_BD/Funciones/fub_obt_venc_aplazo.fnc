create or replace function it.fub_obt_venc_aplazo(vnro_cuenta in varchar2, vfecha in date  ) return number
is
  vresult number;
  vfec_vencimiento date;
begin
  begin
    select max(fec_vencimiento)
      into vfec_vencimiento
    from (select cc.fec_vencimiento
          from ah_cta_certificados cc
          where cc.nro_cuenta = vnro_cuenta
          union all
          select p.fec_vencimiento
          from ah_cta_plazos p
          where p.nro_cuenta = vnro_cuenta);
  exception
    when others then
      vfec_vencimiento := null;
  end;
  if vfec_vencimiento is not null then
    vresult := vfec_vencimiento - vfecha;
  else
    vresult := 0;
  end if;
  return vresult;
end;
/
