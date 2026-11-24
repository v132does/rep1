CREATE OR REPLACE FUNCTION IT.FUG_OBT_CAN_ACCESO ( p_fec_insercion in date,
                                                p_cod_persona varchar2
                                               )
return varchar2 is
  v_nro_caja number(10) := 0;
  v_can_cajas number(10) := 0;
  v_respuesta varchar2(50);
begin

  select count(distinct a.nro_caja)
    into v_can_cajas
    from bw_movimientos a
   where a.cod_tip_mensaje = '020'
     and a.nro_caja in (994,999)
     and trunc(a.fec_insercion) between add_months(p_fec_insercion, -2) and last_day(p_fec_insercion)
     and a.cod_per_principal = p_cod_persona;

  if v_can_cajas = 2 then
    v_respuesta := 'VARIOS CANALES';
  else
    select distinct a.nro_caja
      into v_nro_caja
      from bw_movimientos a
     where a.cod_tip_mensaje = '020'
       and a.nro_caja in (994,999)
       and trunc(a.fec_insercion) between add_months(p_fec_insercion, -2) and last_day(p_fec_insercion)
       and a.cod_per_principal = p_cod_persona;
    if v_nro_caja = 994 then
      v_respuesta:= 'MOVIL';
    elsif v_nro_caja = 999 then
      v_respuesta:= 'WEB';
    end if;
  end if;

  return v_respuesta;

  exception
    when no_data_found then
      v_respuesta:= 'NO DEFINIDO 1';
      return v_respuesta;
    when others then
      v_respuesta:= 'NO DEFINIDO 2';
      return v_respuesta;
end;
/

