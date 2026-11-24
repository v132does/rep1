CREATE OR REPLACE PROCEDURE it.pro_gen_nue_modalidad
-- https://itti-digital.atlassian.net/browse/HA-3976
--Declare
(
   p_cod_ori_modalidad IN NUMBER,
   p_cod_nue_modalidad IN NUMBER,
   p_descripcion       IN VARCHAR2,
   p_cod_modulo        IN NUMBER
) IS
   v_cod_usuario   ge_movimientos.cod_usuario%TYPE := USER;
   v_cod_modalidad ge_modalidades.cod_modalidad%TYPE;
   v_cod_modulo    ba_modulos.cod_modulo%TYPE := p_cod_modulo;
   v_existe        NUMBER(1);
   v_fec_actual    DATE := pag_cal.fu_obt_fec_actual(6);

   --------------------------------------------------------------------------------------------
   --  EMPIEZA EL PROCEDIMIENTO
   --------------------------------------------------------------------------------------------
BEGIN
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := v_cod_modulo;
   END;
   v_cod_modalidad := p_cod_nue_modalidad;
   IF (p_cod_nue_modalidad IS NULL OR p_descripcion IS NULL) THEN
      raise_application_error(-20000,
                              'Error : Es obligatorio el dato de la nueva modalidad y su Descripción. Verifique');
   ELSE
      BEGIN
         SELECT 1 INTO v_existe FROM ge_modalidades WHERE cod_modalidad = p_cod_nue_modalidad;
         IF SQL%FOUND THEN
            raise_application_error(-20001,
                                    'Error : Parametro de la modalidad nueva ' ||
                                     p_cod_nue_modalidad ||
                                     ' ya existe en Ge_modalidades. Verifique');
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            v_cod_modalidad := p_cod_nue_modalidad;
      END;
   END IF;
   -- 1
   BEGIN
      -- Se inserta la modalidad
      INSERT INTO ge_modalidades
         (cod_modulo, cod_modalidad, descripcion, cod_gru_cruzamiento, sigla, cod_pro_contable, tipo)
         SELECT cod_modulo,
                v_cod_modalidad,
                p_descripcion,
                cod_gru_cruzamiento,
                sigla,
                cod_pro_contable,
                tipo
           FROM ge_modalidades
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20002, 'Error en la inserción de Ge_Modalidades. Verifique'||SQLERRM);
   END;

-- 2
   BEGIN
      -- Se inserta la sub_modalidad
      INSERT INTO ge_sub_modalidades
         (COD_MODULO, COD_MODALIDAD, COD_SUB_MODALIDAD, DESCRIPCION)
         SELECT cod_modulo,
                v_cod_modalidad,
                cod_sub_modalidad,
                descripcion
           FROM ge_sub_modalidades
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20002, 'Error en la inserción de Ge_Sub_Modalidades. Verifique'||SQLERRM);
   END;

