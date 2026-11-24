CREATE OR REPLACE PROCEDURE IT.prp_gen_prt_lib_cheques
(
   p_nro_cuenta    IN ge_movimientos.nro_cuenta%TYPE,
   p_nro_boleta    IN ge_movimientos.nro_documento%TYPE,
   p_cod_retencion IN ah_retenciones.cod_retencion%TYPE,
   p_fec_fin       IN DATE
) IS
   v_sal_retenido  ah_retenciones.sal_retenido%TYPE;
   v_monto         ge_movimientos.monto%TYPE;
   v_fec_inicio    DATE;
   v_cod_persona   ba_personas.cod_persona%TYPE;
   v_cod_moneda    ge_cuentas.cod_moneda%TYPE;
   v_fec_proceso   DATE DEFAULT pag_cal.fu_obt_fec_actual(4);
   v_nro_solicitud pr_solicitudes.nro_solicitud%TYPE;
   v_cod_oficina   ba_oficinas.cod_oficina%TYPE;
   v_cod_ori_fondo pr_fondos.cod_ori_fondo%TYPE;
   v_hora          ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
   v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;
   v_nro_cuenta    ge_cuentas.nro_cuenta%TYPE;
   ---
   v_tot_prestamos NUMBER := 0;
   v_fec_final     DATE;
   v_fec_actual    DATE := pag_cal.FU_OBT_FEC_ACTUAL(3);
   v_cta_bancaria  ge_cuentas.nro_cuenta%TYPE;
   v_ofi_cta_ban   ba_oficinas.cod_oficina%TYPE;
   CURSOR c_cheques_det IS /*Detalle del AMLIBRET*/
      SELECT 'ge_cheques_det' origen, nro_cuenta, cod_retencion, nro_documento,
             to_char(nro_cheque) nro_cheque, che.cod_banco, ban.descripcion desc_banco, monto,
             lib_posterior, che.estado estado, cod_moneda, che.rowid registro,
             NULL AS cta_libradora /*CRO-JM-092014: Se agrega la cuenta libradora*/
        FROM ge_cheques_det che, ge_bancos ban
       WHERE che.cod_banco = ban.cod_banco
         AND che.liberado = 'N'
         AND 1 = 2 /*Tabla en Desuso, me aseguro que no traiga ningun registro*/
         AND che.nro_documento = p_nro_boleta
         AND che.nro_cuenta = p_nro_cuenta
         AND che.cod_retencion = p_cod_retencion
      UNION
      SELECT 'cc_che_enviados' origen, nro_cuenta, cod_retencion, nro_boleta nro_documento,
             to_char(nro_cheque), che.cod_banco, descripcion desc_banco, monto, lib_posterior,
             che.estado, cod_moneda, che.rowid registro,
             che.cta_libradora /*CRO-JM-092014: Se agrega la cuenta libradora*/
        FROM cc_che_enviados che, ge_bancos ban
       WHERE che.cod_banco = ban.cod_banco
         AND che.liberado = 'N'
         AND che.nro_boleta NOT IN (SELECT a.nro_boleta
                                      FROM lc_retenciones a
                                     WHERE a.fec_inicio >= che.fecha
                                       AND a.nro_boleta = che.nro_boleta
                                       AND a.nro_cuenta = che.nro_cuenta)
         AND che.nro_boleta = p_nro_boleta
         AND che.nro_cuenta = p_nro_cuenta
         AND che.cod_retencion = p_cod_retencion
      UNION
      SELECT 'cc_che_enviados' origen, nro_cuenta, cod_retencion, nro_boleta nro_documento,
             to_char(nro_cheque), che.cod_banco, descripcion desc_banco, monto, lib_posterior,
             che.estado, cod_moneda, che.rowid registro,
             che.cta_libradora /*CRO-JM-092014: Se agrega la cuenta libradora*/
        FROM cc_che_enviados che, ge_bancos ban
       WHERE che.cod_banco = ban.cod_banco
         AND che.liberado = 'N'
         AND che.estado != 'D'
         AND che.nro_boleta IN (SELECT a.nro_boleta
                                  FROM lc_retenciones a
                                 WHERE a.fec_inicio >= che.fecha
                                   AND a.nro_boleta = che.nro_boleta
                                   AND a.nro_cuenta = che.nro_cuenta)
         AND che.nro_boleta = p_nro_boleta
         AND che.nro_cuenta = p_nro_cuenta
         AND che.cod_retencion = p_cod_retencion
      UNION
      SELECT 'ge_che_exterior' origen, nro_cuenta, cod_retencion, nro_boleta nro_documento,
             nro_cheque, che.cod_banco, nvl(descripcion, des_banco) desc_banco, monto, lib_posterior,
             che.estado, cod_moneda, che.rowid registro,
             NULL AS cta_libradora /*CRO-JM-092014: Se agrega la cuenta libradora*/
        FROM ge_che_exterior che, ge_bancos ban
       WHERE che.cod_banco = ban.cod_banco(+)
         AND che.liberado = 'N'
         AND che.nro_boleta = p_nro_boleta
         AND che.nro_cuenta = p_nro_cuenta
         AND che.cod_retencion = p_cod_retencion;
   v_nro_cuota     pr_sol_cuotas.nro_cuota%TYPE := 0;
   v_tip_documento ba_personas.cod_tip_documento%TYPE;
   v_nro_documento ba_personas.nro_documento%TYPE;
   v_nombre        ba_personas.nom_completo%TYPE;
   v_fec_ingreso   ba_personas.fec_insercion%TYPE;
   v_nro_linea     pr_lineas.nro_linea%TYPE;
   v_tip_garantia  pr_garantias.tipo%TYPE;
   v_can_garantias NUMBER;
