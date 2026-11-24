CREATE OR REPLACE PACKAGE BODY IT.PAA_CTA IS
/* Insertar en datos en GE_CUENTAS */
PROCEDURE PRA_INS_GE_CUENTAS
 (RP_GCUEN IN GE_CUENTAS%ROWTYPE
 )
 IS
BEGIN
  insert into ge_cuentas( nro_cuenta,
                          dig_verificador,
                          denominacion,
                          cod_modulo,
                          cod_modalidad,
                          cod_oficina,
                          estado,
                          fec_cam_estado,
                          sal_contable,
                          cod_moneda,
                          fec_apertura,
                          fec_vencimiento,
                          cod_cau_cancelacion,
                          cod_tasa,
                          fre_extracto,
                          tas_personalizada,
                          tra_prohibida,
                          ret_personalizada,
                          dia_atraso,
                          max_atraso,
                          pro_atraso,
                          sal_promedio,
                          mto_mora,
                          val_tasa,
                          en_juicio,
                          fec_juicio,
                          cod_ent_juicio,
                          est_verificacion,
                          cod_sit_contable,
                          cod_sub_modalidad)
                  values( rp_gcuen.nro_cuenta,
                          rp_gcuen.dig_verificador,
                          rp_gcuen.denominacion,
                          rp_gcuen.cod_modulo,
                          rp_gcuen.cod_modalidad,
                          rp_gcuen.cod_oficina,
                          rp_gcuen.estado,
                          rp_gcuen.fec_cam_estado,
                          rp_gcuen.sal_contable,
                          rp_gcuen.cod_moneda,
                          rp_gcuen.fec_apertura,
                          rp_gcuen.fec_vencimiento,
                          rp_gcuen.cod_cau_cancelacion,
                          rp_gcuen.cod_tasa,
                          rp_gcuen.fre_extracto,
                          rp_gcuen.tas_personalizada,
                          rp_gcuen.tra_prohibida,
                          rp_gcuen.ret_personalizada,
                          rp_gcuen.dia_atraso,
                          rp_gcuen.max_atraso,
                          rp_gcuen.pro_atraso,
                          rp_gcuen.sal_promedio,
                          rp_gcuen.mto_mora,
                          rp_gcuen.val_tasa,
                          rp_gcuen.en_juicio,
                          rp_gcuen.fec_juicio,
                          rp_gcuen.cod_ent_juicio,
                          nvl(rp_gcuen.est_verificacion,'N'),
                          rp_gcuen.cod_sit_contable,
                          rp_gcuen.cod_sub_modalidad);
END;
/* Actualizar datos en GE_CUENTAS */
PROCEDURE PRA_UPD_GE_CUENTAS
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,RP_GCUEN IN GE_CUENTAS%ROWTYPE
 )
 IS
v_cod_modulo    GE_CUENTAS.COD_MODULO%TYPE;
  v_cod_modalidad GE_CUENTAS.COD_MODALIDAD%TYPE;
  v_cod_oficina   GE_CUENTAS.COD_OFICINA%TYPE;
