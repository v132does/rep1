CREATE OR REPLACE PACKAGE BODY IT.PAW_BAS is
 
   --https://itti-digital.atlassian.net/browse/NVB-3811
   --en el original era publica----
   v_cod_mon_local VARCHAR2(3) := pag_gen.FU_OBT_MON_LOCAL;
   CUENTA_TAMANO CONSTANT NUMBER(3) := 18;

   /** --Determina si la cuenta es una Cuenta Conjunta--
   */
   FUNCTION fu_es_conjunta(p_numeroCuenta IN VARCHAR2, p_can_aut_requeridas number) RETURN VARCHAR2 IS
      v_can_conjunta NUMBER;

   BEGIN
      -- veo si la cuenta no es conjunta
      SELECT COUNT(*)
        INTO v_can_conjunta
        FROM ge_cta_clientes
       WHERE nro_cuenta = p_numeroCuenta
         AND relacion = 'Y'
             AND rownum = 1;
      IF v_can_conjunta > 0 AND nvl(p_can_aut_requeridas, 0) = 0 THEN
         /* no requiere autorizacion y la cuenta es conjunta, no debe acceder*/
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;

   -- obtiene el monto en concepto de cargos de un prestamo
   FUNCTION lf_obt_car_prestamo(p_nro_cuenta pr_cobros.nro_cuenta%TYPE,
                                p_nro_cuota pr_cobros.nro_cuota%TYPE,
                                p_est_cuota pr_cuotas.estado%TYPE DEFAULT 'N',
                                p_cod_oficina ge_movimientos.cod_oficina%TYPE DEFAULT NULL)
   RETURN NUMBER IS
      v_tot_cargo NUMBER;
   BEGIN
     IF p_est_cuota = 'N' THEN
        SELECT SUM(
           (--nvl(a.mto_int_documentado,0) +
            nvl(a.mto_int_moratorio,0) +
            nvl(a.mto_int_mor_interes,0) +
            nvl(a.mto_int_mor_adelantado,0) +
            nvl(a.mto_int_punitorio,0) +
            nvl(a.mto_impuesto,0) +
            nvl(a.mto_cargo,0) )) mto_cargo
        INTO v_tot_cargo
        FROM pr_cobros a
        WHERE a.nro_cuenta = p_nro_cuenta
           AND a.nro_cuota  = p_nro_cuota;
     ELSIF p_est_cuota = 'C' THEN
        BEGIN
           SELECT
               --nvl(a.mto_int_documentado,0) +
               nvl(a.mto_int_moratorio,0) +
               nvl(a.mto_int_mor_interes,0) +
               nvl(a.mto_int_mor_adelantado,0) +
               nvl(a.mto_int_punitorio,0) +
               nvl(a.mto_impuesto,0) +
               nvl(a.mto_cargo,0) mto_cargo
            INTO v_tot_cargo
            FROM pr_cobros_tmp a
            WHERE a.nro_cuenta = p_nro_cuenta
               AND a.nro_cuota  = p_nro_cuota;
        EXCEPTION
           WHEN no_data_found THEN
              DECLARE
                 v_mto_cobrado        NUMBER(18, 2);
                 v_cod_error          VARCHAR2(50);
                 v_msj_error          VARCHAR2(200);
                 v_tot_capital        NUMBER(18, 2);
                 v_tot_interes        NUMBER(18, 2);
                 v_tot_int_adelantado NUMBER(18, 2);
                 v_tot_mora           NUMBER(18, 2);
                 v_tot_mora_interes   NUMBER(18, 2);
                 v_tot_mora_int_adel  NUMBER(18, 2);
                 v_tot_punitorio      NUMBER(18, 2);
                 v_tot_impuesto       NUMBER(18, 2);
                 v_tot_cargo          NUMBER(18, 2);
                 v_tot_cargo_iva      NUMBER(18, 2);
                 v_tot_int_descontado NUMBER(18, 2);
                 v_cod_tra_padre      NUMBER(18, 2);
                 v_dia_mora           NUMBER(18, 2);
                 v_nro_cuota_desde    NUMBER(5) := 0;
                 v_nro_cuota_hasta    NUMBER(5) := 999;
              BEGIN
                 pap_pre.PR_INI_AUTORIZACION;
                 pap_pre.PR_OBT_DEU_PRESTAMO(
                    p_nro_cuenta, SYSDATE, v_nro_cuota_desde,
                    v_nro_cuota_hasta, p_cod_oficina,
                    v_mto_cobrado, v_cod_error, v_msj_error,
                    v_tot_capital, v_tot_interes, v_tot_int_adelantado,
                    v_tot_mora, v_tot_mora_interes, v_tot_mora_int_adel,
                    v_tot_punitorio, v_tot_impuesto, v_tot_cargo,
                    v_tot_cargo_iva, v_tot_int_descontado, v_dia_mora,
                    v_cod_tra_padre, 'N');
                  SELECT SUM(
                    (--nvl(a.mto_int_documentado,0) +
                     nvl(a.mto_int_moratorio,0) +
                     nvl(a.mto_int_mor_interes,0) +
                     nvl(a.mto_int_mor_adelantado,0) +
                     nvl(a.mto_int_punitorio,0) +
                     nvl(a.mto_impuesto,0) +
                     nvl(a.mto_cargo,0) )) mto_cargo
                  INTO v_tot_cargo
                  FROM pr_cobros_tmp a
                  WHERE a.nro_cuenta = p_nro_cuenta
                     AND a.nro_cuota  = p_nro_cuota;
         RETURN v_tot_cargo;
              EXCEPTION
                 WHEN OTHERS THEN
                 RETURN -1;
              END;
           WHEN OTHERS THEN
              RETURN -1;
           END;
     ELSE
        v_tot_cargo := -1;
     END IF;
     RETURN v_tot_cargo;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 0;
      WHEN OTHERS THEN
         RETURN -1;
   END;

   -- obtiene el monto cobrado en concepto de cargo
   FUNCTION lf_obt_mto_car_cobrado(p_nro_cuenta pr_cobros.nro_cuenta%TYPE,
                                   p_nro_cuota pr_cobros.nro_cuota%TYPE)
   RETURN NUMBER IS
      v_tot_cobrado NUMBER;
   BEGIN
      SELECT SUM(
         --nvl(a.mto_int_documentado,0) +
         nvl(a.mto_int_moratorio,0) +
         nvl(a.mto_int_mor_interes,0) +
         nvl(a.mto_int_mor_adelantado,0) +
         nvl(a.mto_int_punitorio,0) +
         nvl(a.mto_impuesto,0) +
         nvl(a.mto_cargo,0)) mto_cobro
      INTO v_tot_cobrado
      FROM pr_cobros a
      WHERE a.nro_cuenta = p_nro_cuenta
         AND a.nro_cuota  = p_nro_cuota;
      RETURN v_tot_cobrado;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 0;
      WHEN OTHERS THEN
         RETURN -1;
   END;

    -- obtiene el monto de seguro de incendio de una solicitud de prestamo
   FUNCTION lf_obt_pre_seg_incendio(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE) RETURN NUMBER IS
      v_mto_seg_incendio pr_gar_hipotecarias.val_edilicio%TYPE := 0;
      v_nro_garantia     pr_sol_garantias.nro_garantia%TYPE;
      v_cod_modulo       pr_solicitudes.cod_modulo%TYPE;
      v_cod_modalidad    pr_solicitudes.cod_modalidad%TYPE;
      v_cod_oficina      pr_solicitudes.cod_oficina%TYPE;
      v_cod_moneda       pr_solicitudes.cod_moneda%TYPE;
      v_fec_inicio       pr_solicitudes.fec_inicio%TYPE;
   BEGIN
      BEGIN
         SELECT DISTINCT nvl(g.nro_garantia, NULL)
           INTO v_nro_garantia
           from pr_sol_garantias g
          WHERE g.nro_solicitud = p_nro_solicitud
            AND g.cod_garantia IN (3, 13)  -- Res. 12
            AND EXISTS(select 1
                         from pr_sol_cargos a
                        where a.cod_transaccion = 1520
                          and a.nro_solicitud = g.nro_solicitud);
      EXCEPTION
         WHEN OTHERS THEN
            v_nro_garantia := NULL;
      END;

      IF v_nro_garantia IS NOT NULL THEN
         SELECT s.cod_modulo, s.cod_modalidad, s.cod_oficina, s.cod_moneda, nvl(s.fec_ini_rrr, s.fec_inicio)
           INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_fec_inicio
           FROM pr_solicitudes s
          WHERE s.nro_solicitud = p_nro_solicitud;

         v_mto_seg_incendio := pap_pre.fu_obt_cal_mto_seg_incendio(v_cod_modalidad,
                                     v_cod_modulo,
                                     v_cod_oficina,
                                     v_nro_garantia,
                                     NULL,
                                     fug_obt_ent_seguro(v_cod_modulo, v_cod_modalidad, 'I'),
                                     v_cod_moneda,
                                     v_fec_inicio);
      END IF;

      RETURN v_mto_seg_incendio;
   END;

   -- obtiene el monto de seguro de vida de una solicitud de prestamo
   FUNCTION lf_obt_pre_seg_vida(p_nro_solicitud IN pr_sol_cuotas.nro_solicitud%TYPE,
                                p_nro_cuota     IN pr_sol_cuotas.nro_cuota%TYPE) RETURN NUMBER IS
      v_monto            pr_cta_prestamos.monto%TYPE;
      v_periodo          NUMBER;
      v_can_periodos     NUMBER;
      v_exi_cal_especial VARCHAR2(1);
   BEGIN
      BEGIN
         SELECT DISTINCT 'S'
           INTO v_exi_cal_especial
           FROM pr_cta_gas_seguros r
          WHERE r.nro_solicitud = nvl(p_nro_solicitud,0);
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_exi_cal_especial := 'N';
         WHEN OTHERS THEN
            v_exi_cal_especial := 'N';
      END;

      BEGIN
         SELECT pap_pre.fu_obt_cal_mto_seg_vida(p.cod_modalidad, p.cod_modulo, p.cod_moneda,
                                                nvl(p.cod_oficina, NULL),
                                                decode(s.sal_cap_anterior,0, p.tot_desembolsar,s.sal_cap_anterior),
                                                nvl(c.cod_ent_seguro,fug_obt_ent_seguro(p.cod_modulo, p.cod_modalidad, 'V')),
                                                p.fec_inicio, null,
                                                decode(v_exi_cal_especial, 'S', 'F', decode(c.cod_transaccion, 1521, 'F', 'V')),
                                                p.tot_prestamo, p.nro_solicitud, s.nro_cuota), s.dia_periodo
           INTO v_monto, v_periodo
           FROM pr_sol_cuotas s, pr_solicitudes p, pr_sol_cargos c
          WHERE s.nro_solicitud = p.nro_solicitud
            AND s.nro_cuota > 0
            AND s.nro_solicitud = c.nro_solicitud
            AND c.cod_transaccion = 1521
            AND s.nro_solicitud = p_nro_solicitud
            AND s.nro_cuota = p_nro_cuota;

         IF nvl(v_exi_cal_especial, 'N') = 'N' THEN
            IF nvl(v_periodo,0) > 30 THEN
               v_can_periodos := floor(v_periodo / 30);
               v_monto := v_monto * nvl(v_can_periodos, 1); --multiplica el monto por los meses obtenidos
            END IF;
         END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_monto := 0;
      END;
      RETURN v_monto;
   END;
   
   
    /** Obtiene un mensaje de la base de datos por el nombre del mensaje
   * @param p_mensaje Nombre del mensaje
   * @return p_nombreMensaje Nombre del mensaje
   * @return p_descripcionMensaje Descripción del mensaje
   * @return p_error Indicador de si es o no un mensaje de error
   */
   PROCEDURE pr_mensajeUsuario(mensaje            IN VARCHAR2,
                               nombreMensaje      OUT VARCHAR2,
                               descripcionMensaje OUT VARCHAR2,
                               error              OUT VARCHAR2) IS
      v_error VARCHAR2(1) := 'S';
   BEGIN
      BEGIN
         SELECT a.nombre, a.des_mensaje, a.error
           INTO nombreMensaje, descripcionMensaje, v_error
           FROM bw_men_respuesta a
          WHERE a.nombre = mensaje;
      EXCEPTION
         WHEN no_data_found THEN
            descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado';
         WHEN OTHERS THEN
            descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado';
      END;
      error := v_error;
   END;

   /**
   ****  Validar la Cuenta de Debito  ***
   * @Migrado por: Christian Recalde / Sergio Ayala
   * @Fecha : 17-07-2012
   */
   FUNCTION fu_val_cta_debito(p_nro_cta_debito IN VARCHAR2,
                              p_cod_tra_padre  IN NUMBER,
                              p_monto          IN NUMBER,
                              p_cod_mon_debito OUT VARCHAR2,
                              p_cod_mod_debito OUT NUMBER,
                              p_cod_mad_debito OUT NUMBER,
                              p_cod_ofi_debito OUT NUMBER,
                              p_cta_for_debito OUT VARCHAR2,
                              p_nom_cta_debito OUT VARCHAR2,
                              p_codigoEmpresa in varchar2,
                              p_mensajeCaja    IN typ_mensajeCaja,
                              p_can_firmas     IN NUMBER,
                              p_cod_modulo     IN ge_modalidades.cod_modulo%TYPE DEFAULT NULL,
                              p_cod_modalidad  IN ge_modalidades.cod_modalidad%TYPE DEFAULT NULL) RETURN typ_mensajeRespuesta IS
      MSG_COD_CTA_INVALIDA    CONSTANT VARCHAR2(15) := 'COD_CTA_INVALID';
      MSG_COD_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := 'COD_CTA_INEXIST';
      MSG_COD_TRA_PROHIBIDA   CONSTANT VARCHAR2(15) := 'COD_TRA_PROHIB';
      MSG_COD_SAL_INSUF       CONSTANT VARCHAR2(15) := 'COD_SAL_INSUF';
      MSG_COD_CTA_DUPLICADA   CONSTANT VARCHAR2(15) := 'COD_CTA_DUPLIC';
      MSG_COD_CTA_CONJUNTA   CONSTANT VARCHAR2(15)  := 'CTA_CONJUNTA';

      v_est_cta_debito VARCHAR2(1);
      v_nvo_estado     VARCHAR2(1) := NULL; -- cambio de estado de cuenta
      v_procesa        VARCHAR2(1) := 'N';
      v_sal_disponible NUMBER(18, 2);
      v_can_conjunta   NUMBER(7);
      v_retorno        typ_mensajeRespuesta := typ_mensajeRespuesta;
      -- verifico cuenta de debito
   BEGIN
      PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      SELECT a.cod_moneda, a.estado, cod_modalidad, cod_modulo, cod_oficina, fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda) cta_formateada, denominacion
        INTO p_cod_mon_debito, v_est_cta_debito, p_cod_mad_debito, p_cod_mod_debito, p_cod_ofi_debito, p_cta_for_debito, p_nom_cta_debito
        FROM ge_cuentas a
       WHERE a.nro_cuenta = p_nro_cta_debito; -- contiene el nro de cuenta
      -- debito
      pag_cta.PR_OBT_CUENTA(p_nro_cta_debito);
      v_est_cta_debito := pag_cta.FU_OBT_EST_CUENTA;
      IF p_cod_mad_debito NOT IN (31, 41) THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
      ELSIF v_est_cta_debito NOT IN ('P', 'I', 'N', 'S') THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
      ELSIF pag_cta.fu_ver_tra_prohibida(p_nro_cta_debito, p_cod_tra_padre, 9, 91) = 'S' THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_TRA_PROHIBIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
      ELSIF fu_es_conjunta(p_nro_cta_debito, p_can_firmas) = 'S' THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_CONJUNTA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- v_cod_respuesta := paw_bce.v_cod_tra_invalida;
      ELSE
         pag_cta.pr_ver_operacion(p_nro_cta_debito, p_cod_tra_padre, nvl(p_cod_modulo, 9), nvl(p_cod_modalidad, 91), 'D', p_cod_mon_debito, p_monto, p_mensajeCaja.codigoOficinaOrigen /* v_cod_ofi_origen */, p_cod_mod_debito, p_cod_mad_debito, v_nvo_estado, v_sal_disponible, v_procesa, 503);
         IF v_procesa = 'N' THEN
            -- no se puede debitar
            IF instr(upper(pag_cta.G_MSJ_ERROR), 'INSUFIC') > 0 THEN
               -- saldo insuficiente
               PAW_UTI.pr_mensajeUsuario(MSG_COD_SAL_INSUF, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               -- v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
            ELSE
               PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
            END IF;
         END IF;
      END IF;
      -- agregado para permitir a cuentas indistintas de personas fisicas grabar sin autorizacion
      IF v_retorno.error = 'N' AND p_codigoEmpresa IS NULL THEN
         -- veo si la cuenta no es conjunta
         SELECT COUNT(*)
           INTO v_can_conjunta
           FROM ge_cta_clientes
          WHERE nro_cuenta = p_nro_cta_debito
            AND relacion = 'Y'
            AND rownum = 1;

      /*
      Version inicial solo persona fisicas, atender con juridias
      IF nvl(v_can_conjunta, 0) = 0 THEN
            -- veo si es persona fisica no debe requerir autorizacion
            p_can_aut_requeridas := 0; -- no tiene autorizacion pendiente cuando es la persona fisica
         END IF;
         */
      END IF;

      RETURN v_retorno;
   EXCEPTION
      WHEN no_data_found THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      WHEN too_many_rows THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_DUPLICADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;
  
   FUNCTION fu_val_cta_credito(p_nro_cuenta     IN ge_cuentas.nro_cuenta%TYPE,
                               p_cod_tra_padre  IN ge_transacciones.cod_transaccion%TYPE,
                               p_cod_modulo     IN ge_modalidades.cod_modulo%TYPE,
                               p_cod_modalidad  IN ge_modalidades.cod_modalidad%TYPE,
                               p_monto          IN ge_movimientos.monto%TYPE DEFAULT NULL,
                               p_cod_ofi_origen IN ba_oficinas.cod_oficina%TYPE DEFAULT NULL) RETURN typ_mensajeRespuesta IS
     v_retorno         typ_mensajeRespuesta := typ_mensajeRespuesta;
     v_mto_credito     ge_movimientos.monto%TYPE := nvl(p_monto, 1);
     v_cod_moneda      ge_cuentas.cod_moneda%TYPE;
     v_estado          ge_cuentas.estado%TYPE; 
     v_cod_modalidad   ge_cuentas.cod_moneda%TYPE;
     v_cod_modulo      ge_cuentas.cod_modulo%TYPE;
     v_procesa         VARCHAR2(1);
     v_nvo_est_credito ge_cuentas.estado%TYPE;
     v_sal_dis_credito ge_cuentas.sal_contable%TYPE;
   BEGIN
      BEGIN
         SELECT a.cod_moneda, a.estado, cod_modalidad, cod_modulo
           INTO v_cod_moneda, v_estado, v_cod_modalidad, v_cod_modulo
           FROM ge_cuentas a
          WHERE a.nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            paw_uti.pr_mensajeUsuario('COD_CTA_INEXIST', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
      END;
      -- monto invalido
      IF v_mto_credito <= 0 THEN
         paw_uti.pr_mensajeUsuario('MTO_INVALIDO', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      -- cuenta invalida para credito
      IF v_cod_modalidad NOT IN (31, 41) THEN
         paw_uti.pr_mensajeUsuario('MAD_CTA_CRE_INV', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      -- estado invalido
      IF v_estado NOT IN ('A', 'I', 'N', 'S') THEN
         paw_uti.pr_mensajeUsuario('EST_CTA_CRE_INV', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      -- transaccion prohibida
      IF pag_cta.fu_ver_tra_prohibida(p_nro_cuenta, p_cod_tra_padre, p_cod_modulo, p_cod_modalidad) = 'S' THEN
         paw_uti.pr_mensajeUsuario('CTA_CRE_PROHIBI', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      -- validar operacion
      pag_cta.pr_ver_operacion(p_nro_cuenta, p_cod_tra_padre, p_cod_modulo, p_cod_modalidad, 'C', v_cod_moneda, v_mto_credito, nvl(p_cod_ofi_origen, 31), v_cod_modulo, v_cod_modalidad, v_nvo_est_credito, v_sal_dis_credito, v_procesa, 602);
      IF v_procesa = 'N' THEN
         paw_uti.pr_mensajeUsuario('CTA_CRE_VER_OPE', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      -- validacion de cuenta basica
      IF fug_val_cta_basica(p_nro_cuenta, p_cod_tra_padre, p_cod_modulo, p_cod_modalidad, 602, v_cod_modulo, v_cod_modalidad, p_monto, v_cod_moneda) <> 0 THEN
         paw_uti.pr_mensajeUsuario('CTA_CRE_OPE_BAS', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      
      RETURN v_retorno;
  END;

FUNCTION fu_activarchequera(p_nro_cuenta IN cc_chequeras.nro_cuenta%TYPE,
                            p_nro_inicial IN cc_chequeras.nro_che_inicial%TYPE,
                            p_nro_final IN cc_chequeras.nro_che_final%TYPE)
  RETURN typ_mensajerespuesta IS
  v_retorno typ_mensajerespuesta := typ_mensajerespuesta();
  v_cheques varchar2(500):='';
  v_can_cheques number(15):=0;
BEGIN
  paw_uti.pr_mensajeusuario(paw_uti.MSG_OK, v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta, v_retorno.error);
  BEGIN
    v_can_cheques:=p_nro_final-p_nro_inicial+1;
    for lcntr in 1..v_can_cheques loop
        v_cheques:=v_cheques||'E';
    end loop;

    UPDATE cc_chequeras c
    SET c.estado = 'E', c.est_cheques = v_cheques
    WHERE c.nro_cuenta = p_nro_cuenta
    AND c.cod_usuario = 'HBANK'
    AND c.estado = 'I'
    AND c.nro_che_inicial = p_nro_inicial;
  EXCEPTION
    WHEN OTHERS THEN
      paw_uti.pr_mensajeusuario(paw_uti.MSG_ERROR, v_retorno.nombrerespuesta,
                                v_retorno.descripcionrespuesta, v_retorno.error);
  END;
  RETURN v_retorno;
END;

   PROCEDURE pr_reg_acc_cli_digitales( p_cod_persona IN VARCHAR2,
                                       p_cod_canal IN NUMBER,
                                       p_fec_acceso IN DATE DEFAULT NULL ) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      v_fecha DATE;
      v_anho  NUMBER(4);
      v_mes   NUMBER(2);
   BEGIN
      v_fecha := TRUNC(nvl(p_fec_acceso, SYSDATE));
      v_anho  := TO_NUMBER(to_char(v_fecha, 'YYYY'));
      v_mes   := TO_NUMBER(to_char(v_fecha, 'MM'));
      UPDATE bw_cli_digitales
         SET fec_ult_acc_mob = DECODE(p_cod_canal, 994, TRUNC(v_fecha), fec_ult_acc_mob),  -- 994 = MOBILE
            fec_ult_acc_web = DECODE(p_cod_canal, 999, TRUNC(v_fecha), fec_ult_acc_web),  -- 999 = WEB
            fec_ult_acc_ema = DECODE(p_cod_canal, 990, TRUNC(v_fecha), fec_ult_acc_ema),  -- 990 = EMA
            fec_ult_acc_mic = DECODE(p_cod_canal, 991, TRUNC(v_fecha), fec_ult_acc_mic)   -- 991 = MICROSITIO (Beneficios BBVA)
       WHERE anho = v_anho
         AND mes = v_mes
         AND cod_persona = p_cod_persona;
      IF SQL%NOTFOUND THEN
         INSERT INTO bw_cli_digitales
            ( anho, mes, cod_persona,
              fec_ult_acc_mob,
             fec_ult_acc_web,
             fec_ult_acc_ema,
             fec_ult_acc_mic )
         VALUES
            ( v_anho, v_mes, p_cod_persona,
              DECODE(p_cod_canal, 994, v_fecha, NULL),
              DECODE(p_cod_canal, 999, v_fecha, NULL),
              DECODE(p_cod_canal, 990, v_fecha, NULL),
              DECODE(p_cod_canal, 991, v_fecha, NULL) );
      END IF;
      COMMIT;
   END;

FUNCTION fu_ver_seg_preaprob(p_codigoCanal IN  VARCHAR2,
                             p_codTipo IN NUMBER) RETURN BOOLEAN IS
  v_retorno       BOOLEAN := false;
  v_seg_encendido ge_par_dinamicos.val_parametro%TYPE := nvl(fug_obt_pardinamico('SEG_ENCENDIDO'), 'N');
BEGIN
  BEGIN
    IF(p_codigoCanal = '999' or (p_codigoCanal = '994' and --Canal web siempre, o canal movil mas otros filtros
                                 p_codTipo = 2 and --Para mobile solo debe ser ACCIDENTES PERSONALES
                                 v_seg_encendido = 'S' --Habilitacion para mobile
                                 )) THEN
        v_retorno := true;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;
  RETURN v_retorno;
END;

  /* Obtener Tasa Pizarra */
  FUNCTION fu_obt_tas_pizarra(p_plazo IN NUMBER,
                              p_monto IN NUMBER,
                              p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                              p_cod_modulo IN ba_modulos.cod_modulo%TYPE,
                              p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE,
                              p_cod_sub_modalidad IN ge_sub_modalidades.cod_sub_modalidad%TYPE DEFAULT NULL,
                              p_tip_capitalizacion IN cr_piz_plazos.tip_capitalizacion%TYPE DEFAULT NULL
                              ) RETURN NUMBER IS
     v_retorno cr_piz_plazos.tas_interes%TYPE := NULL;
  BEGIN
     SELECT MAX(p.tas_interes)
       INTO v_retorno
       FROM cr_piz_montos m, cr_piz_plazos p
      WHERE m.cod_moneda = p.cod_moneda
        AND m.cod_moneda = p_cod_moneda
        AND m.mto_desde = p.mto_desde
        AND m.cod_modulo = p.cod_modulo
        AND m.cod_modalidad = p.cod_modalidad
        AND NVL(m.cod_sub_modalidad, -1) = NVL(p.cod_sub_modalidad, -1)
        AND m.cod_modulo = p_cod_modulo
        AND m.cod_modalidad = p_cod_modalidad
        AND NVL(m.cod_sub_modalidad, NVL(p_cod_sub_modalidad, -1)) = NVL(p_cod_sub_modalidad, -1)
        AND NVL(p.tip_capitalizacion, -1) = nvl(p_tip_capitalizacion, -1)
        AND (p_plazo * 30) BETWEEN p.plz_desde AND p.plz_hasta
        AND p_monto BETWEEN m.mto_desde AND m.mto_hasta;
     RETURN v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        RETURN v_retorno;
  END;
  --
  /* Realiza el debito automatico de Prestamos, Tarjetas y Mov.Pendientes */
  PROCEDURE pr_pro_deb_automatico(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                                  p_mto_debito OUT ge_movimientos.monto%TYPE,
                                  p_error      OUT VARCHAR2
                                  ) IS
    -- Obtener el monto de Debito
    FUNCTION lf_obt_mto_debito RETURN ge_movimientos.monto%TYPE IS
       v_monto       ge_movimientos.monto%TYPE;
       v_mto_deb_tc  ge_movimientos.monto%TYPE;
       v_mto_deb_pmo ge_movimientos.monto%TYPE;
       v_mto_deb_pen ge_movimientos.monto%TYPE;
    BEGIN
       -- Tarjetas
       SELECT SUM(a.monto)
         INTO v_mto_deb_tc
         FROM ge_movimientos a
        WHERE a.cod_tra_padre IN(986, 186) -- 986=DEBITO AUTOMATICO DE TARJETAS
          AND a.cod_transaccion = 503 -- 503=DEBITO EN CUENTA
          AND a.nro_cuenta = p_nro_cuenta
          AND a.cod_usuario = USER
          AND TRUNC(a.fec_insercion) = TRUNC(SYSDATE)
          AND a.fec_insercion BETWEEN
              TO_DATE(to_char(SYSDATE - NUMTODSINTERVAL(5, 'SECOND'), 'YYYYMMDD HH24:MI:SS'),'YYYYMMDD HH24:MI:SS') AND SYSDATE; -- 5seg
       -- Prestamos
       SELECT SUM(a.monto)
         INTO v_mto_deb_pmo
         FROM ge_movimientos a
        WHERE a.cod_tra_padre IN( 364, 186) -- 364=COBRO AUTOMATICO DE PRESTAMOS
          AND a.cod_transaccion = 503 -- 503=DEBITO EN CUENTA
          AND a.nro_cuenta = p_nro_cuenta
          AND a.cod_usuario = USER
          AND TRUNC(a.fec_insercion) = TRUNC(SYSDATE)
          AND a.fec_insercion BETWEEN
              TO_DATE(to_char(SYSDATE - NUMTODSINTERVAL(5, 'SECOND'), 'YYYYMMDD HH24:MI:SS'),'YYYYMMDD HH24:MI:SS') AND SYSDATE; -- 5seg
       -- Movimientos pendientes
       SELECT SUM(a.monto)
         INTO v_mto_deb_pen
         FROM ge_mov_pendientes a
        WHERE a.nro_cuenta = p_nro_cuenta
          AND TRUNC(a.fec_modificacion) = TRUNC(SYSDATE)
          AND a.usu_modificacion = USER
          AND a.fec_modificacion BETWEEN
              TO_DATE(to_char(SYSDATE - NUMTODSINTERVAL(5, 'SECOND'), 'YYYYMMDD HH24:MI:SS'),'YYYYMMDD HH24:MI:SS') AND SYSDATE; -- 5seg
       v_monto := NVL(v_mto_deb_pmo, 0) + NVL(v_mto_deb_tc, 0) + NVL(v_mto_deb_pen, 0) ;
       RETURN NVL(v_monto, 0);
    EXCEPTION
       WHEN OTHERS THEN
         RETURN 0;
    END;
  --
  BEGIN
     BEGIN
        prt_deb_automatico(null, p_nro_cuenta);
     EXCEPTION
        WHEN OTHERS THEN
           ROLLBACK;
           p_error := 'Tarjetas ' || SQLERRM;
     END;
     BEGIN
        prp_deb_automatico(NULL, NULL, NULL, p_nro_cuenta);
     EXCEPTION
        WHEN OTHERS THEN
           ROLLBACK;
           p_error := p_error||' - '||'Prestamos ' || SQLERRM;
     END;
     BEGIN
        prg_cob_mov_pendientes(p_nro_cuenta,NULL);
     EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          p_error := p_error||' - '||'Mov. Pendientes ' || SQLERRM;
     END;
     p_mto_debito := lf_obt_mto_debito;
  END;
  /* Apertura de Cuenta de Plazo Fijo*/
  FUNCTION fu_ape_cta_plazo(p_sesion             IN VARCHAR2,
                            p_cod_persona        IN ge_clientes.cod_persona%TYPE,
                            p_cod_canal          IN ge_canales.cod_canal%TYPE,
                            p_nro_caja           IN cj_cajas.nro_caja%TYPE,
                            p_tip_capitalizacion IN ah_cta_plazos.tip_capitalizacion%TYPE,
                            p_nro_cta_credito    IN ah_cta_plazos.nro_cta_capitalizacion%TYPE,
                            p_monto              IN ah_cta_plazos.capital%TYPE,
                            p_can_meses          IN NUMBER
                            ) RETURN typ_cuentagenerada IS
     v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
     v_fec_ape_cuenta  ge_cuentas.fec_apertura%TYPE;
     v_cta_estado      ge_cuentas.estado%TYPE;
     v_cta_modalidad   ge_cuentas.cod_modalidad%TYPE;
     v_cta_modulo      ge_cuentas.cod_modulo%TYPE;
     v_cta_generada    typ_cuentagenerada := typ_cuentagenerada();
     v_cod_operacion   bw_tip_mensajes.cod_tip_mensaje%TYPE := '120';
  BEGIN
     v_cta_generada.error := 'N';
     --Crear la Cuenta de Ahorro a Plazo Fijo
     BEGIN
        pra_gen_cta_plazo(p_tip_capitalizacion, p_nro_cta_credito, p_cod_canal,
                          p_monto, p_can_meses, v_nro_cuenta);
     EXCEPTION
        WHEN OTHERS THEN
           v_cta_generada.error := 'S';
           PAW_UTI.pr_insertarBitacora(p_cod_persona, p_nro_caja, p_sesion, v_cod_operacion, p_cod_persona,
                                       'Error al Generar Cuenta de Ahorro a Plazo Fijo - '||SQLERRM, PAW_UTI.BITACORA_ERROR);
           RETURN v_cta_generada;
     END;
     BEGIN
       SELECT a.fec_apertura, a.estado, a.cod_modulo, a.cod_modalidad
         INTO v_fec_ape_cuenta, v_cta_estado, v_cta_modulo, v_cta_modalidad
         FROM ah_cta_plazos a
        WHERE a.nro_cuenta = v_nro_cuenta;
     EXCEPTION
        WHEN OTHERS THEN
           v_cta_generada.error := 'S';
           PAW_UTI.pr_insertarBitacora(p_cod_persona, p_nro_caja, p_sesion, v_cod_operacion, p_cod_persona,
                                    'Error al recuperar datos de la Cuenta de Ahorro a Plazo Fijo - '||SQLERRM, PAW_UTI.BITACORA_ERROR);
           RETURN v_cta_generada;
     END;
     v_cta_generada.NRO_CUENTA     := v_nro_cuenta;
     v_cta_generada.FECHA_APERTURA := v_fec_ape_cuenta;
     v_cta_generada.COD_MODALIDAD  := v_cta_modalidad;
     v_cta_generada.COD_MODULO     := v_cta_modulo;
     v_cta_generada.ESTADO         := v_cta_estado;
     RETURN v_cta_generada;
  EXCEPTION
     WHEN OTHERS THEN
        v_cta_generada.error := 'S';
        PAW_UTI.pr_insertarBitacora(p_cod_persona, p_nro_caja, p_sesion, v_cod_operacion, p_cod_persona,
                                    'Error al generar Cuenta de Ahorro a Plazo Fijo', PAW_UTI.BITACORA_ERROR);
        RETURN v_cta_generada;
  END;
--

FUNCTION fu_ver_horario(p_horario        OUT VARCHAR2,
                           p_es_mov_noc     OUT VARCHAR2,
                           p_es_cta_noc     OUT VARCHAR2,
                           p_ult_cierre     IN DATE,
                           p_cod_ofi_origen IN VARCHAR2,
                           p_fec_actual     OUT DATE) RETURN typ_MensajeRespuesta IS

      MSG_SIS_CIERRE CONSTANT VARCHAR2(15) := 'HOR_SIS_CIERRE';
      v_est_modulo ba_modulos.estado%TYPE;
      v_retorno    typ_MensajeRespuesta := typ_MensajeRespuesta;
   BEGIN
      --v_cod_respuesta := paw_bce.v_cod_aprobado;
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      p_horario    := 'D'; -- Dia normal
      p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'N';
      p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
      v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);

      IF v_est_modulo IN (1,6) THEN -- DDSI-29 -- 07/2017 --
         -- En cierre.
         --v_cod_respuesta := paw_bce.v_cod_sis_cierre;
         paw_uti.pr_mensajeUsuario(MSG_SIS_CIERRE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(NULL, NULL, NULL, '999', NULL, ' lp_ver_horario()-Sistema en cierre-', paw_uti.BITACORA_ERROR);
      ELSIF v_est_modulo = 2 THEN
         -- El modulo esta abierto

         -- Verifica la hora --
         IF SYSDATE > p_ult_cierre AND trunc(p_ult_cierre) = p_fec_actual THEN
            p_horario    := 'T'; -- Tarde
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
            p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         END IF;

      ELSE
         p_horario := 'N'; -- Noche
         IF v_est_modulo <> 1 THEN
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
         END IF;
         p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         p_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
      END IF;
      pag_cta.g_horario := p_horario;
      RETURN v_retorno;
   END fu_ver_horario;

   FUNCTION fu_obt_fec_snp(p_cod_msj_swift     IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                           p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                           p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE) RETURN DATE IS
      v_fecha       ge_snp_horarios.fecha%TYPE;
      v_estado      ge_snp_horarios.estado%TYPE;
      v_cod_periodo ge_snp_horarios.cod_periodo%TYPE;
   BEGIN
      SELECT m.cod_periodo
        INTO v_cod_periodo
        FROM ge_snp_par_mensajes m
       WHERE m.cod_msj_swift = p_cod_msj_swift
         AND m.cod_tip_operacion = p_tip_operacion
         AND nvl(m.cod_sub_tip_operacion,'x') = nvl(p_sub_tip_operacion,'x')
         AND nvl(m.cod_tra_padre, pas_snp.fu_obt_cod_tra_padre) = pas_snp.fu_obt_cod_tra_padre ;

      SELECT h.fecha
        INTO v_fecha
        FROM ge_snp_horarios h
       WHERE h.cod_periodo = v_cod_periodo;

      IF v_estado = 'A' THEN
         RETURN v_fecha;
      END IF;

      RETURN pag_cal.fu_obt_fec_sig_hab(v_fecha, 1, 1);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   FUNCTION fu_obt_hor_fin_snp(p_cod_periodo IN ge_snp_horarios.cod_periodo%TYPE) RETURN VARCHAR2 IS
      v_retorno ge_snp_horarios.hor_fin%TYPE;
   BEGIN
      SELECT h.hor_fin
        INTO v_retorno
        FROM ge_snp_horarios h
       WHERE h.cod_periodo = p_cod_periodo;

      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   -- Retorna el horario de finalizacion de sipap
  FUNCTION fu_obt_hor_fin_snp(p_cod_msj_swift     IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                              p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                              p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE,
                              p_cod_tra_padre     IN ge_snp_par_mensajes.cod_tra_padre%type default null)
             RETURN VARCHAR2 IS
   v_hor_fin ge_snp_horarios.hor_fin%type;
   v_cod_periodo ge_snp_horarios.cod_periodo%type;
   BEGIN
     select m.cod_periodo
       into v_cod_periodo
     from ge_snp_par_mensajes m
    where m.cod_msj_swift = p_cod_msj_swift
      and m.cod_tip_operacion = p_tip_operacion
      and nvl(m.cod_sub_tip_operacion, '~') = nvl(p_sub_tip_operacion, '~');           --NVB-2232
    --  and nvl(m.cod_tra_padre, pas_snp.fu_obt_cod_tra_padre) = p_cod_tra_padre ;     --NVB-2232


     select hor_fin into v_hor_fin
      from ge_snp_horarios
      where cod_periodo = v_cod_periodo;

     RETURN v_hor_fin;
   END;
  -- retorna la hora de inicio / habilitacion de sipap
  FUNCTION fu_obt_hor_ini_snp(p_cod_msj_swift     IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                              p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                              p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE,
                              p_cod_tra_padre     IN ge_snp_par_mensajes.cod_tra_padre%type default null)
             RETURN VARCHAR2 IS
     v_hor_inicio ge_snp_horarios.hor_inicio%type;
     v_cod_periodo ge_snp_horarios.cod_periodo%type;
  BEGIN
    select m.cod_periodo
       into v_cod_periodo
     from ge_snp_par_mensajes m
    where m.cod_msj_swift = p_cod_msj_swift
      and m.cod_tip_operacion = p_tip_operacion
      and nvl(m.cod_sub_tip_operacion, '~') = nvl(p_sub_tip_operacion, '~');          --NVB-2232
     -- and nvl(m.cod_tra_padre, pas_snp.fu_obt_cod_tra_padre) = p_cod_tra_padre ;    --NVB-2232


     select hor_inicio into v_hor_inicio
      from ge_snp_horarios
      where cod_periodo = v_cod_periodo;

     RETURN v_hor_inicio;
  END;
  --

 FUNCTION fu_tieneInhibiciones(p_nroCuenta IN VARCHAR2) RETURN typ_mensajerespuesta IS
    v_retorno typ_mensajerespuesta := typ_mensajerespuesta;
    G_TIT_INHIBIDO CONSTANT VARCHAR2(15) := 'G_TIT_INHIBIDO';
    CURSOR titulares(p_numeroCuenta VARCHAR2) IS
      SELECT cod_persona FROM ge_cta_clientes c WHERE c.nro_cuenta = p_numeroCuenta;
  BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    FOR titular_rec IN titulares(p_nroCuenta) LOOP
      IF fug_obt_es_per_inhi(titular_rec.cod_persona) = 'S' THEN
         paw_uti.pr_mensajeUsuario(G_TIT_INHIBIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        RETURN v_retorno;
      END IF;
    END LOOP;
    RETURN v_retorno;
  END;


FUNCTION fu_TransferenciaLocal(p_mensajeCaja IN typ_mensajeCaja, p_canal IN VARCHAR2,
                               p_codigoPersona IN VARCHAR2, p_codigoEmpresa IN VARCHAR2,
                               p_fechaValor IN DATE, p_nroCuentaDebito IN VARCHAR2,
                               p_nroCuentaCredito IN VARCHAR2, p_montoDebito IN NUMBER,
                               p_montoCredito IN NUMBER, p_concepto IN VARCHAR2,
                               p_codigoOperacion IN VARCHAR2, p_sesion IN VARCHAR2,
                               p_modo IN VARCHAR2, p_nroDocumento IN NUMBER, p_nroDocBeneficiario VARCHAR2)
  RETURN typ_transferencialote IS
  v_retError      typ_mensajeRespuesta := typ_mensajeRespuesta;
  v_retorno       typ_transferencialote := typ_transferencialote;
  v_cod_tra_padre NUMBER(4) := 388; -- cod. transaccion padre
  v_procesa       VARCHAR2(1) := 'N'; -- indica si se puede o no procesar
  v_nro_secuencia NUMBER(3) := 0;

  v_fec_valor  DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
  v_hor_actual VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual

  v_horario       VARCHAR2(1);
  v_es_mov_noc    VARCHAR2(1);
  v_es_cta_noc    VARCHAR2(1);
  v_fec_actual    DATE;
  v_nro_operacion NUMBER(10); -- nro unico de operacion generado por el cliente

  v_nro_cta_debito  ge_cuentas.nro_cuenta%TYPE;
  v_cod_mon_debito  VARCHAR2(3) := v_cod_mon_local;
  v_nro_cta_credito ge_cuentas.nro_cuenta%TYPE;
  v_cod_mon_credito VARCHAR2(3) := v_cod_mon_local;

  v_cta_for_credito  VARCHAR2(17); -- cuenta formateada
  v_est_cta_credito  VARCHAR2(1); -- estado de la cuenta
  v_cod_mod_credito  NUMBER(4); -- modulo de la cuenta
  v_cod_mad_credito  NUMBER(4); -- modalidad de la cuenta
  v_cod_ofi_credito  NUMBER(4); -- oficina de la cuenta
  v_nvo_est_credito  VARCHAR2(1) := NULL; -- cambio de estado de cuenta
  v_sal_dis_credito  NUMBER(18, 2);
  v_nom_cta_credito  VARCHAR2(100);
  v_cod_operacion    bw_tip_mensajes.cod_tip_mensaje%TYPE := '039';
  v_res_notificacion NUMBER(2);
  TRA_CTA_DEB_ERROR         CONSTANT VARCHAR2(15) := 'TRA_CTA_DEB_ERR';
  TRA_CTA_CRE_ERROR         CONSTANT VARCHAR2(15) := 'TRA_CTA_CRE_ERR';
  TRA_EST_CTA_CRE_INVALIDA  CONSTANT VARCHAR2(15) := 'EST_CTA_CRE_INV';
  TRA_CTA_CRE_PROHIBIDA     CONSTANT VARCHAR2(15) := 'CTA_CRE_PROHIBI';
  TRA_CTA_CRE_VER_OPERACION CONSTANT VARCHAR2(15) := 'CTA_CRE_VER_OPE';
  TRA_CTA_CRE_NO_ENCONTRADA CONSTANT VARCHAR2(15) := 'CTA_CRE_NO_ENCO';
  TRA_TER_DIFF_MONEDA       CONSTANT VARCHAR2(15) := 'TRA_TER_DIFF_MO';
  TRA_MAD_CTA_CRE_INVALIDA  CONSTANT VARCHAR2(15) := 'MAD_CTA_CRE_INV';
  TRA_CTA_CRE_DEB_IGUAL     CONSTANT VARCHAR2(15) := 'CTA_CRE_DEB_IGU';
  TRA_CTA_DEB_INVALIDA      CONSTANT VARCHAR2(15) := 'CTA_DEB_INVALID';
  TRA_CTA_CRE_INVALIDA      CONSTANT VARCHAR2(15) := 'CTA_CRE_INVALID';

  v_msj_bitacora VARCHAR2(400) := substr('paw_bas.fu_TransferenciaLocal ctaDebito:' ||
                                         TRIM(p_nroCuentaDebito) || ', mto:' ||

                                         p_montoDebito || ', ctaCredito:' ||
                                         TRIM(p_nroCuentaCredito) || ', p_nroCuentaCredito:' ||
                                         TRIM(p_nroCuentaCredito) || ', cpto:' ||
                                         paw_uti.depurarTextos(p_concepto, 35), 1, 200);

  -- para recuperar e insertar respuestas.
  PROCEDURE lf_generarLog(p_Mensaje IN VARCHAR2, p_retorno IN OUT typ_transferencialote,
                          p_tipo IN VARCHAR2, p_codigoPersona IN VARCHAR2,
                          p_codigoEmpresa IN VARCHAR2, p_CodigoCanal IN VARCHAR2,
                          p_sesion IN VARCHAR2, p_cod_operacion IN VARCHAR2, p_adicional IN VARCHAR2) IS
  BEGIN

    paw_uti.pr_mensajeUsuario(p_Mensaje, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta,
                              p_retorno.error);
    paw_uti.pr_insertarBitacora(p_codigoPersona, p_CodigoCanal, p_sesion, p_cod_operacion,
                                p_codigoEmpresa,
                                p_adicional ||
                                 paw_uti.fu_generarbitacora(p_retorno.error,
                                                            p_retorno.nombreRespuesta,
                                                            p_retorno.descripcionRespuesta, NULL),
                                p_tipo);

  END;

  FUNCTION fu_obt_nominacionCuenta(p_nroCuenta IN VARCHAR2, p_nroDocBeneficiario IN VARCHAR2) RETURN VARCHAR2 IS
    ctaDenominacion VARCHAR2(50);
  BEGIN
    BEGIN
      SELECT b.pri_nombre || ' ' || b.pri_apellido
      INTO ctaDenominacion
      FROM ba_per_fisicas b
      LEFT JOIN ge_cta_clientes g ON b.cod_persona = g.cod_persona
      LEFT JOIN ba_personas ba ON ba.cod_persona = b.cod_persona
      WHERE g.nro_cuenta = p_nroCuenta
      AND ba.nro_documento = p_nroDocBeneficiario;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN '';
    END;
    RETURN ctaDenominacion;
  END;

BEGIN
  v_nro_cta_debito  := paw_uti.depurarAlfanumerico(p_nroCuentaDebito, CUENTA_TAMANO);
  v_nro_cta_credito := paw_uti.depurarAlfanumerico(p_nroCuentaCredito, CUENTA_TAMANO);

  -- Cargar OK
  lf_generarLog(paw_uti.MSG_OK, v_retorno, paw_uti.BITACORA_ENTRADA, p_codigoPersona,
                p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, v_msj_bitacora);

  BEGIN
    IF (fug_obt_mon_cta(v_nro_cta_debito) <> fug_obt_mon_cta(v_nro_cta_credito)) THEN
      lf_generarLog(TRA_TER_DIFF_MONEDA, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                    p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, v_msj_bitacora);
      RETURN v_retorno;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      lf_generarLog(TRA_CTA_CRE_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                    p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, 'Mon <> deb cre');
      RETURN v_retorno;
  END;

  IF (v_nro_cta_debito = v_nro_cta_credito) THEN
    lf_generarLog(TRA_CTA_CRE_DEB_IGUAL, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                  p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, v_msj_bitacora);
    RETURN v_retorno;
  END IF;

  v_fec_actual := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy

  --Copio los valores para la respuesta
  --v_retorno.NumeroLote:=p_nroLote;
  v_retorno.CodigoPersona    := p_codigoPersona;
  v_retorno.NumeroCuenta     := p_nroCuentaDebito;
  v_retorno.CodigoMoneda     := v_cod_mon_debito;
  v_retorno.Monto            := p_montoDebito;
  v_retorno.FechaPago        := v_fec_actual;
  v_retorno.NroCuentaCredito := p_nroCuentaCredito;
  v_retorno.CodigoBanco      := 7;
  v_retorno.Concepto         := p_concepto;
  v_retorno.NombreBeneficiario := fu_obt_nominacionCuenta(p_nroCuentaCredito, p_nroDocBeneficiario);
  v_retorno.NumeroDocBeneficiario := p_nroDocBeneficiario;
  IF paw_uti.fu_val_cuenta(p_codigoPersona, v_nro_cta_debito, NULL, NULL, NULL).error = 'S' THEN
    -- no es una cuenta del cliente
    lf_generarLog(TRA_CTA_DEB_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                  p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, 'No es una cuenta del cliente');
    RETURN v_retorno;
  END IF;

  --Validar cuenta credito
  BEGIN
    SELECT a.cod_moneda, a.estado, cod_modalidad, cod_modulo, cod_oficina,
           fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda) cta_formateada,
           denominacion
    INTO   v_cod_mon_credito, v_est_cta_credito, v_cod_mad_credito, v_cod_mod_credito,
           v_cod_ofi_credito, v_cta_for_credito, v_nom_cta_credito
    FROM   ge_cuentas a
    WHERE  a.nro_cuenta = v_nro_cta_credito; -- contiene el nro de cuenta

    IF v_cod_mad_credito NOT IN (31, 41) THEN
      lf_generarLog(TRA_MAD_CTA_CRE_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                    p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, v_msj_bitacora);
      RETURN v_retorno;

    ELSIF v_est_cta_credito NOT IN ('A', 'I', 'N', 'S') THEN
      lf_generarLog(TRA_EST_CTA_CRE_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                    p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, v_msj_bitacora);
      RETURN v_retorno;
    ELSIF pag_cta.fu_ver_tra_prohibida(v_nro_cta_credito, v_cod_tra_padre, 9, 91) = 'S' THEN
      lf_generarLog(TRA_CTA_CRE_PROHIBIDA, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                    p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, v_msj_bitacora);
      RETURN v_retorno;
    END IF;

  EXCEPTION
    WHEN no_data_found THEN
      lf_generarLog(TRA_CTA_CRE_NO_ENCONTRADA, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                    p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, v_msj_bitacora);

      RETURN v_retorno;
  END;

  pag_cta.pr_ver_operacion(v_nro_cta_credito, v_cod_tra_padre, 9, 91, 'C', v_cod_mon_credito,
                           p_montoCredito, p_mensajeCaja.codigoOficinaOrigen /* v_cod_ofi_origen */,
                           v_cod_mod_credito, v_cod_mad_credito, v_nvo_est_credito,
                           v_sal_dis_credito, v_procesa, 602);

  IF v_procesa = 'N' THEN
    -- no se puede Acreditar en la cuenta
    lf_generarLog(TRA_CTA_CRE_VER_OPERACION, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                  p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion, v_msj_bitacora);

    RETURN v_retorno;
  END IF;

  -- confirmacion de operacion
  -- seteo las variables
  v_nro_secuencia := 0;
  pag_cta.PR_SET_VARIABLES(p_mensajeCaja.codigoUsuario, p_fechaValor, v_cod_tra_padre, 'N', 'N',
                           v_nro_secuencia, NULL, p_mensajeCaja.codigoOficinaOrigen, 9, 91);
  -- esta la cuenta en condiciones, verifico el horario
  -- lp_ver_horario;
  v_retError := fu_ver_horario(v_horario, v_es_mov_noc, v_es_cta_noc,
                               p_mensajeCaja.fechaUltimoCierre, p_mensajeCaja.codigoOficinaOrigen,
                               v_fec_actual);

  IF (v_retError.error = 'S') THEN
    v_retorno.error                := 'S';
    v_retorno.nombreRespuesta      := v_retError.nombreRespuesta;
    v_retorno.descripcionRespuesta := v_retError.descripcionRespuesta;
    RETURN v_retorno;
  END IF;
  -- genero el numero de operacion
  IF (p_modo = 'C') THEN
    SELECT s_nro_ope_homebanking.NEXTVAL
    INTO   v_nro_operacion
    FROM   dual;
    v_hor_actual            := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, USER, v_es_mov_noc);
    v_retorno.NroReferencia := v_nro_operacion;

    --Debito
    BEGIN
      pag_cta.PR_ACT_OPERACION(v_nro_cta_debito, v_hor_actual, 'D', v_cod_mon_debito, p_montoDebito,
                               v_cod_tra_padre, 503, p_nroDocumento, 1,
                               p_mensajeCaja.codigoOficinaOrigen, 9, 91, NULL, NULL,
                               'Transf. terceros a ' || v_nro_cta_credito || ' desde ' ||
                                v_nro_cta_debito || ' - ' || p_concepto, 'N', v_nro_secuencia,
                               v_fec_valor, NULL, NULL, p_montoDebito);
      IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
        -- hubo error en el debito
        lf_generarLog(TRA_CTA_DEB_ERROR, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                      p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion,
                      ', ERR:[' || substr(pag_cta.G_MSJ_ERROR, 1, 200) || '] ' || v_msj_bitacora);

        RETURN v_retorno;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        lf_generarLog(TRA_CTA_DEB_ERROR, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                      p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion,
                      ',  DEB pr_act_operacion:[' || substr(SQLERRM, 1, 200) || '] ' ||
                       v_msj_bitacora);

        RETURN v_retorno;
    END;
    --Credito
    BEGIN
      pag_cta.PR_ACT_OPERACION(v_nro_cta_credito, v_hor_actual, 'C', v_cod_mon_credito,
                               p_montoCredito, v_cod_tra_padre, 602, p_nroDocumento, 1,
                               p_mensajeCaja.codigoOficinaOrigen, 9, 91, NULL, NULL,
                               'Transf. terceros a ' || v_nro_cta_credito || ' desde ' ||
                                v_nro_cta_debito || ' - ' || p_concepto, 'N', v_nro_secuencia,
                               v_fec_valor, NULL, NULL, p_montoCredito);
      IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
        -- hubo error en el credito
        lf_generarLog(TRA_CTA_CRE_ERROR, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                      p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion,
                      ', ERR:[' || substr(pag_cta.G_MSJ_ERROR, 1, 200) || '] ' || v_msj_bitacora);
        RETURN v_retorno;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        lf_generarLog(TRA_CTA_CRE_ERROR, v_retorno, paw_uti.BITACORA_ERROR, p_codigoPersona,
                      p_codigoEmpresa, p_canal, p_sesion, p_codigoOperacion,
                      ',  CRE pr_act_operacion:[' || substr(SQLERRM, 1, 200) || '] ' ||
                       v_msj_bitacora);
        RETURN v_retorno;
    END;
    IF fug_obt_cli_principal(v_nro_cta_credito) = nvl(p_codigoEmpresa, p_codigoPersona) THEN
       v_cod_operacion := '030';
    END IF;
    --Notificacion al credito
    BEGIN
      v_res_notificacion := PAW_NOT.fu_not_transferencias(v_nro_cta_credito, p_montoCredito,
                                                          v_cod_mon_credito, 'C', v_fec_valor);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    /*
     CANREQVAR - 612
     Notificacion via mail a clientes BBVA por transf entre cuentas y Terceros.
    */
    BEGIN
      v_res_notificacion := paw_not.fu_not_mail_transferencias(v_nro_cta_debito, v_nro_cta_credito,
                                                               v_cod_mon_debito, v_cod_mon_credito,
                                                               v_cod_operacion, p_montoDebito, p_montoCredito,
                                                               p_fechaValor);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    -- registro del movimiento
    paw_uti.lp_reg_operacion(v_nro_cta_debito /*p_nro_cuenta*/, v_cod_mon_debito /*p_cod_moneda */,
                             p_montoDebito /*p_monto*/, v_nro_cta_credito /*p_nro_cta_contra*/, NULL
                              /*p_cantidad*/, NULL /*p_etiqueta*/, v_res_notificacion /*p_dato*/,
                             'Cotizacion' /*p_etiqueta2*/, 1 /*p_dato2*/, 'Yaguarete' /*observacion*/,
                             NULL /*direccion IP*/, '000', p_CodigoPersona, p_codigoOperacion,
                             v_nro_operacion, p_canal, p_sesion, NULL); --codEmpresa
  END IF;
  RETURN v_retorno;
END;

FUNCTION fu_TransferenciaInterbancaria(p_mensajeCaja           IN typ_mensajeCaja,
                                       p_canal                 IN VARCHAR2, 
                                       p_modo                  IN VARCHAR2,
                                       p_codigoPersona         IN VARCHAR2,
                                       p_codigoEmpresa         IN VARCHAR2, 
                                       p_fechaValor            IN DATE,
                                       p_nroCuentaDebito       IN VARCHAR2, 
                                       p_nroCuentaCredito      IN VARCHAR2, 
                                       p_codMonCredito         IN VARCHAR2,
                                       p_montoCredito          IN NUMBER,
                                       p_concepto              IN VARCHAR2,
                                       p_codigoSwift           IN VARCHAR2, 
                                       p_nombreBeneficiario    IN VARCHAR2,
                                       p_DirBeneficiario       IN VARCHAR2,
                                       p_codTipoDocumentoBen   IN NUMBER,
                                       p_numeroDocBeneficiario IN VARCHAR2, 
                                       p_sesion                IN VARCHAR2,
                                       p_prioridad             IN VARCHAR2, 
                                       p_tip_cargos            IN VARCHAR2,
                                       p_firmasRequeridas      IN NUMBER DEFAULT NULL,
                                       p_numeroContrato        IN NUMBER DEFAULT NULL) RETURN typ_transferencialote IS
  v_mensajeCaja           typ_mensajeCaja;
  v_cod_swift             ge_bancos.cod_swift%TYPE;
  v_cod_msj_swift         ge_snp_transferencias.cod_msj_swift%TYPE := 103;
  v_retorno_men_res       typ_mensajerespuesta;
  v_prioridad             VARCHAR2(1);
  v_tip_cargos            ge_snp_transferencias.tip_cargo%TYPE;
  v_cod_tip_operacion     ge_snp_par_mensajes.cod_tip_operacion%TYPE := '001';
  v_cod_sub_tip_operacion ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE := '002';
  v_est_periodo           ge_snp_horarios.estado%TYPE := 'N'; -- Estado del Periodo SNP
  v_mto_max_ach           ge_movimientos.monto%TYPE;
  v_retorno               typ_transferencialote := typ_transferencialote;
  v_cod_tra_padre         ge_transacciones.cod_transaccion%TYPE := 303; -- cod. transaccion padre
  v_cod_tra_credito       ge_transacciones.cod_transaccion%TYPE := 196; -- cod. transaccion hijo credito
  v_cod_tra_debito        ge_transacciones.cod_transaccion%TYPE := 503; -- cod. transaccion hijo debito
  v_cta_pte_solicitante   VARCHAR2(20); -- Nro de Cuenta Interbancaria
  v_cta_pte_sol_bcp       VARCHAR2(20);
  v_nro_referencia        ge_snp_transferencias.nro_referencia%TYPE;
  v_cta_for_debito        VARCHAR2(17);
  v_cod_mod_padre         ge_modalidades.cod_modulo%TYPE; -- Modulo Padre
  v_cod_mad_padre         ge_modalidades.cod_modalidad%TYPE; -- Modalidad Padre
  v_tip_movimiento        VARCHAR2(1); -- D:Debito; C: Credito
  v_cod_mad_debito        ge_cuentas.cod_modalidad%TYPE; -- Modalidad de la cuenta
  v_cod_ofi_debito        ge_cuentas.cod_oficina%TYPE; -- oficina de la cuenta
  v_cod_mod_debito        ge_cuentas.cod_modulo%TYPE; -- Modulo de la cuenta
  v_msj_swift             ge_snp_transferencias.msj_swift%TYPE;
  v_cod_operacion         bw_tip_mensajes.cod_tip_mensaje%TYPE := '036';
  r_gtran                 pas_snp.rg_msj;
  v_nro_secuencia         ge_movimientos.nro_secuencia%TYPE := 0;
  v_can_fir_requeridas    bw_mov_pendientes.can_aut_requeridas%TYPE := nvl(p_firmasRequeridas, 0);
  v_cod_tip_documento     ge_snp_transferencias.cod_tip_doc_solicitante%TYPE;
  v_nro_doc_credito       ge_snp_transferencias.nro_doc_beneficiario%TYPE;
  v_cod_respuesta         NUMBER;
  v_nro_ope_cambio        lc_ope_pendientes.nro_operacion%TYPE;
  v_nro_documento         bw_mov_pendientes.nro_documento%TYPE;

  v_fec_actual            DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
  v_fec_valor             DATE := v_fec_actual;
  v_fec_operacion         ge_calendarios.fec_actual%TYPE := nvl(p_fechaValor, v_fec_actual);
  v_hor_actual            VARCHAR2(8) := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
  v_nro_cta_debito        VARCHAR2(16);
  v_nro_cta_credito       ge_snp_transferencias.nro_cta_beneficiario%TYPE;
  v_nom_cta_debito        ge_cuentas.denominacion%TYPE; -- Nombre de la cuenta
  v_cot_debito            ge_movimientos.cotizacion%TYPE := NULL;
  v_cod_mon_debito        ba_monedas.cod_moneda%TYPE; -- Moneda de la cuenta
  v_mto_debito            ge_movimientos.monto%TYPE;
  v_mto_credito           ge_movimientos.monto%TYPE;
  v_cot_credito           ge_movimientos.cotizacion%TYPE := NULL;
  v_cod_mon_credito       ba_monedas.cod_moneda%TYPE;
  v_mto_equ_local         ge_movimientos.mto_equ_local%TYPE := NULL;
  v_msj_bitacora          VARCHAR2(1000);
  v_nro_contrato          NUMBER;
  v_tip_operacion         VARCHAR2(3);
  v_modo                  VARCHAR2(1) := nvl(substr(trim(p_modo), 1, 1), 'x');
  v_cli_pue_enviar        varchar2(1);
  v_redondeo              NUMBER;
  
   id_pago                     ge_spi_transferencias.id_pago%type;
   resultado                   ge_spi_transferencias.message_result%type;
   motivo                      varchar2(100);
   r_gtranspi                  pas_spi.rg_msj;
   P_RESULT                    ge_spi_transferencias.error%type;
   P_DET_ERROR                 ge_spi_transferencias.error%type;
   P_RESULT_PRO                ge_spi_transferencias.error%type;
   P_DET_ERROR_PRO             ge_spi_transferencias.error%type;
   tipo_transferencia          varchar2(20);
   v_bic_origen                ge_spi_transferencias.bic_origen%type;
   v_tip_doc_receptor          ge_spi_transferencias.tip_doc_receptor%type;
   v_spi_detectado             varchar2(3);
   v_spi_hab_tm                VARCHAR2(1) := fug_obt_pardinamico('SPI_HAB_TM');
   v_spi_hab_pj                VARCHAR2(1) := fug_obt_pardinamico('SPI_HAB_PJ');
   v_spi_hab_corr_ok           VARCHAR2(1) := fug_obt_pardinamico('SPI_ENV_CORR_TM_OK');
   v_spi_hab_corr_fail         VARCHAR2(1) := fug_obt_pardinamico('SPI_ENV_CORR_TM_FAIL');
   v_dir_correo_spi            ge_par_dinamicos.val_parametro%TYPE;
   
    v_banco                     varchar2(100):=NULL;
    v_mje_mail                  LONG;
    v_texto                     varchar2(32000);
    v_texto_detalle             varchar2(32000) := null;
    v_tex_err                   varchar2(4000);
    v_membrete                  LONG := fug_gen_template('M');
    V_FIN                       LONG := fug_gen_template('F');
    V_PIE                       LONG := fug_gen_template('P');
    v_nro_notificacion          number(20);
    v_env_por                   varchar2(100):=fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');
    v_des_monto                 varchar2(100) := NULL;
    v_descripcion_resp          bw_men_respuesta.des_mensaje%TYPE := null;
    v_tipo_persona              varchar2(2);
    v_tipo_doc                  ba_tip_documentos.abreviatura%TYPE := null;
   

  --  Tipos de Mensajes de respuestas
  MSG_MTO_INVALIDO  CONSTANT VARCHAR2(15) := 'MTO_INVALIDO'; /**Monto invalido*/
  MSG_HORA_INVA     CONSTANT VARCHAR2(15) := 'HORA_INVA'; /**Hora Invalida*/
  MSG_CONCAM_INVA   CONSTANT VARCHAR2(15) := 'CONCAM_INVA'; /**Contrato de Cambio invalido*/
  CTA_DEB_INVALIDA  CONSTANT VARCHAR2(15) := 'CTA_DEB_INVALID'; /**Codigo de Cuenta invalida*/
  MSG_CTA_INT_INVA  CONSTANT VARCHAR2(15) := 'CTA_INT_INVA'; /**Cuenta Interbancaria Invalida*/
  MSG_FECHA_INVA    CONSTANT VARCHAR2(15) := 'FECHA_INVA'; /**Fecha Invalida*/
  MSG_ERR_CONVERS   CONSTANT VARCHAR2(15) := 'ERR_CONVERS'; /**Error de conversion*/
  MSG_CODPED_DUPLI  CONSTANT VARCHAR2(15) := 'CODPED_DUPLI'; /**Codigo pedido duplicado*/
  MSG_TRA_INVALIDA  CONSTANT VARCHAR2(15) := 'TRA_INVALIDA'; /** Transaccion invalida*/
  MSG_SIN_PERMISO   CONSTANT VARCHAR2(15) := 'SNP_SIN_AUTORIZ'; 
  MSG_REFTRAEX_INVA CONSTANT VARCHAR2(15) := 'REFTRAEX_INVA'; /**Nro de Referencia Transf. exterior invalida*/
  MSG_CONFSNP_INVA  CONSTANT VARCHAR2(15) := 'CONFSNP_INVA'; /**Confirmacion SNP Invalida*/
  MSG_MONEDA_ER     CONSTANT VARCHAR2(15) := 'MONEDA_ER'; /**Error al obtener moneda*/
  MSG_MTO_MAX_ACH   CONSTANT VARCHAR2(15) := 'SNP_MTO_MAX_ACH'; /*Limite de ach sobrepasado*/
  MSG_TIP_BCP_INV   CONSTANT VARCHAR2(15) := 'SNP_BCP_INV'; /**Tipo de envio invalido para BCP*/
  MSG_OK            CONSTANT VARCHAR2(30) := 'OP_APROBADA';
  -- para recuperar e insertar respuestas.
  PROCEDURE lf_generarLog(p_Mensaje IN VARCHAR2, p_retorno IN OUT typ_transferencialote, p_tipo IN VARCHAR2, p_adicional IN VARCHAR2) IS
  BEGIN
    paw_uti.pr_mensajeUsuario(p_Mensaje, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
    paw_uti.pr_insertarBitacora(p_codigoPersona, p_canal, p_sesion, v_cod_operacion, p_codigoEmpresa, p_adicional || paw_uti.fu_generarbitacora(p_retorno.error, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, NULL), p_tipo);
  END;
BEGIN
  -- Se comenta por diferencias existentes en pas_spi.rg_msj 
 /*  v_mensajeCaja     := p_mensajeCaja;
   v_nro_cta_debito  := paw_uti.depurarAlfanumerico(p_nroCuentaDebito, CUENTA_TAMANO);
   v_nro_cta_credito := paw_uti.depurarAlfanumerico(p_nroCuentaCredito, 16);
   v_cod_swift       := paw_uti.depurarAlfanumerico(p_codigoSwift, 20);
   v_nro_contrato    := nvl(p_numeroContrato, 0);
   v_cod_mon_credito := substr(nvl(p_codMonCredito, 'x'), 1, 3);
   v_mto_credito     := nvl(p_montoCredito, 0);
   v_nro_doc_credito := paw_uti.depurarTextos(p_numeroDocBeneficiario, 20);
   v_cod_tip_documento := paw_uti.depurarNumerico(p_codTipoDocumentoBen, 3);
   
   v_msj_bitacora    := substr('modo: '||v_modo||', nroCtaDebito:' || v_nro_cta_debito || ', nroCtaCredito:' || v_nro_cta_credito || ',codSwift:' || v_cod_swift ||',ope:'||v_cod_operacion
                                               ||', monCre:'||v_cod_mon_credito||', mtoCre:'||v_mto_credito||', canFir:'||v_can_fir_requeridas||', nroCon:'||v_nro_contrato, 1, 1000); 
   
   -- Cargar OK
   lf_generarLog(paw_uti.MSG_OK, v_retorno, paw_uti.BITACORA_ENTRADA, v_msj_bitacora);
   
   -- obtenemos la moneda de la cuenta debito
   BEGIN
      v_cod_mon_debito := fug_obt_mon_cta(v_nro_cta_debito);
   EXCEPTION
     WHEN OTHERS THEN
        lf_generarLog(CTA_DEB_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora||', ora-err: '||SQLERRM);
        RETURN v_retorno;
   END;
   -- chequeo de caja
   IF v_mensajeCaja.error = 'S' THEN
      lf_generarLog(MSG_TRA_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora||', caja invalida ');
      RETURN v_retorno;
   END IF;

   -- obtenemos el monto a debitar en base al monto credito y monedas de las cuentas
   IF v_cod_mon_credito <> v_cod_mon_debito THEN
      -- obtenemos el monto a la cotizacion del dia
      IF v_nro_contrato = 0 THEN
         BEGIN
            paw_uti.pr_con_mon_a_moneda(v_cod_mon_credito, v_cod_mon_debito, v_mto_credito, v_mto_debito, v_cot_credito, v_cot_debito, 'S');
         EXCEPTION
            WHEN OTHERS THEN
               lf_generarLog(MSG_ERR_CONVERS, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
               RETURN v_retorno;
         END;
      ELSE
         -- obtenemos el monto en base al contrato de cambio
         v_cod_respuesta := fu_val_contrato(v_cod_mon_debito, v_cod_mon_credito, v_nro_contrato, nvl(p_codigoEmpresa, p_codigoPersona), 47, v_nro_doc_credito,
                                            v_nro_ope_cambio, v_mto_debito, v_mto_credito, v_cot_debito, v_cot_credito, 
                                            v_mto_equ_local, v_tip_operacion);
         v_msj_bitacora := substr(v_msj_bitacora || ', mtoCon:' || v_mto_debito || ', mtoCreCon:'|| v_mto_credito, 1, 1000);  
         IF v_cod_respuesta = -1 THEN
            lf_generarLog(MSG_HORA_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
            RETURN v_retorno;
         ELSIF v_cod_respuesta <> 0 THEN
            lf_generarLog(MSG_CONCAM_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
            RETURN v_retorno;
         END IF;
      END IF;
   ELSE
      -- Se iguala el monto por que la Moneda Credito y Debito es igual
      v_mto_debito := v_mto_credito;
      if v_nro_contrato > 0 then
         lf_generarLog(MSG_CONCAM_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);  
         RETURN v_retorno;
       END IF ;
       IF v_mto_credito <= 0 OR v_mto_debito <= 0 THEN
          lf_generarLog(MSG_MTO_INVALIDO, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora); 
          RETURN v_retorno;
       END IF;
   END IF;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_cod_mon_credito);
   IF v_mto_credito <> round(v_mto_credito,  v_redondeo) then
      v_msj_bitacora := v_msj_bitacora || ', moneda no admite decimal';
      lf_generarLog(MSG_MTO_INVALIDO, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora); 
      RETURN v_retorno;
   END IF;
   
   v_msj_bitacora := substr(v_msj_bitacora||',mtoDeb:'||v_mto_debito||',monDeb:'||v_cod_mon_debito, 1, 1000);
   IF p_codigoEmpresa IS NOT NULL AND v_can_fir_requeridas = 0 AND v_modo IN ('V', 'C') THEN
      lf_generarLog(MSG_SIN_PERMISO, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora || ', empresa con firma 0'); 
      RETURN v_retorno;
   END IF;
   if p_modo in ('V', 'C', 'A', 'P') THEN
     -- Enviamos en el parametro los datos del MT103 que corresponde a tranf del clientes.
     -- si cumple con las condiciones debe ir como mt103, sino ira como MT10
     v_cli_pue_enviar := fug_pue_env_tra_fue_hora('103','001','002',v_cod_tra_padre,v_mto_credito, v_cod_mon_credito, null, v_nro_cta_debito);
     IF (p_prioridad = 'A' OR p_prioridad IS NULL) and
        (paw_bas.fu_obt_tip_TransfInterbancaria('103','001','002',v_cod_tra_padre,v_mto_credito, v_cod_mon_credito, null, nvl(p_codigoEmpresa, p_codigoPersona)) ='103')
     THEN
        --if fug_den_per_act_snp('103','001','002',v_cod_tra_padre,1) = 'S' then
        v_cod_msj_swift          := '103';
        v_prioridad             := 'A';
        v_cod_tip_operacion     := '001';
        v_cod_sub_tip_operacion := '002';
        if ((fug_den_per_act_snp('103','001','002',v_cod_tra_padre,3) = 'S') and
            (v_cod_mon_credito = v_cod_mon_local) and
            (v_cod_mon_debito <> v_cod_mon_local) and 
            (v_cli_pue_enviar = 'S'))
           then
           v_cod_msj_swift          := '102';
           v_prioridad              := 'B';
           v_cod_tip_operacion      := '011';
           v_cod_sub_tip_operacion  := '001';
           if v_fec_actual = trunc(sysdate) then
             -- seteamos para el siguiente dia
             v_fec_valor              := pag_cal.FU_OBT_FEC_SIG_HAB(v_fec_actual,1);
           end if;
        end if;
     else
        v_cod_msj_swift          := '102';
        v_prioridad              := 'B';
        v_cod_tip_operacion      := '011';
        v_cod_sub_tip_operacion  := '001';
        if v_fec_actual = trunc(sysdate) then
          -- seteamos para el siguiente dia
          v_fec_valor              := pag_cal.FU_OBT_FEC_SIG_HAB(v_fec_actual,1);
        end if;
     END IF;
   end if;
   v_fec_operacion := paw_bas.fu_obt_snp_fec_acreditacion(v_cod_msj_swift, v_cod_mon_credito);    
   -- OMM DIC/2017 Ajuste para no generar MT102
   \*IF nvl(p_prioridad, 'A') = 'A' OR nvl(v_hab_ach, 'N') = 'N' THEN
      v_cod_msj_swift         := 103;
      v_prioridad             := 'A';
      v_cod_tip_operacion     := '001';
      v_cod_sub_tip_operacion := '002';
   ELSIF p_prioridad = 'B' THEN
      v_cod_msj_swift         := 102;
      v_prioridad             := 'B';
      v_cod_tip_operacion     := '011';
      v_cod_sub_tip_operacion := '001';
   END IF;*\

   --v_fec_operacion   := p_fechaValor;
   v_msj_bitacora := substr(v_msj_bitacora||', fecOpe:'||to_char(v_fec_operacion, 'dd-mm-yyyy'),  1, 1000);

   v_est_periodo := pas_snp.fu_obt_est_horario(v_cod_msj_swift, v_cod_tip_operacion, v_cod_sub_tip_operacion);
   if ((v_est_periodo = 'A') and
       (fug_den_per_act_snp('103','001','002',v_cod_tra_padre,3) = 'S') and
       (v_cli_pue_enviar <> 'S')) then
        v_est_periodo := 'C';
   end if;
   
   -- Valida que este abierto el periodo si es de fecha actual
   IF trunc(v_fec_operacion) = trunc(v_fec_actual) THEN
     pas_snp.pr_ini_variables ;

      --v_est_periodo := pas_snp.fu_obt_est_horario(v_cod_msj_swift, v_cod_tip_operacion, v_cod_sub_tip_operacion);
      --if ((v_est_periodo = 'A') and
      --    (fug_den_per_act_snp('103','001','002',v_cod_tra_padre,3) = 'S') and
      --    (v_cli_pue_enviar <> 'S')) then
      --     v_est_periodo := 'C';
      --end if;
   END IF;
   -- operaciones de cambio solo en horario abierto.
   IF v_cod_mon_credito <> v_cod_mon_debito THEN
      -- Verifica que no pueda realizar cambio de monedas en fecha distinta a la fecha actual
      IF v_fec_operacion <> v_fec_actual THEN
        lf_generarLog(MSG_FECHA_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora||', fec_operacion <> fec_actual');
        RETURN v_retorno;
      END IF;
      -- Verifica que no pueda realizar cambio de monedas si el horario sipap esta cerrado.
      IF v_fec_operacion = v_fec_actual AND v_est_periodo <> 'A'  then
         lf_generarLog(MSG_HORA_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora||', Horario sipap cerrado');
         RETURN v_retorno;
      END IF;
   END IF;

   -- validaciones de transf. en lote
   IF v_cod_operacion = '029' THEN 
      IF v_cod_mon_credito <> v_cod_mon_debito THEN
         lf_generarLog(MSG_MONEDA_ER, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
         RETURN v_retorno;
      END IF;
   
      IF p_codigoEmpresa IS NOT NULL THEN
         lf_generarLog(MSG_TRA_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora||', empresa sin persmio para lote');
         RETURN v_retorno;
      END IF;
   END IF;

   -- Valida la cuenta debito si puede realizar la operacion
   v_retorno_men_res := fu_val_cta_debito(v_nro_cta_debito, v_cod_tra_padre, v_mto_debito,
                                          v_cod_mon_debito, v_cod_mod_debito, v_cod_mad_debito,
                                          v_cod_ofi_debito, v_cta_for_debito, v_nom_cta_debito,
                                          p_codigoEmpresa, v_mensajeCaja, v_can_fir_requeridas);

   IF (v_retorno_men_res.error = 'S') THEN
      lf_generarLog(v_retorno_men_res.nombreRespuesta, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
      RETURN v_retorno;
   END IF;

   IF paw_uti.fu_val_cuenta(nvl(p_codigoEmpresa, p_codigoPersona), v_nro_cta_debito, NULL, NULL, NULL).error = 'S' THEN
      -- no es una cuenta del cliente
      lf_generarLog(CTA_DEB_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora||', No es una cuenta del cliente');
      RETURN v_retorno;
   END IF;

   --  Si es BCP hay que cambiar el sub tipo de operacion a 005
   IF v_cod_swift = nvl(fug_obt_pardinamico('SNP_BIC_BCP'), 'X') THEN
      v_cod_sub_tip_operacion := nvl(fug_obt_pardinamico('SNP_SUB_TIP_OPE_TRA_BCP'), '005'); -- DDSI-62
      -- No se pueden hacer transferencias por lotes al BCP
      IF v_cod_tip_operacion = '011' THEN
         lf_generarLog(MSG_TIP_BCP_INV, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
         RETURN v_retorno;
      END IF;
   END IF;
   \* Si es 102 hay que verificar que el monto debito no supere el limite en MTO_MAX_ACH y la moneda de credito tiene que ser GS*\
   IF (v_cod_msj_swift = 102) THEN
      v_mto_max_ach := to_number(fug_obt_pardinamico('MTO_MAX_ACH'));
      IF v_cod_mon_local <> v_cod_mon_credito THEN
         lf_generarLog(MSG_ERR_CONVERS, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
         RETURN v_retorno;
      END IF;
      IF (v_mto_credito > v_mto_max_ach) THEN
         lf_generarLog(MSG_MTO_MAX_ACH, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
         RETURN v_retorno;
      END IF;
   END IF;

   -- Inicializa las Variables del PAS_SNP
   pas_snp.pr_ini_variables;
   pas_snp.pr_ini_registros;
   v_cta_pte_sol_bcp     := pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad), v_cod_mon_credito);
   v_cta_pte_solicitante := pas_snp.fu_obt_cta_bancaria(v_cta_pte_sol_bcp, 'C');
   IF pas_snp.fu_obt_cod_error <> 0 THEN
      lf_generarLog(MSG_CTA_INT_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora||', err:'||pas_snp.g_msj_error);
      RETURN v_retorno;
   END IF;

   IF v_cta_pte_sol_bcp IS NULL THEN
      lf_generarLog(MSG_CTA_INT_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora||', sin cta_pte_sol_bcp');
      RETURN v_retorno;
   ELSE
      r_gtran.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(v_cod_swift, v_cod_mon_credito);
      IF pas_snp.fu_obt_cod_error <> 0 THEN
         v_msj_bitacora := substr(v_msj_bitacora || ',msg-cod:' || pas_snp.fu_obt_cod_error || ', msg-snp:[' ||
                          substr(pas_snp.g_msj_error, 1, 200) || '] -** ', 1, 1000);
         lf_generarLog(MSG_CTA_INT_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
         RETURN v_retorno;
      END IF;

      --Se Evalua que no exista duplicaos
    r_gtran.fec_valor                := v_fec_operacion;
    r_gtran.cod_msj_swift            := v_cod_msj_swift;
    r_gtran.nro_cta_solicitante      := v_nro_cta_debito;
    r_gtran.nro_cta_pte_solicitante  := v_cta_pte_sol_bcp;
    r_gtran.nro_cta_beneficiario     := lpad(v_nro_cta_credito, 16, '0');
    r_gtran.cod_swi_pte_beneficiario := v_cod_swift;
    r_gtran.cod_moneda               := v_cod_mon_credito;
    r_gtran.monto                    := v_mto_credito;

       -- Valida la fecha ingresada
       IF nvl(pas_snp.fu_val_fec_valor(v_fec_operacion), 9) <> 0 OR pag_cal.fu_obt_fec_habil(v_fec_operacion, 1, 1) <> v_fec_operacion THEN
         lf_generarLog(MSG_FECHA_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora ||', obt. fecha habil');
         RETURN v_retorno;
      END IF;

      IF pas_snp.fu_ver_mov_duplicados(r_gtran) <> 0 THEN
         lf_generarLog(MSG_CODPED_DUPLI, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora||', pas_snp.fu_ver_mov_duplicados');
         RETURN v_retorno;
      END IF;
   END IF;
   IF p_tip_cargos = 'O' THEN
      v_tip_cargos := 'OUR';
   ELSIF p_tip_cargos = 'B' THEN
      v_tip_cargos := 'BEN';
   ELSE
      v_tip_cargos := 'SHA';
   END IF;
   v_msj_bitacora := v_msj_bitacora || ', tipCar:' || v_tip_cargos;
   v_retorno.FechaPago             := v_fec_operacion;
   v_retorno.CodigoPersona         := substr(nvl(p_codigoEmpresa, p_codigoPersona), 1, 10);
   v_retorno.CodigoBanco           := v_cod_swift;
   v_retorno.Concepto              := paw_uti.depurarTextos(p_concepto, 100);
   v_retorno.NumeroCuenta          := v_nro_cta_debito;
   v_retorno.NroCuentaCredito      := v_nro_cta_credito;
   v_retorno.Monto                 := v_mto_debito;
   v_retorno.MontoCredito          := v_mto_credito;
   v_retorno.CodigoMoneda          := v_cod_mon_debito;
   v_retorno.CodigoMonedaCredito   := v_cod_mon_credito;
   v_retorno.NombreBeneficiario    := paw_uti.depurarAlfanumerico(p_nombreBeneficiario, 100, 'S');
   v_retorno.NumeroDocBeneficiario := v_nro_doc_credito;
   v_retorno.cotizacionDebito      := v_cot_debito;
   v_retorno.cotizacionCredito     := v_cot_credito;
   v_retorno.nombreCuentaDebito    := v_nom_cta_debito;
   v_retorno.prioridad             := v_prioridad;
   v_retorno.tipoCargo             := v_tip_cargos;
   v_retorno.CodigoDocBeneficiario := v_cod_tip_documento;
   
   IF nvl(length(v_retorno.NombreBeneficiario), 0) = 0 THEN
      lf_generarLog(MSG_TRA_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora ||', sin nombre beneficiario');
      RETURN v_retorno;
   END IF;
   
   SELECT v.participante
     INTO v_retorno.nombreBcoDestino
     FROM gv_snp_participantes v
    WHERE v.cod_swift = v_cod_swift;

  IF v_modo = 'C' AND v_nro_referencia IS NULL THEN
    v_nro_referencia := pas_snp.fu_obt_sig_nro_referencia(v_fec_operacion);
  END IF;
  r_gtran.nro_referencia           := v_nro_referencia;
  r_gtran.cod_modulo               := 4;
  r_gtran.cod_modalidad            := 455;
  r_gtran.cod_oficina              := v_cod_ofi_debito;
  r_gtran.cod_tip_operacion        := v_cod_tip_operacion;
  r_gtran.cod_sub_tip_operacion    := v_cod_sub_tip_operacion;
  r_gtran.fec_ingreso              := v_fec_actual;
  r_gtran.cod_per_solicitante      := v_retorno.CodigoPersona;
  r_gtran.nom_solicitante          := fue_obt_nom_persona(v_retorno.CodigoPersona);
  r_gtran.dir_solicitante          := fue_obt_dir_principa(v_retorno.CodigoPersona);
  r_gtran.cod_tip_doc_solicitante  := fue_obt_doc_principal(v_retorno.CodigoPersona);
  r_gtran.nro_doc_solicitante      := fue_obt_nro_doc_persona(v_retorno.CodigoPersona);
  r_gtran.cod_swi_pte_solicitante  := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
  r_gtran.nom_beneficiario         := v_retorno.NombreBeneficiario;
  r_gtran.dir_beneficiario         := paw_uti.depurarTextos(p_dirBeneficiario, 100);
  r_gtran.cod_tip_doc_beneficiario := v_cod_tip_documento;
  r_gtran.nro_doc_beneficiario     := v_retorno.NumeroDocBeneficiario;
  r_gtran.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(v_cod_swift, v_cod_mon_credito);
  r_gtran.observacion              := v_retorno.Concepto;
  r_gtran.tip_cargo                := v_tip_cargos;

  IF v_prioridad = 'A' THEN
    r_gtran.ind_valor := 'S'; --N
    r_gtran.prioridad := 20; --100
  ELSE
    r_gtran.ind_valor := 'N';
    r_gtran.prioridad := 100;
  END IF;

  r_gtran.situacion      := 'P'; -- Pendiente de Envio a BCP
  r_gtran.estado         := 'S'; -- Solicitado
  r_gtran.nro_operacion  := v_nro_referencia;
  r_gtran.tip_mensaje    := 'CRED';
  r_gtran.ben_dir_correo := NULL;
  r_gtran.cod_tra_padre  := v_cod_tra_padre;
  IF v_modo = 'C' THEN    
    r_gtran.fec_valor := paw_bas.fu_obt_snp_fec_acreditacion(v_cod_msj_swift, r_gtran.cod_moneda);              
      v_spi_detectado := fug_val_mx_spi( v_cod_swift, 
                                           v_nro_doc_credito,
                                           v_nro_cta_credito,
                                           v_cod_mon_credito,
                                           v_mto_credito,'E');                                                             
     if (v_spi_detectado ='S' and (( v_spi_hab_tm='S' and  p_codigoEmpresa is null)  or (v_spi_hab_pj='S' and  p_codigoEmpresa is not null))) then              
                                begin          
                                      v_nro_referencia :=  pas_spi.fu_obt_sig_nro_referencia(v_fec_actual);  
                                      r_gtranspi.NRO_REFERENCIA     := v_nro_referencia;      
                                      r_gtranspi.COD_MONEDA         := 'GS';
                                      r_gtranspi.MONTO              := v_mto_credito;
                                      r_gtranspi.COD_TRA_PADRE      := v_cod_tra_padre;
                                      r_gtranspi.COD_OFICINA        := v_cod_ofi_debito;
                                      r_gtranspi.COD_MODULO         := 4;
                                      r_gtranspi.cod_modalidad      := 455;
                                      r_gtranspi.COD_MX             := 'PACS.008'; 
                                      r_gtranspi.TIP_OPERACION      := 'A';          
                                      r_gtranspi.NOM_CLI_ORIGEN     := fue_obt_nom_persona(v_retorno.CodigoPersona);                                     
                                      if p_codigoEmpresa is null then
                                          r_gtranspi.TIP_DOC_ORIGEN:= 'CI';
                                      else     
                                          r_gtranspi.TIP_DOC_ORIGEN:= 'RUC'; 
                                      end if;  
                                      r_gtranspi.NRO_DOC_ORIGEN     := fue_obt_nro_doc_persona(v_retorno.CodigoPersona);
                                      r_gtranspi.NRO_CTA_ORIGEN     := v_nro_cta_debito; 
                                      r_gtranspi.BIC_ORIGEN         := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
                                      r_gtranspi.COD_PER_ORIGEN     := v_retorno.CodigoPersona;
                                      r_gtranspi.NOM_CLI_RECEPTOR   := p_nombreBeneficiario;
                                      begin
                                          select b.abreviatura
                                          into v_tipo_doc
                                          from ba_tip_documentos b
                                          where  b.cod_tip_documento=p_codTipoDocumentoBen;
                                      exception when no_data_found then  v_tipo_doc:='CI';
                                      end; 
                                      r_gtranspi.TIP_DOC_RECEPTOR   := v_tipo_doc;
                                      r_gtranspi.NRO_DOC_RECEPTOR   := v_nro_doc_credito;
                                      r_gtranspi.NRO_CTA_RECEPTOR   := v_nro_cta_credito;
                                      r_gtranspi.BIC_RECEPTOR       := v_cod_swift;
                                      r_gtranspi.ESTADO             := 'P';   
                                      r_gtranspi.ORIGEN             := 'H';
                                      r_gtranspi.FEC_VALOR          := trunc(sysdate);
                                      r_gtranspi.FEC_RECEPCION      := null;
                                      r_gtranspi.FECHA              := null;
                                      r_gtranspi.HORA               := null; 
                                      r_gtranspi.COD_USUARIO        := null; 
                                      r_gtranspi.COD_MON_ORIGEN     := v_cod_mon_debito;
                                      r_gtranspi.MTO_ORIGEN         := v_mto_debito;
                                      if v_cot_debito is null or v_cot_debito='' then
                                         r_gtranspi.TIP_CAMBIO         := 1;
                                      else
                                         r_gtranspi.TIP_CAMBIO         := v_cot_debito;
                                      end if;
                                      v_cta_pte_solicitante := pas_spi.fu_obt_cta_bancaria(pas_spi.fu_obt_cta_ban_participante(p_cod_moneda => 'GS'),'X');
                                      
                                      pas_spi.pr_ins_transferencias(r_gtranspi,P_RESULT,P_DET_ERROR); 
                                      
                               if p_codigoEmpresa is null then     --solo si es pf debe hacer esta parte para finalizar , si es pj solo debe insertar
                                      if P_RESULT = 'OK' then
                                                 pas_spi.pr_pro_transferencias(r_gtranspi,P_RESULT_PRO,P_DET_ERROR_PRO);  
                                                 v_retorno.FechaPago := to_char(v_fec_actual, 'ddmmyyyy');
                                                 v_retorno.NumeroCuenta := v_nro_cta_debito;
                                                 v_retorno.nombreCuentaDebito := v_nom_cta_debito;
                                                 v_retorno.CodigoMoneda := v_cod_mon_debito;
                                                 v_retorno.Monto := v_mto_debito;
                                                 v_retorno.NroCuentaCredito := v_nro_cta_credito;
                                                 v_retorno.NombreBeneficiario := p_nombreBeneficiario;
                                                 v_retorno.CodigoBanco:= v_cod_swift;
                                                 v_retorno.nombreBcoDestino := substr(pas_snp.fu_obt_des_participante(v_cod_swift), 1, 100);
                                                 v_retorno.CodigoMonedaCredito := v_cod_mon_credito;
                                                 v_retorno.montoCredito := v_mto_credito;
                                                 v_retorno.cotizacionDebito := v_cot_debito;
                                                 v_retorno.cotizacionCredito := v_cot_credito;
                                                 v_retorno.prioridad := v_prioridad;
                                                 SELECT s_nro_ope_homebanking.nextval
                                                 INTO v_nro_documento
                                                 FROM dual;
                                                 v_retorno.NumeroDocBeneficiario := v_nro_documento;
                                                if P_RESULT_PRO = 'OK' then 
                                                          if v_spi_hab_corr_ok='S' then  
                                                                pas_spi.pr_notif_spi(r_gtranspi,'C',P_DET_ERROR_PRO);       
                                                          end if; 
                                                         paw_uti.pr_mensajeusuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error); 
                                                         RETURN  v_retorno;
                                                else       
                                                         if v_spi_hab_corr_fail='S' then    
                                                               pas_spi.pr_notif_spi(r_gtranspi,'R',P_DET_ERROR_PRO);     
                                                          end if; 
                                                         paw_uti.pr_mensajeusuario(P_DET_ERROR_PRO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);        
                                                         RETURN v_retorno;      
                                                end if;  
                                          end if;                         
                                      end if;
                                end;
    else
            pas_snp.pr_ins_transferencias(r_gtran);
            IF nvl(pas_snp.fu_obt_cod_error, 1) <> 0 THEN
              v_msj_bitacora := substr(v_msj_bitacora || ', pr_ins : [' || substr(pas_snp.g_msj_error, 1, 200) || '] ', 1, 1000);
              lf_generarLog(MSG_TRA_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
              RETURN v_retorno;
            END IF;
    
    end if; 
  END IF;
  v_retorno.NroReferencia         := v_nro_referencia;
  -- verificar si se tiene que generar mov. pendiente
  IF v_modo = 'C' and v_can_fir_requeridas > 0 THEN
     -- grabacion en pendiente
     IF v_nro_contrato = 0 THEN
        IF v_cod_mon_debito <> v_cod_mon_credito THEN
           IF v_cod_mon_debito <> v_cod_mon_local THEN
              IF v_cod_mon_credito = v_cod_mon_local THEN
                 v_mto_equ_local := nvl(v_mto_credito, 0);
              ELSE
                 v_mto_equ_local := round(nvl(v_mto_credito, 0) * nvl(v_cot_credito, 0), 0);
              END IF;
           ELSE
              v_mto_equ_local := nvl(v_mto_debito, 0) ;
           END IF;
        END IF;
     END IF;
     
     --- inserto el movimiento pendiente de autorizacion
     SELECT s_nro_documento.nextval
       INTO v_nro_documento
       FROM dual;
     
     INSERT INTO bw_mov_pendientes
        (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda, descripcion, monto, cotizacion, mto_equ_local,
         nro_cta_contra, estado, can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, mto_contra, cot_contra, etiqueta, dato, etiqueta2, dato2,
         referencia, Tip_Pago)
     VALUES
        (v_nro_documento, v_retorno.CodigoPersona, SYSDATE, '036', v_nro_cta_debito, v_cod_mon_debito, v_retorno.Concepto, v_mto_debito, v_cot_debito, v_mto_equ_local,
         v_cta_pte_solicitante, 'P', v_can_fir_requeridas, v_can_fir_requeridas, p_codigoPersona, v_mto_credito, v_cot_credito,
         'nro.cta.cred*mon.cred*nro.prepactado', r_gtran.nro_cta_beneficiario || '*' || v_cod_mon_credito || '*' || nvl(v_nro_contrato, 0), 'Fecha Valor', to_char(v_fec_operacion, 'DD/MM/YYYY'),
         v_nro_referencia, v_prioridad);

     v_retorno.nroDocumento := v_nro_documento;
     lf_generarLog(paw_uti.MSG_OK, v_retorno, paw_uti.BITACORA_SALIDA, v_msj_bitacora);
     RETURN v_retorno;
  END IF;
  
  IF v_modo = 'C' THEN
    IF v_prioridad = 'A' THEN
      -- Genera el Mensaje Swift
      v_msj_swift := pas_snp.fu_obt_msj_mt103(v_nro_referencia, 'N');
      -- Actualiza el Estado y le agrega el Mensaje Swift generado

      UPDATE ge_snp_transferencias gt
         SET gt.msj_swift = v_msj_swift, gt.estado = 'A'
       WHERE gt.nro_referencia = v_nro_referencia
         AND gt.cod_msj_swift = v_cod_msj_swift;

      IF SQL%NOTFOUND THEN
        lf_generarLog(MSG_REFTRAEX_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora ||', upd_ge_snp_transf');
        RETURN v_retorno;
      END IF;
    ELSE
      UPDATE ge_snp_transferencias gt
         SET gt.estado = 'A'
       WHERE gt.nro_referencia = v_nro_referencia
         AND gt.cod_msj_swift = v_cod_msj_swift;
    END IF;
    IF v_est_periodo = 'A' THEN
      -- se retornara la transaccion a ser utilizada para la generacion del movimiento.
      pas_snp.pr_obt_par_mensajes(v_cod_msj_swift, -- Tipo MT
                                  v_cod_tip_operacion, -- Tipo de Operacion
                                  v_cod_sub_tip_operacion, -- Sub-Tipo de Operacion
                                  'E', -- Transferencia Enviada
                                  v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_credito,
                                  v_cod_tra_padre); -- CNFPRSIP-217 --
      IF v_nro_contrato = 0 THEN
         IF v_cod_mon_debito <> v_cod_mon_credito THEN
            IF v_cod_mon_debito <> v_cod_mon_local THEN
               IF v_cod_mon_credito = v_cod_mon_local THEN
                  v_mto_equ_local := v_mto_credito;
               ELSE
                  v_mto_equ_local := round(v_mto_debito * v_cot_debito, 0);
               END IF;
            ELSE
               v_mto_equ_local := NULL;  
            END IF;
         END IF;
      END IF;

      pag_cta.PR_SET_VARIABLES(v_mensajeCaja.codigoUsuario, v_fec_valor, v_cod_tra_padre, 'N', 'N', v_nro_secuencia);
      pag_cta.PR_SET_NRO_DOCUMENTO3(NULL);
      -- Registrar movimientos de Debito al CLIENTE
      pag_cta.pr_set_cod_rubro(NULL, NULL);
      -- DDSI-265 -- 02/2018 : Se busca una hora disponible
      v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, USER, 'N');
      prg_ver_mod_horario;
      pag_cta.pr_act_operacion(v_nro_cta_debito,
                               v_hor_actual,
                               'D', -- Tip.Mov.
                               v_cod_mon_debito,
                               v_mto_debito,
                               v_cod_tra_padre,
                               v_cod_tra_debito, -- Trx.Hija
                               v_nro_referencia, -- Nro.Doc.
                               v_cot_debito, -- Cotizacion
                               v_cod_ofi_debito, -- Ofic.Orig.
                               v_cod_mod_padre, -- Mod.Pad.Cliente
                               v_cod_mad_padre, -- Mad.Pad.Cliente
                               NULL, -- Cod.Tasa
                               NULL, -- Val.Tasa
                               nvl(v_retorno.Concepto, 'HB-SNP-Transf.Cta. ' || v_cta_pte_solicitante),
                               'S', -- Emit.Aviso
                               v_nro_secuencia,
                               v_fec_actual,
                               NULL, -- Cod_Banco
                               NULL, -- Cod_Causa
                               v_mto_equ_local);
      IF nvl(pag_cta.fu_obt_cod_error, 1) <> 0 THEN
        v_msj_bitacora := substr(v_msj_bitacora || SQLERRM || ', debito : [' || substr(pag_cta.G_MSJ_ERROR, 1, 100) || '] ', 1, 1000);
        lf_generarLog(MSG_TRA_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
        RETURN v_retorno;
      ELSE
        IF v_nro_contrato = 0 THEN
           IF v_cod_mon_debito <> v_cod_mon_credito THEN
              IF v_cod_mon_credito <> v_cod_mon_local THEN
                 IF v_cod_mon_debito = v_cod_mon_local THEN
                    v_mto_equ_local := v_mto_debito;
                 ELSE
                    v_mto_equ_local := round(v_mto_credito * v_cot_credito, 0);
                 END IF;
              ELSE
                 v_mto_equ_local := NULL; 
              END IF;  
           END IF;
        END IF;
        
        v_tip_movimiento := pas_snp.fu_obt_tip_mov_transaccion(v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_credito);
        IF nvl(pas_snp.fu_obt_cod_error, 1) <> 0 THEN
          v_msj_bitacora := substr(v_msj_bitacora || ', fu_obt_tip_mov_transaccion : [' || substr(pas_snp.g_msj_error, 1, 100) || '] ', 1, 1000);
          lf_generarLog(MSG_TRA_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
          RETURN v_retorno;
        ELSE
          -- Setea el Tipo de Movimiento del Rubro para SNP
          pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(v_cta_pte_solicitante), v_tip_movimiento);
          -- Setea la Referencia del Movimiento para SNP
          pag_cta.pr_set_referencia(v_cod_swift);
          -- Registrar movimientos a la Cta. Interbancaria
          prg_ver_mod_horario;
          pag_cta.pr_act_operacion(v_cta_pte_solicitante, -- Nro.Cta.
                                   v_hor_actual, -- Hora
                                   v_tip_movimiento, -- Tip.Mov.
                                   v_cod_mon_credito, -- Cod.Mon.
                                   v_mto_credito, -- Monto
                                   v_cod_tra_padre, -- Trx.Padre
                                   v_cod_tra_credito, -- Trx.Hija
                                   v_nro_referencia, -- Nro.Doc.
                                   v_cot_credito, -- Cotizacion
                                   v_cod_ofi_debito, -- Ofic.Orig.
                                   v_cod_mod_padre, -- Mod.Pad.Cliente
                                   v_cod_mad_padre, -- Mad.Pad.Cliente
                                   NULL, -- Cod.Tasa
                                   NULL, -- Val.Tasa
                                   nvl(v_retorno.Concepto, 'HB-SNP-Transf.Cta. ' || v_nro_cta_debito),
                                   'S', -- Emit.Aviso
                                   v_nro_secuencia,
                                   v_fec_actual,
                                   NULL, -- Cod_Banco
                                   NULL, -- Cod_Causa
                                   v_mto_equ_local);

          --DYDMR-5272  Nov/2016
          pag_cta.pr_set_cod_rubro(NULL, NULL);
          pag_cta.pr_set_referencia(NULL);

          IF pag_cta.fu_obt_cod_error = 0 THEN
            pas_snp.pr_gen_mov_cargo(r_gtran, v_nro_cta_debito, v_cta_pte_solicitante, v_mto_credito, v_hor_actual, v_nro_secuencia, 'W');
          END IF;

          IF nvl(pag_cta.fu_obt_cod_error, 1) <> 0 THEN
            v_msj_bitacora := substr(v_msj_bitacora || ', pr_act_operacion : [' || substr(pag_cta.G_MSJ_ERROR, 1, 100) || '] ', 1, 1000);
            lf_generarLog(MSG_TRA_INVALIDA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
            RETURN v_retorno;
          ELSE
            BEGIN
              -- Actualiza la Transferencia
              UPDATE ge_snp_transferencias gt
                 SET gt.fecha = v_fec_actual, gt.hora = v_hor_actual,
                     gt.cod_usuario = v_mensajeCaja.codigoUsuario
               WHERE gt.nro_referencia = v_nro_referencia
                 AND gt.cod_msj_swift = v_cod_msj_swift;

              IF SQL%NOTFOUND THEN
                v_msj_bitacora := substr(v_msj_bitacora || 'ora-err: [' || SQLERRM || '] ', 1, 1000);
                lf_generarLog(MSG_CONFSNP_INVA, v_retorno, paw_uti.BITACORA_ERROR, v_msj_bitacora);
                RETURN v_retorno;
              END IF;
            END;
            -- cambio el estado del contrato de cambio
            IF nvl(v_nro_contrato,0) <> 0 THEN
               pr_liq_ope_cambio(v_mensajeCaja.codigoUsuario, v_nro_cta_debito, v_mto_debito, v_cod_mon_debito, v_cod_mon_credito, v_nro_ope_cambio);
            END IF;
            --GENERAR MOVIMIENTO DE POSICIÓN DE CAMBIOS
            pr_act_mov_ope_cam_snp(v_hor_actual, v_nro_referencia, v_cod_mon_debito, v_cod_mon_credito, v_mensajeCaja.codigoUsuario);
          END IF;
        END IF;
      END IF;
      -- Si esta todo OK envia la transferencia al Socket
      IF v_est_periodo = 'A' THEN
        COMMIT; -- Commitea antes de intentar enviar al socket
        pas_snp.pr_gen_arc_swift(v_nro_referencia, 'N');
      END IF;
    END IF;
  END IF;

  v_retorno.FechaPago     := v_fec_operacion;
  v_retorno.NroReferencia := v_nro_referencia;
  lf_generarLog(paw_uti.MSG_OK, v_retorno, paw_uti.BITACORA_SALIDA, v_msj_bitacora);
  RETURN v_retorno;*/
  RETURN NULL;
END;

  -- verificar que la hora para contrato prepactado sea valida
  FUNCTION fu_ver_hor_contrato RETURN VARCHAR2 IS
     v_formato    CONSTANT VARCHAR2(10) := 'HH24:MI';
     v_hor_inicio VARCHAR2(10) := to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_INICIO', 7, 71),v_formato),v_formato);
     v_hor_fin    VARCHAR2(10) := to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_FIN',    7, 71),v_formato),v_formato);
  BEGIN
     IF to_char(SYSDATE, v_formato) NOT BETWEEN v_hor_inicio AND v_hor_fin THEN
        -- hora invalida
        RETURN 'N';
     END IF;
     RETURN 'S';
  END;

  -- validar contrato de cambio
  FUNCTION fu_val_contrato(p_cod_mon_debito    IN ba_monedas.cod_moneda%TYPE,
                           p_cod_mon_credito   IN ba_monedas.cod_moneda%TYPE,
                           p_nro_contrato      IN lc_ope_pendientes.nro_diario%TYPE,
                           p_cod_persona       IN ba_personas.cod_persona%TYPE,
                           p_cod_tip_ope_venta IN lc_ope_pendientes.cod_tip_operacion%TYPE,
                           p_cod_per_tercero   IN ba_personas.cod_persona%TYPE DEFAULT NULL,
                           p_nro_ope_cambio    OUT lc_ope_pendientes.nro_operacion%TYPE,
                           p_monto             OUT lc_ope_pendientes.monto%TYPE,
                           p_mto_credito       OUT lc_ope_pendientes.monto%TYPE,
                           p_cot_debito        OUT lc_ope_pendientes.cotizacion%TYPE,
                           p_cot_credito       OUT lc_ope_pendientes.cotizacion%TYPE,
                           p_mto_equ_local     OUT lc_ope_pendientes.mto_equ_local%TYPE,
                           p_tip_operacion     OUT VARCHAR2) RETURN NUMBER IS
     v_deb_local       VARCHAR2(1) := 'N';
     v_cre_local       VARCHAR2(1) := 'N';
     v_tip_operacion   lc_tip_operaciones.cod_tip_operacion%TYPE;
     v_cotizacion      lc_ope_pendientes.cotizacion%TYPE;
     v_mon_cambio      lc_ope_pendientes.cod_moneda%TYPE;
     v_nro_doc_credito lc_ope_pendientes.nro_documento%TYPE;
  BEGIN
    IF fu_ver_hor_contrato() = 'N' THEN
       -- hora invalida
       RETURN -1;
    END IF;
    -- si el debito es en moneda local
    IF p_cod_mon_debito = v_cod_mon_local THEN
       v_deb_local := 'S';
       v_tip_operacion := 30; -- venta de divisas
       p_tip_operacion := 'V';
       p_cot_debito    := 1;
    END IF;
    -- si el credito es en moneda local
    IF p_cod_mon_credito = v_cod_mon_local THEN
       v_cre_local     := 'S';
       v_tip_operacion := 16; -- compra de Divisas
       p_tip_operacion := 'C';
       p_cot_credito   := 1;
    END IF;

    IF v_deb_local = 'S' AND v_cre_local = 'S' THEN
       -- no hay operacion de cambio
       RETURN -2;
    END IF;

    IF v_deb_local = 'S' OR v_cre_local = 'S' THEN
       -- si una moneda es local
       SELECT l.cotizacion, l.mto_equ_local, l.nro_operacion, decode(l.cod_moneda, p_cod_mon_debito, l.monto, l.mto_equ_local) mto_debito,
                        decode(l.cod_moneda, p_cod_mon_debito, l.mto_equ_local, l.monto) mto_credito, l.cod_moneda
         INTO v_cotizacion, p_mto_equ_local, p_nro_ope_cambio, p_monto, p_mto_credito, v_mon_cambio
         FROM lc_ope_pendientes l
        WHERE l.nro_diario = p_nro_contrato
          AND l.liquidado = 'N'
          AND l.ope_homebanking = 'S'
          AND l.cod_tip_operacion = v_tip_operacion
          AND l.nro_documento = FUE_OBT_NRO_DOC_PERSONA(p_cod_persona)
          AND l.fec_operacion = pag_cal.fu_obt_fec_actual(9);

       IF p_cod_mon_debito <> v_cod_mon_local THEN
          p_cot_debito := v_cotizacion;
       ELSE
          p_cot_credito := v_cotizacion;
       END IF;

        -- si es una venta la moneda de debito debe ser guaranies y la moneda de credito tiene que ser igual al contrato de cambio
        IF v_tip_operacion = 30 AND (v_mon_cambio <> p_cod_mon_credito) THEN
           RETURN -3; -- contrato invalido
        END IF;

        -- si es una compra la moneda de debito tiene que ser la moneda del contrato y la de credito tiene que ser guaranies
        IF v_tip_operacion = 16 AND (p_cod_mon_debito <> v_mon_cambio) THEN
           RETURN -3; -- contrato invalido
        END IF;
    ELSE
       -- arbitraje
       -- se valida la operacion en la cuenta debito
       SELECT l.cotizacion, l.mto_equ_local, l.nro_operacion, decode(l.cod_moneda, p_cod_mon_debito, l.monto, l.mto_equ_local) mto_debito,
              l.cod_moneda
         INTO p_cot_debito, p_mto_equ_local, p_nro_ope_cambio, p_monto, v_mon_cambio
         FROM lc_ope_pen_cambios l
        WHERE l.nro_diario = p_nro_contrato
          AND l.liquidado = 'N'
          AND l.ope_homebanking = 'S'
          AND l.cod_tip_operacion = 61 -- compra debito cuenta cliente
          AND l.nro_documento = FUE_OBT_NRO_DOC_PERSONA(p_cod_persona)
          AND l.fec_operacion = pag_cal.fu_obt_fec_actual(9);

       IF v_mon_cambio <> p_cod_mon_debito THEN
           RETURN -3; -- contrato invalido
       END IF;

       -- se valida la operacion en la cuenta credito
       SELECT l.cotizacion, l.mto_equ_local, l.nro_operacion, decode(l.cod_moneda, p_cod_mon_debito, l.mto_equ_local, l.monto) mto_credito,
              l.cod_moneda, l.nro_documento
         INTO p_cot_credito, p_mto_equ_local, p_nro_ope_cambio, p_mto_credito, v_mon_cambio, v_nro_doc_credito
         FROM lc_ope_pen_cambios l
        WHERE l.nro_diario = p_nro_contrato
          AND l.liquidado = 'N'
          AND l.ope_homebanking = 'S'
          AND l.cod_tip_operacion = p_cod_tip_ope_venta -- venta credito cuenta cliente
          AND l.fec_operacion = pag_cal.fu_obt_fec_actual(9);

       IF v_mon_cambio <> p_cod_mon_credito THEN
           RETURN -3; -- contrato invalido
       END IF;
       IF p_cod_tip_ope_venta <> '47' THEN
          -- si no es sipap, se debe controlar el nro documento de la venta
          IF nvl(v_nro_doc_credito, 'x') <> nvl(p_cod_per_tercero, FUE_OBT_NRO_DOC_PERSONA(p_cod_persona)) THEN
             RETURN -4;
          END IF;
       END IF;
       p_tip_operacion := 'A'; -- arbitraje
    END IF;
    RETURN 0;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        RETURN -2; -- no hay operacion de cambio
     WHEN OTHERS THEN
        RETURN -99; -- otro error
  END;

  -- liquidar contrato prepactado
  PROCEDURE pr_liq_ope_cambio(p_cod_usuario     IN ba_usuarios.cod_usuario%TYPE,
                              p_nro_cta_debito  IN ge_cuentas.nro_cuenta%TYPE,
                              p_mto_debito      IN ge_movimientos.monto%TYPE,
                              p_cod_mon_debito  IN ba_monedas.cod_moneda%TYPE,
                              p_cod_mon_credito IN ba_monedas.cod_moneda%TYPE,
                              p_nro_operacion   IN lc_ope_pendientes.nro_operacion%TYPE) IS
  BEGIN
     IF p_cod_mon_debito = v_cod_mon_local OR p_cod_mon_credito = v_cod_mon_local THEN
        UPDATE lc_ope_pendientes lc
           SET lc.liquidado           = 'S',
               lc.cod_usu_liquidacion = p_cod_usuario,
               lc.fec_liquidacion     = SYSDATE,
               -- para limite de operaciones
               lc.cta_ref_contra3     = p_nro_cta_debito,
               lc.mto_contra3         = p_mto_debito
         WHERE lc.nro_operacion = p_nro_operacion;
      ELSE
         UPDATE lc_ope_pen_cambios lc
            SET lc.liquidado           = 'S',
                lc.cod_usu_liquidacion = p_cod_usuario,
                lc.fec_liquidacion     = SYSDATE
          WHERE lc.nro_operacion = p_nro_operacion;

         -- para limite de operaciones,
         UPDATE lc_ope_pen_cambios lc
            SET lc.cta_ref_contra3 = nvl(cta_ref_contra3, p_nro_cta_debito),
                lc.mto_contra3     = p_mto_debito
          WHERE lc.nro_operacion = p_nro_operacion
            AND lc.cod_tip_operacion = 61;
      END IF;
  END;
  
  PROCEDURE pr_act_mov_ope_cam_snp(p_hora                IN ge_movimientos.hora%TYPE,
                                   p_nro_documento       IN ge_movimientos.nro_documento%TYPE,
                                   p_cod_mon_debito      IN ge_movimientos.cod_moneda%TYPE,
                                   p_cod_mon_credito     IN ge_movimientos.cod_moneda%TYPE,
                                   p_usuario             IN VARCHAR2) IS

      v_ind_inc_hbank varchar2(1) := fug_obt_pardinamico ('IND_INC_HBANK');

   BEGIN
      IF v_ind_inc_hbank = 'S' and p_cod_mon_debito <> p_cod_mon_credito THEN
         IF ((p_cod_mon_debito <> v_cod_mon_local) AND
            (p_cod_mon_credito <> v_cod_mon_local)) THEN
            --llamar compra--
            PRL_PRO_OPE_CAM_SIPAP(p_hora, p_usuario, p_nro_documento,'C');
            --llamar venta--
            PRL_PRO_OPE_CAM_SIPAP(p_hora, p_usuario, p_nro_documento,'V');
         ELSE
            IF p_cod_mon_debito = v_cod_mon_local THEN
               --llamar venta--
               PRL_PRO_OPE_CAM_SIPAP(p_hora, p_usuario, p_nro_documento,'V');
            ELSE
               --llamar compra--
               PRL_PRO_OPE_CAM_SIPAP(p_hora, p_usuario, p_nro_documento,'C');
            END IF;
         END IF;
      END IF;

   END;

FUNCTION fu_obtenerSaldos(p_nro_cuenta IN VARCHAR2) RETURN typ_saldos IS
  v_sal_actual NUMBER;
  v_error      VARCHAR2(1);
  v_msj_error  VARCHAR2(2000);
  v_saldos     typ_saldos := typ_saldos;
  v_cod_modulo NUMBER(1) := 0;
BEGIN

  BEGIN
    SELECT cod_modulo
    INTO v_cod_modulo
    FROM ge_cuentas
    WHERE nro_cuenta = p_nro_cuenta;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  IF v_cod_modulo IN (3, 4) THEN
    -- cuentas pasivas
    pag_cta.pr_obt_cuenta(p_nro_cuenta);

    IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
      prg_obt_sal_atm_cierre(p_nro_cuenta, pag_cta.g_ctas.sal_disponible,
                             pag_cta.g_ctas.sal_actual,
                             pag_cta.g_ctas.sal_retenido,
                             pag_cta.g_ctas.sal_bloqueado, v_error,
                             v_msj_error);
    END IF;
    v_saldos.disponible := pag_cta.g_ctas.sal_disponible;
    v_saldos.actual     := pag_cta.g_ctas.sal_actual;
    v_saldos.retenido   := pag_cta.g_ctas.sal_retenido;
    v_saldos.bloqueado  := pag_cta.g_ctas.sal_bloqueado;
    RETURN v_saldos;
    --    v_sal_actual := pag_cta.fu_sal_disponible;
  ELSIF v_cod_modulo = 5 THEN
    -- Tarjetas
    SELECT nvl(lin_credito, 0) -
            (nvl(b.sal_facturar, 0) + nvl(b.sal_facturado, 0) +
             nvl(b.sal_financiado, 0) + nvl(b.sal_cuo_pendientes, 0))
    INTO v_sal_actual
    FROM ta_cta_tarjetas b
    WHERE b.nro_cuenta = p_nro_cuenta;
  ELSIF v_cod_modulo = 6 THEN
    -- prestamos
    SELECT nvl(b.sal_capital, 0) + nvl(b.sal_int_adelantado, 0)
    INTO v_sal_actual
    FROM pr_cta_prestamos b
    WHERE b.nro_cuenta = p_nro_cuenta;
  ELSIF v_cod_modulo = 8 THEN
    -- comercio exterior
    v_sal_actual := 0;
  END IF;
  v_saldos.actual := v_sal_actual;
  RETURN v_saldos;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL; -- saldo 0(cero)
END;

 FUNCTION fu_obtenerresumencuentas(p_codpersona          IN VARCHAR2,
                                     p_codempresa          IN VARCHAR2,
                                     p_codcanal            IN VARCHAR2,
                                     p_identificadorsesion IN VARCHAR2,
                                     p_canFirmas           IN NUMBER,
                                     p_filtro              IN VARCHAR2 DEFAULT NULL)
     RETURN typ_resumencuentas IS

     msg_login_err_sin_autorizacion CONSTANT VARCHAR2(30) := 'P_OP_NO_PERM';
     msg_obtcuenta_cta_duplicada    CONSTANT VARCHAR2(30) := 'OBT_CTA_DUP';
     msg_obtcuenta_cta_noexist      CONSTANT VARCHAR2(30) := 'OBT_CTA_NOEXIST';
     cod_operacion                  CONSTANT VARCHAR2(3) := '011';
     sal_err_obt_dat_entes          CONSTANT VARCHAR2(15) := 'SAL_ERR_DAT_ENT'; -- error al obtener datos de ente
     pro_err_obt_dat_entes          CONSTANT VARCHAR2(15) := 'PRO_OBT_CTA_DEB';
     -- datos recibidos
     v_ver_cuentas   VARCHAR2(1) := 'T';
     v_tipo_consulta VARCHAR2(3);
     v_can_detalles NUMBER;
     v_cod_moneda   VARCHAR(3) := NULL;
     --
     v_despliega      VARCHAR2(1); -- indica si la cuenta debe o no desplegarse
     v_cta_formateada VARCHAR2(17); -- para guardar la cuenta formateada
     v_es_nomina      VARCHAR2(1);
     v_imp_extracto   VARCHAR2(1);

     v_listacuentas typ_listaresumencuenta := typ_listaresumencuenta();
     v_retorno      typ_resumencuentas := typ_resumencuentas;
     v_logmessage   VARCHAR2(500);
     v_mod_cta         ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MAD_CTA_BAN_WEB'); --BWP-391 --NVB-2232
     -- cursor de cuentas del cliente
     CURSOR cuentas IS
       SELECT a.nro_cuenta, a.cod_modalidad cod_modalidad,
              fug_cta_formateada(a.cod_modulo, a.cod_modalidad,
                                  a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada,
              paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
              fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta,
              a.cod_moneda cod_moneda, a.denominacion nom_cuenta,
              paw_bce.fu_obt_sal_actual(a.cod_modulo, a.cod_modalidad,
                                         a.nro_cuenta) sal_actual,
              a.cod_modulo, a.estado, b.relacion, a.cod_sub_modalidad
       FROM ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
       WHERE a.nro_cuenta = b.nro_cuenta
       AND b.relacion IN ('O', 'P', 'Y')
       AND b.cod_persona = nvl(p_codempresa, p_codpersona)
       AND a.cod_modulo = c.cod_modulo
       AND a.cod_modalidad = c.cod_modalidad
       AND a.estado = c.estado
       AND b.cod_modulo != 7
       AND b.cod_modalidad <> 36
       AND COALESCE(fug_obt_paradicional(a.nro_cuenta, 'CTA_BILLETERA'),'N') = 'N'
       AND COALESCE(fug_obt_paradicional(a.nro_cuenta, 'IND_NO_MOS_CTA_APP'),'N') = 'N'
       --AND (c.activo = 'S' OR b.cod_modalidad IN (37,38,31,41,34,39,334) or b.cod_modulo = 5 ) -- solo cuentas activas o ctas de plazo fijo  --BWP-391 --NVB-2232
       AND (c.activo = 'S' OR (instr(v_mod_cta, '#'||b.cod_modalidad||'#' ) > 0 and c.activo='S') or b.cod_modulo = 5 ) --BWP-391 --NVB-2232
       AND a.estado <> 'X' -- pendiente de verificacion
       ORDER BY decode(b.cod_modalidad, 31, 1,
                        decode(b.cod_modulo, 5, 2,
                                decode(b.cod_modalidad, 33, 4, 34, 4, 36, 4,
                                        decode(b.cod_modulo, 4, 3, 7))));
     -- listado de entes con pagos de salarios
     CURSOR entes IS -- OMM 11/01/2011
       SELECT a.cod_ente,
              TRIM(fug_obt_parentes(a.cod_ente, 'NRO_CTA_DEBITO')) cta_debito
       FROM ge_entes a
       WHERE a.cod_persona = nvl(p_codempresa, p_codpersona)
       AND a.tipo = 'SU'
       AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO') = 'S'
       AND fug_obt_parentes(a.cod_ente, 'HAB_HOMEBANKING') = 'S';
     -- Se utiliza para validar pago de Sueldos
     CURSOR ctas_entes(p_cod_ente NUMBER,
                       p_moneda   VARCHAR2) IS
       SELECT DISTINCT a.cod_ente, g.cod_moneda, g.nro_cuenta,
                       decode(g.cod_modalidad, 31, 'AH', 'CC') tipo_cta,
                       g.denominacion, g.cod_modulo, g.cod_modalidad,
                       fug_obt_des_modal(g.cod_modulo, g.cod_modalidad) des_tip_cuenta
       FROM ge_entes a, ge_cta_clientes c, ge_cuentas g
       WHERE a.cod_persona = nvl(p_codempresa, p_codpersona)
       AND a.tipo = 'SU'
       AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO') = 'S'
       AND fug_obt_parentes(a.cod_ente, 'HAB_HOMEBANKING') = 'S'
       AND a.cod_ente = p_cod_ente
       AND a.cod_persona = c.cod_persona
       AND c.relacion in ( 'P' , 'O' ) --NVB-2263 
       AND c.nro_cuenta = g.nro_cuenta
       AND g.cod_modalidad IN (31, 41)
       AND g.estado IN ('N', 'S')
       AND g.cod_moneda = p_moneda
       ORDER BY g.cod_moneda, tipo_cta, g.nro_cuenta;
     -- se utiliza para desplegar las cuentas debito para pago a proveedores
     CURSOR ctas_provee(p_cod_ente        ge_entes.cod_ente%TYPE,
                        p_cod_per_empresa ge_clientes.cod_persona%TYPE) IS
       SELECT c.cod_moneda cod_moneda, TRIM(a.val_parametro) nro_cuenta,
              decode(c.cod_modalidad, 31, 'AH', 'CC') tipo_cta,
              c.denominacion, c.cod_modulo, c.cod_modalidad
       FROM ge_par_entes a, ge_cuentas c, ge_cta_clientes b
       WHERE a.cod_ente = p_cod_ente
       AND b.cod_persona = p_cod_per_empresa
       AND c.cod_modulo IN (3, 4)
       AND c.cod_modalidad IN (31, 41)
       AND c.nro_cuenta = TRIM(a.val_parametro)
       AND c.nro_cuenta = b.nro_cuenta
       AND c.cod_moneda IN
             (pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_fuerte)
       AND a.parametro LIKE 'CTA_DEB_PPROV%'
       AND c.estado NOT IN ('X', 'C', 'P')
       AND a.val_parametro IS NOT NULL;
     -- se utiliza para desplegar las cuentas credito para recaudaciones
     CURSOR ctas_recaudacion(p_cod_ente        ge_entes.cod_ente%TYPE,
                             p_cod_per_empresa ge_clientes.cod_persona%TYPE) IS
       SELECT c.cod_moneda cod_moneda, TRIM(a.val_parametro) nro_cuenta,
              decode(c.cod_modalidad, 31, 'AH', 'CC') tipo_cta,
              c.denominacion, c.cod_modulo, c.cod_modalidad
       FROM ge_par_entes a, ge_cuentas c, ge_cta_clientes b
       WHERE a.cod_ente = p_cod_ente
       AND b.cod_persona = p_cod_per_empresa
       AND c.cod_modulo IN (3, 4)
       AND c.cod_modalidad IN (31, 41)
       AND c.nro_cuenta = TRIM(a.val_parametro)
       AND c.nro_cuenta = b.nro_cuenta
       AND b.relacion = 'P'
       AND a.parametro LIKE 'NRO_CTA_RECAUDADORA_%'
       AND c.estado NOT IN ('X', 'C', 'P')
       AND a.val_parametro IS NOT NULL;
     -- se utiliza para desplegar las cuentas debito para acreditaciones gourmet
     CURSOR ctas_acregourmet(p_cod_ente        ge_entes.cod_ente%TYPE,
                             p_cod_per_empresa ge_clientes.cod_persona%TYPE) IS
       SELECT c.cod_moneda cod_moneda, TRIM(a.val_parametro) nro_cuenta,
              decode(c.cod_modalidad, 31, 'AH', 'CC') tipo_cta,
              c.denominacion, c.cod_modulo, c.cod_modalidad
       FROM ge_par_entes a, ge_cuentas c, ge_cta_clientes b
       WHERE a.cod_ente = p_cod_ente
       AND b.cod_persona = p_cod_per_empresa
       AND c.cod_modulo IN (3, 4)
       AND c.cod_modalidad IN (31, 41)
       AND c.nro_cuenta = TRIM(a.val_parametro)
       AND c.nro_cuenta = b.nro_cuenta
       AND c.cod_moneda IN
             (pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_fuerte)
       AND a.parametro LIKE 'NRO_CTA_DEB_PAG_GOURMET%'
       AND c.estado NOT IN ('X', 'C', 'P')
       AND a.val_parametro IS NOT NULL;
    -- listado de entes con el servicio DAS
     CURSOR entes_das IS -- OMM 11/01/2011
       SELECT a.cod_ente
       FROM ge_entes a
       WHERE a.cod_persona = nvl(p_codempresa, p_codpersona)
       AND a.tipo = 'DA'
       AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO_DAS') = 'S'
       AND fug_obt_parentes(a.cod_ente, 'TIENE_CON_DAS') = 'S';
     -- Se utiliza para validar das
     CURSOR ctas_entes_das(p_cod_ente NUMBER,
                       p_moneda   VARCHAR2) IS
       SELECT DISTINCT a.cod_ente, g.cod_moneda, g.nro_cuenta,
                       decode(g.cod_modalidad, 31, 'AH', 'CC') tipo_cta,
                       g.denominacion, g.cod_modulo, g.cod_modalidad,
                       fug_obt_des_modal(g.cod_modulo, g.cod_modalidad) des_tip_cuenta
       FROM ge_entes a, ge_cta_clientes c, ge_cuentas g
       WHERE a.cod_persona = nvl(p_codempresa, p_codpersona)
       AND a.tipo = 'DA'
       AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO_DAS') = 'S'
       AND fug_obt_parentes(a.cod_ente, 'TIENE_CON_DAS') = 'S'
       AND a.cod_ente = p_cod_ente
       AND a.cod_persona = c.cod_persona
       AND c.relacion in ( 'P' , 'O' ) --NVB-2263 
       AND c.nro_cuenta = g.nro_cuenta
       AND g.cod_modalidad IN (31, 41)
       AND g.estado IN ('N', 'S')
       AND g.cod_moneda = p_moneda
       ORDER BY g.cod_moneda, tipo_cta, g.nro_cuenta;
   BEGIN
     paw_uti.pr_mensajeusuario(paw_uti.msg_ok, v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
     v_retorno.cantcuentas := 0;
     IF (p_filtro IS NOT NULL) THEN
       --Para que se filtren las cuentas debitables por tipo de operacion
       v_ver_cuentas   := substr(p_filtro, 4, 1);
       v_tipo_consulta := substr(p_filtro, 1, 3);
       IF (length(p_filtro) > 4) THEN
         v_cod_moneda := substr(p_filtro, 5, 3);
       END IF;
     ELSE
       v_tipo_consulta := '020';
     END IF;

     --Logear parametros
     v_logmessage := 'obtenerResumenCuentas(p_filtro=' || p_filtro || ')';
     paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                 p_identificadorsesion, cod_operacion,
                                 p_codempresa, v_logmessage,
                                 paw_uti.bitacora_entrada);

     -- 2. busco los datos de la cuentas
     IF v_retorno.error = 'N' THEN
       v_can_detalles := 0;
     
       IF v_tipo_consulta = '100' OR v_tipo_consulta = '110' THEN                  
         v_es_nomina := pag_pre.fu_es_cli_nomina(nvl(p_codempresa,p_codpersona));     
       END IF;                                                                   
       IF v_tipo_consulta = '097' THEN
         v_imp_extracto := paw_uti.fu_imp_extracto(nvl(p_codempresa,p_codpersona));
       END IF;
       FOR ct IN cuentas LOOP
         v_despliega := 'N';
         IF v_ver_cuentas = 'T' THEN
           -- quiere ver todas las cuentas
           IF (substr(v_tipo_consulta, 1, 2) = '06' AND
              ct.cod_modalidad = 41) THEN
             -- consulta de chequeras
             v_despliega := 'S'; -- cuentas corrientes por chequeras
           ELSIF (v_tipo_consulta IN ('021', '040', '041') AND
                 ct.cod_modalidad IN (31, 41)) THEN
             v_despliega := 'S'; -- cuentas ahorro o ctacte y es consulta de mov, cheq, dev o depositos pendientes
           ELSIF (v_tipo_consulta IN ('020')) THEN
             -- consulta de saldos general
             v_despliega := 'S';
           ELSIF (v_tipo_consulta IN ('070')) THEN
             -- Pago de Sueldos.
             DECLARE
               v_accountinfo typ_resumencuenta := typ_resumencuenta;
               v_moneda      VARCHAR(3);
             BEGIN
               SELECT COUNT(*)
               INTO v_can_detalles
               FROM ge_entes a
               WHERE a.cod_persona = nvl(p_codempresa, p_codpersona)
               AND a.tipo = 'SU'
               AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO') = 'S'
               AND fug_obt_parentes(a.cod_ente, 'HAB_HOMEBANKING') = 'S';
               v_despliega := 'N';
               -- Si existe verifico cuantas cuentas posee.
               IF v_can_detalles > 0 THEN
                 v_can_detalles := 0;
                 FOR et IN entes LOOP
                   v_moneda := fug_obt_mon_cta(et.cta_debito);
                   FOR ce IN ctas_entes(et.cod_ente, v_moneda) LOOP
                     v_can_detalles               := v_can_detalles + 1;
                     v_accountinfo.codigocuenta   := substr(ce.cod_ente, 0,5);
                     v_accountinfo.codmoneda      := substr(ce.cod_moneda, 0,3);
                     v_accountinfo.nrocuenta      := substr(ce.nro_cuenta, 0,15);
                     v_accountinfo.tipocuenta     := substr(ce.tipo_cta, 0, 2);
                     v_accountinfo.denominacion   := substr(ce.denominacion,0, 70);
                     v_accountinfo.desctipocuenta := substr(ce.des_tip_cuenta,0, 35);
                     v_accountinfo.saldoactual    := paw_bce.fu_obt_sal_actual(ce.cod_modulo,ce.cod_modalidad, ce.nro_cuenta);
                     v_accountinfo.alias := fug_obt_paradicional(ct.nro_cuenta, 'CTA_ALIAS');
                     --
                     v_accountinfo.codModalidad := ct.cod_modalidad;
                     v_accountinfo.codSubModalidad:= ct.cod_sub_modalidad;
                     --
                     v_listacuentas.extend;
                     v_listacuentas(v_listacuentas.count) := v_accountinfo;
                   END LOOP;
                 END LOOP;
               ELSE
                 paw_uti.pr_mensajeusuario(msg_login_err_sin_autorizacion,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Sin auth ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               END IF;
             EXCEPTION
               WHEN too_many_rows THEN
                 paw_uti.pr_mensajeusuario(msg_obtcuenta_cta_duplicada,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Cta. Duplicada' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               WHEN OTHERS THEN
                 paw_uti.pr_mensajeusuario(sal_err_obt_dat_entes,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - ORA-ERR: [' ||
                                              substr(SQLERRM, 1, 200) || '] ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
             END;
             
           ELSIF (v_tipo_consulta IN ('300')) then
              -- Servicio DAS
             DECLARE
               v_accountinfo typ_resumencuenta := typ_resumencuenta;
               v_moneda      VARCHAR(3);
             BEGIN
               SELECT COUNT(*)
               INTO v_can_detalles
               FROM ge_entes a
               WHERE a.cod_persona = nvl(p_codempresa, p_codpersona)
               AND a.tipo = 'DA'
               AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO_DAS') = 'S'
               AND fug_obt_parentes(a.cod_ente, 'TIENE_CON_DAS') = 'S';
               v_despliega := 'N';
               -- Si existe verifico cuantas cuentas posee.
               IF v_can_detalles > 0 THEN
                 v_can_detalles := 0;
                 FOR et IN entes_das LOOP
                   v_moneda := 'GS'; --solo guaranies
                   FOR ce IN ctas_entes_das(et.cod_ente, v_moneda) LOOP
                     v_can_detalles               := v_can_detalles + 1;
                     v_accountinfo.codigocuenta   := substr(ce.cod_ente, 0,5);
                     v_accountinfo.codmoneda      := substr(ce.cod_moneda, 0,3);
                     v_accountinfo.nrocuenta      := substr(ce.nro_cuenta, 0,15);
                     v_accountinfo.tipocuenta     := substr(ce.tipo_cta, 0, 2);
                     v_accountinfo.denominacion   := substr(ce.denominacion,0, 70);
                     v_accountinfo.desctipocuenta := substr(ce.des_tip_cuenta,0, 35);
                     v_accountinfo.saldoactual    := paw_bce.fu_obt_sal_actual(ce.cod_modulo,ce.cod_modalidad, ce.nro_cuenta);
                     v_accountinfo.alias := fug_obt_paradicional(ct.nro_cuenta, 'CTA_ALIAS');
                     --
                     v_accountinfo.codModalidad := ct.cod_modalidad;
                     v_accountinfo.codSubModalidad:= ct.cod_sub_modalidad;
                     --
                     v_listacuentas.extend;
                     v_listacuentas(v_listacuentas.count) := v_accountinfo;
                   END LOOP;
                 END LOOP;
               ELSE
                 paw_uti.pr_mensajeusuario(msg_login_err_sin_autorizacion,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Sin auth ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               END IF;
             EXCEPTION
               WHEN too_many_rows THEN
                 paw_uti.pr_mensajeusuario(msg_obtcuenta_cta_duplicada,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Cta. Duplicada' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               WHEN OTHERS THEN
                 paw_uti.pr_mensajeusuario(sal_err_obt_dat_entes,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - ORA-ERR: [' ||
                                              substr(SQLERRM, 1, 200) || '] ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
             END;
           
           ELSIF (v_tipo_consulta IN ('071')) THEN
             -- Acreditaciones Gourmet Card
             DECLARE
               v_cod_ente    ge_entes.cod_ente%TYPE;
               v_accountinfo typ_resumencuenta := typ_resumencuenta;
             BEGIN
               -- Se utiliza para validar Acreditaciones Gourmet Card
               SELECT cod_ente
               INTO v_cod_ente
               FROM ge_entes a
               WHERE a.cod_persona = nvl(p_codempresa, p_codpersona)
               AND a.tipo = 'AG'
               AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO_GOU') = 'S'
               AND fug_obt_parentes(a.cod_ente, 'HAB_HOMEBANKING_GOU') = 'S';
               v_despliega := 'N';

               BEGIN
                 FOR cp IN ctas_acregourmet(v_cod_ente,
                                            nvl(p_codempresa, p_codpersona)) LOOP
                   v_can_detalles             := v_can_detalles + 1;
                   v_accountinfo.codigocuenta := substr(v_cod_ente, 0, 5);
                   v_accountinfo.codmoneda    := substr(cp.cod_moneda, 0, 3);
                   v_accountinfo.nrocuenta    := substr(cp.nro_cuenta, 0, 15);
                   v_accountinfo.tipocuenta   := substr(cp.tipo_cta, 0, 2);
                   v_accountinfo.denominacion := substr(cp.denominacion, 0,70);
                   v_accountinfo.saldoactual  := paw_bce.fu_obt_sal_actual(cp.cod_modulo,cp.cod_modalidad,cp.nro_cuenta);
                   v_accountinfo.alias := fug_obt_paradicional(ct.nro_cuenta, 'CTA_ALIAS');
                   --
                   v_accountinfo.codModalidad := ct.cod_modalidad;
                   v_accountinfo.codSubModalidad:= ct.cod_sub_modalidad;
                   --
                   v_listacuentas.extend;
                   v_listacuentas(v_listacuentas.count) := v_accountinfo;
                 END LOOP;
               END;
               IF v_can_detalles = 0 THEN
                 paw_uti.pr_mensajeusuario(msg_login_err_sin_autorizacion,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Sin auth ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               END IF;
             EXCEPTION
               WHEN too_many_rows THEN
                 paw_uti.pr_mensajeusuario(msg_obtcuenta_cta_duplicada,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Cta.Duplicada' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               WHEN OTHERS THEN
                 paw_uti.pr_mensajeusuario(pro_err_obt_dat_entes,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - sin auth ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
             END;
           ELSIF (v_tipo_consulta IN ('075')) THEN
             -- Pago a Proveedores
             DECLARE
               v_cod_ente    ge_entes.cod_ente%TYPE;
               v_accountinfo typ_resumencuenta := typ_resumencuenta;
               v_hor_cierre  VARCHAR2(5) := nvl(substr(TRIM(fug_obt_pardinamico('HOR_CIE_PROVEEDOR_HB')),
                                                       1, 5), '14:30');
             BEGIN
               -- Se utiliza para validar pago a proveedores
               SELECT cod_ente
               INTO v_cod_ente
               FROM ge_entes a
               WHERE a.cod_persona = nvl(p_codempresa, p_codpersona)
               AND a.tipo = 'PR'
               AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO_PRV') = 'S'
               AND fug_obt_parentes(a.cod_ente, 'HAB_HOMEBANKING_PRV') = 'S';
               v_despliega := 'N';

               BEGIN
                 FOR cp IN ctas_provee(v_cod_ente,
                                       nvl(p_codempresa, p_codpersona)) LOOP
                   v_can_detalles               := v_can_detalles + 1;
                   v_accountinfo.codigocuenta   := substr(v_cod_ente, 0, 5);
                   v_accountinfo.codmoneda      := substr(cp.cod_moneda, 0,3);
                   v_accountinfo.nrocuenta      := substr(cp.nro_cuenta, 0,15);
                   v_accountinfo.desctipocuenta := v_hor_cierre;
                   v_accountinfo.tipocuenta     := substr(cp.tipo_cta, 0, 2);
                   v_accountinfo.denominacion   := substr(cp.denominacion, 0,70);
                   v_accountinfo.saldoactual    := paw_bce.fu_obt_sal_actual(cp.cod_modulo,cp.cod_modalidad,cp.nro_cuenta);
                   v_accountinfo.alias := fug_obt_paradicional(ct.nro_cuenta, 'CTA_ALIAS');
                   --
                   v_accountinfo.codModalidad := ct.cod_modalidad;
                   v_accountinfo.codSubModalidad:= ct.cod_sub_modalidad;
                   --
                   v_listacuentas.extend;
                   v_listacuentas(v_listacuentas.count) := v_accountinfo;
                 END LOOP;
               END;
               IF v_can_detalles = 0 THEN
                 paw_uti.pr_mensajeusuario(msg_login_err_sin_autorizacion,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Sin auth ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               END IF;
             EXCEPTION
               WHEN too_many_rows THEN
                 paw_uti.pr_mensajeusuario(msg_obtcuenta_cta_duplicada,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Cta.Duplicada' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               WHEN OTHERS THEN
                 paw_uti.pr_mensajeusuario(pro_err_obt_dat_entes,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - sin auth ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
             END;
           ELSIF (v_tipo_consulta IN ('090')) THEN
             -- Recaudaciones
             DECLARE
               v_cod_ente    ge_entes.cod_ente%TYPE;
               v_accountinfo typ_resumencuenta := typ_resumencuenta;
             BEGIN
               -- Se utiliza para validar servicio de recaudaciones
               SELECT cod_ente
               INTO v_cod_ente
               FROM ge_entes a
               WHERE a.cod_persona = nvl(p_codempresa, p_codpersona)
               AND a.tipo = 'SR'
               AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO_SR') = 'S'
               AND fug_obt_parentes(a.cod_ente, 'HAB_HOMEBANKING_SR') = 'S';
               v_despliega := 'N';
               BEGIN
                 FOR cp IN ctas_recaudacion(v_cod_ente,
                                            nvl(p_codempresa, p_codpersona)) LOOP
                   v_can_detalles               := v_can_detalles + 1;
                   v_accountinfo.codigocuenta   := substr(v_cod_ente, 0, 5);
                   v_accountinfo.codmoneda      := substr(cp.cod_moneda, 0,3);
                   v_accountinfo.nrocuenta      := substr(cp.nro_cuenta, 0,15);
                   v_accountinfo.desctipocuenta := NULL;
                   v_accountinfo.tipocuenta     := substr(cp.tipo_cta, 0, 2);
                   v_accountinfo.denominacion   := substr(cp.denominacion, 0,70);
                   v_accountinfo.saldoactual    := paw_bce.fu_obt_sal_actual(cp.cod_modulo,cp.cod_modalidad,cp.nro_cuenta);
                   v_accountinfo.alias := fug_obt_paradicional(ct.nro_cuenta, 'CTA_ALIAS');
                   --
                   v_accountinfo.codModalidad := ct.cod_modalidad;
                   v_accountinfo.codSubModalidad:= ct.cod_sub_modalidad;
                   --
                   v_listacuentas.extend;
                   v_listacuentas(v_listacuentas.count) := v_accountinfo;
                 END LOOP;
               END;
               IF v_can_detalles = 0 THEN
                 paw_uti.pr_mensajeusuario(msg_login_err_sin_autorizacion,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Sin auth ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               END IF;
             EXCEPTION
               WHEN too_many_rows THEN
                 paw_uti.pr_mensajeusuario(msg_obtcuenta_cta_duplicada,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - Cta.Duplicada' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
               WHEN OTHERS THEN
                 paw_uti.pr_mensajeusuario(pro_err_obt_dat_entes,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
                 paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                             p_identificadorsesion,
                                             cod_operacion, p_codempresa,
                                             'obtenerResumenCuentas - sin auth ' ||
                                              paw_uti.fu_generarbitacora(v_retorno.error,
                                                                         v_retorno.nombrerespuesta,
                                                                         v_retorno.descripcionrespuesta,
                                                                         NULL),
                                             paw_uti.bitacora_error);
             END;
           ELSIF v_tipo_consulta = '097' THEN
             -- listado de cuentas para extractos, solo Tarjeta, AH y CC y si es principal
             IF ct.relacion = 'P' THEN
               IF ct.cod_modulo = 5 AND
                  pat_imp.fu_ret_extracto(ct.nro_cuenta) = 'N' THEN
                 IF paw_not.lf_es_gourmet(ct.cod_modalidad) = 'N' THEN
                   v_despliega := 'S';
                 END IF;

               END IF;
               IF ct.cod_modulo IN (3, 4) AND ct.cod_modalidad IN (31, 41) AND
                  v_imp_extracto = 'S' THEN
                 v_despliega := 'S';
               END IF;
             END IF;
           END IF;
         ELSIF (v_ver_cuentas IN ('D', 'C') AND
              /* ct.cod_modalidad IN (31, 41)*/(instr(v_mod_cta, '#'||ct.cod_modalidad||'#' ) > 0)) THEN    --NVB-2232
           -- OMM 03/02/2011 -- Para evitar mostrar monedas distintas a GS en Pago de Salarios
           IF v_tipo_consulta = '087' AND
              ct.cod_moneda <> paw_bas.g_mon_local THEN
             v_despliega := 'N';
           ELSE
             IF ct.cod_modalidad = 31 AND
                pag_cta.fu_obt_cta_cte_comb(ct.nro_cuenta) IS NOT NULL THEN
               -- Cuentas de ahorro conjuntas no se deben desplegar para debito
               IF v_ver_cuentas = 'D' AND
                  fu_es_conjunta(ct.nro_cuenta, p_canFirmas) = 'S' THEN
                 v_despliega := 'N';
               ELSE
                 v_despliega := 'S';
               END IF;
             ELSE
               IF v_ver_cuentas = 'D' THEN
                 -- veo si la cuenta no es conjunta
                 IF fu_es_conjunta(ct.nro_cuenta, p_canFirmas) = 'S' OR
                    ct.estado IN ('X', 'A', 'T', 'D', 'C', 'V', 'P', 'B') THEN
                   v_despliega := 'N';

                   IF v_tipo_consulta = '110' AND
                      fu_es_conjunta(ct.nro_cuenta, p_canFirmas) = 'N' AND
                      ct.estado = 'A' THEN
                     -- si se consulta cuentas en estado A para desembolso de prestamo preAprobado
                     v_despliega := 'S';
                   END IF;
                 ELSE
                   v_despliega := 'S';
                 END IF;

               ELSE
                 -- OMM 20/10/2010 Se agrego condicion para no mostrar cuentas inactivas
                 IF ct.estado IN ('X', 'T', /*'D',*/ 'C', 'V', 'P', 'B') THEN
                   v_despliega := 'N';
                 ELSE
                   v_despliega := 'S';
                 END IF;
               END IF;
             END IF;
             IF (v_tipo_consulta = '100' OR v_tipo_consulta = '110') AND
                v_despliega = 'S' THEN
               -- DDEVOLUT-329 - CN - 10/2017 --
               IF v_es_nomina = 'S' THEN
                 IF pag_pre.fu_es_cta_nomina(nvl(p_codempresa, p_codpersona),ct.nro_cuenta, ct.cod_modalidad) = 'N' THEN
                   v_despliega := 'N';
                 ELSE
                   IF fug_ver_pue_des_preaprob(ct.nro_cuenta) = 'N' THEN
                     v_despliega := 'N';
                   END IF;
                 END IF;
               ELSE
                 IF fug_ver_pue_des_preaprob(ct.nro_cuenta) = 'N' THEN
                   v_despliega := 'N';
                 END IF;
               END IF;
               IF v_tipo_consulta = '100' and ct.relacion <> 'P' THEN
                   v_despliega := 'N';
               END IF;
               IF v_tipo_consulta = '110' and ct.relacion <> 'P' THEN
                   v_despliega := 'N';
               END IF;
             END IF;
           END IF;
         ELSIF v_tipo_consulta IN ('031', '032') AND
               v_ver_cuentas NOT IN ('D') THEN
           IF v_tipo_consulta = '032' THEN
             -- pago de tarjetas
             IF ct.cod_modulo = 5 THEN
               v_despliega := 'S';
             END IF;
           ELSIF v_tipo_consulta = '031' THEN
             -- pago de prestamos
             IF ct.cod_modulo = 6 THEN
               v_despliega := 'S';
             END IF;
           END IF;
           /*OBTENER LISTA DE CUENTAS APTAS PARA DESEMBOLSO DE PRESTAMOS, CASO APERTURA DE CUENTA PARA PRODUCTOS PRE-APROBADOS*/
         ELSIF v_tipo_consulta = '236' AND v_ver_cuentas IN ('D') THEN
           IF (ct.cod_modulo = 3) OR (ct.cod_modulo = 4) THEN
             v_despliega := 'S';
           END IF;
         END IF;

         --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
         IF paw_uti.fu_es_juridica(ct.nro_cuenta, p_codempresa, p_codpersona) = 'S' AND
            v_despliega = 'S' THEN
           v_despliega := 'N';
         END IF;
         IF v_cod_moneda IS NOT NULL AND
            TRIM(v_cod_moneda) <> TRIM(ct.cod_moneda) THEN
           v_despliega := 'N';
         END IF;
         -- En caso que el estado de la cuenta sea 'A', v_despliega := 'N' (excepto si, v_tipo_consulta = '110' )
         IF v_tipo_consulta <> '110' AND
            (ct.estado = 'A' AND ct.cod_modulo = 3 AND
            ct.cod_modalidad = 31 AND ct.cod_sub_modalidad = 9) THEN
           v_despliega := 'N';
         END IF;
         IF v_despliega = 'S' THEN
           -- solo si se muestra
           DECLARE
             v_accountinfo typ_resumencuenta := typ_resumencuenta;
           BEGIN
             --Se comenta porque debe de devolver si o si nro de cuenta cuando es Tarjeta
             /*IF ct.cod_modulo = 5 THEN                                                                   --NVB-2232     
               v_cta_formateada := paw_bce.fu_obt_nro_tarjeta(ct.nro_cuenta,p_codpersona,p_codempresa);   --NVB-2232
             ELSE                                          --NVB-2232
               v_cta_formateada := ct.cta_formateada;      --NVB-2232
             END IF;*/                                     --NVB-2232
             v_cta_formateada := ct.cta_formateada;
             v_can_detalles               := v_can_detalles + 1;
             v_accountinfo.nrocuenta      := substr(v_cta_formateada, 0, 17);
             v_accountinfo.tipocuenta     := substr(ct.cod_tip_cuenta, 0, 2);
             v_accountinfo.desctipocuenta := substr(ct.des_tip_cuenta, 0, 35);
             v_accountinfo.denominacion   := substr(ct.nom_cuenta, 0, 50);
             v_accountinfo.codmoneda      := substr(ct.cod_moneda, 0, 3);
             v_accountinfo.saldoactual    := ct.sal_actual;
             v_accountinfo.relacion       := ct.relacion;
             v_accountinfo.alias := fug_obt_paradicional(ct.nro_cuenta, 'CTA_ALIAS');
             --
             v_accountinfo.codModalidad := ct.cod_modalidad;
             v_accountinfo.codSubModalidad:= ct.cod_sub_modalidad;
             --
             v_listacuentas.extend;
             v_listacuentas(v_listacuentas.count) := v_accountinfo;
           END;
         END IF;
         IF (v_tipo_consulta IN ('300','070', '071', '075', '090')) THEN
           -- Recaudaciones, Acreditaciones Gourmet, Pago de Sueldos y Pago de Proveedores...
           EXIT;
         END IF;
       END LOOP;
       IF v_can_detalles = 0 AND
          nvl(v_tipo_consulta, 'k') NOT IN ('031', '032') AND
          v_tipo_consulta NOT IN ('030', '070', '075', '300') THEN
         -- no tiene cotizaciones
         --p_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
         paw_uti.pr_mensajeusuario(msg_obtcuenta_cta_noexist,v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
       END IF;
     END IF;
     paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                 p_identificadorsesion, cod_operacion,
                                 p_codempresa,
                                 'obtenerResumenCuentas- filtro: ' ||
                                  p_filtro || ', canDet:' || v_can_detalles || ' ' ||
                                  paw_uti.fu_generarbitacora(v_retorno.error,
                                                             v_retorno.nombrerespuesta,
                                                             v_retorno.descripcionrespuesta,
                                                             NULL),
                                 paw_uti.bitacora_salida);

     IF v_retorno.error = 'N' THEN
       -- todo ok, se arma el mensaje de respuesta
       v_retorno.resumencuentas := v_listacuentas;
       v_retorno.cantcuentas    := v_can_detalles;
       RETURN v_retorno;
     ELSE
       v_retorno.resumencuentas := NULL; --just in case...
       RETURN v_retorno;
     END IF;
   EXCEPTION
     WHEN OTHERS THEN
       paw_uti.pr_mensajeusuario(paw_uti.msg_error, v_retorno.nombrerespuesta,v_retorno.descripcionrespuesta,v_retorno.error);
       paw_uti.pr_insertarbitacora(p_codpersona, p_codcanal,
                                   p_identificadorsesion, cod_operacion,
                                   p_codempresa,
                                   v_logmessage || ', canDet:' ||
                                    v_can_detalles || ' - [' || SQLERRM || ']',
                                   paw_uti.bitacora_error);
       RETURN v_retorno;
   END;

    FUNCTION fu_obtenerMovimientos_por_fec( p_cod_persona          IN VARCHAR2,
                                            p_cod_empresa          IN VARCHAR2,
                                            p_cod_canal            IN VARCHAR2,
                                            p_identificadorsesion IN VARCHAR2,
                                            p_nroCuentaEspecifica IN VARCHAR2,
                                            p_nroPagina           IN NUMBER DEFAULT NULL,
                                            p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                            p_fec_inicio          IN DATE DEFAULT NULL,
                                            p_fec_fin             IN DATE DEFAULT NULL)
            RETURN typ_detalleMovimientos IS


      MSG_OBT_CTADET_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := 'OBTCTADET_CTAIX';
      -- datos recibidos
      v_nro_pagina         NUMBER(3); -- nro de pagina
      v_ver_todas          VARCHAR2(3);
      v_nro_cta_especifica VARCHAR2(16);
      --datos a responder
      v_can_detalles NUMBER(3); -- cantidad de cuentas
      -- variables
      v_monto1 NUMBER(18, 2) := 0; -- monto 1
      --v_che_devuelto    varchar2(01);
      v_can_movimientos NUMBER(8);
      --v_can_enviados    number(8);
      v_saldo      NUMBER(18, 2) := 0;
      v_fec_actual DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
      v_fec_inicio DATE := nvl(p_fec_inicio, v_fec_actual - 30);
      v_fec_final  DATE := nvl(p_fec_fin, v_fec_actual);
      v_fec_ant_habil  DATE := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_final,null);

      v_reg_inicial    NUMBER(10);
      v_reg_final      NUMBER(10);
      v_can_pagina     NUMBER(5); -- movimientos por pagina
      v_horario        VARCHAR2(1);
      v_es_mov_noc     VARCHAR2(1);
      v_es_cta_noc     VARCHAR2(1);
      v_ult_cierre     DATE;
      v_cod_ofi_origen VARCHAR2(3);
      COD_OPERACION    VARCHAR2(3) := '021';
      v_codCanal       VARCHAR2(3);
      v_retorno        typ_DetalleMovimientos := typ_detalleMovimientos;
      v_logmessage     VARCHAR2(1000);
      v_fec_ult_extracto cc_cta_corrientes.fec_ult_extracto%type;
      v_mod_cta         ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MAD_CTA_BAN_WEB'); --BWP-391 --NVB-2232
      -- cursor de cuentas pasivas del cliente
      CURSOR cuentas IS
         SELECT a.nro_cuenta, a.cod_modalidad cod_modalidad,
                fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada,
                paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta, fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta,
                a.cod_moneda cod_moneda, a.denominacion nom_cuenta, a.cod_modulo
           FROM ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion IN ('O', 'P', 'Y')
            AND b.cod_persona = nvl(p_cod_empresa, p_cod_persona)
            AND a.cod_modulo = c.cod_modulo
            AND a.cod_modalidad = c.cod_modalidad
            AND a.estado = c.estado
            AND c.activo = 'S' -- solo cuentas activas
            AND a.estado <> 'X' -- pendiente de verificacion
            --AND b.cod_modalidad IN (31, 41, 34,38,39,334)  --BWP-391        --NVB-2232
            AND instr(v_mod_cta, '#'||b.cod_modalidad||'#' ) > 0 --BWP-391    --NVB-2232
            AND (v_ver_todas = 'S' OR b.nro_cuenta = v_nro_cta_especifica); -- solo ve la cuenta recibida o todas
      -- movimientos por cuenta
      CURSOR movimientos(p_nro_cuenta IN VARCHAR2) IS
         SELECT fecha, fec_valor, nro_documento, decode(a.cod_transaccion,9611,a.CONCEPTO,9612,a.CONCEPTO,des_tra_padre) as des_tra_padre, decode(paw_bce.fu_caj_homebanking(v_codCanal), 'S', REPLACE(a.hora, ':', ''), abr_tra_padre) abr_tra_padre,
                fug_obt_tra_tipo(b.cod_transaccion, b.tipo, b.afecta) cod_tip_movimiento, monto, hora, nro_secuencia, a.fec_insercion, a.TIPO,
                a.NRO_CAJA, a.cod_modulo, a.cod_modalidad,a.COD_TRA_PADRE,a.COD_TRANSACCION, nvl(a.REVERSADO,'N') reversado
           FROM ge_transacciones b, gv_movimientos a
          WHERE nro_cuenta = p_nro_cuenta
        AND fecha between nvl(p_fec_inicio,v_fec_actual - 30) and nvl(p_fec_fin, v_fec_actual)
       -- se corrige filtro de fecha DDSI-1792  porque no tomaba los filtros anteriores y filtraba siempre hasta fecha actual. 
       -- de esta manera si ya toma hasta la fecha del filtro.
           -- AND fecha between v_fec_inicio and v_fec_final
            AND estado = 'N'
            -- Se comenta por que no corresponde, debe de traer los movimientos del mes
            --BWP-1043
           /* AND (a.reversado = 'N'
             OR (a.reversado = 'S' and a.fec_valor < v_fec_ult_extracto)
             OR (a.reversado = 'S' and a.COD_TRA_PADRE in (303, 302) and a.COD_MAD_PADRE= 455)-- BBVASOP-888/AP 3056
            )*/
            AND monto <> 0
            AND cod_tip_movimiento IN ('D', 'C')
               --and fecha >= v_fec_actual - v_can_dias
            AND a.cod_modulo = b.cod_modulo
            AND a.cod_modalidad = b.cod_modalidad
            AND a.cod_transaccion = b.cod_transaccion
            AND b.ve_cliente = 'S'
            AND NOT EXISTS (SELECT 0
                   FROM ah_retenciones x
                  WHERE x.nro_cuenta = a.nro_cuenta
                    AND x.nro_documento = a.nro_documento
                    AND x.cod_retencion = a.cod_retencion
                    AND x.fec_final = a.fec_fin_retencion
                    AND x.liberado = 'N')
            AND (NVL(b.AFECTA,'XX') = 'B'
                AND a.COD_CAUSA IN
                    (select cod_causa
                       from ge_par_causales
                     where parametro = 'COD_CAU_BLO_EXT'
                       and val_parametro = 'S' )
                OR NVL(b.AFECTA,'XX') != 'B' ) --DDSI-306 No se muestran los levantamientos de embargos movimientos
            ORDER BY a.fecha DESC, a.fec_insercion DESC;                
   BEGIN
      paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      v_codCanal           := PAW_UTI.depurarAlfanumerico(p_cod_canal,3);
      v_nro_pagina         := p_nroPagina;
      v_nro_cta_especifica := PAW_UTI.depurarAlfanumerico(p_nroCuentaEspecifica, 16);
      v_ver_todas          := 'N';

      ---p_cod_respuesta := fu_val_caja(v_codCanal,v_cod_ofi_origen,v_ult_cierre,v_cod_usuario);
      --XXX reaccionar a los codigos de respuesta de fu_val_caja...

      IF paw_bce.fu_caj_homebanking(v_codCanal) = 'N' /*v_codCanal <> '999'*/ THEN
         v_nro_pagina := 1;
      END IF;

      v_can_pagina := p_cantItemsPagina;

      v_reg_inicial := (v_nro_pagina * v_can_pagina) - (v_can_pagina - 1);
      v_reg_final   := (v_nro_pagina * v_can_pagina);

      --Logear parametros

      v_logMessage := 'obtenerMovimientos(nroCuentaEspecifica=' || v_nro_cta_especifica || ' ,p_fec_inicio= ['|| p_fec_inicio || '] ,p_fec_fin= [' || p_fec_fin || '], p_nroPagina='||v_nro_pagina||',p_cantItemsPagina='||v_can_pagina||' )';
      PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, v_logMessage, paw_uti.BITACORA_ENTRADA);

      -- 1.1. Armo el nro de cuenta

      IF v_nro_cta_especifica IS NULL THEN
         PAW_UTI.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'Cta Inexistente -' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), PAW_UTI.BITACORA_ERROR);
         RETURN v_retorno;
      END IF;

      -- 2. busco los datos de la cuentas
      IF v_retorno.error = 'N' THEN
         v_can_detalles := 0;

         FOR ct IN cuentas LOOP
            DECLARE
               detalleMovimiento typ_Movimiento := typ_Movimiento;
               listaMovimientos  typ_listaMovimientos;
               v_ver_horario     typ_mensajeRespuesta := typ_mensajeRespuesta;
            BEGIN
               --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
               IF PAW_UTI.fu_es_juridica(ct.nro_cuenta, p_cod_empresa, p_cod_persona) = 'N' THEN
                  v_can_detalles := v_can_detalles + 1;
                  v_can_movimientos := 0;
                  -- busco los demas datos de las cuentas
                  BEGIN
                     pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
                  EXCEPTION
                     WHEN OTHERS THEN
                        paw_uti.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                        paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'Cta Inexistente -' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), PAW_UTI.BITACORA_ERROR);
                        return v_retorno;
                  END;
                  IF ct.cod_modalidad = 31 then
                    BEGIN
                      SELECT fec_ult_extracto
                        INTO v_fec_ult_extracto
                       FROM ah_cta_vistas
                      WHERE nro_cuenta = ct.nro_cuenta;
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                         v_fec_ult_extracto := pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(9);
                    END;
                  ELSE
                    BEGIN
                      SELECT fec_ult_extracto
                        INTO v_fec_ult_extracto
                       FROM cc_cta_corrientes
                      WHERE nro_cuenta = ct.nro_cuenta;
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                         v_fec_ult_extracto := pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(9);
                    END;
                  END IF;
                  listaMovimientos := typ_listaMovimientos();
                  IF v_fec_final = v_fec_actual THEN
                  --V_monto1 = al saldo disponible de la cuenta pero sin considerar el Bloqueado
                  v_monto1 := pag_cta.g_ctas.sal_disponible /*+ pag_cta.g_ctas.sal_bloqueado*/;
                  ELSE
                    BEGIN
                    SELECT nvl(SAL_TOT_CAP, 0) - nvl(SAL_RET_ADE, 0) - nvl(SAL_BLO_INT, 0)
                      INTO v_monto1
                      FROM Ge_Sal_Diarios
                      WHERE fecha = v_fec_final
                      AND nro_cuenta = ct.nro_cuenta;
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                        BEGIN
                          SELECT nvl(SAL_TOT_CAP, 0) - nvl(SAL_RET_ADE, 0) - nvl(SAL_BLO_INT, 0)
                            INTO v_monto1
                            FROM Ge_Sal_Diarios
                            WHERE fecha = v_fec_ant_habil
                            AND nro_cuenta = ct.nro_cuenta;
                          EXCEPTION
                            WHEN OTHERS THEN
                             v_monto1 := 0;
                        END;
                    END;
                  END IF;
                  --Saldo disponibles + el Saldo bloqueado que resto en el package
                    v_saldo           := v_monto1;
                    v_can_movimientos := 0;
                  --v_can_enviados    := 0;

                    v_ver_horario := paw_uti.fu_ver_horario(v_horario, v_es_mov_noc, v_es_cta_noc, v_ult_cierre, v_cod_ofi_origen, v_fec_actual);

                  IF (v_ver_horario.error = 'S') THEN
                     v_retorno.nombreRespuesta      := v_ver_horario.nombreRespuesta;
                     v_retorno.descripcionRespuesta := v_ver_horario.descripcionRespuesta;
                     v_retorno.error                := v_ver_horario.error;
                     PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'lp_ver_horario - [' || v_ver_horario.descripcionRespuesta || ']' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), PAW_UTI.BITACORA_ERROR);
                     RETURN v_retorno;
                  END IF;

                  --DYDMR-3628
                  IF (v_es_mov_noc = 'S') THEN
                     v_fec_final := v_fec_actual;
                  END IF;
                  -- primer ciclo solo para obtener el monto 1
                  FOR mv IN movimientos(ct.nro_cuenta) LOOP
                     IF v_horario = 'N' THEN
                        paw_uti.lp_can_reg_historicos(ct.nro_cuenta, v_fec_actual, v_horario);
                     END IF;
                     -- OMM 13/10/2010 se agrego para que no tome en cuenta los movimientos diarios si el horario es N (nocturno)
                     IF v_horario IN ('D', 'T') OR (v_horario = 'N' AND mv.tipo IN ('H', 'N')) THEN
                        v_can_movimientos := v_can_movimientos + 1;

                        IF (v_reg_inicial IS NULL) OR (v_can_movimientos >= v_reg_inicial) THEN
                           -- es un registro que debo mostrar
                           --   v_can_enviados := v_can_enviados + 1;
                           detalleMovimiento.fecha                       := PAW_UTI.lf_for_date(mv.fecha);
                           detalleMovimiento.fechaValor                  := PAW_UTI.lf_for_date(mv.fec_valor);
                           detalleMovimiento.nroDocumento                := substr(mv.nro_documento,0, 15);
                           detalleMovimiento.descripcionTransaccionPadre := substr(mv.des_tra_padre, 0, 100);
                           detalleMovimiento.abreviaturaTransaccionPadre := mv.cod_tra_padre;
                           detalleMovimiento.tipoMovimiento              := substr(mv.cod_tip_movimiento,0, 1);
                           detalleMovimiento.monto                       := PAW_UTI.lf_for_money(mv.monto);
                           detalleMovimiento.saldo                       := PAW_UTI.lf_for_money(v_saldo);
                           detalleMovimiento.hora                        := mv.hora;
                           detalleMovimiento.codigoModulo                := mv.cod_modulo;
                           detalleMovimiento.codigoModalidad             := mv.cod_modalidad;
                           detalleMovimiento.fechaInsercion              := mv.fec_insercion;
                           detalleMovimiento.nroSecuencia                := mv.nro_secuencia;
                           detalleMovimiento.esReversado                 := mv.reversado;
                           IF detalleMovimiento.descripcionTransaccionPadre = 'COBRO DE PRESTAMOS POR CAJA' AND mv.nro_caja IS NULL THEN
                              detalleMovimiento.descripcionTransaccionPadre := 'COBRO DE PRESTAMOS POR HOME BANKING';
                           END IF;
                           IF mv.cod_tra_padre = 303 THEN
                              IF mv.cod_transaccion = 196 THEN
                                 detalleMovimiento.descripcionTransaccionPadre := 'CARGO POR TRANS. OTROS BANCOS';
                              END IF;
                              IF mv.cod_transaccion = 517 THEN
                                 detalleMovimiento.descripcionTransaccionPadre := 'IVA S/COMISIONES TRANS. A OTROS BANCOS';
                              END IF;
                           END IF;

               -- operacion correspondiente a cobro de prestamo por debito automatico
                           IF mv.cod_tra_padre = 364 THEN
                             detalleMovimiento.reportType:='aut_deb';
                           ELSE
                             detalleMovimiento.reportType:='';
                           END IF;
                           
                           listaMovimientos.extend;
                           listaMovimientos(listaMovimientos.count) := detalleMovimiento;
                        END IF;
                        IF mv.reversado = 'N' and nvl(mv.monto, 0) > 0 then
                          IF mv.cod_tip_movimiento = 'C' THEN
                             v_saldo := nvl(v_saldo, 0) - nvl(mv.monto, 0);
                          ELSE
                             v_saldo := nvl(v_saldo, 0) + nvl(mv.monto, 0);
                          END IF;
                        ELSE
                           IF mv.cod_tip_movimiento = 'C' and nvl(mv.monto, 0) > 0 THEN
                              v_saldo := nvl(v_saldo, 0) - abs(nvl(mv.monto, 0));
                           elsif mv.cod_tip_movimiento = 'C' and nvl(mv.monto, 0) < 0 THEN
                               v_saldo := nvl(v_saldo, 0) + abs(nvl(mv.monto, 0));
                           elsif mv.cod_tip_movimiento = 'D' and nvl(mv.monto, 0) > 0 THEN
                               v_saldo := nvl(v_saldo, 0) + abs(nvl(mv.monto, 0));
                            ELSE
                               v_saldo := nvl(v_saldo, 0) - abs(nvl(mv.monto, 0));
                            END IF;
                             
                       END IF;
                     
                       IF (v_reg_final IS NOT NULL) AND (v_can_movimientos >= v_reg_final) THEN
                           EXIT;
                        END IF;
                     END IF;
                  END LOOP; --end loop movimientos
                  --
                  v_monto1 := v_saldo;
                  IF v_retorno.error = 'N' THEN
                     -- esta bien el dato se carga el detalle
                     v_retorno.cantMovimientos  := v_can_movimientos;
                     v_retorno.listaMovimientos := listaMovimientos;
                  END IF;
               END IF;
            END;
         END LOOP; --end loop cuentas
         IF v_can_detalles = 0 THEN
            -- no tiene detalles
            --p_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
            PAW_UTI.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'fu_obtenerMovimientos - Cta Inexistente -' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), PAW_UTI.BITACORA_ERROR);
         END IF;
      END IF;
      -- registro del movimiento
      paw_uti.lp_reg_operacion(substr(v_nro_cta_especifica,0,15) /*p_nro_cuenta*/, NULL /*p_cod_moneda */, NULL /*p_monto*/, NULL /*p_nro_cta_contra*/, NULL /*p_cantidad*/, 'Ver Todas' /*p_etiqueta*/, v_ver_todas, /*p_dato*/ NULL, NULL, NULL, NULL, NULL, p_cod_persona, COD_OPERACION, p_cod_persona || p_cod_canal, p_cod_canal, p_identificadorsesion, p_cod_empresa);
      paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa,
            'fu_obtenerMovimientos_por_fec-' || ' cantidad de movimientos= ['|| v_retorno.cantMovimientos ||'], ' ||paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
            paw_uti.BITACORA_SALIDA);

      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'fu_obtenerMovimientos_por_fec -' || SQLERRM, PAW_UTI.BITACORA_ERROR);
         RETURN v_retorno;
   END;
   --
   FUNCTION fu_val_gen_ope_cierre RETURN VARCHAR2 IS
      v_genera      VARCHAR2(1) := 'S'; -- 'S' Puede Generar Operacion.
      v_nro_orden   ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('NRO_ORD_PROCESOS') ;
   BEGIN
      -- NO se debe generar ningun tipo de movimientos cuando se esta corriendo alguno de estos procesos
      SELECT DISTINCT('N')
        INTO v_genera
        FROM ge_procesos_det a
       WHERE a.cod_proceso = 11
         AND instr(v_nro_orden, ','||a.nro_orden||',') > 0
         AND a.hor_inicio IS NOT NULL
         AND a.hor_fin IS NULL;
      RETURN v_genera;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_genera ;
   END;

   FUNCTION fu_obtTotCuoPrestamo(p_cod_persona          IN VARCHAR2,
                                 p_cod_empresa          IN VARCHAR2,
                                 p_cod_canal            IN VARCHAR2,
                                 p_nro_prestamo IN VARCHAR2,
                                 p_identificador_sesion IN VARCHAR2 DEFAULT NULL)
    RETURN typ_obtCuotasPrestamo IS

      PRE_CTA_INVALIDA  CONSTANT VARCHAR2(15) := 'PRE_CTA_INVALID';
      v_retorno         typ_obtCuotasPrestamo := typ_obtCuotasPrestamo;
      detalleCuota      typ_cuotaPrestamo := typ_cuotaPrestamo;
      listaCuotas       typ_listaCuotaPrestamo := typ_listaCuotaPrestamo();
      v_mensajeCaja     typ_mensajeCaja;
      v_pre_cabecera    pr_cta_prestamos%ROWTYPE;
      v_dias_mora_cuota NUMBER(5) := 0;
      v_fec_actual      DATE := pae_cnf.FU_OBT_FEC_ACTUAL(6);
      v_can_cuotas      NUMBER(5) := 0;
      v_cod_operacion   VARCHAR2(3) := '701';
      v_mto_car_cuota   NUMBER(18, 2);
      v_cod_tip_doc     pr_rel_chq_lib.cod_tip_documento%TYPE;
      v_nro_doc_lib     pr_rel_chq_lib.nro_documento%TYPE;
      v_nom_librador    ba_personas.nom_completo%TYPE;
      v_lis_negra       VARCHAR2(50);

      CURSOR cuotas(p_nro_cuenta IN VARCHAR2) IS
         SELECT a.*, c.nro_cheque, c.cta_libradora, c.cod_banco, c.cod_cau_devolucion, c.estado est_cheque, c.fec_vencimiento ven_cheque, c.monto mto_cheque
         FROM pr_cuotas a, ge_che_custodias c
         WHERE a.nro_cuenta = p_nro_cuenta
           AND a.nro_cuenta = c.nro_referencia(+)
           AND a.nro_cuota = c.nro_cuota(+)
           AND a.nro_cuota > 0
         ORDER BY a.nro_cuota ASC;

      CURSOR cuotaMonto(p_nro_cuenta IN VARCHAR2, p_nro_cuota IN NUMBER) IS
         SELECT nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0)
            + nvl(c.mto_int_documentado, 0) + nvl(c.mto_int_moratorio, 0)
            + nvl(c.mto_int_mor_interes, 0) + nvl(c.mto_int_mor_adelantado, 0) + nvl(c.mto_int_punitorio, 0)
            + nvl(c.mto_cargo, 0) + nvl(c.mto_impuesto, 0) mto_cuota
           FROM pr_cobros_tmp c, pr_cuotas a
          WHERE c.nro_cuenta = a.nro_cuenta
                AND c.nro_cuota = a.nro_cuota
                AND c.nro_cuota = p_nro_cuota
                AND a.nro_cuenta = p_nro_cuenta
                AND a.nro_cuota > 0
                AND a.estado <> 'N';

   BEGIN
      PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificador_sesion, v_cod_operacion, p_cod_empresa,
            'Nro. Prestamo:' || p_nro_prestamo || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
            PAW_UTI.BITACORA_ENTRADA);

      -- No controlamos caja

      IF v_retorno.error <> 'S' THEN
         BEGIN
            SELECT a.*
            INTO v_pre_cabecera
            FROM ge_cta_clientes b, pr_cta_prestamos a
            WHERE a.nro_cuenta = p_nro_prestamo
               AND a.nro_cuenta = b.nro_cuenta
               AND b.cod_persona = nvl(p_cod_empresa, p_cod_persona)
               AND b.relacion = 'P';
         EXCEPTION
            WHEN no_data_found THEN
               PAW_UTI.pr_mensajeUsuario(PRE_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificador_sesion, v_cod_operacion, p_cod_empresa,
                    'Nro. Prestamo:' || p_nro_prestamo || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta,null),
                    PAW_UTI.BITACORA_ERROR);
         END;
      END IF;
      IF v_retorno.error <> 'S' THEN
         v_can_cuotas := 0;
         FOR cu IN cuotas(v_pre_cabecera.nro_cuenta)
         LOOP
            v_can_cuotas                  := v_can_cuotas + 1;
            detalleCuota.nroCuota         := cu.nro_cuota;
            IF cu.estado = 'N' THEN
               detalleCuota.valRecargo :=  NVL(lf_obt_car_prestamo(v_pre_cabecera.nro_cuenta, cu.nro_cuota), 0);
            ELSE
               detalleCuota.valRecargo :=  NVL(lf_obt_car_prestamo(v_pre_cabecera.nro_cuenta, cu.nro_cuota,'C', v_mensajeCaja.codigoOficinaOrigen), 0) + cu.val_recargo;
            END IF;

            detalleCuota.monCuoPagado     := NVL(FUP_OBT_MTO_COBRADO(v_pre_cabecera.nro_cuenta, cu.nro_cuota, cu.fec_ult_pago),0);
            detalleCuota.fechaVencimiento := cu.fec_vencimiento;
            detalleCuota.mtoCapital       := NVL(cu.mto_capital,0);
            detalleCuota.mtoInteres       := NVL(cu.mto_interes,0) + NVL(cu.mto_int_documentado,0) - NVL(cu.mto_int_descontado, 0);
            detalleCuota.estado           := cu.estado;
            detalleCuota.salCapital       := NVL(cu.sal_capital,0);
            detalleCuota.salInteres       := NVL(cu.sal_interes,0);
            detalleCuota.fecUltPago       := cu.fec_ult_pago;
            detalleCuota.montoCuota       := detalleCuota.mtoCapital + detalleCuota.mtoInteres + NVL(detalleCuota.valRecargo,0);
            detalleCuota.salCuota         := NVL(detalleCuota.montoCuota,0) - NVL(detalleCuota.monCuoPagado,0);
            
            IF cu.fec_vencimiento < v_fec_actual and cu.estado <> 'N' then
               v_dias_mora_cuota := v_fec_actual - cu.fec_vencimiento;
            END IF;

            IF cu.estado = 'N' AND cu.fec_vencimiento < cu.fec_ult_pago THEN
               v_dias_mora_cuota := cu.fec_ult_pago - cu.fec_vencimiento;
            ELSIF cu.estado = 'C' THEN
                IF cu.fec_vencimiento < v_fec_actual THEN
                   BEGIN
                      detalleCuota.mtoAPagar := 0;
                      OPEN cuotaMonto(v_pre_cabecera.nro_cuenta, cu.nro_cuota);
                      FETCH cuotaMonto INTO detalleCuota.mtoAPagar;
                      CLOSE cuotaMonto;
                   EXCEPTION
                         WHEN no_data_found THEN
                            PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificador_sesion, v_cod_operacion, p_cod_empresa,
                                'Nro. Prestamo:' || v_pre_cabecera.nro_cuenta || ' ' ||' cuota: '|| cu.nro_cuota ||
                                ' Sin registros en pr_cobros_tmp' ||
                                PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null ),
                                PAW_UTI.BITACORA_ERROR);
                   END;
                   v_dias_mora_cuota :=  v_fec_actual - cu.fec_vencimiento;
                   detalleCuota.estado := 'M';
                END IF;

                IF NVL(cu.mto_cap_adelantado,0) > 0 THEN
                   v_mto_car_cuota := NVL(lf_obt_mto_car_cobrado(v_pre_cabecera.nro_cuenta, cu.nro_cuota),0);
                   detalleCuota.valRecargo := NVL(detalleCuota.valRecargo,0) + v_mto_car_cuota;
                   detalleCuota.montoCuota := NVL(detalleCuota.montoCuota,0) + v_mto_car_cuota;
                   detalleCuota.salCuota := NVL(detalleCuota.montoCuota,0) - NVL(detalleCuota.monCuoPagado,0);
                   v_mto_car_cuota := 0;
                END IF;


            END IF;
            detalleCuota.diasMora := v_dias_mora_cuota;
            detalleCuota.nroCheque := substr(cu.nro_cheque, 1, 20);
            IF cu.cod_banco IS NOT NULL THEN
               detalleCuota.bancoCheque := substr(fug_obt_des_banco(cu.cod_banco), 1, 100);
               prp_obt_doc_che_custodia(cu.cta_libradora, cu.cod_banco, cu.nro_cheque, v_cod_tip_doc, v_nro_doc_lib);
               BEGIN
                  prp_obt_nom_librador (v_cod_tip_doc, null, v_nro_doc_lib, v_nom_librador, v_lis_negra);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_nom_librador := NULL;
               END;
               IF v_nom_librador IS NOT NULL THEN
                  detalleCuota.librador := substr(v_nro_doc_lib||' '||v_nom_librador, 1, 150);
               END IF;
            END IF;
            IF cu.est_cheque IS NOT NULL THEN
              detalleCuota.estCheque := substr(fue_obt_sig_refcodes('EST_CHE_CUSTODIA', cu.est_cheque), 1,100);
            END IF;
            IF cu.cod_cau_devolucion IS NOT NULL THEN
               detalleCuota.causaRechazo := substr(fug_obt_des_causa(cu.cod_cau_devolucion), 1, 1000);
            END IF;
            detalleCuota.mtoCheque     := cu.mto_cheque;
            detalleCuota.fecVencCheque := cu.ven_cheque;

            listaCuotas.EXTEND;
            listaCuotas(listaCuotas.COUNT) := detalleCuota;
            v_dias_mora_cuota := 0;
         END LOOP;
         v_retorno.cantidadCuotas := v_can_cuotas;
         v_retorno.listaCuotas    := listaCuotas;
         v_retorno.numeroPrestamo := v_pre_cabecera.nro_cuenta;
         v_retorno.descripcion    := fug_obt_des_modal(v_pre_cabecera.cod_Modulo, v_pre_cabecera.cod_modalidad);
         v_retorno.nroCtaDebito   := v_pre_cabecera.nro_Cta_Debito;
         v_retorno.estado         := v_pre_cabecera.estado;
         v_retorno.mtoCapital     := v_pre_cabecera.mto_capital;
         v_retorno.salCapital     := v_pre_cabecera.sal_capital;
         v_retorno.salInteres     := v_pre_cabecera.Sal_Interes;
         v_retorno.codMoneda      := v_pre_cabecera.cod_moneda;
         v_retorno.monto          := v_pre_cabecera.monto;
         v_retorno.fecInicio      := v_pre_cabecera.fec_inicio;
         v_retorno.tipo           := v_pre_cabecera.tipo;
         v_retorno.cuoPagadas     := v_pre_cabecera.can_cuo_pagadas;
         v_retorno.diasAtraso     := v_pre_cabecera.dia_atraso;
         v_retorno.mtoMora        := v_pre_cabecera.mto_mora;

         PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificador_sesion, v_cod_operacion, p_cod_empresa,
                'Nro. Prestamo:' || p_nro_prestamo || ', canCuotas: '||v_can_cuotas||' '||
                PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ),
                PAW_UTI.BITACORA_SALIDA);

      END IF;

      return v_retorno;
   END;

   FUNCTION fu_obt_prestamo(p_cod_persona          IN VARCHAR2,
                            p_cod_empresa          IN VARCHAR2,
                            p_cod_canal            IN VARCHAR2,
                            p_nro_prestamo         IN VARCHAR2,
                            p_identificador_sesion IN VARCHAR2 DEFAULT NULL)
    RETURN typ_mapa IS
        v_retorno         typ_mapa := typ_mapa();
        v_map_prestamo    typ_listaClaveValor := typ_listaClaveValor();
        v_cod_operacion   VARCHAR2(3) := '701';
        v_prestamo    pr_cta_prestamos%ROWTYPE;
        PRE_CTA_INVALIDA  CONSTANT VARCHAR2(15) := 'PRE_CTA_INVALID';
        --labels
        LBL_NRO_PRESTAMO  CONSTANT VARCHAR2(40) := 'NRO_PRESTAMO';
        LBL_TIPO_PRESTAMO_COD  CONSTANT VARCHAR2(40) := 'TIPO_PRESTAMO_COD';
        LBL_TIPO_PRODUCTO_COD  CONSTANT VARCHAR2(40) := 'TIPO_PRODUCTO_COD';
        LBL_TIPO_PRODUCTO_DESC  CONSTANT VARCHAR2(40) := 'TIPO_PRODUCTO_DESC';
        LBL_CUENTA_DEBITO  CONSTANT VARCHAR2(40) := 'CUENTA_DEBITO';
        LBL_FECHA_CANCELACION  CONSTANT VARCHAR2(40) := 'FECHA_CANCELACION';
        LBL_ESTADO_COD  CONSTANT VARCHAR2(40) := 'ESTADO_COD';
        LBL_ESTADO_DESC  CONSTANT VARCHAR2(40) := 'ESTADO_DESC';
        LBL_MONTO_CAPITAL  CONSTANT VARCHAR2(40) := 'MONTO_CAPITAL';
        LBL_SALDO_CAPITAL  CONSTANT VARCHAR2(40) := 'SALDO_CAPITAL';
        LBL_SALDO_INTERES  CONSTANT VARCHAR2(40) := 'SALDO_INTERES';
        LBL_MONEDA_COD  CONSTANT VARCHAR2(40) := 'MONEDA_COD';
        LBL_FECHA_INICIO  CONSTANT VARCHAR2(40) := 'FECHA_INICIO';
        LBL_FECHA_VENCIMIENTO  CONSTANT VARCHAR2(40) := 'FECHA_VENCIMIENTO';
        LBL_TASA  CONSTANT VARCHAR2(40) := 'TASA';
        LBL_CANTIDAD_CUOTAS  CONSTANT VARCHAR2(40) := 'CANTIDAD_CUOTAS';
        LBL_CANTIDAD_CUOTAS_PAGADAS  CONSTANT VARCHAR2(40) := 'CANTIDAD_CUOTAS_PAGADAS';
        LBL_CANTIDAD_CUOTAS_PENDIENTES  CONSTANT VARCHAR2(40) := 'CANTIDAD_CUOTAS_PENDIENTES';
        LBL_DIAS_ATRASO  CONSTANT VARCHAR2(40) := 'DIAS_ATRASO';


    BEGIN
        --inicializamos el retorno
        PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

        --inciamos la bitacora
        PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificador_sesion, v_cod_operacion, p_cod_empresa,
                'Obteniendo detalles del prestamo Nro.: ' || p_nro_prestamo || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                PAW_UTI.BITACORA_ENTRADA);


        BEGIN
            SELECT a.*
            INTO v_prestamo
            FROM ge_cta_clientes b, pr_cta_prestamos a
            WHERE a.nro_cuenta = p_nro_prestamo
               AND a.nro_cuenta = b.nro_cuenta
               AND b.cod_persona = nvl(p_cod_empresa, p_cod_persona)
               AND b.relacion = 'P';
         EXCEPTION
            WHEN no_data_found THEN
               PAW_UTI.pr_mensajeUsuario(PRE_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificador_sesion, v_cod_operacion, p_cod_empresa,
                        'Prestamo invalido - Nro. Prestamo:' || p_nro_prestamo || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta,null),
                        PAW_UTI.BITACORA_ERROR);
         END;

        PAW_uti.pr_add_value(v_map_prestamo, LBL_NRO_PRESTAMO, v_prestamo.NRO_CUENTA, 'VARCHAR');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_TIPO_PRESTAMO_COD, v_prestamo.tipo, 'VARCHAR');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_TIPO_PRODUCTO_COD, v_prestamo.cod_modalidad, 'VARCHAR');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_TIPO_PRODUCTO_DESC, fug_obt_des_modal(v_prestamo.cod_Modulo, v_prestamo.cod_modalidad),'VARCHAR');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_CUENTA_DEBITO, v_prestamo.NRO_CTA_DEBITO, 'VARCHAR');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_FECHA_CANCELACION, TO_CHAR(v_prestamo.FEC_CANCELACION, 'ddMMyyyy') , 'DATE');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_ESTADO_COD, v_prestamo.ESTADO, 'VARCHAR');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_ESTADO_DESC, v_prestamo.ESTADO, 'VARCHAR');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_MONTO_CAPITAL, v_prestamo.MTO_CAPITAL, 'MONEY');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_SALDO_CAPITAL, v_prestamo.SAL_CAPITAL, 'MONEY');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_SALDO_INTERES, v_prestamo.SAL_INTERES, 'MONEY');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_MONEDA_COD, v_prestamo.COD_MONEDA, 'VARCHAR');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_FECHA_INICIO, TO_CHAR(v_prestamo.FEC_INICIO, 'ddMMyyyy') ,'DATE');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_FECHA_VENCIMIENTO, TO_CHAR(v_prestamo.FEC_VENCIMIENTO, 'ddMMyyyy'), 'DATE');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_TASA, v_prestamo.VAL_TASA,'VARCHAR');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_CANTIDAD_CUOTAS, v_prestamo.CAN_CUOTAS, 'NUMBER');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_CANTIDAD_CUOTAS_PAGADAS, v_prestamo.CAN_CUO_PAGADAS, 'NUMBER');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_CANTIDAD_CUOTAS_PENDIENTES, v_prestamo.CAN_CUO_PAGADAS, 'NUMBER');
        PAW_uti.pr_add_value(v_map_prestamo, LBL_DIAS_ATRASO, v_prestamo.DIA_ATRASO, 'NUMBER');


        v_retorno.datosAdicionales := v_map_prestamo;
        v_retorno.cantidad := v_map_prestamo.count;


        PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificador_sesion, v_cod_operacion, p_cod_empresa,
                'Nro. Prestamo:' || p_nro_prestamo || ' '||
                PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ),
                PAW_UTI.BITACORA_SALIDA);

        return v_retorno;
    END;

   FUNCTION fu_obt_liq_prestamo(p_cod_persona IN VARCHAR2,
                                p_nro_cuenta IN VARCHAR2) RETURN typ_infoLiquidacionPrestamo IS
      v_retorno                 typ_infoLiquidacionPrestamo := typ_infoLiquidacionPrestamo();
      v_cuota                   typ_cuotaPrestamo;
      v_dias                    NUMBER := 0;
      v_existe                  VARCHAR(1);
      --campos
      v_fec_desembolso          DATE;
      v_fech_pri_venc           DATE;
      v_nro_documento           ba_personas.nro_documento%TYPE;
      v_moneda                  ba_monedas.descripcion%TYPE;
      v_dias_plazo              pr_solicitudes.dia_plazo%TYPE;
      v_nro_solicitud           pr_solicitudes.nro_solicitud%TYPE;
      v_tasa_tan                NUMBER(20,4);
      v_tasa_tae                NUMBER(20,4);
      v_tasa                    NUMBER(20,4);
      v_int_adelantado          pr_solicitudes.mto_interes%TYPE;
      v_tot_credito             pr_solicitudes.tot_prestamo%TYPE;
      v_tot_desembolso          pr_solicitudes.tot_desembolso%TYPE;
      v_tot_desembolsar         pr_solicitudes.tot_desembolsar%TYPE;
      v_cod_modalidad           pr_solicitudes.cod_modalidad%TYPE;
      v_mto_seg_incendio        pr_solicitudes.monto%TYPE;
      v_for_pago                VARCHAR2(50);
      v_cont_detalles           NUMBER := 0;
      v_can_resumen             NUMBER := 0;
      v_nro_cta_debito          pr_solicitudes.nro_cta_debito%TYPE;
      v_lis_resumen             typ_listaetiquetavalor := typ_listaetiquetavalor();

      
      CURSOR cuotaDetalles (p_nro_solicitud varchar2) IS
          SELECT
          S.NRO_SOLICITUD,
          S.NRO_CUOTA,
          S.DIA_PERIODO,
          S.MTO_CAPITAL,
          S.FEC_VTO_HABIL,
          S.FEC_VTO_EXACTO,
          S.VAL_INTERES,
          S.SAL_CAPITAL,
          S.SAL_CAP_ANTERIOR,
          NVL(P.FEC_INI_RRR,P.FEC_INICIO) FEC_INICIO,
          P.COD_MODULO,
          P.COD_MODALIDAD,
          P.COD_OFICINA,
          P.COD_MONEDA,
          DECODE(P.IVA_DESGLOSE,
                 'S',
                 (DECODE(P.COD_MONEDA,'GS',ROUND((S.VAL_INTERES*10)/100,0),ROUND((S.VAL_INTERES*10)/100,2))),
                 0
                 ) MTO_CAR_INTERES
          FROM PR_SOL_CUOTAS S, PR_SOLICITUDES P
          WHERE S.NRO_SOLICITUD = P.NRO_SOLICITUD
          and p.nro_solicitud=p_nro_solicitud;

      CURSOR solicitudCargos(p_nro_solicitud varchar2) IS
         select nro_solicitud, cod_transaccion, mto_mon_prestamo tasa
           from pr_sol_cargos
          where NRO_SOLICITUD = pr_sol_cargos.nro_solicitud and pr_sol_cargos.nro_solicitud=p_nro_solicitud
                 AND (not exists (select 1
                              from ge_transacciones t
                             where t.cod_modulo = 6

                               and t.cod_transaccion = pr_sol_cargos.cod_transaccion
                               and t.afecta = 'G') OR
                (pr_sol_cargos.cod_transaccion = 1521 AND EXISTS
                (select 1
                   from ba_tab_dat_adicionales a
                  where a.parametro = 'PRE_IND_CUO_CAL_SEGURO'
                    and a.referencia = pr_sol_cargos.nro_solicitud)));

   BEGIN
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      BEGIN
         -- validar que la cuenta este activa y pertenesca al cliente
         select 'S'
           into v_existe
           from ge_cta_clientes gcc, ge_cuentas gc, ge_est_cuentas gec
          where gcc.nro_cuenta = gc.nro_cuenta
            and gcc.relacion = 'P'
            and gcc.cod_persona = p_cod_persona
            and gcc.nro_cuenta = p_nro_cuenta
            and gcc.cod_modulo = gc.cod_modulo
            and gcc.cod_modalidad = gc.cod_modalidad
            and gcc.cod_modulo = gec.cod_modulo
            and gcc.cod_modalidad = gec.cod_modalidad
            and gc.estado = gec.estado
            and gec.activo = 'S';
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            paw_uti.pr_mensajeUsuario('COD_CTA_INVALID', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
      END;

      SELECT

        NVL(FPPROPU.FEC_INI_RRR,FPPROPU.FEC_INICIO) FECHA_DESEMBOLSO,
        FPPROPU.FEC_PRI_VENCIMIENTO,
        B.NRO_DOCUMENTO,
        Initcap(BA_MONEDAS.DESCRIPCION) MONEDA,
        FPPROPU.Dia_Plazo,
        FPPROPU.NRO_SOLICITUD,
        PR_CTA_PRESTAMOS.VAL_TASA,
        FPPROPU.TOT_PRESTAMO,
        decode(FPPROPU.TIP_INTERES, 'A', FPPROPU.MTO_INTERES, 0),
        --FPPROPU.TOT_DESEMBOLSAR,
        '',
        FPPROPU.TOT_DESEMBOLSO,
        FPPROPU.COD_MODALIDAD,
        FPPROPU.NRO_CTA_DEBITO

        INTO v_fec_desembolso, v_fech_pri_venc, v_nro_documento, v_moneda, v_dias_plazo, v_nro_solicitud
        , v_tasa, v_tot_credito, v_int_adelantado, /*v_tot_desembolsar,*/ v_for_pago,v_tot_desembolso,v_cod_modalidad,
          v_nro_cta_debito

        FROM BA_MONEDAS, BA_PERSONAS B, PR_CTA_PRESTAMOS, PR_SOLICITUDES FPPROPU
       WHERE DECODE(fppropu.cod_modalidad,64,nvl(FUX_OBT_CCE_BENEFICIARIO(fppropu.nro_solicitud),FPPROPU.COD_PERSONA),
             FPPROPU.COD_PERSONA) = B.COD_PERSONA
         AND FPPROPU.NRO_SOLICITUD = PR_CTA_PRESTAMOS.NRO_SOLICITUD(+)
         AND PR_CTA_PRESTAMOS.ESTADO(+) <> 'N'
         AND BA_MONEDAS.COD_MONEDA = FPPROPU.COD_MONEDA
         AND PR_CTA_PRESTAMOS.nro_cuenta=p_nro_cuenta;

      --obtener TAN y TAE
      PAS_BCP.PR_OBT_TAS_PRESTAMO(v_nro_solicitud, NULL, v_tasa_tae, v_tasa_tan);
      --obtener cargos solicitud
      v_tot_desembolsar := v_tot_credito;
      -- se carga la lista de resumen
      paw_uti.pr_add_value(v_lis_resumen, 'Total Crédito', paw_uti.lf_for_money(v_tot_credito));
      v_can_resumen := v_can_resumen + 1;
      IF v_int_adelantado > 0 THEN
        v_tot_desembolsar := v_tot_desembolsar - v_int_adelantado;
         paw_uti.pr_add_value(v_lis_resumen, 'Interes Adelantado', paw_uti.lf_for_money(v_int_adelantado));
         v_can_resumen := v_can_resumen + 1;
      END IF;

      FOR cargo IN solicitudCargos(v_nro_solicitud) LOOP
         v_tot_desembolsar := v_tot_desembolsar - cargo.tasa;
         paw_uti.pr_add_value(v_lis_resumen, Initcap(fug_obt_des_transaccion(6, v_cod_modalidad, cargo.cod_transaccion)), paw_uti.lf_for_money(cargo.tasa));
         v_can_resumen := v_can_resumen + 1;
      END LOOP;

      IF nvl(fup_obt_tip_descuento(v_cod_modalidad),'x') IN ('F','D','C') THEN
         v_tot_desembolso := nvl(v_tot_desembolso, v_tot_desembolsar);
      END IF;

      IF nvl(v_tot_desembolso, 0) > 0 AND v_nro_cta_debito IS NOT NULL THEN
         v_for_pago := substr('Credito en Cta. ' || v_nro_cta_debito, 1, 50);
      END IF;

      --seteo de variable retorno
      v_retorno.fec_desembolso    := v_fec_desembolso;
      v_retorno.fech_pri_venc     := v_fech_pri_venc;
      v_retorno.nro_documento     := v_nro_documento;
      v_retorno.moneda            := v_moneda;
      v_retorno.dias_plazo        := v_dias_plazo;
      v_retorno.nro_solicitud     := v_nro_solicitud;
      v_retorno.tasa_tan          := v_tasa_tan;
      v_retorno.tasa_tae          := v_tasa_tae;
      v_retorno.tasa              := v_tasa;
      v_retorno.total_desembolso  := nvl(v_tot_desembolso, 0);
      v_retorno.total_desembolsar := v_tot_desembolsar;
      v_retorno.for_pago          := v_for_pago;
      v_retorno.cantidadResumen   := v_can_resumen;
      v_retorno.listaResumen      := v_lis_resumen;
      v_retorno.imagenLogo := fug_obt_dat_entidad(p_opcion => 'BW_LOGO',
                                        p_fecha  => to_char(v_fec_desembolso, 'ddmmyyyy'),
                                        p_tipo   => 'FA');
      
      v_retorno.entidad := fug_obt_dat_entidad(p_opcion => 'NOM',
                                        p_fecha  => to_char(v_fec_desembolso, 'ddmmyyyy'),
                                        p_tipo   => 'FA');

      v_mto_seg_incendio := lf_obt_pre_seg_incendio(v_nro_solicitud);
      --obtener detalle de cuotas
      v_retorno.listaCuotas := typ_listaCuotaPrestamo();
      FOR cuota IN cuotaDetalles(v_nro_solicitud) LOOP
         IF (cuota.nro_cuota > 0) THEN
            v_cuota := typ_cuotaPrestamo();
            v_cuota.nroCuota         := cuota.nro_cuota;
            v_cuota.fechaVencimiento := cuota.fec_vto_habil;
            v_cuota.valRecargo       := cuota.mto_car_interes;
            v_cuota.mtoSeguro        := v_mto_seg_incendio + lf_obt_pre_seg_vida(v_nro_solicitud, cuota.nro_cuota);
            v_cuota.mtoCapital       := cuota.mto_capital;
            v_cuota.mtoInteres       := cuota.val_interes;
            v_cuota.montoCuota       := (v_cuota.mtoCapital + v_cuota.mtoInteres);
            v_cuota.mtoAPagar        := (v_cuota.montoCuota + v_cuota.valRecargo + v_cuota.mtoSeguro);
            v_cuota.diasMora         := cuota.dia_periodo;
            -- TODO: validar
            IF nvl(fup_obt_tip_descuento(v_cod_modalidad),'x') IN ('F','D','C') THEN
               v_cuota.diasMora := v_cuota.diasMora - v_dias;
            END IF;
            -- sumarizadores
            v_cont_detalles          := v_cont_detalles + 1;
            v_dias                   := cuota.dia_periodo;
            -- para lista
            v_retorno.listaCuotas.extend;
            v_retorno.listaCuotas(v_retorno.listaCuotas.count):= v_cuota;
         END IF;
      END LOOP;

      v_retorno.cantidadCuotas := v_cont_detalles;
      RETURN v_retorno;
   END;

   FUNCTION fu_obt_dat_cliente(p_cod_persona IN VARCHAR2)
       RETURN TYP_CONTACTOSCLIENTE IS
     v_retorno               typ_contactoscliente;
     v_contactoCliente       typ_contactocliente;
     v_listaContactoCliente  typ_listacontactocliente;
     v_can_contactos         NUMBER(8) := 0;
     v_dir_correo            ba_personas.dir_correo%type;
     v_cod_canal             VARCHAR2(3) := '990';
     v_cod_operacion         VARCHAR2(3) := '008';

   CURSOR telefonos IS
       SELECT cod_persona, area, telefono, tipo, tip_linea, principal
       FROM ba_telefonos
       WHERE cod_persona = p_cod_persona;

   CURSOR tel_softtoken IS
       SELECT cod_persona, cod_per_vinculo, telefono
       FROM BW_TD_CONFIGURACIONES
       WHERE cod_per_vinculo = p_cod_persona;

   CURSOR emails IS
       SELECT cod_persona, dir_correo, tipo, principal
       FROM ba_mails
       WHERE cod_persona = p_cod_persona;

   BEGIN
       v_retorno := typ_contactoscliente();
       v_listaContactoCliente := typ_listacontactocliente();

       paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, '', v_cod_operacion, '',
                                   'Obteniendo lista de contactos del cliente: ' || p_cod_persona ||
                                   PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                   PAW_UTI.BITACORA_ENTRADA);

       FOR tel IN telefonos LOOP
           BEGIN
               v_contactoCliente := typ_contactocliente();
               v_contactoCliente.cod_persona := tel.cod_persona;
               v_contactoCliente.contacto := tel.area || tel.telefono;
               v_contactoCliente.principal := tel.principal;

               IF tel.tip_linea = 'C' THEN
                   IF tel.tipo = 'P' THEN
                       v_contactoCliente.tipo := 'PERSONAL_MOBILE_NUMBER';
                   ELSIF tel.tipo = 'L' THEN
                       v_contactoCliente.tipo := 'WORK_MOBILE_NUMBER';
                   ELSE
                       v_contactoCliente.tipo := 'OTHER_MOBILE_NUMBER';
                   END IF;
               ELSIF tel.tip_linea = 'B' THEN
                   IF tel.tipo = 'P' THEN
                       v_contactoCliente.tipo := 'PERSONAL_PHONE_NUMBER';
                   ELSIF tel.tipo = 'L' THEN
                       v_contactoCliente.tipo := 'WORK_PHONE_NUMBER';
                   ELSE
                       v_contactoCliente.tipo := 'OTHER_PHONE_NUMBER';
                   END IF;
               ELSIF tel.tip_linea = 'F' THEN
                   IF tel.tipo = 'P' THEN
                       v_contactoCliente.tipo := 'PERSONAL_FAX_NUMBER';
                   ELSIF tel.tipo = 'L' THEN
                       v_contactoCliente.tipo := 'WORK_FAX_NUMBER';
                   ELSE
                       v_contactoCliente.tipo := 'OTHER_FAX_NUMBER';
                   END IF;
               END IF;
               v_listaContactoCliente.extend;
               v_listaContactoCliente(v_listaContactoCliente.count) := v_contactoCliente;
               v_can_contactos := v_can_contactos + 1;
           END;
        END LOOP;

       FOR tel IN tel_softtoken LOOP
           BEGIN
               v_contactoCliente := typ_contactocliente();
               v_contactoCliente.cod_persona := tel.cod_persona;
               v_contactoCliente.cod_per_vinculada := tel.cod_per_vinculo;
               v_contactoCliente.contacto := tel.telefono;
               v_contactoCliente.tipo := 'SOFTTOKEN_MOBILE_NUMBER';
               v_contactoCliente.principal := 'N';

               v_listaContactoCliente.extend;
               v_listaContactoCliente(v_listaContactoCliente.count) := v_contactoCliente;
               v_can_contactos := v_can_contactos + 1;
           END;
        END LOOP;

       FOR mail IN emails LOOP
           BEGIN
               v_contactoCliente := typ_contactocliente();
               v_contactoCliente.cod_persona := mail.cod_persona;
               v_contactoCliente.contacto := mail.dir_correo;
               v_contactoCliente.principal := mail.principal;

               IF mail.tipo = 'P' THEN
                   v_contactoCliente.tipo := 'PERSONAL_EMAIL';
               ELSIF mail.tipo = 'L' THEN
                   v_contactoCliente.tipo := 'WORK_EMAIL';
               ELSE
                   v_contactoCliente.tipo := 'OTHER_EMAIL';
               END IF;
               v_listaContactoCliente.extend;
               v_listaContactoCliente(v_listaContactoCliente.count) := v_contactoCliente;
               v_can_contactos := v_can_contactos + 1;
           END;
        END LOOP;

        SELECT dir_correo INTO v_dir_correo FROM ba_personas WHERE cod_persona = p_cod_persona;
        IF v_dir_correo IS NOT NULL THEN
            v_contactoCliente := typ_contactocliente();
            v_contactoCliente.cod_persona := p_cod_persona;
             v_contactoCliente.contacto := v_dir_correo;
             v_contactoCliente.tipo := 'OTHER_EMAIL';
             v_contactoCliente.principal := 'N';

             v_listaContactoCliente.extend;
             v_listaContactoCliente(v_listaContactoCliente.count) := v_contactoCliente;
             v_can_contactos := v_can_contactos + 1;
        END IF;

        v_retorno.cantContactos := v_can_contactos;
        v_retorno.listaContactoCliente := v_listaContactoCliente;

        return v_retorno;
   EXCEPTION
       WHEN OTHERS THEN
           paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, '', v_cod_operacion, '',
                                       'Error al obtener lista de contactos del cliente: ' || p_cod_persona || SQLERRM,
                                       PAW_UTI.BITACORA_ERROR);

           RETURN v_retorno;
   END;


   FUNCTION fu_cta_alias(p_cod_persona IN VARCHAR2,
                         p_cod_per_vinculada IN VARCHAR2,
                         p_cod_canal IN VARCHAR2,
                         p_id_producto IN VARCHAR2,
                         p_alias IN VARCHAR2,
                         p_id_sesion IN VARCHAR2 DEFAULT NULL)
       RETURN TYP_MENSAJERESPUESTA IS
      v_retorno typ_mensajerespuesta := typ_mensajerespuesta();
      v_existe VARCHAR2(1) := 'N';
      v_cod_operacion VARCHAR2(3) := '000'; -- todo a definir
      v_alias VARCHAR2(200);
      COD_ALIAS   VARCHAR2(20) := 'CTA_ALIAS';

   BEGIN
      PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      -- todo: validar vinculo de la persona
      v_alias := PAW_UTI.depurarTextos(p_alias, 200);
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM GE_CTA_CLIENTES C
          WHERE C.COD_PERSONA = p_cod_per_vinculada
            AND C.NRO_CUENTA = p_id_producto
            AND ROWNUM = 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
           -- seguros no contemplamos
           PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, '', v_cod_operacion, p_cod_per_vinculada, 'fu_cta_alias - ' || SQLERRM, PAW_UTI.BITACORA_ERROR);
      END;
      IF v_existe = 'S' THEN
         BEGIN
            INSERT INTO GE_CTA_DAT_ADICIONALES
            (NRO_CUENTA, PARAMETRO, VAL_PARAMETRO)
            VALUES
            (p_id_producto, COD_ALIAS, v_alias);
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               UPDATE GE_CTA_DAT_ADICIONALES C SET C.VAL_PARAMETRO = v_alias
               WHERE NRO_CUENTA = p_id_producto
               AND PARAMETRO = COD_ALIAS;
         END;
      END IF;
      return v_retorno;
   END;

   FUNCTION fu_obt_terminosycondiciones(p_cod_persona IN VARCHAR2,
                                        p_cod_empresa IN VARCHAR2,
                                        p_aplicacion  IN VARCHAR2,
                                        p_cod_canal   IN VARCHAR2,
                                        p_cod_sesion  IN VARCHAR2 DEFAULT NULL)
                                        RETURN TYP_TERMINOSYCONDICIONES IS
     v_cod_operacion VARCHAR2(3) := '008';
     v_retorno       typ_terminosycondiciones := typ_terminosycondiciones();
     v_cod_version   BW_TYC_VERSIONES.cod_version%type;
     v_version       BW_TYC_VERSIONES.version%type;
     v_terminos      BW_TYC_VERSIONES.terminos%type;
     v_aceptado      VARCHAR2(1);

   BEGIN
       PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_cod_sesion, v_cod_operacion, p_cod_empresa,
           'Obteniendo terminos y condiciones para usuario: ' || p_cod_persona || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
           PAW_UTI.BITACORA_ENTRADA);

       v_retorno.codPersona := p_cod_persona;
       v_retorno.codEmpresa := p_cod_empresa;
       v_retorno.aplicacion := p_aplicacion;

       SELECT cod_version, version, terminos
       INTO v_cod_version, v_version, v_terminos
       FROM (
           SELECT cod_version, version, terminos
           FROM BW_TYC_VERSIONES
           WHERE aplicacion = p_aplicacion
           ORDER BY cod_version DESC
       ) WHERE ROWNUM = 1;

       BEGIN
           SELECT 'S'
           INTO v_aceptado
           FROM BW_TYC_USUARIOS u
           WHERE u.cod_persona = p_cod_persona
             --AND u.cod_empresa = p_cod_empresa
             AND u.cod_version = v_cod_version
             AND ROWNUM = 1;
           v_retorno.version := v_version;
           v_retorno.aceptado := v_aceptado;
       EXCEPTION
           WHEN NO_DATA_FOUND THEN
               v_aceptado := 'N';
               v_retorno.version := v_version;
               v_retorno.aceptado := v_aceptado;
               v_retorno.terminos := v_terminos;
       END;

       RETURN v_retorno;
   END;

   FUNCTION fu_reg_terminosycondiciones(p_cod_persona IN VARCHAR2,
                                        p_cod_empresa IN VARCHAR2,
                                        p_aplicacion  IN VARCHAR2,
                                        p_cod_canal   IN VARCHAR2,
                                        p_cod_sesion  IN VARCHAR2 DEFAULT NULL)
                                        RETURN TYP_MENSAJERESPUESTA IS
     v_retorno TYP_MENSAJERESPUESTA := TYP_MENSAJERESPUESTA();
     v_cod_operacion VARCHAR2(3) := '008';
     v_cod_version   BW_TYC_VERSIONES.cod_version%type;
     v_version       BW_TYC_VERSIONES.version%type;
   BEGIN
       SELECT cod_version, version
       INTO v_cod_version, v_version
       FROM (
           SELECT cod_version, version
           FROM BW_TYC_VERSIONES
           WHERE aplicacion = p_aplicacion
           ORDER BY cod_version DESC
       ) WHERE ROWNUM = 1;

       PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_cod_sesion, v_cod_operacion, p_cod_empresa,
           'Registro de aceptacion de terminos y condiciones para usuario: ' || p_cod_persona || ' ' || p_aplicacion || ' ' || v_version || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
           PAW_UTI.BITACORA_ENTRADA);
       BEGIN
           INSERT INTO BW_TYC_USUARIOS(cod_persona, cod_empresa, cod_version)
           VALUES (p_cod_persona, p_cod_empresa, v_cod_version);
       EXCEPTION
           WHEN DUP_VAL_ON_INDEX THEN
               PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_cod_sesion, v_cod_operacion, p_cod_empresa,
                   'Error en registro de aceptacion de terminos y condiciones:' || p_cod_persona || ' ' || p_aplicacion || ' ' || v_version || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, null),
                   PAW_UTI.BITACORA_ERROR);
       END;

       RETURN v_retorno;
   END;

   FUNCTION fu_reg_ema_login_blacklist(p_cod_persona IN VARCHAR2,
                                       p_cod_empresa IN VARCHAR2,
                                       p_cod_dispositivo IN VARCHAR2,
                                       p_version_ema IN VARCHAR2,
                                       p_mobile_os IN VARCHAR2,
                                       p_estado IN VARCHAR2,
                                       p_cod_canal   IN VARCHAR2,
                                       p_cod_sesion  IN VARCHAR2 DEFAULT NULL)
                                       RETURN TYP_TERMINOSYCONDICIONES IS
     v_retorno       typ_terminosycondiciones := typ_terminosycondiciones();
     v_cod_operacion VARCHAR2(3) := '008';
     v_existe        VARCHAR2(1);
     v_aplicacion    VARCHAR2(25);
     v_aceptado      VARCHAR2(1);
     v_pass_time     NUMBER := TO_NUMBER(nvl(fug_obt_pardinamico('EMA_LOGIN_BLOCK_PASS_TIME'), '60'));
     v_version       BW_TYC_VERSIONES.version%type;
     v_terminos      BW_TYC_VERSIONES.terminos%type;
     v_estado_anterior  BW_EMA_LOGIN_BLACKLIST.estado%type;
     v_estado_nuevo     BW_EMA_LOGIN_BLACKLIST.estado%type;
     v_fec_modificacion BW_EMA_LOGIN_BLACKLIST.fec_modificacion%type;
   BEGIN
       PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_cod_sesion, v_cod_operacion, p_cod_empresa,
           'Registrando blacklist de login para usuario: ' || p_cod_persona || ', empresa: ' || p_cod_empresa || ', estado: ' || p_estado || '. ' || 
           PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
           PAW_UTI.BITACORA_ENTRADA);
       BEGIN
          BEGIN
             SELECT 'S'
             INTO v_existe
             FROM BW_EMA_LOGIN_BLACKLIST
             WHERE cod_persona = p_cod_persona;
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                v_existe := 'N';
          END;
       
          IF v_existe = 'N' AND p_estado = 'BLOCK' THEN
             INSERT INTO BW_EMA_LOGIN_BLACKLIST (cod_persona, cod_empresa, cod_dispositivo, version_ema, mobile_os, estado)
             VALUES (p_cod_persona, p_cod_empresa, p_cod_dispositivo, p_version_ema, p_mobile_os, p_estado);
             v_aceptado := 'N';
          END IF;
          IF v_existe = 'S' THEN
             IF p_estado = 'BLOCK' THEN
                SELECT estado, fec_modificacion
                INTO v_estado_anterior, v_fec_modificacion
                FROM BW_EMA_LOGIN_BLACKLIST
                WHERE cod_persona = p_cod_persona;
                
                IF v_estado_anterior = 'PASS' AND MOD(TRUNC(24 * 60 * 60 * (SYSDATE - v_fec_modificacion)), 60) < v_pass_time THEN
                   v_estado_nuevo := '1PASS';
                   v_aceptado := 'S';
                ELSE
                   v_estado_nuevo := 'BLOCK';
                   v_aceptado := 'N';
                END IF;
             ELSE
                v_estado_nuevo := 'PASS';
             END IF;
             
             UPDATE BW_EMA_LOGIN_BLACKLIST 
             SET cod_empresa = p_cod_empresa,
                 cod_dispositivo = p_cod_dispositivo,
                 version_ema = p_version_ema,
                 mobile_os = p_mobile_os,
                 estado = v_estado_nuevo
             WHERE cod_persona = p_cod_persona;
          END IF;
       
          IF p_estado = 'BLOCK' and v_aceptado = 'N' THEN
             IF p_mobile_os = 'ANDROID' THEN
                v_aplicacion := 'EMA_BLACKLIST_ANDROID';
             ELSIF p_mobile_os = 'IOS' THEN
                v_aplicacion := 'EMA_BLACKLIST_IOS';
             END IF;
          
             SELECT version, terminos
             INTO v_version, v_terminos
             FROM BW_TYC_VERSIONES T
             WHERE aplicacion = v_aplicacion
                AND ROWNUM = 1;
          
             v_retorno.aplicacion := v_aplicacion;
             v_retorno.version := v_version;
             v_retorno.terminos := v_terminos;
          END IF;
          v_retorno.aceptado := v_aceptado;
       EXCEPTION
          WHEN OTHERS THEN
             PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
             PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_cod_sesion, v_cod_operacion, p_cod_empresa,
                'Error en el registro del blacklist de login para usuario: ' || p_cod_persona || ', empresa: ' || p_cod_empresa || ', estado: ' || p_estado || '. ' || 
                PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, null),
                PAW_UTI.BITACORA_ERROR);
       END;

       RETURN v_retorno;
   END;

   FUNCTION fu_obt_ema_login_blacklist(p_cod_persona IN VARCHAR2,
                                       p_cod_empresa IN VARCHAR2,
                                       p_cod_canal   IN VARCHAR2,
                                       p_cod_sesion  IN VARCHAR2 DEFAULT NULL)
                                       RETURN TYP_MENSAJERESPUESTA IS
   v_retorno TYP_MENSAJERESPUESTA := TYP_MENSAJERESPUESTA();
   v_cod_operacion VARCHAR2(3) := '008';
   v_respuesta     BW_EMA_LOGIN_BLACKLIST.estado%type;
   BEGIN
       PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_cod_sesion, v_cod_operacion, p_cod_empresa,
           'Obteniendo registro de blacklist de login para usuario: ' || p_cod_persona || ', empresa: ' || p_cod_empresa || '. ' || 
           PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
           PAW_UTI.BITACORA_ENTRADA);
       BEGIN
          BEGIN
             SELECT estado
             INTO v_respuesta
             FROM BW_EMA_LOGIN_BLACKLIST
             WHERE cod_persona = p_cod_persona
               AND cod_empresa = p_cod_empresa;
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                v_respuesta := 'PASS';
          END;
       
          v_retorno.nombreRespuesta := v_respuesta;  
          v_retorno.descripcionRespuesta := v_respuesta;  
       EXCEPTION
          WHEN OTHERS THEN
             PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
             PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_cod_sesion, v_cod_operacion, p_cod_empresa,
                'Error obteniendo el registro de blacklist de login para usuario: ' || p_cod_persona || ', empresa: ' || p_cod_empresa || '. ' || 
                PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, null),
                PAW_UTI.BITACORA_ERROR);
       END;

      RETURN v_retorno;
   END;

   FUNCTION fu_obt_tip_TransfInterbancaria( p_cod_msj_swift     IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                                            p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                                            p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE,
                                            p_cod_tra_padre     IN ge_snp_par_mensajes.cod_tra_padre%type,
                                            p_monto             IN ge_snp_transferencias.monto%TYPE,
                                            p_cod_mon_credito   IN ge_snp_transferencias.cod_moneda%type,
                                            p_fec_pago          IN ge_snp_transferencias.fec_valor%type default null,
                                            p_cod_persona       IN ge_snp_transferencias.cod_per_solicitante%type default null)
     return varchar2
    IS
     -- varibles
     v_fec_actual  date := pag_cal.FU_OBT_FEC_ACTUAL(9);
     v_hor_actual  varchar2(10) := to_char(sysdate,'hh24mi') ;
     v_fec_snp     ge_snp_horarios.fecha%type;
     v_hor_ini_snp ge_snp_horarios.hor_inicio%type;
     v_hor_fin_snp ge_snp_horarios.hor_fin%type;
     v_cod_periodo ge_snp_horarios.cod_periodo%type;
     v_mto_ach     number(18):= to_number(fug_obt_pardinamico('MTO_MAX_ACH'));
     v_hab_ach     varchar2(1) := substr(fug_obt_pardinamico('SNP_HAB_MSJ_ACH'),1,1);
     v_lugar       varchar(200);
     v_fec_pago    date        := p_fec_pago;  --Pago aProveedores Fecha Futura
     v_cod_mon_local ba_monedas.cod_moneda%type;
     v_mto_lim_int_tarde ge_snp_transferencias.monto%type;
     v_mto_tra_env_cliente ge_snp_transferencias.monto%type;
     v_hor_ini_tarde ge_snp_horarios.hor_inicio%type;
     v_hor_fin_tarde ge_snp_horarios.hor_fin%type;
     v_dia_actual varchar2(1);
     v_es_feriado varchar2(1);

     begin
     --Carga de Variables--
     v_hor_ini_snp := fu_obt_hor_ini_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre);
     v_hor_fin_snp := fu_obt_hor_fin_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre);
     v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
     v_dia_actual := rtrim(upper(to_char(trunc(sysdate),'d')));

     --Verificar si fecha sistema es feriado--
     select decode(nvl(count(*),0),0,'N','S')
       into v_es_feriado
       from ba_feriados
      where fecha = trunc(sysdate)
        and cod_oficina = fug_obt_ofi_usuario(user);

     begin
       v_lugar :='-1.Obt periodo sipap.'||p_cod_msj_swift||'-'||p_tip_operacion||'-'||p_sub_tip_operacion;
       SELECT m.cod_periodo
         INTO v_cod_periodo
         FROM ge_snp_par_mensajes m
        WHERE m.cod_msj_swift = p_cod_msj_swift
          AND m.cod_tip_operacion = p_tip_operacion
          AND nvl(m.cod_sub_tip_operacion,'x') = nvl(p_sub_tip_operacion,'x');                                               --NVB-2232
         -- AND nvl(m.cod_tra_padre, pas_snp.fu_obt_cod_tra_padre) =nvl(p_cod_tra_padre, pas_snp.fu_obt_cod_tra_padre) ;     --NVB-2232
     exception
        when others then
          v_lugar := v_lugar|| '-Err.'||sqlerrm;
           return v_lugar;
     end;
     begin
       v_lugar :='-2-Obt fecha sipap.'||p_cod_msj_swift||'-'||p_tip_operacion||'-'||p_sub_tip_operacion;
       SELECT h.fecha
         INTO v_fec_snp
         FROM ge_snp_horarios h
        WHERE h.cod_periodo = v_cod_periodo;
     exception
        when others then
          v_lugar := v_lugar|| '-Err.'||sqlerrm;
           return v_lugar;
     end;

     begin
       v_lugar :='-3-Obt hora inicio fin tarde';
       SELECT h.hor_inicio, h.hor_fin
         INTO v_hor_ini_tarde, v_hor_fin_tarde
         FROM ge_snp_horarios h
        WHERE h.cod_periodo = 3; --Periodo Tarde--
     exception
       when others then
         v_lugar := v_lugar|| 'Periodo tarde-Err.'||sqlerrm;
         return v_lugar;
     end;

     -- si no esta habilitado ACH entonces retorna 103
     if v_hab_ach ='N' 
       --o Se trata de una transaccion con intermediario patrocinador spparpat-2
       or (p_sub_tip_operacion = '004' and --VAE 10/2021
           p_tip_operacion     = '001' and 
           p_cod_msj_swift     ='103') then
       return '103' ;
     else
          -- si la moneda de credito es USD continua como  MT103
         if p_cod_mon_credito <> v_cod_mon_local then
               return '103' ;
         end if;

         -- si supera el monto maximo establecido continua como MT103
         if p_monto > v_mto_ach then
           return '103' ;
         end if;


         -- si la fecha de pago es mayor a hoy entonces se va como MT102, aplica a fecha fut y ope programadas
         if v_fec_pago is not null and v_fec_pago > v_fec_actual then
           return '102';
         end if;

         -- si es dia habil  el horario esta dentro del horario de sipap
         -- seteamos como de Alto Valor - MT103, o si el monto supera el mto maximo para ACH
         IF v_fec_actual = v_fec_snp and  -- si son iguales ya abrio el mercado
            v_hor_actual between v_hor_ini_snp and v_hor_fin_snp
         THEN
            --return '103';
            IF v_hor_actual between v_hor_ini_tarde and v_hor_fin_tarde
            THEN
               if (v_hor_actual < v_hor_ini_snp) then
                  return '102';
               elsif (v_hor_actual > v_hor_fin_tarde) then
                  return '102';
               else
                if p_cod_tra_padre not in (302) then
                  if ((p_cod_mon_credito <> v_cod_mon_local)) then
                     return '102';
                  else
                      v_mto_lim_int_tarde := fug_obt_pardinamico('SNP_MTO_LIM_INT_TARDE',null,null,v_cod_mon_local);
                      v_mto_tra_env_cliente := fug_obt_tot_tra_snp(p_cod_persona, v_cod_mon_local,
                                                                   v_fec_actual, v_hor_ini_tarde,
                                                                   v_hor_fin_tarde, 103);

                      if ((nvl(v_mto_tra_env_cliente,0) + nvl(p_monto,0) <= nvl(v_mto_lim_int_tarde,0)) and
                          (v_hor_actual between v_hor_ini_tarde and v_hor_fin_tarde) and
                          (fug_den_per_act_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre,3) = 'S'))
                       then
                         return '103';
                      else
                        return 102;
                      end if;
                  end if;
                else
                  return 102;
                end if;
               end if;
            else
              return '103';
            end if;
         else
            /*if ((v_dia_actual in ('1','7')) or (v_es_feriado = 'S')) then
               --Sabado, Domingo, o Feriado--
               return '102';
            else*/
              if (v_hor_actual < v_hor_ini_snp) then
                  return '102';
              elsif (v_hor_actual > v_hor_fin_tarde) then
                  return '102';
              else
                if p_cod_tra_padre not in (302) then
                  if ((p_cod_mon_credito <> v_cod_mon_local)) then
                     return '102';
                  else
                      v_mto_lim_int_tarde := fug_obt_pardinamico('SNP_MTO_LIM_INT_TARDE',null,null,v_cod_mon_local);
                      v_mto_tra_env_cliente := fug_obt_tot_tra_snp(p_cod_persona, v_cod_mon_local,
                                                                   v_fec_actual, v_hor_ini_tarde,
                                                                   v_hor_fin_tarde, 103);

                      if ((nvl(v_mto_tra_env_cliente,0) + nvl(p_monto,0) <= nvl(v_mto_lim_int_tarde,0)) and
                          (v_hor_actual between v_hor_ini_tarde and v_hor_fin_tarde) and
                          (fug_den_per_act_snp(p_cod_msj_swift,p_tip_operacion,p_sub_tip_operacion,p_cod_tra_padre,3) = 'S'))
                       then
                         return '103';
                      else
                        return 102;
                      end if;
                  end if;
                else
                  return 102;
                end if;
              end if;
            --end if;
         END IF;
     end if;
  end;

  -- retorna la fecha actual de snp
  FUNCTION fu_obt_snp_fec_acreditacion(p_cod_msj_swift IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                                       p_cod_mon_credito   IN ge_snp_transferencias.cod_moneda%type)
  RETURN DATE IS
      v_fec_actual  ge_snp_horarios.fecha%TYPE;
      v_fec_hab_sigte ge_snp_horarios.fecha%TYPE ;
      v_hor_actual  varchar2(10) := to_char(sysdate,'hh24mi');
      v_hor_ini_snp ge_snp_horarios.hor_inicio%type;
      v_hor_fin_snp ge_snp_horarios.hor_fin%type;
      v_cod_mt                    VARCHAR2(3):= '103';
      v_cod_tip_operacion         VARCHAR2(3):='001';
      v_cod_sub_tip_operacion     VARCHAR2(3):='002';
      v_hab_ach                   varchar2(1) := substr(fug_obt_pardinamico('SNP_HAB_MSJ_ACH'),1,1);
      v_hor_extendido             varchar2(2) := fug_obt_pardinamico('SNP_HOR_EXTENDIDO');
     -- v_hor_snp_usd ge_snp_horarios.hor_fin%type    := fug_obt_pardinamico('SNP_HOR_CIE_USD',null,null,p_cod_mon_credito,null,null);

   BEGIN
      v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
      v_fec_hab_sigte := pag_cal.FU_OBT_FEC_SIG_HAB(trunc(v_fec_actual),1,1);
     /*if p_cod_msj_swift = '103' then
        v_cod_tip_operacion     := '001';
        v_cod_sub_tip_operacion := '002';
     else
        v_cod_tip_operacion      := '011';
        v_cod_sub_tip_operacion  := '001';
     end if; */
     -- siempre comparamos con el horario del 103
     v_hor_ini_snp := paw_bas.fu_obt_hor_ini_snp(v_cod_mt,v_cod_tip_operacion,v_cod_sub_tip_operacion,302);
     v_hor_fin_snp := paw_bas.fu_obt_hor_fin_snp(v_cod_mt,v_cod_tip_operacion,v_cod_sub_tip_operacion,302);
    -- v_estado      := pas_snp.fu_obt_est_horario(p_cod_msj_swift,v_cod_tip_operacion,v_cod_sub_tip_operacion,p_cod_mon_credito);


      -- SI ES MT102 Y LA FECHA
     IF p_cod_msj_swift = 102 THEN
       IF v_fec_actual = trunc(sysdate) and -- si ya estamos en una fecha habil
          v_hor_actual < v_hor_ini_snp then
          return v_fec_actual;
       elsif v_fec_actual > trunc(sysdate) then
          return v_fec_actual;
       else
          return v_fec_hab_sigte;
       end if;
     else --103
       --if p_cod_mon_credito = pag_gen.FU_OBT_MON_FUERTE and
       --and   v_hor_actual >= v_hor_snp_usd then
      if p_cod_mon_credito <> v_cod_mon_local then
          if v_hor_actual >= v_hor_fin_snp then -- si ya supero el horario de cierre
             return v_fec_hab_sigte;
          else
             return v_fec_actual;
          end if;
       elsif v_hab_ach = 'N'  then -- DYDMR-15392 VAE 06/2021
          if  v_fec_actual = TRUNC(SYSDATE) then
               if v_hor_actual >= paw_bas.fu_obt_hor_fin_snp(v_hor_extendido) then -- si ya supero el horario extendido
                  return v_fec_hab_sigte;
               else
                  return v_fec_actual;
               end if;
          elsif v_fec_actual > trunc(sysdate) then
                return v_fec_actual;
          else
                return v_fec_hab_sigte;
          end if;   
       else  
         return v_fec_actual;
       end if;
     end if;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   
   FUNCTION fu_obtenerMovimientos_por_fec_ext( p_cod_persona          IN VARCHAR2,
                                               p_cod_empresa          IN VARCHAR2,
                                               p_cod_canal            IN VARCHAR2,
                                               p_identificadorsesion IN VARCHAR2,
                                               p_nroCuentaEspecifica IN VARCHAR2,
                                               p_nroPagina           IN NUMBER DEFAULT NULL,
                                               p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                               p_fec_inicio          IN DATE DEFAULT NULL,
                                               p_fec_fin             IN DATE DEFAULT NULL)
            RETURN typ_detalleMovimientos IS


      MSG_OBT_CTADET_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := 'OBTCTADET_CTAIX';
      -- datos recibidos
      v_nro_pagina         NUMBER(3); -- nro de pagina
      v_ver_todas          VARCHAR2(3);
      v_nro_cta_especifica VARCHAR2(16);
      --datos a responder
      v_can_detalles NUMBER(3); -- cantidad de cuentas
      -- variables
      v_monto1 NUMBER(18, 2) := 0; -- monto 1
      --v_che_devuelto    varchar2(01);
      v_can_movimientos NUMBER(8);
      --v_can_enviados    number(8);
      v_saldo      NUMBER(18, 2) := 0;
      v_fec_actual DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
      v_fec_inicio DATE := nvl(p_fec_inicio, v_fec_actual - 30);
      v_fec_final  DATE := nvl(p_fec_fin, v_fec_actual);
      v_fec_ant_habil  DATE := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_inicio,null);

      v_reg_inicial    NUMBER(10);
      v_reg_final      NUMBER(10);
      v_can_pagina     NUMBER(5); -- movimientos por pagina
      v_horario        VARCHAR2(1);
      v_es_mov_noc     VARCHAR2(1);
      v_es_cta_noc     VARCHAR2(1);
      v_ult_cierre     DATE;
      v_cod_ofi_origen VARCHAR2(3);
      COD_OPERACION    VARCHAR2(3) := '021';
      v_codCanal       VARCHAR2(3);
      v_retorno        typ_DetalleMovimientos := typ_detalleMovimientos;
      v_logmessage     VARCHAR2(1000);
      v_fec_ult_extracto cc_cta_corrientes.fec_ult_extracto%type;
      v_mod_cta         ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MAD_CTA_BAN_WEB'); --BWP-391 --NVB-2232
      v_nombre_cta_deb VARCHAR2(100); --UES-1196 Se agrega el nombre del titular de la cuenta al procesar los DAS (LEL) 14/11/2024
      -- cursor de cuentas pasivas del cliente
      CURSOR cuentas IS
         SELECT a.nro_cuenta, a.cod_modalidad cod_modalidad,
                fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada,
                paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta, fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta,
                a.cod_moneda cod_moneda, a.denominacion nom_cuenta, a.cod_modulo
           FROM ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion IN ('O', 'P', 'Y')
            AND b.cod_persona = nvl(p_cod_empresa, p_cod_persona)
            AND a.cod_modulo = c.cod_modulo
            AND a.cod_modalidad = c.cod_modalidad
            AND a.estado = c.estado
            AND c.activo = 'S' -- solo cuentas activas
            AND a.estado <> 'X' -- pendiente de verificacion
            --AND b.cod_modalidad IN (31, 41, 34,38,39,334)  --BWP-391        --NVB-2232
            AND instr(v_mod_cta, '#'||b.cod_modalidad||'#' ) > 0 --BWP-391    --NVB-2232
            AND (v_ver_todas = 'S' OR b.nro_cuenta = v_nro_cta_especifica); -- solo ve la cuenta recibida o todas
      -- movimientos por cuenta
      CURSOR movimientos(p_nro_cuenta IN VARCHAR2) IS
         SELECT fecha, fec_valor, nro_documento, decode(a.cod_transaccion,9611,a.CONCEPTO,9612,a.CONCEPTO,des_tra_padre) as des_tra_padre, decode(paw_bce.fu_caj_homebanking(v_codCanal), 'S', REPLACE(a.hora, ':', ''), abr_tra_padre) abr_tra_padre,
                fug_obt_tra_tipo(b.cod_transaccion, b.tipo, b.afecta) cod_tip_movimiento, monto, hora, nro_secuencia, a.fec_insercion, a.TIPO,
                a.NRO_CAJA, a.cod_modulo, a.cod_modalidad,a.COD_TRA_PADRE,a.COD_TRANSACCION, nvl(a.REVERSADO,'N') reversado
                ,a.COD_USUARIO, a.CONCEPTO --UES-1196 Se agrega para poder obtener el nombre del titular de la cuenta al procesar los DAS (LEL) 14/11/2024
           FROM ge_transacciones b, gv_movimientos a
          WHERE nro_cuenta = p_nro_cuenta
        AND fecha between nvl(p_fec_inicio,v_fec_actual - 300) and nvl(p_fec_fin, v_fec_actual)
       -- se corrige filtro de fecha DDSI-1792  porque no tomaba los filtros anteriores y filtraba siempre hasta fecha actual. 
       -- de esta manera si ya toma hasta la fecha del filtro.
           -- AND fecha between v_fec_inicio and v_fec_final
            AND estado = 'N'
            -- Se comenta por que no corresponde, debe de traer los movimientos del mes
            --BWP-1043
           /* AND (a.reversado = 'N'
             OR (a.reversado = 'S' and a.fec_valor < v_fec_ult_extracto)
             OR (a.reversado = 'S' and a.COD_TRA_PADRE in (303, 302) and a.COD_MAD_PADRE= 455)-- BBVASOP-888/AP 3056
            )*/
            AND monto <> 0
            AND cod_tip_movimiento IN ('D', 'C')
               --and fecha >= v_fec_actual - v_can_dias
            AND a.cod_modulo = b.cod_modulo
            AND a.cod_modalidad = b.cod_modalidad
            AND a.cod_transaccion = b.cod_transaccion
            AND b.ve_cliente = 'S'
            AND NOT EXISTS (SELECT 0
                   FROM ah_retenciones x
                  WHERE x.nro_cuenta = a.nro_cuenta
                    AND x.nro_documento = a.nro_documento
                    AND x.cod_retencion = a.cod_retencion
                    AND x.fec_final = a.fec_fin_retencion
                    AND x.liberado = 'N')
            AND (NVL(b.AFECTA,'XX') = 'B'
                AND a.COD_CAUSA IN
                    (select cod_causa
                       from ge_par_causales
                     where parametro = 'COD_CAU_BLO_EXT'
                       and val_parametro = 'S' )
                OR NVL(b.AFECTA,'XX') != 'B' ) --DDSI-306 No se muestran los levantamientos de embargos movimientos
            ORDER BY a.fecha ASC, a.fec_insercion ASC;                
   BEGIN
      paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      v_codCanal           := PAW_UTI.depurarAlfanumerico(p_cod_canal,3);
      v_nro_pagina         := p_nroPagina;
      v_nro_cta_especifica := PAW_UTI.depurarAlfanumerico(p_nroCuentaEspecifica, 16);
      v_ver_todas          := 'N';

      ---p_cod_respuesta := fu_val_caja(v_codCanal,v_cod_ofi_origen,v_ult_cierre,v_cod_usuario);
      --XXX reaccionar a los codigos de respuesta de fu_val_caja...

      IF paw_bce.fu_caj_homebanking(v_codCanal) = 'N' /*v_codCanal <> '999'*/ THEN
         v_nro_pagina := 1;
      END IF;

      v_can_pagina := p_cantItemsPagina;

      v_reg_inicial := (v_nro_pagina * v_can_pagina) - (v_can_pagina - 1);
      v_reg_final   := (v_nro_pagina * v_can_pagina);

      --Logear parametros

      v_logMessage := 'obtenerMovimientos(nroCuentaEspecifica=' || v_nro_cta_especifica || ' ,p_fec_inicio= ['|| p_fec_inicio || '] ,p_fec_fin= [' || p_fec_fin || '], p_nroPagina='||v_nro_pagina||',p_cantItemsPagina='||v_can_pagina||' )';
      PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, v_logMessage, paw_uti.BITACORA_ENTRADA);

      -- 1.1. Armo el nro de cuenta

      IF v_nro_cta_especifica IS NULL THEN
         PAW_UTI.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'Cta Inexistente -' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), PAW_UTI.BITACORA_ERROR);
         RETURN v_retorno;
      END IF;

      -- 2. busco los datos de la cuentas
      IF v_retorno.error = 'N' THEN
         v_can_detalles := 0;

         FOR ct IN cuentas LOOP
            DECLARE
               detalleMovimiento typ_Movimiento := typ_Movimiento;
               listaMovimientos  typ_listaMovimientos;
               v_ver_horario     typ_mensajeRespuesta := typ_mensajeRespuesta;
            BEGIN
               --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
               IF PAW_UTI.fu_es_juridica(ct.nro_cuenta, p_cod_empresa, p_cod_persona) = 'N' THEN
                  v_can_detalles := v_can_detalles + 1;
                  v_can_movimientos := 0;
                  -- busco los demas datos de las cuentas
                  BEGIN
                     pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
                  EXCEPTION
                     WHEN OTHERS THEN
                        paw_uti.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                        paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'Cta Inexistente -' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), PAW_UTI.BITACORA_ERROR);
                        return v_retorno;
                  END;
                  
                  IF ct.cod_modalidad = 31 then
                    BEGIN
                      SELECT fec_ult_extracto
                        INTO v_fec_ult_extracto
                       FROM ah_cta_vistas
                      WHERE nro_cuenta = ct.nro_cuenta;
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                         v_fec_ult_extracto := pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(9);
                    END;
                  ELSE
                    BEGIN
                      SELECT fec_ult_extracto
                        INTO v_fec_ult_extracto
                       FROM cc_cta_corrientes
                      WHERE nro_cuenta = ct.nro_cuenta;
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                         v_fec_ult_extracto := pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(9);
                    END;
                  END IF;
                  
                  listaMovimientos := typ_listaMovimientos();
                  --IF v_fec_final = v_fec_actual THEN
                  --V_monto1 = al saldo disponible de la cuenta pero sin considerar el Bloqueado
                  --v_monto1 := pag_cta.g_ctas.sal_disponible /*+ pag_cta.g_ctas.sal_bloqueado*/;
                   --ELSE
                   BEGIN
                    SELECT nvl(SAL_TOT_CAP, 0) - nvl(SAL_RET_ADE, 0) - nvl(SAL_BLO_INT, 0)
                      INTO v_monto1
                      FROM Ge_Sal_Diarios
                      WHERE fecha = v_fec_inicio - 1
                      AND nro_cuenta = ct.nro_cuenta;
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                        BEGIN
                          SELECT nvl(SAL_TOT_CAP, 0) - nvl(SAL_RET_ADE, 0) - nvl(SAL_BLO_INT, 0)
                            INTO v_monto1
                            FROM Ge_Sal_Diarios
                            WHERE fecha = v_fec_ant_habil
                            AND nro_cuenta = ct.nro_cuenta;
                          EXCEPTION
                            WHEN OTHERS THEN
                             v_monto1 := 0;
                        END;
                      WHEN OTHERS THEN
                          v_monto1 := 0;
                    END;
                  --END IF;
                  --Saldo disponibles + el Saldo bloqueado que resto en el package
                    v_saldo           := v_monto1;
                    v_can_movimientos := 0;
                  --v_can_enviados    := 0;

                    v_ver_horario := paw_uti.fu_ver_horario(v_horario, v_es_mov_noc, v_es_cta_noc, v_ult_cierre, v_cod_ofi_origen, v_fec_actual);

                    IF (v_ver_horario.error = 'S') THEN
                       v_retorno.nombreRespuesta      := v_ver_horario.nombreRespuesta;
                       v_retorno.descripcionRespuesta := v_ver_horario.descripcionRespuesta;
                       v_retorno.error                := v_ver_horario.error;
                       PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'lp_ver_horario - [' || v_ver_horario.descripcionRespuesta || ']' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), PAW_UTI.BITACORA_ERROR);
                       RETURN v_retorno;
                    END IF;

                    --DYDMR-3628
                    IF (v_es_mov_noc = 'S') THEN
                       v_fec_final := v_fec_actual;
                    END IF;
                  -- primer ciclo solo para obtener el monto 1
                  FOR mv IN movimientos(ct.nro_cuenta) LOOP
                     IF v_horario = 'N' THEN
                        paw_uti.lp_can_reg_historicos(ct.nro_cuenta, v_fec_actual, v_horario);
                     END IF;
                     -- OMM 13/10/2010 se agrego para que no tome en cuenta los movimientos diarios si el horario es N (nocturno)
                     IF v_horario IN ('D', 'T') OR (v_horario = 'N' AND mv.tipo IN ('H', 'N')) THEN
                        v_can_movimientos := v_can_movimientos + 1;

                        IF (v_reg_inicial IS NULL) OR (v_can_movimientos >= v_reg_inicial) THEN
                           -- es un registro que debo mostrar
                           --   v_can_enviados := v_can_enviados + 1;
                           detalleMovimiento.fecha                       := PAW_UTI.lf_for_date(mv.fecha);
                           detalleMovimiento.fechaValor                  := PAW_UTI.lf_for_date(mv.fec_valor);
                           detalleMovimiento.nroDocumento                := substr(mv.nro_documento,0, 15);
                           detalleMovimiento.descripcionTransaccionPadre := substr(mv.des_tra_padre, 0, 100);
                           detalleMovimiento.abreviaturaTransaccionPadre := mv.cod_tra_padre;
                           detalleMovimiento.tipoMovimiento              := substr(mv.cod_tip_movimiento,0, 1);
                           detalleMovimiento.monto                       := PAW_UTI.lf_for_money(mv.monto);
                           detalleMovimiento.hora                        := mv.hora;
                           detalleMovimiento.codigoModulo                := mv.cod_modulo;
                           detalleMovimiento.codigoModalidad             := mv.cod_modalidad;
                           detalleMovimiento.fechaInsercion              := mv.fec_insercion;
                           detalleMovimiento.nroSecuencia                := mv.nro_secuencia;
                           detalleMovimiento.esReversado                 := mv.reversado;
                           detalleMovimiento.concepto                    := substr(mv.concepto, 0, 100); --UES-2297 Se agrega el campo concepto al extracto (LEL) 29/11/2024
                           IF detalleMovimiento.descripcionTransaccionPadre = 'COBRO DE PRESTAMOS POR CAJA' AND mv.nro_caja IS NULL THEN
                              detalleMovimiento.descripcionTransaccionPadre := 'COBRO DE PRESTAMOS POR HOME BANKING';
                           END IF;
                           IF mv.cod_tra_padre = 303 THEN
                              IF mv.cod_transaccion = 196 THEN
                                 detalleMovimiento.descripcionTransaccionPadre := 'CARGO POR TRANS. OTROS BANCOS';
                              END IF;
                              IF mv.cod_transaccion = 517 THEN
                                 detalleMovimiento.descripcionTransaccionPadre := 'IVA S/COMISIONES TRANS. A OTROS BANCOS';
                              END IF;
                           END IF;
                           /***********************************************************************************************************************/
                           /* UES-1196 Se agrega proceso para la busqueda nombre del titular de la cuenta al procesar los DAS (LEL) 14/11/2024   */
                           /**********************************************************************************************************************/
                           IF mv.cod_tra_padre = fug_obt_pardinamico('COD_TRA_PADRE_DAS' ) THEN
                                BEGIN
                                    SELECT bper.nom_completo 
                                    INTO   v_nombre_cta_deb
                                    FROM  ba_personas bper,
                                          ge_cta_clientes gcc
                                    WHERE bper.cod_persona = gcc.cod_persona
                                    AND gcc.nro_cuenta in ( SELECT gmov.nro_cuenta 
                                                            FROM  gv_movimientos gmov
                                                            WHERE gmov.fecha = mv.fecha
                                                            AND gmov.hora = mv.hora
                                                            AND gmov.cod_usuario = mv.cod_usuario
                                                            AND gmov.cod_tra_padre = mv.cod_tra_padre
                                                            AND gmov.cod_transaccion  IN (SELECT gpd.val_parametro 
                                                                                          FROM ge_par_dinamicos gpd
                                                                                          WHERE gpd.parametro = 'COD_TRA_DEB_DAS')
                                                          )
                                    AND gcc.RELACION ='P';
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        v_nombre_cta_deb := ' ';
                                END;
                                detalleMovimiento.concepto :=substr(mv.concepto ||' - '||v_nombre_cta_deb,0,100); --UES-2297 Se agrega el campo concepto al extracto (LEL) 29/11/2024
                            END IF;
                           /***********************************************************************************************************************/
                           /* Fin de Bloque UES-1196                                                                                              */
                           /***********************************************************************************************************************/
                            
               -- operacion correspondiente a cobro de prestamo por debito automatico
                           IF mv.cod_tra_padre = 364 THEN
                             detalleMovimiento.reportType:='aut_deb';
                           ELSE
                             detalleMovimiento.reportType:='';
                           END IF;

                           IF mv.reversado = 'N' and nvl(mv.monto, 0) > 0 then
                               IF mv.cod_tip_movimiento = 'D' THEN
                                 v_saldo := nvl(v_saldo, 0) - nvl(mv.monto, 0);
                               ELSE
                                 v_saldo := nvl(v_saldo, 0) + nvl(mv.monto, 0);
                               END IF;
                           ELSE
                               IF mv.cod_tip_movimiento = 'C' and nvl(mv.monto, 0) > 0 THEN
                                   v_saldo := nvl(v_saldo, 0) + abs(nvl(mv.monto, 0));
                               ELSIF mv.cod_tip_movimiento = 'C' and nvl(mv.monto, 0) < 0 THEN
                                   v_saldo := nvl(v_saldo, 0) - abs(nvl(mv.monto, 0));
                               ELSIF mv.cod_tip_movimiento = 'D' and nvl(mv.monto, 0) > 0 THEN
                                   v_saldo := nvl(v_saldo, 0) - abs(nvl(mv.monto, 0));
                               ELSE
                                   v_saldo := nvl(v_saldo, 0) + abs(nvl(mv.monto, 0));
                               END IF;
                            END IF;
                            
                             detalleMovimiento.saldo        := PAW_UTI.lf_for_money(v_saldo);
                             detalleMovimiento.saldoInicial := v_monto1;
                             listaMovimientos.extend;
                             listaMovimientos(listaMovimientos.count) := detalleMovimiento;
                             
                       END IF;
                     
                       IF (v_reg_final IS NOT NULL) AND (v_can_movimientos >= v_reg_final) THEN
                           EXIT;
                       END IF;
                     END IF;
                  END LOOP; --end loop movimientos
                  --
                  --v_monto1 := v_saldo;
                  IF v_retorno.error = 'N' THEN
                     -- esta bien el dato se carga el detalle
                     v_retorno.cantMovimientos  := v_can_movimientos;
                     v_retorno.listaMovimientos := listaMovimientos;
                  END IF;
               END IF;
            END;
         END LOOP; --end loop cuentas
         IF v_can_detalles = 0 THEN
            -- no tiene detalles
            --p_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
            PAW_UTI.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'fu_obtenerMovimientos - Cta Inexistente -' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), PAW_UTI.BITACORA_ERROR);
         END IF;
      END IF;
      -- registro del movimiento
      paw_uti.lp_reg_operacion(substr(v_nro_cta_especifica,0,15) /*p_nro_cuenta*/, NULL /*p_cod_moneda */, NULL /*p_monto*/, NULL /*p_nro_cta_contra*/, NULL /*p_cantidad*/, 'Ver Todas' /*p_etiqueta*/, v_ver_todas, /*p_dato*/ NULL, NULL, NULL, NULL, NULL, p_cod_persona, COD_OPERACION, p_cod_persona || p_cod_canal, p_cod_canal, p_identificadorsesion, p_cod_empresa);
      paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa,
            'fu_obtenerMovimientos_por_fec-' || ' cantidad de movimientos= ['|| v_retorno.cantMovimientos ||'], ' ||paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
            paw_uti.BITACORA_SALIDA);

      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_identificadorsesion, COD_OPERACION, p_cod_empresa, 'fu_obtenerMovimientos_por_fec -' || SQLERRM, PAW_UTI.BITACORA_ERROR);
         RETURN v_retorno;
   END;
  
begin
   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9; --Modulo caja
end PAW_BAS;
/