BEGIN
   BEGIN
      SELECT a.cod_moneda, a.sal_retenido, a.monto, a.fec_inicio, a.cod_oficina, a.fec_final
        INTO v_cod_moneda, v_sal_retenido, v_monto, v_fec_inicio, v_cod_oficina, v_fec_final
        FROM ah_retenciones a
       WHERE a.nro_cuenta = p_nro_cuenta
         AND a.nro_documento = p_nro_boleta
         AND a.cod_retencion = p_cod_retencion
         AND trunc(a.fec_final) = trunc(p_fec_fin);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Al Obt.Retencion:' || SQLERRM);
   END;
   v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
   v_cta_bancaria := fug_obt_pardinamico('CTA_LIB_ANT_CHEQUES', 4, 47, v_cod_moneda,
                                         v_cod_oficina);
   IF v_cta_bancaria IS NULL THEN
      raise_application_error(-20000, 'Cuenta Operativa de Desembolso no definida para oficina '
                                  || v_cod_oficina);
   ELSE
      BEGIN
         SELECT cod_oficina
           INTO v_ofi_cta_ban
           FROM ge_cuentas
          WHERE nro_cuenta = v_cta_bancaria;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'Cuenta Operativa de Desembolso no corresponde.');
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Obt.Cta.Operativa:' || SQLERRM);
      END;
      IF v_ofi_cta_ban <> v_cod_oficina THEN
         raise_application_error(-20000, 'Cuenta Operativa de Desembolso no pertenece a oficina '||v_cod_oficina);
      END IF;
   END IF;
   --generar solicitud de prestamo
   prp_gen_atm_solicitud(v_cod_persona, 699, v_cod_moneda, v_monto, 1 /*cuota*/, 'S', 'N',
                         v_fec_proceso, v_fec_final, NULL /*tasa*/, 28 /*canal*/, NULL /*877 campaña*/,
                         'Lib.Ant.C/O/B ' || p_nro_boleta, NULL, NULL, NULL, NULL, v_cta_bancaria,
                         v_nro_solicitud);
   BEGIN
      INSERT INTO cc_lib_ant_cheques
         (nro_cuenta, nro_documento, cod_retencion, fec_final, cod_oficina, cod_moneda, monto,
          fec_inicio, nro_sol_prestamo, estado)
      VALUES
         (p_nro_cuenta, p_nro_boleta, p_cod_retencion, trunc(p_fec_fin), v_cod_oficina,
          v_cod_moneda, v_monto, v_fec_inicio, v_nro_solicitud, 'S');
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Al Ins.CC_LIB_ANT_CHEQUES:' || SQLERRM);
   END;
      --Obtiene el nro de documento y tipo de codumento de la persona
      BEGIN
         SELECT nro_documento, cod_tip_documento, nom_completo, fec_insercion
           INTO v_nro_documento, v_tip_documento, v_nombre, v_fec_ingreso
           FROM ba_personas
          WHERE cod_persona = v_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            v_nro_documento := 1;
            v_tip_documento := 1;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Obt.Doc_Persona:' || SQLERRM);
      END;
   FOR i IN c_cheques_det LOOP
      v_nro_cuota := v_nro_cuota + 1;
      BEGIN
         INSERT INTO ge_che_custodias
            (nro_cuota, cod_banco, cta_libradora, nro_cheque, monto, fec_emision, fec_vencimiento,
             observacion, nro_referencia, estado, fec_proceso, tip_servicio, cod_moneda,
             nro_boleta)
         VALUES
            (v_nro_cuota, i.cod_banco, nvl(i.cta_libradora,p_nro_cuenta), i.nro_cheque,
             i.monto, v_fec_inicio, v_fec_final,
             'Liberacion Anticipada Cheque Cargo Otros Bancos Boleta N° ' || p_nro_boleta,
             v_nro_solicitud, 'I', v_fec_proceso, 'D', i.cod_moneda,
             p_nro_boleta);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Ins.GE_CHE_CUSTODIAS:' || SQLERRM);
      END;
      ---
      BEGIN
         INSERT INTO pr_documentos
            (documento, cod_moneda, monto, fec_emision, fec_vencimiento,
             nro_referencia, nro_cuota, estado,
             cod_tip_documento, nro_documento, nom_completo,
             observaciones)
         VALUES
            (i.nro_cheque, i.cod_moneda, i.monto, v_fec_inicio, v_fec_final,
             v_nro_solicitud, v_nro_cuota, 'I',
             v_tip_documento, v_nro_documento, v_nombre,
             'Liberacion Anticipada Cheque Cargo Otros Bancos Boleta N° ' || p_nro_boleta);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Ins.PR_DOCUMENTOS:' || SQLERRM);
      END;
      BEGIN
         INSERT INTO pr_rel_chq_lib
            (cod_banco, nro_cheque, cta_libradora, nro_documento, cod_tip_documento)
         VALUES
            (i.cod_banco, i.nro_cheque, nvl(i.cta_libradora,p_nro_cuenta),
             v_nro_documento, v_tip_documento);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Ins.PR_REL_CHQ_LIB:' || SQLERRM);
      END;
      BEGIN
         INSERT INTO pr_chq_libradores
            (nro_documento, nom_completo, fec_ingreso, cod_tip_documento)
         VALUES
            (v_nro_documento, v_nombre, v_fec_ingreso, v_tip_documento);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Ins.PR_CHQ_LIBRADORES:' || SQLERRM);
      END;
   END LOOP;
   /*
   || PCCLIANC-68
   || Para casos que no tienen detalle de cheque
   */
   IF v_nro_cuota = 0 THEN
      v_nro_cuota := v_nro_cuota + 1;
      BEGIN
         INSERT INTO ge_che_custodias
            (nro_cuota, cod_banco, cta_libradora, nro_cheque, monto, fec_emision, fec_vencimiento,
             observacion, nro_referencia, estado, fec_proceso, tip_servicio, cod_moneda,
             nro_boleta)
         VALUES
            (v_nro_cuota, 7, p_nro_cuenta, p_nro_boleta,
             v_monto, v_fec_inicio, v_fec_final,
             'Liberacion Anticipada Cheque Cargo Otros Bancos Boleta N° ' || p_nro_boleta,
             v_nro_solicitud, 'I', v_fec_proceso, 'D', v_cod_moneda,
             p_nro_boleta);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Ins.GE_CHE_CUSTODIAS:' || SQLERRM);
      END;
      ---
      BEGIN
         INSERT INTO pr_documentos
            (documento, cod_moneda, monto, fec_emision, fec_vencimiento,
             nro_referencia, nro_cuota, estado,
             cod_tip_documento, nro_documento, nom_completo,
             observaciones)
        VALUES
            (p_nro_boleta, v_cod_moneda, v_monto, v_fec_inicio, v_fec_final,
             v_nro_solicitud, v_nro_cuota, 'I',
             v_tip_documento, v_nro_documento, v_nombre,
             'Liberacion Anticipada Cheque Cargo Otros Bancos Boleta N° ' || p_nro_boleta);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Ins.PR_DOCUMENTOS:' || SQLERRM);
      END;
      BEGIN
         INSERT INTO pr_rel_chq_lib
            (cod_banco, nro_cheque, cta_libradora, nro_documento, cod_tip_documento)
         VALUES
            (7, p_nro_boleta, p_nro_cuenta,
             v_nro_documento, v_tip_documento);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Ins.PR_REL_CHQ_LIB:' || SQLERRM);
      END;
      BEGIN
         INSERT INTO pr_chq_libradores
            (nro_documento, nom_completo, fec_ingreso, cod_tip_documento)
         VALUES
            (v_nro_documento, v_nombre, v_fec_ingreso, v_tip_documento);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Ins.PR_CHQ_LIBRADORES:' || SQLERRM);
      END;
   END IF;
   /*
   || Si el cliente tiene límite de crédito para la nueva solicitud:
   || Aprobar la solicitud y Desembolsar el préstamo
   || Acreditar a su cuenta corriente el monto del préstamo
   || En caso de que no tenga, queda la solicitud pendiente de aprobación
   */
   BEGIN
      SELECT a.nro_linea
        INTO v_nro_linea
        FROM pr_lineas a
       WHERE a.estado = 'A'
         AND a.cod_persona = v_cod_persona
         AND a.fec_vencimiento >= v_fec_proceso;
   EXCEPTION
      WHEN OTHERS THEN
         v_nro_linea := NULL;
   END;
   IF v_nro_linea IS NOT NULL THEN
      BEGIN
         SELECT 'S'
           INTO v_tip_garantia
           FROM pr_lin_tip_garantias plt
          WHERE plt.nro_linea = v_nro_linea
            AND plt.cod_garantia = 1;
      EXCEPTION
         WHEN OTHERS THEN
            v_nro_linea := NULL;
      END;
      --   
      BEGIN
         SELECT COUNT(*)
           INTO v_can_garantias
           FROM pr_lin_tip_gar_mad mad
          WHERE mad.nro_linea = v_nro_linea
            AND mad.cod_garantia = 1
            AND rownum = 1;
      EXCEPTION
         WHEN OTHERS THEN
            v_can_garantias := 0;
      END;
      IF nvl(v_can_garantias,0) > 0 THEN
         BEGIN
            SELECT nvl(mad.mto_limite, 0) - nvl(mad.mto_aplicado, 0) saldo
              INTO v_tot_prestamos
              FROM pr_lin_tip_gar_mad mad
             WHERE mad.nro_linea = v_nro_linea
               AND mad.cod_garantia = 1
               AND mad.cod_modulo = 6
               AND (mad.cod_modalidad IS NULL OR mad.cod_modalidad = 699);
         EXCEPTION
            WHEN OTHERS THEN
               v_tot_prestamos := 0;
         END;
      END IF;

      IF nvl(v_tot_prestamos, 0) >= nvl(v_monto, 0) THEN
         BEGIN
            SELECT cod_ori_fondo
              INTO v_cod_ori_fondo
              FROM pr_fondos p
             WHERE p.descripcion LIKE 'FONDOS PROPIOS%'
               AND cod_moneda = v_cod_moneda;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Al Obt.Origen de Fondos:' || SQLERRM);
         END;
         UPDATE pr_solicitudes a
            SET a.nro_linea        = v_nro_linea,
                a.mto_lin_aplicado = v_monto
          WHERE a.nro_solicitud = v_nro_solicitud;
         IF SQL%NOTFOUND THEN
            raise_application_error(-20000, 'Al Actualiza Nro.Linea:' || SQLERRM);
         END IF;
         -- Desembolso de Préstamo
         -- Invocando al procedimiento existente PAP_PRE.PR_DES_PRESTAMOS
         pap_pre.pr_des_prestamos(v_nro_solicitud, v_monto, v_fec_actual, 2
                                  /*tip_documento=Vencimiento*/, 1, 1, v_cod_oficina, v_cod_ori_fondo,
                                  v_hora, v_nro_secuencia, v_nro_cuenta); --out
         prp_cob_car_liberacion(v_nro_solicitud, v_fec_actual, v_hora, v_nro_secuencia, v_cod_oficina);
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'En PRP_GEN_PRT_LIB_CHEQUES:' || SQLERRM);
END prp_gen_prt_lib_cheques;
/