BEGIN
  -- Bloqueo el registro
  select cod_modulo, cod_modalidad, cod_oficina
    into v_cod_modulo, v_cod_modalidad, v_cod_oficina
    from ge_cuentas
   where nro_cuenta = p_nro_cuenta
     for update nowait;
  -- Primero actualizo la pk solo si ha cambiado para que no bloquee tablas que la referencien
  IF p_nro_cuenta <> rp_gcuen.nro_cuenta THEN
    update ge_cuentas
       set nro_cuenta = rp_gcuen.nro_cuenta
     where nro_cuenta = p_nro_cuenta;
  END IF;
  --- Actualizo la uk solo si ha cambiado para que no bloquee tablas que la referencien
  IF v_cod_modulo <> rp_gcuen.cod_modulo OR
     v_cod_modalidad <> rp_gcuen.cod_modalidad OR
     v_cod_oficina <> rp_gcuen.cod_oficina THEN
    update ge_cuentas
       set cod_modulo = rp_gcuen.cod_modulo,
           cod_modalidad = rp_gcuen.cod_modalidad,
           cod_oficina = rp_gcuen.cod_oficina
     where nro_cuenta = p_nro_cuenta;
  END IF;
  -- Actualiza los datos en GE_CUENTAS
  update ge_cuentas
     set ge_cuentas.dig_verificador = rp_gcuen.dig_verificador,
         ge_cuentas.denominacion = rp_gcuen.denominacion,
         ge_cuentas.estado = rp_gcuen.estado,
         ge_cuentas.fec_cam_estado = rp_gcuen.fec_cam_estado,
         ge_cuentas.sal_contable = rp_gcuen.sal_contable,
         ge_cuentas.cod_moneda = rp_gcuen.cod_moneda,
         ge_cuentas.fec_apertura = rp_gcuen.fec_apertura,
         ge_cuentas.fec_vencimiento = rp_gcuen.fec_vencimiento,
         ge_cuentas.cod_cau_cancelacion = rp_gcuen.cod_cau_cancelacion,
         ge_cuentas.cod_tasa = rp_gcuen.cod_tasa,
         ge_cuentas.fre_extracto = rp_gcuen.fre_extracto,
         ge_cuentas.tas_personalizada = rp_gcuen.tas_personalizada,
         ge_cuentas.tra_prohibida = rp_gcuen.tra_prohibida,
         ge_cuentas.ret_personalizada = rp_gcuen.ret_personalizada,
         ge_cuentas.dia_atraso = nvl(rp_gcuen.dia_atraso, ge_cuentas.dia_atraso),
         ge_cuentas.max_atraso = nvl(rp_gcuen.max_atraso, ge_cuentas.max_atraso),
         ge_cuentas.pro_atraso = nvl(rp_gcuen.pro_atraso, ge_cuentas.pro_atraso),
         ge_cuentas.sal_promedio = nvl(rp_gcuen.sal_promedio, ge_cuentas.sal_promedio),
         ge_cuentas.mto_mora = nvl(rp_gcuen.mto_mora, ge_cuentas.mto_mora),
         ge_cuentas.val_tasa = nvl(rp_gcuen.val_tasa, ge_cuentas.val_tasa),
         ge_cuentas.en_juicio = nvl(rp_gcuen.en_juicio, ge_cuentas.en_juicio),
         ge_cuentas.fec_juicio = nvl(rp_gcuen.fec_juicio, ge_cuentas.fec_juicio),
         ge_cuentas.cod_ent_juicio = nvl(rp_gcuen.cod_ent_juicio, ge_cuentas.cod_ent_juicio),
         ge_cuentas.est_verificacion = nvl(rp_gcuen.est_verificacion,ge_cuentas.est_verificacion),
         ge_cuentas.cod_sit_contable = nvl(rp_gcuen.cod_sit_contable,ge_cuentas.cod_sit_contable),
         ge_cuentas.cod_oficina = nvl(rp_gcuen.cod_oficina,ge_cuentas.cod_oficina),
         ge_cuentas.cod_sub_modalidad = nvl(rp_gcuen.cod_sub_modalidad,ge_cuentas.cod_sub_modalidad)
   where ge_cuentas.nro_cuenta = rp_gcuen.nro_cuenta;
EXCEPTION
  when no_data_found then
     PAA_CTA.PRA_INS_GE_CUENTAS(rp_gcuen);
  when others then
    IF sqlcode = -54 THEN
      raise_application_error(-20000, 'Registro de cuenta ' || p_nro_cuenta || ' bloqueado por otro usuario.' );
    END IF;
    raise_application_error( -20000, 'Act.ge_ctas ' || sqlerrm );
END;
/* Obtiene la siguiente tasa vigente a partir de una fecha dada */
PROCEDURE PR_SIG_TASA
 (P_COD_TASA IN GE_TASAS.COD_TASA%TYPE
 ,P_COD_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN GE_TAS_FECHAS.COD_OFICINA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIO IN GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_FEC_FINAL IN DATE
 ,P_VAL_TASA OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 ,P_FEC_VIGENCIA OUT GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_FIN_TASA IN OUT VARCHAR2
 )
 IS
 v_cod_sub_modalidad number(5) := fug_obt_cod_sub_modalidad(p_nro_cuenta);
 v_cod_ente          ge_tas_fechas.cod_ente%type;
BEGIN
   IF P_NRO_CUENTA IS NOT NULL THEN
     v_cod_ente := fug_obt_ent_pag_sue(p_nro_cuenta);
   ELSE
     v_cod_ente := NULL;
   END IF;
/*Lee la menor fecha de tasa que sea mayor que la fecha de inicio en GE_TAS_FECHAS.
Si no encuentra es por que ya no volvio a cambiar*/
   P_FIN_TASA := 'N';
   SELECT MIN(fec_vigencia)
     INTO P_FEC_VIGENCIA
     FROM GE_TAS_FECHAS
    WHERE COD_TASA = P_COD_TASA
      AND (COD_MODULO = P_COD_MODULO OR COD_MODULO IS NULL)
      AND (COD_MODALIDAD = P_COD_MODALIDAD OR COD_MODALIDAD IS NULL)
      AND (COD_SUB_MODALIDAD = V_COD_SUB_MODALIDAD OR COD_SUB_MODALIDAD IS NULL)
      AND (COD_OFICINA = p_cod_oficina OR COD_OFICINA IS NULL)
      AND (COD_ENTE = v_cod_ente OR COD_ENTE IS NULL)
      AND (COD_MONEDA = P_COD_MONEDA OR COD_MONEDA IS NULL)
      AND (NRO_CUENTA = P_NRO_CUENTA OR  NRO_CUENTA IS NULL)
      AND FEC_VIGENCIA > P_FEC_INICIO;
   IF P_FEC_VIGENCIA IS NULL THEN
   	  P_FIN_TASA := 'S';
   	  P_FEC_VIGENCIA := P_FEC_FINAL + 1;
   ELSE
      BEGIN
         SELECT VAL_TASA
           INTO P_VAL_TASA
           FROM GE_TAS_FECHAS
          WHERE COD_TASA = P_COD_TASA
            AND (COD_MODULO = p_cod_modulo OR COD_MODULO IS NULL)
            AND (COD_MODALIDAD = P_COD_MODALIDAD OR COD_MODALIDAD IS NULL)
            AND (COD_SUB_MODALIDAD = V_COD_SUB_MODALIDAD OR COD_SUB_MODALIDAD IS NULL)
            AND (COD_OFICINA = P_COD_OFICINA OR COD_OFICINA IS NULL)
            AND (COD_ENTE = v_cod_ente OR COD_ENTE IS NULL)
            AND (COD_MONEDA = P_COD_MONEDA OR COD_MONEDA IS NULL)
            AND (NRO_CUENTA = P_NRO_CUENTA OR  NRO_CUENTA IS NULL)
            AND FEC_VIGENCIA = P_FEC_VIGENCIA;
      EXCEPTION
            WHEN NO_DATA_FOUND THEN
               RAISE_APPLICATION_ERROR(-20000,SQLERRM||' / '||'No se encuentra valor de la tasa');
      END;
   END IF;
