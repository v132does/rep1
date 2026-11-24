CREATE OR REPLACE FUNCTION IT.FUS_OBT_COD_MSJ_HOMEBANKING
 (P_FECHA IN DATE)
  RETURN CHAR
  IS
v_fec_periodo_1  DATE;
v_fec_periodo_7  DATE;
v_cod_msj_swift  VARCHAR2(5);
BEGIN
  -- Obtener Fecha Período 1
  BEGIN
    select distinct h.fecha
    into v_fec_periodo_1
    from ge_snp_horarios h
   where upper(h.descripcion) like '%PERIODO DE INTERCAMBIO 1%';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
    v_fec_periodo_1 := pag_cal.fu_obt_fec_actual(1);
  WHEN OTHERS THEN
    v_fec_periodo_1 := pag_cal.fu_obt_fec_actual(1);
  END;

  -- Obtener Fecha Período 7
  BEGIN
    select distinct h.fecha
    into v_fec_periodo_7
    from ge_snp_horarios h
   where upper(h.descripcion) like '%PERIODO DE INTERCAMBIO DE TARDE%';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
    v_fec_periodo_7 := pag_cal.fu_obt_fec_actual(1);
  WHEN OTHERS THEN
    v_fec_periodo_7 := pag_cal.fu_obt_fec_actual(1);
  END;

  -- Validar fechas
  if P_FECHA > v_fec_periodo_1 and P_FECHA > v_fec_periodo_7 and
     v_fec_periodo_1 = v_fec_periodo_7 then
   v_cod_msj_swift := 'MT102';
  elsif P_FECHA = v_fec_periodo_1 and P_FECHA > v_fec_periodo_7 and
     v_fec_periodo_1 > v_fec_periodo_7 then
   v_cod_msj_swift := 'MT103';
  elsif P_FECHA = v_fec_periodo_1 and P_FECHA = v_fec_periodo_7 and
     v_fec_periodo_1 = v_fec_periodo_7 then
   v_cod_msj_swift := 'MT102';
  else
     v_cod_msj_swift := 'MT103';
  end if;
  return v_cod_msj_swift;
END;
/

