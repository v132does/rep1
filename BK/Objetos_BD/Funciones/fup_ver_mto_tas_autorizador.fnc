CREATE OR REPLACE FUNCTION IT.FUP_VER_MTO_TAS_AUTORIZADOR(P_COD_MODULO    IN GE_USU_LIMITES.COD_MODULO%TYPE,
                                                           P_COD_MODALIDAD IN GE_USU_LIMITES.COD_MODALIDAD%TYPE,
                                                           P_CATEGORIA     IN GE_USU_LIMITES.CATEGORIA%TYPE,
                                                           P_PUN_TASAS     IN PR_SOL_TASAS.VAL_TASA%TYPE,
                                                           P_NRO_SOLICITUD IN PR_SOL_TASAS.NRO_SOLICITUD%TYPE)

 RETURN VARCHAR2 IS

  v_cant                      NUMBER:=0;
  v_cod_modulo                ge_cuentas.cod_modulo%TYPE;
  v_cod_modalidad             ge_cuentas.cod_modalidad%TYPE;
  v_cod_moneda                ge_cuentas.cod_moneda%TYPE;
  v_plazo                     NUMBER;
  v_monto                     ge_cuentas.sal_promedio%TYPE;
  v_tas_minima                ge_tas_fechas.val_tasa%TYPE;
  v_tas_maxima                ge_tas_fechas.val_tasa%TYPE;
  v_tas_interes               ge_tas_fechas.val_tasa%TYPE;
  v_tas_efectiva              cr_piz_plazos.tas_efectiva%TYPE;
  v_cod_sub_modalidad         ge_cuentas.cod_sub_modalidad%TYPE;
  --- Recuperar usuarios que pueden visualizar
  cursor c_usuarios is
    select g.cod_usuario, g.categoria
      from ge_usu_limites g
     where nvl(g.cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
       and nvl(g.cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
       and ABS(v_tas_interes - P_PUN_TASAS) <= G.PUN_TASAS
       and g.pun_tasas is not null;
BEGIN
  --recuperar datos de la solicitud
  select pr.cod_modulo,pr.cod_modalidad,pr.cod_moneda,pr.dia_plazo,pr.monto,pr.cod_sub_modalidad
    into v_cod_modulo,v_cod_modalidad,v_cod_moneda,v_plazo,v_monto,v_cod_sub_modalidad
    from pr_solicitudes pr
   where pr.nro_solicitud = P_NRO_SOLICITUD;

  -- recuperar tasa pizarra
     PAP_PRE.PR_OBT_TAS_PIZARRA(v_cod_modulo,
                                v_cod_modalidad,
                                v_cod_moneda,
                                v_plazo,
                                v_monto,
                                null,
                                v_tas_minima,
                                v_tas_maxima,
                                v_tas_interes,
                                v_tas_efectiva,
                                v_cod_sub_modalidad);

  for i in c_usuarios loop
    if i.cod_usuario is not null then
      if i.cod_usuario = user then
        v_cant := 1;
      end if;
    elsif i.categoria is not null then
      if i.categoria = P_CATEGORIA then
        v_cant := 1;
      end if;
    end if;
  end loop;

  if v_cant = 0 then
    return 'N';
  else
    return 'S';
  end if;
EXCEPTION
  when others then
    return 'N';
END;
/