END;
/* obtiene la sgte vigencia de una tasa */
PROCEDURE PR_TAS_SIG_VIGENCIA
 (P_COD_TASA IN GE_TASAS.COD_TASA%TYPE
 ,P_COD_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN GE_TAS_FECHAS.COD_OFICINA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIO IN GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_FEC_FINAL IN DATE
 ,P_FEC_VIGENCIA OUT GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_FIN_TASA IN OUT VARCHAR2
 )
 IS
 v_tip_tasa ge_tasas.tipo%type;
 v_cod_sub_modalidad number(5) := fug_obt_cod_sub_modalidad(p_nro_cuenta);
 v_cod_ente          ge_tas_fechas.cod_ente%type;

BEGIN
/*Lee la menor fecha de tasa que sea mayor que la fecha de inicio en GE_TAS_FECHAS.
Si no encuentra es por que ya no volvio a cambiar*/
   P_FIN_TASA := 'N';
   --
   IF P_NRO_CUENTA IS NOT NULL THEN
     v_cod_ente := fug_obt_ent_pag_sue(p_nro_cuenta);
   ELSE
     v_cod_ente := NULL;
   END IF;
   --
   SELECT tipo
     INTO v_tip_tasa
     FROM GE_TASAS
    WHERE COD_TASA = P_COD_TASA;
   ---
   if v_tip_tasa = 'F' then
       -- tasas  por fecha
       SELECT MIN(fec_vigencia)
         INTO P_FEC_VIGENCIA
         FROM GE_TAS_FECHAS
        WHERE COD_TASA = P_COD_TASA
          AND (COD_MODULO = P_COD_MODULO OR COD_MODULO IS NULL)
          AND (COD_MODALIDAD = P_COD_MODALIDAD OR COD_MODALIDAD IS NULL)
          AND (COD_SUB_MODALIDAD = V_COD_SUB_MODALIDAD OR COD_SUB_MODALIDAD IS NULL)
          AND (COD_OFICINA = p_cod_oficina OR COD_OFICINA IS NULL)
          AND (COD_ENTE = v_cod_ente OR COD_ENTE IS NULL)
          AND (COD_MONEDA = P_COD_MONEDA OR COD_MONEDA IS NULL)
          AND (NRO_CUENTA = P_NRO_CUENTA OR  NRO_CUENTA IS NULL)
          AND FEC_VIGENCIA > P_FEC_INICIO;
   elsif v_tip_tasa = 'V' then
       -- Tasas por rangos ------
       SELECT MIN(fec_vigencia)
         INTO P_FEC_VIGENCIA
         FROM GE_TAS_RANGOS
        WHERE COD_TASA = P_COD_TASA
          AND (COD_MODULO = P_COD_MODULO OR COD_MODULO IS NULL)
          AND (COD_MODALIDAD = P_COD_MODALIDAD OR COD_MODALIDAD IS NULL)
          AND (COD_SUB_MODALIDAD = V_COD_SUB_MODALIDAD OR COD_SUB_MODALIDAD IS NULL)
          AND (COD_OFICINA = p_cod_oficina OR COD_OFICINA IS NULL)
          AND (COD_ENTE = v_cod_ente OR COD_ENTE IS NULL)
          AND (COD_MONEDA = P_COD_MONEDA OR COD_MONEDA IS NULL)
          AND (NRO_CUENTA = P_NRO_CUENTA OR  NRO_CUENTA IS NULL)
          AND FEC_VIGENCIA > P_FEC_INICIO;
   else
       raise_application_error(-20000,'Tipo de Tasa '||v_tip_tasa||' no valido!!!');
   end if;
   IF P_FEC_VIGENCIA IS NULL THEN
   	  P_FIN_TASA := 'S';
   	  P_FEC_VIGENCIA := P_FEC_FINAL + 1;
   END IF;
END;
END PAA_CTA;
/