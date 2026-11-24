create or replace function it.FUJ_CIE_CAJA(
      p_nro_operacion in varchar2,     -- Nro de operacion del Cajero
      p_nro_caja in varchar2)          -- Nro de Caja

return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;    -- Caja
  v_cod_modalidad number(3) := 91; -- Caja
  v_cod_usuario varchar2(10) := upper(user);  -- usuario es el que se conecta
  --
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_usu_responsable varchar2(10); -- usuario responsable de la caja
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
 begin
  --si todo fue ok, actualizar el indicador de cajero presente
  if p_nro_caja is not null then
    update cj_cajas
       set presente = 'N'
     where nro_caja = p_nro_caja;
  end if;
  -- armo finalmente los datos, si hubo o no errores
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta;
  return(v_msj_salida);
end FUJ_CIE_CAJA;
/