-- 5
   BEGIN
      -- Se inserta las transacciones de la modalidad
      INSERT INTO ge_transacciones
         (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, DESCRIPCION, VE_CLIENTE, TIPO, ABREVIATURA, RUTINA1, RUTINA2, RUTINA3,
         COD_TIP_ASIENTO, COD_TASA, BATCH, COD_RETENCION, INTERNO, AFECTA, COD_TIP_ASIENTO2, TIP_DESPLIEGUE)
         SELECT cod_transaccion,
                cod_modulo,
                v_cod_modalidad,
                descripcion,
                ve_cliente,
                tipo,
                abreviatura,
                rutina1,
                rutina2,
                rutina3,
                cod_tip_asiento,
                cod_tasa,
                batch,
                cod_retencion,
                interno,
                afecta,
                cod_tip_asiento2,
                tip_despliegue
           FROM ge_transacciones
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20003,
                                 SQLERRM ||
                                  '. Error en la inserción de Ge_Transacciones. Verifique');
   END;
  --commit;
 -- 6
 /*  BEGIN
      -- Se inserta los detalles de las transacciones de la modalidad
      INSERT INTO ge_con_transacciones
         (FECHA, COD_MOD_PADRE, COD_MAD_PADRE, COD_OFI_ORIGEN, COD_OFICINA, COD_MONEDA, COD_MODULO, COD_MODALIDAD, COD_TRANSACCION,
         COD_SECTOR, COD_TIP_DEUDOR, RESIDENTE, COD_PLAZO, CANTIDAD, TOTAL, TOT_MON_LOCAL, NRO_REFERENCIA, EST_CUENTA,
         TIP_CUENTA, TIP_INTERES, TIP_RENOVACION, CAT_AUTOMATICA, FEC_VALOR, COD_TRA_PADRE)

        SELECT FECHA, COD_MOD_PADRE, v_cod_modalidad, COD_OFI_ORIGEN, COD_OFICINA, COD_MONEDA, COD_MODULO, v_cod_modalidad, COD_TRANSACCION,
         COD_SECTOR, COD_TIP_DEUDOR, RESIDENTE, COD_PLAZO, CANTIDAD, TOTAL, TOT_MON_LOCAL, NRO_REFERENCIA, EST_CUENTA,
         TIP_CUENTA, TIP_INTERES, TIP_RENOVACION, CAT_AUTOMATICA, FEC_VALOR, COD_TRA_PADRE
           FROM ge_con_transacciones
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20004,
                                 'Error en la inserción de ge_con_transacciones. Verifique' ||
                                  SQLERRM);
   END;*/

 -- 7
   BEGIN
      -- Se inserta los detalles de las transacciones de la modalidad
      INSERT INTO ge_transacciones_det
         (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, COD_TRA_HIJO, COD_MOD_HIJO, COD_MAD_HIJO, NRO_ORDEN, OBLIGATORIO)
         SELECT cod_transaccion,
                cod_modulo,
                v_cod_modalidad,
                cod_tra_hijo,
                cod_mod_hijo,
                v_cod_modalidad,
                nro_orden,
                obligatorio
           FROM ge_transacciones_det
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo  -- El módulo es de Préstamos
            AND cod_mod_hijo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20004,
                                 'Error en la inserción de Ge_Transacciones_det. Verifique' ||
                                  SQLERRM);
   END;

 -- 8
   BEGIN
      -- Se inserta los estados de la modalidad
      INSERT INTO ge_est_cuentas
         (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, ACTIVO)
         SELECT cod_modulo,
                v_cod_modalidad,
                estado,
                descripcion,
                activo
           FROM ge_est_cuentas
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo;  -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20004,
                                 'Error en la inserción de ge_est_cuentas. Verifique' ||
                                  SQLERRM);
   END;

-- 9
     BEGIN
      -- Se inserta los plazos de la pizarra para la modalidad
      INSERT INTO cr_piz_plazos
         (cod_modulo, cod_modalidad, cod_moneda, mto_desde, plz_desde, plz_hasta, tas_interes,
          tas_minima, tas_maxima, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
          tip_capitalizacion, tas_efectiva,COD_SUB_MODALIDAD)
         SELECT cod_modulo,
                v_cod_modalidad,
                cod_moneda,
                mto_desde,
                plz_desde,
                plz_hasta,
                tas_interes,
                tas_minima,
                tas_maxima,
                v_cod_usuario,
                v_fec_actual,
                usu_modificacion,
                fec_modificacion,
                tip_capitalizacion,
                tas_efectiva,
                cod_sub_modalidad
           FROM cr_piz_plazos
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20008, 'Error en la inserción de cr_piz_plazos. Verifique');
   END;

-- 9
--ge_entes

-- 10
   BEGIN
      -- Se inserta las solicitudes de cargos
      INSERT INTO ge_sol_cargos
         (cod_canal, cod_campana, cod_modulo, cod_modalidad, cod_transaccion, cod_ent_seguro,
          usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_tip_canal)
         SELECT cod_canal,
                cod_campana,
                cod_modulo,
                v_cod_modalidad,
                cod_transaccion,
                cod_ent_seguro,
                v_cod_usuario,
                v_fec_actual,
                usu_modificacion,
                fec_modificacion,
                cod_tip_canal
           FROM ge_sol_cargos
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20005, 'Error en la inserción de Ge_sol_cargos. Verifique');
   END;

 -- 11
   BEGIN
      -- Se inserta parametros dinamicos para la modalidad
      INSERT INTO ge_par_dinamicos
         (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_sub_modalidad)
         SELECT parametro,
                val_parametro,
                cod_modulo,
                v_cod_modalidad,
                cod_oficina,
                cod_moneda,
                cod_sub_modalidad
           FROM ge_par_dinamicos
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20006, 'Error en la inserción de Ge_par_dinamicos. Verifique');
   END;

   -- 12
   BEGIN
      -- Se inserta los montos de la pizarra para la modalidad
      INSERT INTO cr_piz_montos
         (cod_modulo, cod_modalidad, cod_moneda, mto_desde, mto_hasta, usu_insercion, fec_insercion,
          usu_modificacion, fec_modificacion, cod_sub_modalidad)
         SELECT cod_modulo,
                v_cod_modalidad,
                cod_moneda,
                mto_desde,
                mto_hasta,
                v_cod_usuario,
                v_fec_actual,
                usu_modificacion,
                fec_modificacion,
                cod_sub_modalidad
           FROM cr_piz_montos
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20007, 'Error en la inserción de cr_piz_montos. Verifique');
   END;

