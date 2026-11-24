CREATE OR REPLACE FUNCTION IT.FUV_OBT_CTA_VENCIDA(p_nro_cta_origen in varchar2) RETURN varchar2 is
v_nro_cta_vencida varchar2(30);
begin
  select nro_cuenta
    into v_nro_cta_vencida
    from ov_cta_vencidas
   where nro_cta_origen = p_nro_cta_origen;
  return v_nro_cta_vencida;
exception
   when others then
     return null;
end;
/

