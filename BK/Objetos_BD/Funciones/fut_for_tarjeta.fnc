create or replace function it.fut_for_tarjeta(p_nro_tarjeta in varchar2) return varchar2 is
  v_nro_tar_formateado varchar2(20);
begin
  -- Formatea el numero de tarjeta con espacios cada 4 caracteres...
  v_nro_tar_formateado := SUBSTR(P_NRO_TARJETA,1,4)||' '||SUBSTR(P_NRO_TARJETA, 5, 4)||' '||SUBSTR(P_NRO_TARJETA,9,4)||' '||SUBSTR(P_NRO_TARJETA, 13,4);
  return(v_nro_tar_formateado);
end fut_for_tarjeta;
/