-- 13
   BEGIN
      -- Se inserta los sectores de creditos para la modalidad
      INSERT INTO pr_sec_cre_modalidades
         (cod_modulo, cod_modalidad, cod_sec_credito, usu_insercion, fec_insercion,
          usu_modificacion, fec_modificacion)
         SELECT cod_modulo,
                v_cod_modalidad,
                cod_sec_credito,
                v_cod_usuario,
                v_fec_actual,
                usu_modificacion,
                fec_modificacion
           FROM pr_sec_cre_modalidades
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20009,
                                 'Error en la inserción de pr_sec_cre_modalidades. Verifique');
   END;

   BEGIN
      -- Se inserta los estados de cuentas para la modalidad
      INSERT INTO ge_tra_roles
         (cod_transaccion, cod_modulo, cod_modalidad, cod_rol,
          ope_fec_valor)
         SELECT cod_transaccion,
                cod_modulo,
                v_cod_modalidad,
                cod_rol,
                ope_fec_valor
           FROM ge_tra_roles
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20011, 'Error en la inserción de ge_tra_roles. Verifique');
   END;

   BEGIN
      -- Se inserta los estados de cuentas para la modalidad
      INSERT INTO ge_gru_transacciones_det
         (cod_gru_transaccion, cod_transaccion, cod_modulo, cod_modalidad)
         SELECT cod_gru_transaccion,
                cod_transaccion,
                cod_modulo,
                v_cod_modalidad
           FROM ge_gru_transacciones_det
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20012, 'Error en la inserción de ge_gru_transacciones_det. Verifique');
   END;
   BEGIN
      -- Se inserta los rubros economicos para la modalidad
      INSERT INTO pr_rub_eco_modalidades
         (cod_modulo, cod_modalidad, cod_rub_economico, referencia)
         SELECT cod_modulo,
                v_cod_modalidad,
                cod_rub_economico,
                referencia
           FROM pr_rub_eco_modalidades
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo; -- El módulo es de Préstamos
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20013, 'Error en la inserción de pr_rub_eco_modalidades. Verifique');
   END;
   BEGIN
      -- Se inserta las tasas variables definidas para la modalidad
      INSERT INTO ge_tas_rangos
         (cod_tasa, fec_vigencia, cod_oficina, cod_moneda, cod_modulo, cod_modalidad, nro_cuenta, val_hasta, val_tasa, no_actualizable,
          val_extension, cod_persona, observaciones, fec_vencimiento, cod_sub_modalidad)
         SELECT cod_tasa,
                fec_vigencia,
                cod_oficina,
                cod_moneda,
                cod_modulo,
                v_cod_modalidad,
                nro_cuenta,
                val_hasta,
                val_tasa,
                no_actualizable,
                val_extension,
                cod_persona,
                observaciones,
                fec_vencimiento,
                cod_sub_modalidad
           FROM ge_tas_rangos
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo -- El módulo es de Préstamos
            AND nro_cuenta is null;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20013, 'Error en la inserción de ge_tas_rangos. Verifique');
   END;
   BEGIN
      -- Se inserta las tasas fijas definidas para la modalidad
      INSERT INTO ge_tas_fechas
         (COD_TASA, FEC_VIGENCIA, APLICAR, COD_OFICINA, COD_MONEDA, COD_MODULO, COD_MODALIDAD, NRO_CUENTA, VAL_MAXIMO, VAL_MINIMO,
         VAL_BASE, VAL_TASA, FEC_VENCIMIENTO, OBSERVACIONES, VAL_EXTENSION, TIP_IVA, COD_PERSONA, NO_ACTUALIZABLE,
         COD_SUB_MODALIDAD, COD_ENTE)
         SELECT cod_tasa,
                fec_vigencia,
                aplicar,
                cod_oficina,
                cod_moneda,
                cod_modulo,
                v_cod_modalidad,
                nro_cuenta,
                val_maximo,
                val_minimo,
                val_base,
                val_tasa,
                fec_vencimiento,
                observaciones,
                val_extension,
                tip_iva,
                cod_persona,
                no_actualizable,
                cod_sub_modalidad,
                cod_ente
           FROM ge_tas_fechas
          WHERE cod_modalidad = p_cod_ori_modalidad -- Modalidad modelo
            AND cod_modulo = v_cod_modulo -- El módulo es de Préstamos
            AND nro_cuenta is null;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20013, 'Error en la inserción de ge_tas_fechas. Verifique');
   END;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20014, 'Error al generar Modalidad' || ' Error : ' || SQLERRM);
END;
/
