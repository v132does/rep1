CREATE OR REPLACE PACKAGE BODY IT.PAP_FAD IS
/* Insertar Validaciones. */
PROCEDURE PR_INS_VALIDACIONES (P_NRO_SOLICITUD  PR_FAD_CHE_VAL_DET.NRO_SOLICITUD%TYPE,
                               P_NRO_SECUENCIA  PR_FAD_CHE_VAL_DET.NRO_SECUENCIA%TYPE,
                               P_COD_PERSONA    PR_FAD_CHE_VAL_DET.COD_PERSONA%TYPE,
                               P_RELACION       PR_FAD_CHE_VAL_DET.RELACION%TYPE,
                               P_NRO_CUOTA      PR_FAD_CHE_VAL_DET.NRO_CUOTA%TYPE,
                               P_COD_BANCO      PR_FAD_CHE_VAL_DET.COD_BANCO%TYPE,
                               P_NRO_CHEQUE     PR_FAD_CHE_VAL_DET.NRO_CHEQUE%TYPE,
                               P_CTA_LIBRADORA  PR_FAD_CHE_VAL_DET.CTA_LIBRADORA%TYPE,
                               P_NRO_VALIDACION PR_FAD_CHE_VAL_DET.NRO_VALIDACION%TYPE,
                               P_TIP_VALIDACION PR_FAD_CHE_VAL_DET.TIP_VALIDACION%TYPE,
                               P_ABR_VALIDACION PR_FAD_CHE_VAL_DET.ABR_VALIDACION%TYPE,
                               P_OBSERVACION    PR_FAD_CHE_VAL_DET.OBSERVACION%TYPE,
                               P_AFE_LIM_CRE    VARCHAR2 DEFAULT NULL) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   INSERT INTO pr_fad_che_val_det (nro_solicitud, nro_secuencia, cod_persona, relacion,
                                   nro_cuota, cod_banco, nro_cheque, cta_libradora,
                                   nro_validacion, tip_validacion, abr_validacion, observacion, tip_afe_lim_cre)
   VALUES (p_nro_solicitud, p_nro_secuencia, p_cod_persona, p_relacion,
                                   p_nro_cuota, p_cod_banco, p_nro_cheque, p_cta_libradora,
                                   p_nro_validacion, p_tip_validacion, p_abr_validacion, p_observacion, p_afe_lim_cre);
   COMMIT;
EXCEPTION
   WHEN others THEN
      null;
END;

/* Obtener referencia de Validaci¿n. */
PROCEDURE PR_OBT_REF_VALIDACION (P_DOMINIO     IN  BA_COD_REFERENCIAS.DOMINIO%TYPE,
                                 P_VALOR       IN  BA_COD_REFERENCIAS.VAL_MINIMO%TYPE,
                                 P_TIP_VAL     OUT BA_COD_REFERENCIAS.VAL_MAXIMO%TYPE,
                                 P_VALIDACION  OUT BA_COD_REFERENCIAS.ABREVIATURA%TYPE,
                                 P_TIE_ERR_BLO IN OUT VARCHAR2) IS
BEGIN
   SELECT val_maximo, abreviatura
     INTO p_tip_val, p_validacion
     FROM ba_cod_referencias
    WHERE dominio    = p_dominio
      AND val_minimo = p_valor;
   IF p_tip_val = 'B' THEN
      p_tie_err_blo := 'S';
   END IF;
EXCEPTION
   WHEN others THEN
      p_tip_val     := 'B';
      p_validacion  := 'VAL_FAD_SIN_REF';
      p_tie_err_blo := 'S';
END;

/* Obtener faja del cliente. */
FUNCTION FU_OBT_FAJ_INFORMCONF (P_COD_PERSONA IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE ) RETURN VARCHAR2 IS
   v_faj_buro ge_cli_antecedentes.faj_buro%type;
BEGIN
   SELECT faj_buro
     INTO v_faj_buro
     FROM ge_cli_antecedentes a
    WHERE a.cod_persona = p_cod_persona;

   RETURN v_faj_buro;
EXCEPTION
   WHEN others THEN
      v_faj_buro := null;
      RETURN v_faj_buro;
END;

/* Obtener Situaci¿n Infocheck del Cliente. */
FUNCTION FU_OBT_SIT_INFOCHECK (P_COD_PERSONA IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE ) RETURN VARCHAR2 IS
   v_sit_infocheck ge_cli_antecedentes.sit_infocheck%type;
BEGIN
   SELECT sit_infocheck
     INTO v_sit_infocheck
     FROM ge_cli_antecedentes a
    WHERE a.cod_persona = p_cod_persona;

   RETURN v_sit_infocheck;
EXCEPTION
   WHEN others THEN
      v_sit_infocheck := null;
      RETURN v_sit_infocheck;
END;

/* Obtener Saldo L¿nea de Cr¿dito del Cliente. */
FUNCTION FU_OBT_CLI_LIN_CREDITO (P_COD_PERSONA   IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                                 P_COD_MONEDA    IN PR_FAD_SOLICITUDES.COD_MONEDA%TYPE,
                                 P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE default null,
                                 P_TIPO          IN VARCHAR2 default null) RETURN VARCHAR2 IS -- A=Asignado; S=Saldo
   v_cod_moneda      pr_lineas.cod_moneda%type;
   v_sal_linea       pr_lin_tip_gar_mad.mto_limite%type;
   v_sal_lin_destino pr_lin_tip_gar_mad.mto_limite%type;
   v_cotizacion      ge_cotizaciones.val_conversion%type := null;
BEGIN
   IF P_COD_MODALIDAD is null THEN
      BEGIN
         SELECT a.monto - a.mto_aplicado, cod_moneda
           INTO v_sal_linea, v_cod_moneda
           FROM pr_lineas a
          WHERE a.estado='A' AND a.cod_persona=p_cod_persona;
      EXCEPTION
         WHEN others THEN
            v_sal_linea  := 0;
            v_cod_moneda := null;
      END;
   ELSE
      IF nvl(p_tipo, 'A') = 'A' THEN
         BEGIN
            SELECT max(b.mto_limite) mto_limite, cod_moneda
              INTO v_sal_linea, v_cod_moneda
              FROM pr_lineas a, pr_lin_tip_gar_mad b
             WHERE a.nro_linea=b.nro_linea
               AND a.estado='A' AND a.cod_persona=p_cod_persona AND b.cod_modalidad=p_cod_modalidad
             GROUP BY cod_moneda;
         EXCEPTION
            WHEN others THEN
               v_sal_linea  := 0;
               v_cod_moneda := null;
         END;
      ELSIF nvl(p_tipo, 'A') = 'S' THEN
         BEGIN
            SELECT max(nvl(b.mto_limite, 0) - nvl(b.mto_aplicado, 0) ) mto_limite, cod_moneda
              INTO v_sal_linea, v_cod_moneda
              FROM pr_lineas a, pr_lin_tip_gar_mad b
             WHERE a.nro_linea=b.nro_linea
               AND a.estado='A' AND a.cod_persona=p_cod_persona AND b.cod_modalidad=p_cod_modalidad
             GROUP BY cod_moneda;
         EXCEPTION
            WHEN others THEN
               v_sal_linea  := 0;
               v_cod_moneda := null;
         END;
      END IF;
   END IF;
   IF v_sal_linea <= 0 THEN
      v_sal_lin_destino := 0;
   ELSE
      IF v_cod_moneda = p_cod_moneda THEN
         v_sal_lin_destino := v_sal_linea;
      ELSE
         pag_gen.pr_con_mon_a_moneda(v_cod_moneda, p_cod_moneda, v_sal_linea, v_sal_lin_destino,
                                     v_cotizacion, v_cotizacion);
      END IF;
   END IF;

   RETURN v_sal_lin_destino;
EXCEPTION
   WHEN others THEN
      v_sal_lin_destino := 0;
      RETURN v_sal_lin_destino;
END;

/* Obtener Concentraci¿n del Librador por Operaci¿n. */
FUNCTION FU_OBT_CONCENTRACION (P_NRO_SOLICITUD     IN PR_FAD_REL_CHE_LIB.NRO_SOLICITUD%TYPE,
                               P_COD_TIP_DOCUMENTO IN PR_FAD_REL_CHE_LIB.COD_TIP_DOCUMENTO%TYPE,
                               P_NRO_DOCUMENTO     IN PR_FAD_REL_CHE_LIB.NRO_DOCUMENTO%TYPE) RETURN NUMBER IS
   v_cod_moneda       pr_fad_solicitudes.cod_moneda%type;
   v_cod_persona      pr_fad_solicitudes.cod_persona%type;
   v_tot_operacion    pr_fad_solicitudes.monto%type;
   v_sum_che_librador number;
   v_sal_linea        number;
   v_mto_concen       number;
   v_can_cheques      number;
   v_can_che_min      number := to_number(nvl(fug_obt_pardinamico('FAD_MIN_CHE_CONCENTRACION'), 0));
BEGIN
   -- Moneda y Monto de la Operacion
   SELECT a.cod_moneda, cod_persona, sum(b.monto), nvl(count(1), 0)
     INTO v_cod_moneda, v_cod_persona, v_tot_operacion, v_can_cheques
     FROM pr_fad_solicitudes a, pr_fad_che_custodias b
    WHERE a.nro_solicitud=b.nro_solicitud
      AND b.estado='V' -- Solo Cheques en estado Valido
      AND a.nro_solicitud = p_nro_solicitud
    GROUP BY a.cod_moneda, a.monto, cod_persona;

   -- Si ya supera el m¿nimo que no siga contando.
   IF v_can_cheques < v_can_che_min THEN
      SELECT nvl(count(1), 0) + v_can_cheques
        INTO v_can_cheques
        FROM pr_fad_che_custodias a, pr_fad_solicitudes c
       WHERE a.nro_solicitud = c.nro_solicitud
         AND a.estado = 'V' -- Solo Cheques en estado Valido
         AND c.estado not in ('C', 'D') -- Excluir las solicitudes Canceladas y Descontadas
         AND a.nro_solicitud <> p_nro_solicitud
         AND c.cod_persona = v_cod_persona
         AND EXISTS (SELECT 1 FROM pr_fad_rel_che_lib b
                      WHERE b.nro_solicitud=a.nro_solicitud
                        AND b.nro_cuota=a.nro_cuota
                        AND b.cod_tip_documento = p_cod_tip_documento
                        AND b.nro_documento = p_nro_documento);

      SELECT nvl(count(1), 0) + v_can_cheques
        INTO v_can_cheques
        FROM pr_cta_prestamos pr, pr_cuotas cu
       WHERE pr.nro_cuenta=cu.nro_cuenta
         AND fug_obt_cli_principal(pr.nro_cuenta) = v_cod_persona
         AND pr.estado not in ('N', 'I') AND cu.nro_cuota>0
         AND EXISTS (SELECT 1 FROM pr_rel_chq_lib rl, ge_che_custodias ch
                      WHERE pr.nro_cuenta=ch.nro_referencia
                        AND ch.estado in ('C','I','A')
                        AND ch.cod_banco=rl.cod_banco AND ch.nro_cheque=rl.nro_cheque AND ch.cta_libradora=rl.cta_libradora
                        AND rl.cod_tip_documento = p_cod_tip_documento
                        AND rl.nro_documento = p_nro_documento);
   END IF;

   -- El control de concentraci¿n se realiza solo si superan 5 (FAD_MIN_CHE_CONCENTRACION) cheques
   IF v_can_cheques >= v_can_che_min THEN
      -- Linea de Cr¿dito del Cliente
      v_sal_linea := fu_obt_cli_lin_credito(v_cod_persona, v_cod_moneda, 608);

      -- Sumatoria de cheques del Librador
      SELECT nvl(sum(a.monto), 0)
        INTO v_sum_che_librador
        FROM pr_fad_che_custodias a, pr_fad_rel_che_lib b
       WHERE a.nro_solicitud=b.nro_solicitud AND a.nro_cuota=b.nro_cuota
         AND a.cod_banco=b.cod_banco AND a.nro_cheque=b.nro_cheque AND a.cta_libradora=b.cta_libradora
         AND a.estado = 'V' -- Solo Cheques en estado Valido
         AND b.cod_tip_documento = p_cod_tip_documento
         AND b.nro_documento = p_nro_documento
         AND a.nro_solicitud = p_nro_solicitud;

      -- Sumatoria de cheques del Librador, en otras solicitudes del mismo deudor.
      SELECT nvl(sum(pag_gen.FU_CON_MON_A_MONEDA(c.cod_moneda, v_cod_moneda, a.monto)), 0) + v_sum_che_librador
        INTO v_sum_che_librador
        FROM pr_fad_che_custodias a, pr_fad_rel_che_lib b, pr_fad_solicitudes c
       WHERE a.nro_solicitud=b.nro_solicitud AND a.nro_cuota=b.nro_cuota
         AND a.cod_banco=b.cod_banco AND a.nro_cheque=b.nro_cheque AND a.cta_libradora=b.cta_libradora
         AND a.estado = 'V' -- Solo Cheques en estado Valido
         AND c.estado not in ('C', 'D') -- Excluir las solicitudes Canceladas y Descontadas
         AND c.nro_solicitud = a.nro_solicitud
         AND b.cod_tip_documento = p_cod_tip_documento
         AND b.nro_documento = p_nro_documento
         AND a.nro_solicitud <> p_nro_solicitud
         AND c.cod_persona = v_cod_persona;

      -- Sumatoria de cheques del Librador, en Prestamos del mismo deudor
      SELECT nvl(sum(pag_gen.FU_CON_MON_A_MONEDA(pr.cod_moneda, v_cod_moneda, ch.monto)), 0) + v_sum_che_librador
        INTO v_sum_che_librador
        FROM pr_cta_prestamos pr, pr_cuotas cu, ge_che_custodias ch, pr_rel_chq_lib rl
       WHERE pr.nro_cuenta=cu.nro_cuenta
         AND pr.nro_cuenta=ch.nro_referencia
         AND cu.nro_cuota=ch.nro_cuota
         AND ch.estado in ('C','I','A')
         AND ch.cod_banco=rl.cod_banco AND ch.nro_cheque=rl.nro_cheque AND ch.cta_libradora=rl.cta_libradora
         AND fug_obt_cli_principal(pr.nro_cuenta) = v_cod_persona
         AND pr.estado not in ('N', 'I')
         AND rl.cod_tip_documento = p_cod_tip_documento
         AND rl.nro_documento = p_nro_documento;

      IF v_sal_linea > 0 THEN
         v_mto_concen := round(v_sum_che_librador / v_sal_linea * 100, 0);
      ELSIF v_tot_operacion > 0 THEN
         v_mto_concen := round(v_sum_che_librador / v_tot_operacion * 100, 0);
      ELSE
         v_mto_concen := 0;
      END IF;
   ELSE
      v_mto_concen := 0;
   END IF;

   RETURN v_mto_concen;
EXCEPTION
   WHEN others THEN
      RETURN 0;
END;

/* Verificar cheques cruzados entre Deudor y Librador. */
FUNCTION FU_VER_CHE_CRUZADOS (P_COD_PER_DEUDOR IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                              P_COD_PER_LIB IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                              P_TIP_DOC_LIB IN PR_CHQ_LIBRADORES.COD_TIP_DOCUMENTO%TYPE,
                              P_NRO_DOC_LIB IN PR_CHQ_LIBRADORES.NRO_DOCUMENTO%TYPE,
                              P_TIPO        IN VARCHAR2,
                              P_CUENTAS IN OUT VARCHAR2) RETURN NUMBER IS
   v_tip_doc_deu ba_personas.cod_tip_documento%type;
   v_nro_doc_deu ba_personas.nro_documento%type;
   v_can_operaciones number(3);
   v_cuentas         varchar2(100);

   CURSOR ope_anterior IS
      SELECT pr.nro_cuenta, cc.cod_persona cod_per_deudor, li.cod_persona cod_per_lib, li.cod_tip_documento, li.nro_documento
        FROM pr_cta_prestamos pr, ge_cta_clientes cc, pr_cuotas cu, ba_personas pe,
             ge_che_custodias ch, pr_rel_chq_lib lc, pr_chq_libradores li
       WHERE pr.nro_cuenta=cc.nro_cuenta AND cc.relacion='P' AND pr.nro_cuenta=cu.nro_cuenta
         AND cc.cod_persona=pe.cod_persona
         AND ch.nro_referencia=pr.nro_cuenta AND ch.nro_cuota=cu.nro_cuota AND cu.nro_cuota>0
         AND ch.cod_banco=lc.cod_banco AND ch.nro_cheque=lc.nro_cheque AND ch.cta_libradora=lc.cta_libradora
         AND lc.cod_tip_documento=li.cod_tip_documento AND lc.nro_documento=li.nro_documento
         AND ((p_tipo = 'S' AND pr.fec_inicio >= sysdate -180)
          OR  (p_tipo = 'T' AND pr.fec_inicio < sysdate -180))
         -- Titular de la Op. existente = Librador
         AND ( ( pe.cod_persona = p_cod_per_lib AND p_cod_per_lib is not null)
          OR   ( pe.cod_tip_documento = p_tip_doc_lib AND pe.nro_documento = p_nro_doc_lib) )
         -- Librador de la Op. existente = Deudor
         AND ( ( li.cod_persona = p_cod_per_deudor and li.cod_persona is not null)
          OR   ( li.cod_tip_documento = v_tip_doc_deu and li.nro_documento = v_nro_doc_deu) );
BEGIN
   BEGIN
      SELECT cod_tip_documento, nro_documento
        INTO v_tip_doc_deu, v_nro_doc_deu
        FROM ba_personas
       WHERE cod_persona = p_cod_per_deudor;
   EXCEPTION
      WHEN others THEN
         v_tip_doc_deu := null;
         v_nro_doc_deu := null;
   END;
   v_can_operaciones := 0;
   FOR rant IN ope_anterior LOOP
      v_can_operaciones := v_can_operaciones + 1;
      IF v_cuentas is null THEN
         v_cuentas := rant.nro_cuenta;
      ELSE
         IF length(v_cuentas||','||rant.nro_cuenta) < 50 THEN
            v_cuentas := v_cuentas||','||rant.nro_cuenta;
         END IF;
      END IF;
   END LOOP;
   p_cuentas := v_cuentas;
   RETURN v_can_operaciones;
EXCEPTION
   WHEN others THEN
      v_can_operaciones := 0;
      RETURN v_can_operaciones;
END;

/*Eliminar las validaciones anteriores*/
PROCEDURE PR_ELI_VAL_SOLICITUD (P_NRO_SOLICITUD IN PR_FAD_CHE_CUSTODIAS.NRO_SOLICITUD%TYPE) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   DELETE pr_fad_che_val_det WHERE nro_solicitud = p_nro_solicitud;
   COMMIT;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20061, 'Error al eliminar validaciones anteriores. Solicitud Nro= '||p_nro_solicitud||' - '||SQLERRM);
END;

/*Validar si Librador debe consultar Informconf e Infocheck*/
FUNCTION FU_VAL_LIB_CONSULTA (P_NRO_SOLICITUD IN PR_FAD_CHE_CUSTODIAS.NRO_SOLICITUD%TYPE,
                              P_COD_TIP_DOC   IN PR_CHQ_LIBRADORES.COD_TIP_DOCUMENTO%TYPE,
                              P_NRO_DOCUMENTO IN PR_CHQ_LIBRADORES.NRO_DOCUMENTO%TYPE) RETURN VARCHAR2 IS

  v_mon_local    ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_cod_moneda   ba_monedas.cod_moneda%type;
  v_cod_per_deu  pr_fad_solicitudes.cod_persona%type;
  v_fec_actual   ge_calendarios.fec_actual%type := pae_cnf.fu_obt_fec_actual(6);
  v_redondeo     number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,null,v_mon_local,null);
  v_acu_mto_ml   number(18,2) := 0;
  v_deu_lin_cred number(18,2) := 0;
  v_tot_ope      number(18,2) := 0;

  CURSOR mto_chq IS
     SELECT a.cod_moneda, a.monto
       FROM pr_fad_che_custodias a, pr_fad_rel_che_lib b
      WHERE a.nro_solicitud=b.nro_solicitud AND a.nro_cuota=b.nro_cuota
        AND a.cod_banco=b.cod_banco and a.nro_cheque=b.nro_cheque and a.cta_libradora=b.cta_libradora
        AND a.nro_solicitud=p_nro_solicitud
        AND b.cod_tip_documento=p_cod_tip_doc AND b.nro_documento=p_nro_documento
     -- Se comenta a pedido del usuario. Solo debe considerar los cheques de la partida en cuesti¿n. DYDMR-10145
     /*UNION ALL
     SELECT a.cod_moneda, a.monto
       FROM pr_fad_che_custodias a, pr_fad_rel_che_lib b, pr_fad_solicitudes d
      WHERE a.nro_solicitud=b.nro_solicitud AND a.nro_cuota=b.nro_cuota
        AND a.cod_banco=b.cod_banco AND a.nro_cheque=b.nro_cheque AND a.cta_libradora=b.cta_libradora
        AND a.nro_solicitud=d.nro_solicitud
        AND d.estado not in ('C', 'D') AND a.estado='V'
        AND d.nro_solicitud <> p_nro_solicitud
        AND d.cod_persona = v_cod_per_deu
        AND b.cod_tip_documento=p_cod_tip_doc AND b.nro_documento=p_nro_documento
     UNION ALL
     SELECT pr.cod_moneda, ch.monto
       FROM pr_cta_prestamos pr, pr_cuotas cu, ge_che_custodias ch, pr_rel_chq_lib rl
      WHERE pr.nro_cuenta=cu.nro_cuenta
        AND pr.nro_cuenta=ch.nro_referencia
        AND cu.nro_cuota=ch.nro_cuota
        AND ch.estado in ('C','I','A')
        AND ch.cod_banco=rl.cod_banco AND ch.nro_cheque=rl.nro_cheque AND ch.cta_libradora=rl.cta_libradora
        AND fug_obt_cli_principal(pr.nro_cuenta) = v_cod_per_deu
        AND pr.estado not in ('N', 'I')
        AND rl.cod_tip_documento = p_cod_tip_doc
        AND rl.nro_documento = p_nro_documento*/;
BEGIN
  -- Obtener el cod_persona y la sumatoria de cheques v¿lidos hasta el momento.
  BEGIN
     SELECT cod_persona, cod_moneda,
           (SELECT nvl(sum(a.monto), 0) FROM pr_fad_che_custodias a
             WHERE a.nro_solicitud=s.nro_solicitud AND a.estado='V')
       INTO v_cod_per_deu, v_cod_moneda, v_tot_ope
       FROM pr_fad_solicitudes s
      WHERE nro_solicitud = p_nro_solicitud;
  EXCEPTION
     WHEN others THEN
        v_cod_per_deu := null;
  END;

  FOR rch IN mto_chq LOOP
     IF rch.cod_moneda = v_mon_local THEN
        v_acu_mto_ml := v_acu_mto_ml + rch.monto;
     ELSE
        v_acu_mto_ml := v_acu_mto_ml + round(rch.monto *
                                     pag_gen.fu_obt_cotizacion(rch.cod_moneda, v_fec_actual), v_redondeo);
     END IF;
  END LOOP;

  -- Obtener Saldo de L¿nea de Cr¿dito del Deudor.
  IF v_cod_per_deu is not null THEN
     v_deu_lin_cred := fu_obt_cli_lin_credito(v_cod_per_deu, v_cod_moneda, 61);
  ELSE
     v_deu_lin_cred := 0;
  END IF;

  IF v_deu_lin_cred > v_tot_ope THEN
     IF v_acu_mto_ml > to_number(fug_obt_pardinamico('FAD_MTO_MIN_VAL_INF')) THEN
        RETURN 'S';
     ELSE
        RETURN 'N';
     END IF;
  ELSE
     RETURN 'S';
  END IF;
END;

/* Obtener Informaci¿n Antecedentes - Informconf  */
FUNCTION FU_OBT_ANT_INFORMCONF (P_COD_PERSONA  IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                                P_COD_TIP_SERV IN NUMBER ) RETURN NUMBER IS
   v_can_no_finiquitadas number(20);
BEGIN
   /*Referencia: PAR_SER_INFORMCONF*/
   -- convocatorias
   IF p_cod_tip_serv = 2 THEN
      SELECT nvl(t.can_no_finiquitadas, 0)
        INTO v_can_no_finiquitadas
        FROM ge_eqf_convocatorias_res t
       WHERE t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_convocatorias_res a
                               where a.cod_persona=p_cod_persona);
   -- demandas
   ELSIF p_cod_tip_serv = 3 THEN
      SELECT nvl(t.can_no_finiquitadas, 0)
        INTO v_can_no_finiquitadas
        FROM ge_eqf_demandas_res t
       WHERE t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_demandas_res a
                               where a.cod_persona=p_cod_persona);
   -- cuentasInhabilitadas
   ELSIF p_cod_tip_serv = 4 THEN
      SELECT nvl(t.can_total, 0)
        INTO v_can_no_finiquitadas
        FROM ge_eqf_inhabilitaciones_res t
       WHERE t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_inhabilitaciones_res a
                               where a.cod_persona=p_cod_persona);
   -- inhibiciones
   ELSIF p_cod_tip_serv = 5 THEN
      SELECT nvl(t.can_no_finiquitadas, 0)
        INTO v_can_no_finiquitadas
        FROM ge_eqf_inhibiciones_res t
       WHERE t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_inhibiciones_res a
                               where a.cod_persona=p_cod_persona);
   -- morosidadesAdefi
   ELSIF p_cod_tip_serv = 6 THEN
      SELECT nvl(t.cantidad, 0)
        INTO v_can_no_finiquitadas
        FROM ge_eqf_mor_act_adefi t
       WHERE t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_mor_act_adefi a
                               where a.cod_persona=p_cod_persona);
   -- morosidades
   ELSIF p_cod_tip_serv = 7 THEN
      SELECT nvl(t.cantidad, 0)
        INTO v_can_no_finiquitadas
        FROM ge_eqf_mor_actividades t
       WHERE t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_mor_actividades a
                               where a.cod_persona=p_cod_persona);
   -- remates
   ELSIF p_cod_tip_serv = 8 THEN
      SELECT nvl(t.can_no_finiquitadas, 0)
        INTO v_can_no_finiquitadas
        FROM ge_eqf_remates_res t
       WHERE t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_remates_res a
                               where a.cod_persona=p_cod_persona);
   -- quiebras
   ELSIF p_cod_tip_serv = 10 THEN
      SELECT nvl(t.can_no_finiquitadas, 0)
        INTO v_can_no_finiquitadas
        FROM ge_eqf_quiebras_res t
       WHERE t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_quiebras_res a
                               where a.cod_persona=p_cod_persona);
   END IF;

   RETURN v_can_no_finiquitadas;
EXCEPTION
   WHEN others THEN
      v_can_no_finiquitadas := 0;
      RETURN v_can_no_finiquitadas;
END;

/* Obtener Informaci¿n Antecedentes - Infocheck  */
FUNCTION FU_OBT_ANT_INFOCHECK (P_COD_PERSONA   IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                               P_COD_TIP_SERV  IN VARCHAR2,
                               P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE DEFAULT NULL ) RETURN NUMBER IS
   v_return number(20);
BEGIN
   IF p_cod_tip_serv = '1' THEN
      SELECT count(*)
        INTO v_return
        FROM ge_eqf_chk_cheques t
       WHERE t.cod_mot_rechazo = 201
         AND to_date(t.fec_rechazo,'dd/mm/yyyy') >= add_months(sysdate,-12) 
         AND t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_chk_cheques a
                               where a.cod_persona=p_cod_persona);
   ELSIF p_cod_tip_serv = '2' THEN
      SELECT count(*)
        INTO v_return
        FROM ge_eqf_chk_inhabilitaciones t
       WHERE to_date(t.fec_inhabilitacion,'dd/mm/yyyy') >= add_months(sysdate,-12) 
         AND t.nro_solicitud=(select max(a.nro_solicitud) from ge_eqf_chk_inhabilitaciones a
                               where a.cod_persona=p_cod_persona);
   END IF;
   
   IF p_nro_solicitud is not null THEN
      /*P_COD_TIP_SERV: CON-Consultas, INH-inhabilitaciones, CHR-Chq rechazados*/
      IF p_cod_tip_serv = 'CON' THEN
         BEGIN
            SELECT COUNT(*) 
             INTO v_return
             FROM ge_eqf_chk_consultas
            WHERE nro_solicitud=p_nro_solicitud;
         EXCEPTION
            WHEN others THEN
               v_return := 0;
         END;
      ELSIF p_cod_tip_serv in ('BAJA','MEDIA','GRAVE') THEN
         BEGIN
            SELECT COUNT(*) 
             INTO v_return
             FROM ge_eqf_chk_inhabilitaciones
            WHERE nro_solicitud=p_nro_solicitud
              AND upper(falta) = p_cod_tip_serv;
         EXCEPTION
            WHEN others THEN
               v_return := 0;
         END;
      ELSIF p_cod_tip_serv in ('RECHAZADO','RECHAZADO_HISTORICO','ANULADO') THEN
         BEGIN
            SELECT COUNT(*) 
             INTO v_return
             FROM ge_eqf_chk_cheques a
            WHERE nro_solicitud=p_nro_solicitud
              AND upper(a.tip_cheque) = p_cod_tip_serv;
         EXCEPTION
            WHEN others THEN
               v_return := 0;
         END;
      END IF;
   END IF;

   RETURN v_return;
EXCEPTION
   WHEN others THEN
      v_return := 0;
      RETURN v_return;
END;

/* Procedimiento principal de Validaci¿n de la Operaci¿n. */
PROCEDURE PR_VAL_OPERACION (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE,
                            P_ERROR         IN OUT NUMBER,
                            P_DES_ERROR     IN OUT VARCHAR2) IS

   v_tip_validacion     pr_fad_che_val_det.tip_validacion%type;
   v_abr_validacion     pr_fad_che_val_det.abr_validacion%type;
   v_observacion        pr_fad_che_val_det.observacion%type;
   v_cat_sistema        ge_clientes.cat_sistema%type;
   v_cat_bbva           ge_clientes.cat_automatica%type;
   v_sal_linea          pr_lin_tip_gar_mad.mto_limite%type;
   v_fec_actual         ge_calendarios.fec_actual%type := pae_cnf.fu_obt_fec_actual(6);
   v_fec_con_informconf ge_cli_antecedentes.fec_ult_informconf%type;
   v_faj_buro           ge_cli_antecedentes.faj_buro%type;
   v_fec_con_infocheck  ge_cli_antecedentes.fec_ult_infocheck%type;
   v_sit_infocheck      ge_cli_antecedentes.sit_infocheck%type;
   v_cod_persona        ba_personas.cod_persona%type;
   v_nro_solicitud      pr_fad_solicitudes.nro_solicitud%type;
   v_des_vinculo        ba_tip_vinculos.descripcion%type;
   v_tip_per_lib        ba_personas.tipo%type;
   v_cod_banco          ge_bancos.cod_banco%type := fug_obt_cod_banco;
   v_fec_nacimiento     ba_per_fisicas.fec_nacimiento%type;
   v_nro_documento      ba_personas.nro_documento%type;

   v_concentracion      number;
   v_dia_atraso         number;
   v_can_operaciones    number;
   v_sum_che_librador   number;
   v_nro_validacion     number(5);
   v_val_secuencia      number(5) := 1;
   v_val_che            number(7) := 0;
   v_tot_che_validos    number(18):= 0;
   v_tot_che_val_pcp    number(18):= 0;
   v_est_cheques			  varchar2(1);
   v_sol_tie_error      varchar2(1);
   v_con_informconf     varchar2(1) := 'S';
   v_con_infocheck      varchar2(1) := 'S';
   v_che_tie_error      varchar2(1) := 'N';
   v_activo             varchar2(1) := 'N';
   v_referencia         varchar2(30);
   v_err_informcomf     varchar2(4000);
   v_err_infocheck      varchar2(4000);
   v_cuentas            varchar2(100);
   v_err_cheques			  varchar2(4000);

   v_dias 		          number(5) := fug_obt_pardinamico('DIA_DES_CHEQUES');
	 v_min_dias           number(5) := fug_obt_pardinamico('DIA_MIN_DES_CHEQUES');
   v_dia_atr_deudor     number(5) := fug_obt_pardinamico('FAD_DIA_ATR_DEUDOR');
   v_dia_atr_librador   number(5) := fug_obt_pardinamico('FAD_DIA_ATR_LIBRADOR');
   v_fec_vig_inf        number(5) := to_number(fug_obt_pardinamico('FAD_VIG_INF_COMERCIALES'));
   v_val_dominio        varchar2(40) := 'FAD_TIP_VALIDACION';

   CURSOR c_solicitud IS
      SELECT a.nro_solicitud, a.cod_persona, a.cod_oficina, a.cod_modalidad, a.cod_moneda, a.monto,
             b.tipo tip_persona, a.ind_lin_credito
        FROM pr_fad_solicitudes a, ba_personas b
       WHERE a.cod_persona = b.cod_persona
         AND nro_solicitud = p_nro_solicitud;

   CURSOR c_cheques IS
      SELECT a.nro_solicitud, a.nro_cuota, a.cod_banco, a.nro_cheque, a.cta_libradora, a.cod_moneda,
             a.monto, a.fec_emision, a.fec_vencimiento, b.cod_tip_documento, b.nro_documento, b.relacion,
             a.estado, decode(a.estado, 'V', 'N', 'S') tie_err_blo, c.cod_persona cod_per_lib, a.tip_afe_lim_cre
        FROM pr_fad_che_custodias a, pr_fad_rel_che_lib b, pr_chq_libradores c
       WHERE a.nro_solicitud=b.nro_solicitud AND a.nro_cuota=b.nro_cuota
         AND a.cod_banco=b.cod_banco AND a.nro_cheque=b.nro_cheque AND a.cta_libradora=b.cta_libradora
         AND b.cod_tip_documento=c.cod_tip_documento AND b.nro_documento=c.nro_documento AND b.relacion = 'L'
         AND a.nro_solicitud = p_nro_solicitud
       ORDER BY b.cod_tip_documento, b.nro_documento, b.cod_banco, b.cta_libradora, b.nro_cheque; -- Por Corte de Control

   /*Actualizar el estado (Con error o Validado) de la Solicitud*/
   PROCEDURE LP_ACT_EST_SOLICITUD (P_NRO_SOLICITUD IN PR_FAD_CHE_CUSTODIAS.NRO_SOLICITUD%TYPE,
                                   P_TIE_ERR_BLO   IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      UPDATE pr_fad_solicitudes
         SET estado = decode(p_tie_err_blo, 'N', 'V', 'E')
       WHERE nro_solicitud = p_nro_solicitud;
       COMMIT;
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20051, 'Error al act. Estado de la Solicitud Nro= '||p_nro_solicitud||' - '||SQLERRM);
   END;

   /*Actualizar el estado (Con error o Validado) del Cheque*/
   PROCEDURE LP_ACT_EST_CHEQUE (P_NRO_SOLICITUD IN PR_FAD_CHE_CUSTODIAS.NRO_SOLICITUD%TYPE,
                                P_NRO_CUOTA     IN PR_FAD_CHE_CUSTODIAS.NRO_CUOTA%TYPE,
                                P_COD_BANCO     IN PR_FAD_CHE_CUSTODIAS.COD_BANCO%TYPE,
                                P_NRO_CHEQUE    IN PR_FAD_CHE_CUSTODIAS.NRO_CHEQUE%TYPE,
                                P_CTA_LIBRADORA IN PR_FAD_CHE_CUSTODIAS.CTA_LIBRADORA%TYPE,
                                P_TIE_ERR_BLO   IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      UPDATE pr_fad_che_custodias
         SET estado = decode(p_tie_err_blo, 'N', 'V', 'E')
       WHERE nro_solicitud = p_nro_solicitud
         AND nro_cuota = p_nro_cuota
         AND nro_cheque = p_nro_cheque
         AND cod_banco = p_cod_banco
         AND cta_libradora = p_cta_libradora;
       COMMIT;
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20051, 'Error al act. Estado del Cheque Nro= '||p_nro_cheque||' - '||SQLERRM);
   END;

   /*Actualizar de personas_ref datos del Librador*/
   FUNCTION LF_ACT_DAT_LIBRADOR (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN DATE IS

      v_fec_nacimiento ba_per_fisicas.fec_nacimiento%type;
      v_nombre         personas_ref.rf_nombre%type;
      v_apellido       personas_ref.rf_apellido%type;

      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      BEGIN
         SELECT r.rf_fecha_nac, r.rf_nombre, r.rf_apellido
           INTO v_fec_nacimiento, v_nombre, v_apellido
           FROM personas_ref r, ba_personas p
          WHERE r.rf_tipo_ident = fue_obt_tip_doc_abreviatura(p.cod_tip_documento)
            AND r.rf_numero = p.nro_documento
            AND p.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN others THEN
            v_fec_nacimiento := null;
            v_nombre         := null;
            v_apellido       := null;
      END;
      IF v_fec_nacimiento is not null OR v_nombre is not null OR v_apellido is not null THEN
         UPDATE ba_per_fisicas
            SET fec_nacimiento = nvl(v_fec_nacimiento, fec_nacimiento),
                pri_nombre     = nvl(trim(fug_obt_nombre(v_nombre,1)), pri_nombre),
                seg_nombre     = nvl(trim(fug_obt_nombre(v_nombre,2)), seg_nombre),
                pri_apellido   = nvl(trim(fug_obt_nombre(v_apellido,1)), pri_apellido ),
                seg_apellido   = nvl(trim(fug_obt_nombre(v_apellido,2)), seg_apellido )
          WHERE cod_persona = p_cod_persona;
      END IF;
      COMMIT;
      RETURN v_fec_nacimiento;
   END;
   
   /*Verificar Inhibiciones del Librador*/
   FUNCTION LF_VER_INHIBICION (P_COD_PERSONA IN GE_CTA_CLIENTES.COD_PERSONA%TYPE,
                               P_IND_EXCLUIR IN VARCHAR2 ) RETURN VARCHAR2 IS
      v_return varchar2(1);
      v_cod_cau_excluir number(5) := 9999;
   BEGIN
      IF p_ind_excluir = 'S' THEN
         v_cod_cau_excluir := to_number(fug_obt_pardinamico('FAD_COD_CAU_EXC_INH'));
      END IF;
      SELECT decode(count(*),0,'N','S')
        INTO v_return
        FROM ge_per_inhibidas a
       WHERE cod_persona = p_cod_persona
         AND fug_obt_parcausales(a.cod_causa, 'AFE_CREDITOS') = 'S'
         AND a.cod_causa <> v_cod_cau_excluir
         AND estado = 'I';
      RETURN (v_return);
   EXCEPTION
      WHEN others THEN
         IF sqlcode = -20000 THEN
            SELECT decode(count(*),0,'N','S')
              INTO v_return
              FROM ge_per_inhibidas a
             WHERE cod_persona = p_cod_persona
               AND a.cod_causa <> v_cod_cau_excluir
               AND estado = 'I';
            RETURN (v_return);
         ELSE
            raise_application_error(-20000,'LF_VER_INHIBICION '||sqlerrm);
         END IF;
   END;

BEGIN
   FOR rsol IN c_solicitud LOOP
      v_nro_solicitud   := rsol.nro_solicitud;
      v_sol_tie_error   := 'N';
      v_tot_che_validos := 0;
      v_tot_che_val_pcp := 0;
      -- Eliminar todos los registros de validaciones anteriores
      pr_eli_val_solicitud(rsol.nro_solicitud);

      --** Cada nro corresponde al val_minimo de la referencia: FAD_TIP_VALIDACION**--
      --** Desde 1 p/ Clientes. Desde 100 p/ Libradores

      --** 1 Inhibici¿n **--
      IF fug_ver_inhibicion(rsol.cod_persona, nvl(rsol.cod_modalidad, 608)) = 'S' THEN
         v_nro_validacion := 1;
         pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                               v_abr_validacion, v_sol_tie_error);
         v_observacion := 'Cliente posee inhibici¿n';
         v_val_secuencia := v_val_secuencia + 1;
         pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                             v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
      END IF;

      --** 2 Atrasos **--
      v_dia_atraso := fug_obt_atraso(rsol.cod_persona, 'A', null, null);
      IF nvl(v_dia_atraso, 0) > v_dia_atr_deudor THEN
         v_nro_validacion := 2;
         pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                               v_abr_validacion, v_sol_tie_error);
         v_observacion := 'Cliente con '||v_dia_atraso||' Dias de Atraso';
         v_val_secuencia := v_val_secuencia + 1;
         pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                             v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
      END IF;
      -- D¿as de Atraso en Operaciones Vencidas
      BEGIN
         SELECT nvl(max(dia_atraso),0) dia_atraso
           INTO v_dia_atraso
           FROM GE_CUENTAS a, GE_CTA_CLIENTES B
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND b.cod_persona = rsol.cod_persona
            AND a.cod_modulo = 15  -- solo cuentas pasivas
            AND EXISTS (SELECT 0
                          FROM ge_est_cuentas c
                         WHERE c.cod_modulo = b.cod_modulo
                           AND c.cod_modalidad = b.cod_modalidad
                           AND c.estado = a.estado
                           AND c.activo = 'S');
      EXCEPTION
         WHEN others THEN
           v_dia_atraso := 0;
      END;
      IF nvl(v_dia_atraso, 0) > v_dia_atr_deudor THEN
         v_nro_validacion := 2;
         pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                               v_abr_validacion, v_sol_tie_error);
         v_observacion := 'Cliente con '||v_dia_atraso||' Dias de Atraso en Operaciones Vencidas';
         v_val_secuencia := v_val_secuencia + 1;
         pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                             v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
      END IF;

      BEGIN
         SELECT nvl(cat_sistema, 1), fup_obt_categoria(nvl(cat_automatica, 1), cat_subjetiva)
           INTO v_cat_sistema, v_cat_bbva
           FROM ge_clientes
          WHERE cod_persona = rsol.cod_persona;
      EXCEPTION
         WHEN others THEN
           v_cat_sistema := 1;
           v_cat_bbva  := 1;
      END;

      --** 3 Clasificaci¿n BBVA cat_riesgo **--
      IF v_cat_bbva > 1 THEN
         v_nro_validacion := 3;
         pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                               v_abr_validacion, v_sol_tie_error);
         v_observacion := 'Cliente con Categor¿a: '||v_cat_bbva;
         v_val_secuencia := v_val_secuencia + 1;
         pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                             v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
      END IF;

      --** 4 Clasificaci¿n Sistema cat_sistema **--
      IF v_cat_sistema > 1 THEN
         v_nro_validacion := 4;
         pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                               v_abr_validacion, v_sol_tie_error);
         v_observacion := 'Cliente con Categor¿a en el Sistema: '||v_cat_sistema;
         v_val_secuencia := v_val_secuencia + 1;
         pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                             v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
      END IF;

      --**Obtener ¿ltimas consultas a Informconf e Infocheck**--
      BEGIN
         SELECT fec_ult_informconf, faj_buro, fec_ult_infocheck, sit_infocheck
           INTO v_fec_con_informconf, v_faj_buro, v_fec_con_infocheck, v_sit_infocheck
           FROM ge_cli_antecedentes
          WHERE cod_persona = rsol.cod_persona;
      EXCEPTION
         WHEN others THEN
            v_fec_con_informconf := null;
            v_fec_con_infocheck  := null;
            v_sit_infocheck      := null;
            v_faj_buro           := null;
      END;
      --** Validar Informconf
      IF v_fec_con_informconf IS NULL THEN
         v_con_informconf := 'S';
      ELSIF v_fec_actual - trunc(v_fec_con_informconf) > v_fec_vig_inf THEN
         v_con_informconf := 'S';
      ELSIF v_faj_buro IS NULL THEN
         v_con_informconf := 'S';
      ELSIF v_faj_buro IS NOT NULL THEN
         v_con_informconf := 'N';
      END IF;

      IF rsol.tip_persona = 'F' THEN
         IF v_con_informconf = 'S' THEN
            v_err_informcomf := pag_eqf.fu_pro_dat_informconf(rsol.cod_persona, 'N', 99);
            v_faj_buro       := fu_obt_faj_informconf(rsol.cod_persona);
         END IF;

         --** 6 Informconf **--
         IF v_faj_buro is null THEN
            v_nro_validacion := 6;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_sol_tie_error);
            v_observacion := 'Cliente sin Datos en Informconf';
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                                v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
         ELSIF v_faj_buro > 'L' THEN
            v_nro_validacion := 6;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_sol_tie_error);
            v_observacion := 'Cliente con Faja en Informconf: '||v_faj_buro;
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                                v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
         END IF;
      END IF;

      --** Validar Infocheck
      IF v_fec_con_infocheck IS NULL THEN
         v_con_infocheck := 'S';
      ELSIF v_fec_actual - trunc(v_fec_con_infocheck) > v_fec_vig_inf THEN
         v_con_infocheck := 'S';
      ELSIF v_sit_infocheck IS NULL THEN
         v_con_infocheck := 'S';
      ELSIF v_sit_infocheck IS NOT NULL THEN
         v_con_infocheck := 'N';
      END IF;
      IF v_con_infocheck = 'S' THEN
         v_err_infocheck := pag_eqf.fu_pro_dat_infocheck(rsol.cod_persona, 'N', 1);
         v_sit_infocheck := fu_obt_sit_infocheck(rsol.cod_persona);
      END IF;

      --** 7 Infocheck **--
      IF v_sit_infocheck is null THEN
         v_nro_validacion := 7;
         pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                               v_abr_validacion, v_sol_tie_error);
         v_observacion := 'Cliente sin Datos en Infocheck';
         v_val_secuencia := v_val_secuencia + 1;
         pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                             v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
      ELSIF v_sit_infocheck = '3' THEN
         v_nro_validacion := 8;
         pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                               v_abr_validacion, v_sol_tie_error);
         v_observacion := 'Cliente con Situaci¿n en Infocheck: '||v_sit_infocheck||' - '||fue_obt_des_refcodes('SIT_INFOCHECK', v_sit_infocheck);
         v_val_secuencia := v_val_secuencia + 1;
         pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                             v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
         /*ELSIF v_sit_infocheck <> '1' THEN
           v_nro_validacion := 7;
           pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                 v_abr_validacion, v_sol_tie_error);
           v_observacion := 'Cliente con Situaci¿n en Infocheck: '||v_sit_infocheck||' - '||fue_obt_des_refcodes('SIT_INFOCHECK', v_sit_infocheck);
           v_val_secuencia := v_val_secuencia + 1;
           pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                               v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);*/
      END IF;
      --** 7 Verificar Cheq. Rechazados **--
      v_can_operaciones := 0;
      v_can_operaciones := fu_obt_ant_infocheck(rsol.cod_persona, 1);
      IF v_can_operaciones > 0 THEN
         v_nro_validacion := 7;
         pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                v_abr_validacion, v_che_tie_error);
         v_observacion := 'Cliente con '||v_can_operaciones||' Cheques Rechazados por IF en los ¿ltimos 12 meses';
         v_val_secuencia := v_val_secuencia + 1;
         pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                     v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
      END IF;


      ----**** CHEQUES y LIBRADORES ****----
      FOR rche IN c_cheques LOOP
         v_tip_validacion      := null;
         v_abr_validacion      := null;
         v_fec_con_informconf  := null;
         v_fec_con_infocheck   := null;
         v_sit_infocheck       := null;
         v_faj_buro            := null;
         v_des_vinculo         := null;
         v_tip_per_lib         := null;
         v_nro_documento       := null;
         v_cod_persona         := null;
         v_referencia          := null;
         v_est_cheques         := null;
         v_err_cheques         := null;
         v_activo              := null;
         v_fec_nacimiento      := null;
         v_can_operaciones     := 0;
         v_dia_atraso          := 0;
         v_val_che             := 0;
         v_cat_sistema         := 1;
         v_cat_bbva            := 1;
         v_che_tie_error       := 'N';

         BEGIN
            SELECT cod_persona, tipo
              INTO v_cod_persona, v_tip_per_lib
              FROM ba_personas a
             WHERE a.cod_tip_documento=rche.cod_tip_documento
               AND a.nro_documento=rche.nro_documento;
         EXCEPTION
            WHEN others THEN
               v_cod_persona := null;
               v_tip_per_lib := null;
         END;

         --** 130 Plazo m¿ximo (180 d¿as) **--
         IF rche.fec_vencimiento is null or rche.fec_emision is null THEN
            v_nro_validacion := 130;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_che_tie_error);
            v_observacion := 'Fecha de Vencimiento y/o Emisi¿n no pueden ser nulos ';
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, null, 'C', rche.nro_cuota, rche.cod_banco,
                  rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
         ELSIF (rche.fec_vencimiento - v_fec_actual) < v_min_dias THEN
            v_nro_validacion := 130;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_che_tie_error);
            v_observacion := 'La Fecha de Vencimiento del cheque no debe ser inferior a: '||v_min_dias;
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                  rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
         ELSIF (rche.fec_vencimiento - rche.fec_emision) > v_dias THEN
            v_nro_validacion := 130;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_che_tie_error);
            v_observacion := 'Plazo mayor al m¿ximo permitido ('||v_dias||'). Plazo: '||to_char(rche.fec_vencimiento - rche.fec_emision);
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                  rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
         END IF;

         --** 131 Moneda **--
         IF rsol.cod_moneda <> rche.cod_moneda THEN
            v_nro_validacion := 131;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_che_tie_error);
            v_observacion := 'Moneda del Cheque es distinta al de la Solicitud';
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
         END IF;

         --** 132 Redondeo **--
         IF rche.monto <> round(rche.monto,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,rche.cod_moneda,null)) then
            v_nro_validacion := 132;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_che_tie_error);
            v_observacion := 'Error de redondeo';
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
         END IF;

         --** 133 Si en la solicitud est¿ duplicado**--
         SELECT count(*)
           INTO v_val_che
           FROM pr_fad_che_custodias a
          WHERE a.nro_solicitud = rche.nro_solicitud
            AND a.cod_banco = rche.cod_banco
            AND a.nro_cheque = rche.nro_cheque
            AND a.cta_libradora = rche.cta_libradora;
         IF v_val_che > 1 then
            v_nro_validacion := 133;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_che_tie_error);
            v_observacion := 'En esta solicitud existen '||v_val_che||' cheques con el mismo numero';
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
         END IF;

         --** 134 Si ya existe en otra solicitud **--
         SELECT max(a.nro_solicitud), max(s.cod_persona)
           INTO v_val_che, v_referencia
           FROM pr_fad_che_custodias a, pr_fad_solicitudes s
          WHERE a.nro_solicitud=s.nro_solicitud
            AND a.nro_solicitud <> rche.nro_solicitud
            AND a.cod_banco = rche.cod_banco
            AND a.nro_cheque = rche.nro_cheque
            AND a.cta_libradora = rche.cta_libradora
            AND s.estado <> 'C';
         IF v_val_che > 0 then
            v_nro_validacion := 134;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_che_tie_error);
            v_observacion := 'El cheque ya se encuentra en la solicitud: '||v_val_che||', del Deudor con Cod.Pers.: '||v_referencia;
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
         END IF;

         --** 135 Si en la solicitud est¿ duplicado**--
         v_referencia := null;
         SELECT max(a.nro_referencia)
           INTO v_referencia
           FROM ge_che_custodias a
          WHERE a.cod_banco = rche.cod_banco
            AND a.nro_cheque = rche.nro_cheque
            AND a.cta_libradora = rche.cta_libradora;
         IF v_referencia is not null then
            v_nro_validacion := 135;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_che_tie_error);
            v_observacion := 'El cheque ya est¿ relacionada a la Cuenta/Solicitud: '||v_referencia;
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
         END IF;

         --** Validar Cheques Cargo Ntro Banco **--
         IF rche.cod_banco = v_cod_banco THEN
            --** 136 Validar estado del Cheque **--
            v_est_cheques := pac_che.fu_obt_est_che(rche.cta_libradora,rche.nro_cheque,v_err_cheques);
            v_nro_validacion := 136;
            IF v_err_cheques is not null THEN
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Error al validar Estado del Cheque: '||v_err_cheques;
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            ELSIF v_est_cheques = 'O' THEN
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Cheque con Orden de No Pago.';
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            ELSIF v_est_cheques != 'E' THEN
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Cheque con estado incorrecto para Descontar.';
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            END IF;

            --** 137 Validar estado de la Cuenta **--
            BEGIN
               SELECT 'S'
                 INTO v_activo
                 FROM ge_cuentas a, ge_est_cuentas b
                WHERE a.cod_modulo = b.cod_modulo
                  AND a.cod_modalidad = b.cod_modalidad
                  AND a.estado = b.estado
                  AND b.activo = 'S' and b.estado <> 'P'
                  AND a.nro_cuenta = rche.cta_libradora;
            EXCEPTION
               WHEN Others THEN
                  v_activo := 'N';
      		 	END;
            v_nro_validacion := 137;
            IF v_activo != 'S' THEN
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Cuenta Libradora Inactiva';
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            END IF;
            --** 138 Validar firmantes inhibidos **--
            v_nro_validacion := 138;
            IF fuc_ver_fir_inhibidos(rche.cta_libradora) = 'S' THEN -- Ley 3711
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Cuenta Libradora posee Firmante Inhibido';
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'C', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            END IF;
         END IF;

         --** Validaciones para Libradores que NO son Clientes **--
         IF v_cod_persona is null THEN
            --** 101 Librador NO es Cliente **--
            v_nro_validacion := 101;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_che_tie_error);
            v_observacion := 'Librador NO es cliente';
            v_val_secuencia := v_val_secuencia + 1;
            pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, null, 'L', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);

         --** Validaciones para Libradores que son Clientes **--
         ELSE
            --** 112 Atrasos **--
            v_dia_atraso := fug_obt_atraso(v_cod_persona, 'A', null, null);
            IF nvl(v_dia_atraso, 0) > v_dia_atr_librador THEN
               v_nro_validacion := 112;
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Librador con '||v_dia_atraso||' Dias de Atraso';
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            END IF;
            -- D¿as de Atraso en Operaciones Vencidas
            BEGIN
               SELECT nvl(max(dia_atraso),0) dia_atraso
                 INTO v_dia_atraso
                 FROM GE_CUENTAS a, GE_CTA_CLIENTES B
                WHERE a.nro_cuenta = b.nro_cuenta
                  AND b.relacion = 'P'
                  AND b.cod_persona = v_cod_persona
                  AND a.cod_modulo = 15  -- solo cuentas pasivas
                  AND EXISTS (SELECT 0
                                FROM ge_est_cuentas c
                               WHERE c.cod_modulo = b.cod_modulo
                                 AND c.cod_modalidad = b.cod_modalidad
                                 AND c.estado = a.estado
                                 AND c.activo = 'S');
            EXCEPTION
               WHEN others THEN
                 v_dia_atraso := 0;
            END;
            IF nvl(v_dia_atraso, 0) > v_dia_atr_librador THEN
               v_nro_validacion := 112;
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Librador con '||v_dia_atraso||' Dias de Atraso en Operaciones Vencidas';
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            END IF;

            BEGIN
               SELECT nvl(cat_sistema, 1), fup_obt_categoria(nvl(cat_automatica, 1), cat_subjetiva)
                 INTO v_cat_sistema, v_cat_bbva
                 FROM ge_clientes
                WHERE cod_persona = v_cod_persona;
            EXCEPTION
               WHEN others THEN
                 v_cat_sistema := 1;
                 v_cat_bbva  := 1;
            END;

            --**Obtener ¿ltimas consultas a Informconf e Infocheck, si cumple condici¿n fu_val_lib_consulta**--
            IF fu_val_lib_consulta(rche.nro_solicitud, rche.cod_tip_documento, rche.nro_documento) = 'S' THEN
               --** 111 Inhibici¿n **--
               IF lf_ver_inhibicion(v_cod_persona, 'N') = 'S' THEN
                  v_nro_validacion := 111;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Librador posee inhibici¿n';
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                              rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
               END IF;
               --** 113 Clasificaci¿n BBVA cat_riesgo **--
               IF v_cat_bbva > 1 THEN
                  v_nro_validacion := 113;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Librador con Categor¿a: '||v_cat_bbva;
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                              rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
               END IF;

               --** 114 Clasificaci¿n Sistema cat_sistema **--
               IF v_cat_sistema > 1 THEN
                  v_nro_validacion := 114;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Librador con Categor¿a en el Sistema: '||v_cat_sistema;
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                              rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
               END IF;

               IF v_tip_per_lib = 'F' THEN
                  v_faj_buro := fu_obt_faj_informconf(v_cod_persona);
                  --** 115 Informconf **--
                  IF v_faj_buro is null THEN
                     v_nro_validacion := 115;
                     pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                           v_abr_validacion, v_che_tie_error);
                     v_observacion := 'Librador sin Datos en Informconf';
                     v_val_secuencia := v_val_secuencia + 1;
                     pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                  ELSIF v_faj_buro = 'M' THEN
                     --** 115 Verificar convocatorias **--
                     v_nro_validacion := 115;
                     pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                            v_abr_validacion, v_che_tie_error);
                     v_observacion := 'Librador con Faja en Informconf: '||v_faj_buro;
                     v_val_secuencia := v_val_secuencia + 1;
                     pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                 rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                     --** 122 Verificar convocatorias **--
                     v_can_operaciones := 0;
                     v_can_operaciones := fu_obt_ant_informconf(v_cod_persona, 2);
                     IF v_can_operaciones > 0 THEN
                        v_nro_validacion := 122;
                        pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                              v_abr_validacion, v_che_tie_error);
                        v_observacion := 'Librador  con '||v_can_operaciones||' convocatoria/s NO finiquitada/s';
                        v_val_secuencia := v_val_secuencia + 1;
                        pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                    rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                     END IF;
                     --** 123 Verificar demanda **--
                     v_can_operaciones := 0;
                     v_can_operaciones := fu_obt_ant_informconf(v_cod_persona, 3);
                     IF v_can_operaciones > 0 THEN
                        v_nro_validacion := 123;
                        pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                              v_abr_validacion, v_che_tie_error);
                        v_observacion := 'Librador con '||v_can_operaciones||' demanda/s NO finiquitada/s';
                        v_val_secuencia := v_val_secuencia + 1;
                        pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                    rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                     END IF;
                     --** 124 Verificar inhabilitaciones **--
                     v_can_operaciones := 0;
                     v_can_operaciones := fu_obt_ant_informconf(v_cod_persona, 4);
                     IF v_can_operaciones > 0 THEN
                        v_nro_validacion := 124;
                        pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                              v_abr_validacion, v_che_tie_error);
                        v_observacion := 'Librador con '||v_can_operaciones||' inhabilitacion/es NO finiquitada/s';
                        v_val_secuencia := v_val_secuencia + 1;
                        pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                    rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                     END IF;
                     --** 125 Verificar inhibiciones **--
                     v_can_operaciones := 0;
                     v_can_operaciones := fu_obt_ant_informconf(v_cod_persona, 5);
                     IF v_can_operaciones > 0 THEN
                        v_nro_validacion := 125;
                        pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                              v_abr_validacion, v_che_tie_error);
                        v_observacion := 'Librador con '||v_can_operaciones||' inhibicion/es NO finiquitada/s';
                        v_val_secuencia := v_val_secuencia + 1;
                        pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                    rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                     END IF;
                     --** 126 Verificar act. morosas ADEFI **--
                     v_can_operaciones := 0;
                     v_can_operaciones := fu_obt_ant_informconf(v_cod_persona, 6);
                     IF v_can_operaciones > 0 THEN
                        v_nro_validacion := 126;
                        pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                              v_abr_validacion, v_che_tie_error);
                        v_observacion := 'Librador con '||v_can_operaciones||' act. morosas-AFEDI NO finiquitada/s';
                        v_val_secuencia := v_val_secuencia + 1;
                        pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                    rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                     END IF;
                     --** 127 Verificar act. morosas **--
                     v_can_operaciones := 0;
                     v_can_operaciones := fu_obt_ant_informconf(v_cod_persona, 7);
                     IF v_can_operaciones > 0 THEN
                        v_nro_validacion := 127;
                        pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                              v_abr_validacion, v_che_tie_error);
                        v_observacion := 'Librador con '||v_can_operaciones||' act. morosa/s NO finiquitada/s';
                        v_val_secuencia := v_val_secuencia + 1;
                        pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                    rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                     END IF;
                     --** 128 Verificar remates **--
                     v_can_operaciones := 0;
                     v_can_operaciones := fu_obt_ant_informconf(v_cod_persona, 8);
                     IF v_can_operaciones > 0 THEN
                        v_nro_validacion := 128;
                        pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                              v_abr_validacion, v_che_tie_error);
                        v_observacion := 'Librador con '||v_can_operaciones||' remate/s NO finiquitado/s';
                        v_val_secuencia := v_val_secuencia + 1;
                        pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                    rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                     END IF;
                     --** 129 Verificar quiebras **--
                     v_can_operaciones := 0;
                     v_can_operaciones := fu_obt_ant_informconf(v_cod_persona, 10);
                     IF v_can_operaciones > 0 THEN
                        v_nro_validacion := 129;
                        pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                              v_abr_validacion, v_che_tie_error);
                        v_observacion := 'Librador con '||v_can_operaciones||' quiebra/s NO finiquitada/s';
                        v_val_secuencia := v_val_secuencia + 1;
                        pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                    rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                      END IF;
                      --** 160 Verificar Cheq. Rechazados **--
                      v_can_operaciones := 0;
                      v_can_operaciones := fu_obt_ant_infocheck(v_cod_persona, 1);
                      IF v_can_operaciones > 0 THEN
                         v_nro_validacion := 160;
                         pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                               v_abr_validacion, v_che_tie_error);
                         v_observacion := 'Librador con '||v_can_operaciones||' Cheques Rechazados por IF en los ¿ltimos 12 meses';
                         v_val_secuencia := v_val_secuencia + 1;
                         pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                     rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                      END IF;
                  ELSIF v_faj_buro > 'M' THEN
                     v_nro_validacion := 115;
                     pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                            v_abr_validacion, v_che_tie_error);
                     v_observacion := 'Librador con Faja en Informconf: '||v_faj_buro;
                     v_val_secuencia := v_val_secuencia + 1;
                     pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                 rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                  END IF;
               END IF;

               v_sit_infocheck := fu_obt_sit_infocheck(v_cod_persona);
               --** 116 Infocheck **--
               IF v_sit_infocheck is null THEN
                  v_nro_validacion := 116;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Librador sin Datos en Infocheck';
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                              rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
               ELSIF v_sit_infocheck = '3' THEN
                  v_nro_validacion := 117;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Librador con Situaci¿n en Infocheck: '||v_sit_infocheck||' - '||fue_obt_des_refcodes('SIT_INFOCHECK', v_sit_infocheck);
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                              rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
               /*ELSIF v_sit_infocheck <> '1' THEN
                  v_nro_validacion := 116;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Librador con Situaci¿n en Infocheck: '||v_sit_infocheck||' - '||fue_obt_des_refcodes('SIT_INFOCHECK', v_sit_infocheck);
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                              rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);*/
               END IF;
               --** 117 Verificar Cheq. Rechazados **--
               v_can_operaciones := 0;
               v_can_operaciones := fu_obt_ant_infocheck(v_cod_persona, 1);
               IF v_can_operaciones > 0 and nvl(v_faj_buro, 'X') <> 'M' THEN
                  v_nro_validacion := 117;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Librador con '||v_can_operaciones||' Cheques Rechazados por IF en los ¿ltimos 12 meses';
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                              rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
               END IF;
            ELSE
               --** 111 Inhibici¿n **--
               IF lf_ver_inhibicion(v_cod_persona, 'S') = 'S' THEN
                  v_nro_validacion := 111;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Librador posee inhibici¿n';
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                              rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
               END IF;
            END IF;
            --** 118 Verificar vinculos **--
            BEGIN
               SELECT b.descripcion
                 INTO v_des_vinculo
                 FROM ba_vinculos a, ba_tip_vinculos b
                WHERE a.tipo=b.cod_tip_vinculo
                  AND a.cod_persona=rsol.cod_persona
                  AND a.cod_per_vinculo=v_cod_persona ;
            EXCEPTION
               WHEN too_many_rows THEN
                  BEGIN
                     SELECT b.descripcion
                       INTO v_des_vinculo
                       FROM ba_vinculos a, ba_tip_vinculos b
                      WHERE a.tipo=b.cod_tip_vinculo
                        AND a.cod_persona=rsol.cod_persona
                        AND a.cod_per_vinculo=v_cod_persona
                        AND a.fec_insercion = (SELECT max(c.fec_insercion)
                                                 FROM ba_vinculos c
                                                WHERE c.cod_persona=rsol.cod_persona
                                                  AND c.cod_per_vinculo=v_cod_persona );
                  EXCEPTION
                     WHEN others THEN
                        v_des_vinculo := null;
                  END;
               WHEN others THEN
                  v_des_vinculo := null;
            END;
            IF v_des_vinculo is not null THEN
               v_nro_validacion := 118;
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Deudor y Librador poseen viculo de tipo: '||v_des_vinculo;
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            END IF;
            --** 118 Verificar vinculos - Grupo Econ¿mico **--
            v_des_vinculo := null;
            BEGIN
               SELECT g.descripcion
                 INTO v_des_vinculo
                 FROM ge_clientes a, ge_clientes c, ge_gru_economicos g
                WHERE a.cod_gru_economico=c.cod_gru_economico
                  AND a.cod_gru_economico=g.cod_gru_economico
                  AND a.cod_persona=rsol.cod_persona
                  AND c.cod_persona=v_cod_persona;
            EXCEPTION
               WHEN others THEN
                  v_des_vinculo := null;
            END;
            IF v_des_vinculo is not null THEN
               v_nro_validacion := 118;
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Deudor y Librador pertenecen al mismo Grupo Econ¿mico: '||v_des_vinculo;
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            END IF;

            --** 119 Verificar Cheques Cruzados **--
            v_can_operaciones := fu_ver_che_cruzados(rsol.cod_persona, v_cod_persona, rche.cod_tip_documento,
                                                     rche.nro_documento, 'T', v_cuentas);
            IF nvl(v_can_operaciones, 0) > 0 THEN
               v_nro_validacion := 119;
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Cheque Prestado Deudor-Librador. Cuenta/s: '||v_cuentas;
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            END IF;
            --** 120 Verificar Cheques Cruzados (prestado) en los ¿ltimos 180 d¿as **--
            v_can_operaciones := fu_ver_che_cruzados(rsol.cod_persona, v_cod_persona, rche.cod_tip_documento,
                                                     rche.nro_documento, 'S', v_cuentas);
            IF nvl(v_can_operaciones, 0) > 0 THEN
               v_nro_validacion := 120;
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_che_tie_error);
               v_observacion := 'Cheque Prestado Deudor-Librador en los ¿ltimos 180 d¿as. Cuenta/s: '||v_cuentas;
               v_val_secuencia := v_val_secuencia + 1;
               pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                           rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
            END IF;

            IF v_tip_per_lib = 'F' THEN
               BEGIN
                 SELECT fec_nacimiento
                   INTO v_fec_nacimiento
                   FROM ba_per_fisicas
                  WHERE cod_persona = v_cod_persona;
               EXCEPTION
                 WHEN others THEN
                    v_fec_nacimiento := null;
               END;

               IF v_fec_nacimiento is null THEN
                  v_fec_nacimiento := lf_act_dat_librador(v_cod_persona);
               END IF;

               IF v_fec_nacimiento is null THEN
                  v_nro_validacion := 121;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'No se encuentra la fecha de nacimiento del librador. Cod. Persona: '||v_cod_persona;
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, v_cod_persona, 'L', rche.nro_cuota, rche.cod_banco,
                                      rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
               END IF;
            END IF;
         END IF;

         --Actualizar estado del Cheque
         lp_act_est_cheque(rche.nro_solicitud, rche.nro_cuota, rche.cod_banco, rche.nro_cheque,
                           rche.cta_libradora, v_che_tie_error);
         -- Si la Operaci¿n no tiene error y al menos un cheque tampoco, la cabecera puede pasar a estado V=Validado
         IF v_sol_tie_error = 'N' and v_che_tie_error = 'N' THEN
            v_sol_tie_error := 'N';
         END IF;
      END LOOP;

      ----**** 2 CHEQUES y LIBRADORES ****----
      -- Se vuelve a recorrer el curso solo para Calcular la Concentraci¿n,
      -- ya que para el calculo debe tomar solo los cheques en estado V=VALIDADO.
      FOR rche IN c_cheques LOOP
         -- En caso que el librador sea TIER, se le permite hasta el 100%
         IF fue_per_dat_adicional(rche.cod_per_lib, 'TIER') is null THEN
            v_sum_che_librador:= 0;
            v_che_tie_error   := rche.tie_err_blo;
            v_concentracion   := fu_obt_concentracion(rche.nro_solicitud, rche.cod_tip_documento, rche.nro_documento);
            v_faj_buro        := fu_obt_faj_informconf(v_cod_persona);
            --** 151 Concentraci¿n **--
            IF v_faj_buro = 'M' THEN
               BEGIN
                  -- Sumatoria de cheques del Librador
                  SELECT nvl(sum(a.monto), 0)
                    INTO v_sum_che_librador
                    FROM pr_fad_che_custodias a, pr_fad_rel_che_lib b
                   WHERE a.nro_solicitud=b.nro_solicitud AND a.nro_cuota=b.nro_cuota
                     AND a.cod_banco=b.cod_banco AND a.nro_cheque=b.nro_cheque AND a.cta_libradora=b.cta_libradora
                     AND a.estado = 'V' -- Solo Cheques en estado Valido
                     AND b.cod_tip_documento = rche.cod_tip_documento
                     AND b.nro_documento = rche.nro_documento
                     AND b.nro_solicitud = rche.nro_solicitud;
               END;
               -- La concentraci¿n no debe superar el 10%. No debe superar 50MM por librador
               IF v_concentracion > 10 THEN
                  v_nro_validacion := 151;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Concentraci¿n: '||v_concentracion||'% supera el l¿mite para Libradores con Faja M';
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, rche.cod_per_lib, 'L', rche.nro_cuota, rche.cod_banco,
                                 rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                  --Actualizar estado del Cheque
                  lp_act_est_cheque(rche.nro_solicitud, rche.nro_cuota, rche.cod_banco, rche.nro_cheque,
                                    rche.cta_libradora, v_che_tie_error);
                  -- Si la Operaci¿n no tiene error y al menos un cheque tampoco, la cabecera puede pasar a estado V=Validado
                  IF v_sol_tie_error = 'N' and v_che_tie_error = 'N' THEN
                     v_sol_tie_error := 'N';
                  END IF;
               ELSIF v_sum_che_librador > 50000000 THEN
                  v_nro_validacion := 151;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Concentraci¿n. Total de cheque por librador '||v_sum_che_librador||' supera el l¿mite para Libradores con Faja M';
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, rche.cod_per_lib, 'L', rche.nro_cuota, rche.cod_banco,
                                 rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                  --Actualizar estado del Cheque
                  lp_act_est_cheque(rche.nro_solicitud, rche.nro_cuota, rche.cod_banco, rche.nro_cheque,
                                    rche.cta_libradora, v_che_tie_error);
                  -- Si la Operaci¿n no tiene error y al menos un cheque tampoco, la cabecera puede pasar a estado V=Validado
                  IF v_sol_tie_error = 'N' and v_che_tie_error = 'N' THEN
                     v_sol_tie_error := 'N';
                  END IF;
               END IF;
            ELSE
               -- La concentraci¿n no debe superar el 30%.
               IF v_concentracion > 30 THEN
                  v_nro_validacion := 151;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_che_tie_error);
                  v_observacion := 'Concentraci¿n: '||v_concentracion||'% supera el l¿mite';
                  v_val_secuencia := v_val_secuencia + 1;
                  pr_ins_validaciones(rche.nro_solicitud, v_val_secuencia, rche.cod_per_lib, 'L', rche.nro_cuota, rche.cod_banco,
                                 rche.nro_cheque, rche.cta_libradora, v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion, rche.tip_afe_lim_cre);
                  --Actualizar estado del Cheque
                  lp_act_est_cheque(rche.nro_solicitud, rche.nro_cuota, rche.cod_banco, rche.nro_cheque,
                                    rche.cta_libradora, v_che_tie_error);
                  -- Si la Operaci¿n no tiene error y al menos un cheque tampoco, la cabecera puede pasar a estado V=Validado
                  IF v_sol_tie_error = 'N' and v_che_tie_error = 'N' THEN
                     v_sol_tie_error := 'N';
                  END IF;
               END IF;
            END IF;
         END IF;
      END LOOP;

      --** 5 Verificaci¿n de L¿nea de Cr¿dito **--
      IF nvl(rsol.ind_lin_credito, 'N') = 'S' THEN
         v_sal_linea := fu_obt_cli_lin_credito(rsol.cod_persona, rsol.cod_moneda);
         IF v_sal_linea > 0 THEN
            SELECT sum(decode(a.tip_afe_lim_cre, 'D', a.monto, 0)), sum(decode(a.tip_afe_lim_cre, 'P', a.monto, 0))
              INTO v_tot_che_validos, v_tot_che_val_pcp
              FROM pr_fad_che_custodias a
             WHERE a.nro_solicitud = rsol.nro_solicitud
               AND a.estado='V';

            IF v_sal_linea < (nvl(v_tot_che_validos, 0) + nvl(v_tot_che_val_pcp, 0)) THEN
               v_nro_validacion := 5;
               pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                     v_abr_validacion, v_sol_tie_error);
               v_observacion := 'Linea de Cr¿dito del Cliente con Saldo Insuficiente.';
               v_val_secuencia := 1;
               pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                                   v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
            END IF;
            
            IF v_tot_che_validos > 0 THEN
               v_sal_linea := fu_obt_cli_lin_credito(rsol.cod_persona, rsol.cod_moneda, 608, 'S');
               IF nvl(v_sal_linea, 0) < nvl(v_tot_che_validos, 0) THEN
                  v_nro_validacion := 5;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_sol_tie_error);
                  v_observacion := 'Sub L¿mite del Cliente con Saldo Insuficiente para la Modalidad 608.';
                  v_val_secuencia := 1;
                  pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                                      v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);  
               END IF;
            ELSIF v_tot_che_val_pcp > 0 THEN
               v_sal_linea := fu_obt_cli_lin_credito(rsol.cod_persona, rsol.cod_moneda, 61, 'S');
               IF nvl(v_sal_linea, 0) < nvl(v_tot_che_val_pcp, 0) THEN
                  v_nro_validacion := 5;
                  pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                        v_abr_validacion, v_sol_tie_error);
                  v_observacion := 'Sub L¿mite del Cliente con Saldo Insuficiente para la Modalidad 61.';
                  v_val_secuencia := 1;
                  pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                                      v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);  
               END IF;
            END IF;
         ELSIF v_sal_linea = 0 THEN
            v_nro_validacion := 5;
            pr_obt_ref_validacion(v_val_dominio, v_nro_validacion, v_tip_validacion,
                                  v_abr_validacion, v_sol_tie_error);
            v_observacion := 'Cliente sin L¿nea de Cr¿dito';
            v_val_secuencia := 1;
            pr_ins_validaciones(rsol.nro_solicitud, v_val_secuencia, rsol.cod_persona, 'D', null, null, null, null,
                                v_nro_validacion, v_tip_validacion, v_abr_validacion, v_observacion);
         END IF;
      END IF;
      --Actualizar estado de la Operaci¿n.
      lp_act_est_solicitud(rsol.nro_solicitud, v_sol_tie_error);
   END LOOP;
EXCEPTION
   WHEN others THEN
      v_observacion := substr('Error en PR_VAL_OPERACION. Error: '||sqlerrm, 1,200);
      p_error       := 99;
      p_des_error   := v_observacion;
      v_val_secuencia := v_val_secuencia + 1;
      pr_ins_validaciones(v_nro_solicitud, v_val_secuencia, null, 'S', null, null,
                          null, null, 999, 'B', 'VAL_ERR_VAL_OPERACION', v_observacion);
END;

/* Obtener tipo de Persona seg¿n Tipo y Nro de Documento. */
FUNCTION FU_OBT_TIP_PERSONA (P_COD_TIP_DOC   IN PR_FAD_REL_CHE_LIB.COD_TIP_DOCUMENTO%TYPE,
                             P_NRO_DOCUMENTO IN PR_FAD_REL_CHE_LIB.NRO_DOCUMENTO%TYPE) RETURN VARCHAR2 IS
   v_tipo ba_tip_documentos.tip_persona%type;
BEGIN
   BEGIN
      SELECT tip_persona
        INTO v_tipo
        FROM ba_tip_documentos
       WHERE cod_tip_documento = p_cod_tip_doc;
   EXCEPTION
      WHEN others THEN
         v_tipo := 'F';
   END;

   IF v_tipo = 'A' THEN
      IF replace(p_nro_documento, '-','') > 80000000 THEN
         v_tipo := 'J';
      ELSE
         v_tipo := 'F';
      END IF;
   END IF;
   RETURN v_tipo;
END;

/* Insertar como persona a Libradores, por Operaci¿n. */
PROCEDURE PR_INS_PERSONAS (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE) IS
   v_nro_documento pr_fad_rel_che_lib.nro_documento%type;
   v_cod_persona   ba_personas.cod_persona%type;
   v_tipo          ba_tip_documentos.tip_persona%type;
   v_cod_oficina   ba_oficinas.cod_oficina%type;
   v_cod_oficial   ge_par_dinamicos.val_parametro%type;
   v_fec_nacimiento ba_per_fisicas.fec_nacimiento%type;
   v_nombre        personas_ref.rf_nombre%type;
   v_apellido      personas_ref.rf_apellido%type;
   CURSOR libradores IS
      SELECT DISTINCT a.cod_tip_documento, a.nro_documento, relacion, b.nombre, b.apellido
        FROM pr_fad_rel_che_lib a, pr_chq_libradores b
       WHERE a.cod_tip_documento=b.cod_tip_documento
         AND a.nro_documento=b.nro_documento
         AND nro_solicitud = p_nro_solicitud
         AND not exists (SELECT 1 FROM ba_personas c
                          WHERE a.cod_tip_documento=c.cod_tip_documento
                            AND a.nro_documento=c.nro_documento);
BEGIN
   BEGIN
      SELECT b.cod_oficina, b.cod_usu_oficial
        INTO v_cod_oficina, v_cod_oficial
        FROM pr_fad_solicitudes a, ge_clientes b
       WHERE a.cod_persona = b.cod_persona
         AND a.nro_solicitud = p_nro_solicitud;
   EXCEPTION
      WHEN others THEN
         v_cod_oficina := fug_obt_ofi_matriz;
         v_cod_oficial := fug_obt_pardinamico('COD_USU_OFI_DEFECTO',null,null,null,v_cod_oficina,null);
   END;

   FOR rlib IN libradores LOOP
      v_nro_documento := rlib.nro_documento;
      v_tipo := fu_obt_tip_persona(rlib.cod_tip_documento, rlib.nro_documento);
      IF v_tipo = 'F' THEN
         BEGIN
            SELECT p.rf_fecha_nac, p.rf_nombre, p.rf_apellido
              INTO v_fec_nacimiento, v_nombre, v_apellido
              FROM personas_ref p
             WHERE p.rf_tipo_ident = fue_obt_tip_doc_abreviatura(rlib.cod_tip_documento)
               AND p.rf_numero = rlib.nro_documento;
         EXCEPTION
            WHEN others THEN
               v_fec_nacimiento := null;
               v_nombre := null;
               v_apellido := null;
         END;
      ELSE
         v_fec_nacimiento := null;
         v_nombre := rlib.nombre;
         v_apellido := rlib.apellido;
      END IF;
      prl_ins_persona(rlib.nro_documento, rlib.cod_tip_documento, 1, nvl(v_nombre, rlib.nombre),
                      nvl(v_apellido,rlib.apellido), v_tipo, v_fec_nacimiento, v_cod_persona);
      BEGIN
         UPDATE pr_chq_libradores
            SET cod_persona = v_cod_persona,
                nombre = nvl(v_nombre, rlib.nombre),
                apellido = nvl(v_apellido, rlib.apellido),
                nom_completo = nvl(v_nombre, rlib.nombre)||' '||  nvl(v_apellido, rlib.apellido)
          WHERE cod_tip_documento=rlib.cod_tip_documento
            AND nro_documento=rlib.nro_documento;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20021, 'Error al actualizar Librador. Doc. Nro= '||rlib.nro_documento||' - '||SQLERRM);
      END;
      BEGIN
         INSERT INTO ge_clientes
            (cod_persona, cod_oficina, cod_usu_oficial, tip_extracto, residente,
             cod_sec_contable, cod_tip_deudor)
         VALUES
            (v_cod_persona, v_cod_oficina, v_cod_oficial, 'N', 'S', 'N', 2);
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20021, 'Error al insertar Cliente. Doc. Nro= '||rlib.nro_documento||' - '||SQLERRM);
      END;
   END LOOP;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'Error al Insertar Librador. Doc. Nro= '||v_nro_documento||' - '||sqlerrm);
END;

/* Aprobar Operacion */
PROCEDURE PR_APR_VALIDACION (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE) IS
   v_estado   pr_fad_solicitudes.estado%type;
BEGIN
   SELECT estado
     INTO v_estado
     FROM pr_fad_solicitudes a
    WHERE a.nro_solicitud = p_nro_solicitud;
   IF nvl(v_estado, 'X') = 'V' THEN
      BEGIN
         UPDATE pr_fad_solicitudes
            SET estado = 'A'
          WHERE nro_solicitud = p_nro_solicitud;
      EXCEPTION
         WHEN others THEN
            raise_application_error(-20000,'Error al Aprobar Operacion - '||sqlerrm);
      END;
   ELSE
      raise_application_error(-20000,'Operaci¿n no puede ser aprobada. El estado debe ser Verificado');
   END IF;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'Error al consultar estado de la Operacion - '||sqlerrm);
END;

/* Cancelar Operacion */
PROCEDURE PR_CAN_VALIDACION (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE) IS
   v_estado   pr_fad_solicitudes.estado%type;
BEGIN
   SELECT nvl(estado, 'X')
     INTO v_estado
     FROM pr_fad_solicitudes a
    WHERE a.nro_solicitud = p_nro_solicitud;
   IF v_estado IN ('I','V','A', 'E') THEN
      BEGIN
         UPDATE pr_fad_solicitudes
            SET estado = 'C'
          WHERE nro_solicitud = p_nro_solicitud;
      EXCEPTION
         WHEN others THEN
            raise_application_error(-20000,'Error al Cancelar Operacion - '||sqlerrm);
      END;
   ELSIF v_estado = 'C' THEN
      raise_application_error(-20000,'La Operaci¿n ya est¿ Cancelada');
   ELSIF v_estado = 'D' THEN
      raise_application_error(-20000,'La Operaci¿n ya relacionada a una cuenta');
   ELSE
      raise_application_error(-20000,'Operaci¿n no puede ser Cancelada, estado inv¿lido.');
   END IF;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'Error al consultar estado de la Operacion - '||sqlerrm);
END;

/* Vincular/Desvincular Solicitud con Operacion */
PROCEDURE PR_VIN_SOL_VALIDACION (P_NRO_SOL_VAL IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE,
                                 P_TIPO        IN VARCHAR2,
                                 P_TIP_AFE_LIM IN PR_FAD_CHE_CUSTODIAS.TIP_AFE_LIM_CRE%TYPE,
                                 P_NRO_SOL_PRE IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE default null) IS
   v_estado      pr_fad_solicitudes.estado%type;
   v_referencia  pr_fad_solicitudes.referencia%type;
   v_referencia2 pr_fad_solicitudes.referencia%type;
BEGIN

   SELECT nvl(estado, 'X'), a.referencia, a.referencia2
     INTO v_estado, v_referencia, v_referencia2
     FROM pr_fad_solicitudes a
    WHERE a.nro_solicitud = p_nro_sol_val;

   -- Vincular
   IF p_tipo = 'V' THEN
      IF v_estado = 'A' THEN -- Aprobado
         IF p_tip_afe_lim = 'D' THEN
            IF v_referencia2 is not null THEN
               -- Actualizar referencia y estado=D
               BEGIN
                  UPDATE pr_fad_solicitudes
                     SET estado = 'D',
                         referencia = p_nro_sol_pre
                   WHERE nro_solicitud = p_nro_sol_val;
               EXCEPTION
                  WHEN others THEN
                     raise_application_error(-20000,'Error al Vincular Operacion - '||sqlerrm);
               END;
            ELSE
               -- Actualizar solo referencia
               BEGIN
                  UPDATE pr_fad_solicitudes
                     SET referencia = p_nro_sol_pre
                   WHERE nro_solicitud = p_nro_sol_val;
               EXCEPTION
                  WHEN others THEN
                     raise_application_error(-20000,'Error al Vincular Operacion - '||sqlerrm);
               END;
            END IF;
         ELSIF p_tip_afe_lim = 'P' THEN
            IF v_referencia is not null THEN
               -- Actualizar referencia2 y estado=D
               BEGIN
                  UPDATE pr_fad_solicitudes
                     SET estado = 'D',
                         referencia2 = p_nro_sol_pre
                   WHERE nro_solicitud = p_nro_sol_val;
               EXCEPTION
                  WHEN others THEN
                     raise_application_error(-20000,'Error al Vincular Operacion - '||sqlerrm);
               END;
            ELSE
               -- Actualizar solo referencia2
               BEGIN
                  UPDATE pr_fad_solicitudes
                     SET referencia2 = p_nro_sol_pre
                   WHERE nro_solicitud = p_nro_sol_val;
               EXCEPTION
                  WHEN others THEN
                     raise_application_error(-20000,'Error al Vincular Operacion - '||sqlerrm);
               END;
            END IF;
         END IF;
         
         BEGIN
            DELETE pr_fad_dat_cheques_tmp
             WHERE nro_solicitud = p_nro_sol_val;
         EXCEPTION
            WHEN others THEN
               raise_application_error(-20000,'Error al Eliminar temporal - '||sqlerrm);
         END;
      END IF;
   -- Desvincular
   ELSIF p_tipo = 'D' THEN
      IF v_estado in ('A', 'D') THEN -- Descontado
         IF p_tip_afe_lim = 'D' THEN
            IF v_referencia2 is null THEN
               BEGIN
                  UPDATE pr_fad_solicitudes
                     SET estado = 'V',
                         referencia = null
                   WHERE nro_solicitud = p_nro_sol_val;
               EXCEPTION
                  WHEN others THEN
                     raise_application_error(-20000,'Error al Desvincular Operacion - '||sqlerrm);
               END;
            ELSE
               BEGIN
                  UPDATE pr_fad_solicitudes
                     SET estado = 'A',
                         referencia = null
                   WHERE nro_solicitud = p_nro_sol_val;
               EXCEPTION
                  WHEN others THEN
                     raise_application_error(-20000,'Error al Desvincular Operacion - '||sqlerrm);
               END;
            END IF;
         ELSIF p_tip_afe_lim = 'P' THEN
            IF v_referencia is null THEN
               BEGIN
                  UPDATE pr_fad_solicitudes
                     SET estado = 'V',
                         referencia2 = null
                   WHERE nro_solicitud = p_nro_sol_val;
               EXCEPTION
                  WHEN others THEN
                     raise_application_error(-20000,'Error al Desvincular Operacion - '||sqlerrm);
               END;
            ELSE
               BEGIN
                  UPDATE pr_fad_solicitudes
                     SET estado = 'A',
                         referencia2 = null
                   WHERE nro_solicitud = p_nro_sol_val;
               EXCEPTION
                  WHEN others THEN
                     raise_application_error(-20000,'Error al Desvincular Operacion - '||sqlerrm);
               END;
            END IF;
         END IF;
      END IF;
   END IF;
END;

/* Insertar en la tabla pr_dat_cheques_tmp (PMDESDOC) */
PROCEDURE PR_INS_DAT_CHEQUES_TMP (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE,
                                  P_AFE_LIM_CRED  IN PR_FAD_CHE_CUSTODIAS.TIP_AFE_LIM_CRE%TYPE) IS
   v_abr_tip_documento1 pr_fad_dat_cheques_tmp.abr_tip_documento1%TYPE;
   v_nro_documento1     pr_fad_dat_cheques_tmp.nro_documento1%TYPE;
   v_nom_completo1      pr_fad_dat_cheques_tmp.nom_completo1%TYPE;
   v_abr_tip_documento2 pr_fad_dat_cheques_tmp.abr_tip_documento1%TYPE;
   v_nro_documento2     pr_fad_dat_cheques_tmp.nro_documento1%TYPE;
   v_nom_completo2      pr_fad_dat_cheques_tmp.nom_completo1%TYPE;
   v_abr_tip_documento3 pr_fad_dat_cheques_tmp.abr_tip_documento1%TYPE;
   v_nro_documento3     pr_fad_dat_cheques_tmp.nro_documento1%TYPE;
   v_nom_completo3      pr_fad_dat_cheques_tmp.nom_completo1%TYPE;
   v_cont               number;
   CURSOR cheques IS
      SELECT nro_cuota, fec_deposito, cod_banco, nro_cheque, cta_libradora,
             b.monto, fec_emision, b.fec_vencimiento, observacion
        FROM pr_fad_solicitudes a, pr_fad_che_custodias b
       WHERE a.nro_solicitud = b.nro_solicitud
         AND a.estado='A' AND b.estado='V'
         AND a.nro_solicitud = p_nro_solicitud
         AND b.tip_afe_lim_cre = p_afe_lim_cred
       ORDER BY b.nro_cuota;

   CURSOR libradores (p_nro_cuota number, p_cod_banco number, p_nro_cheque number, p_cta_libradora varchar2) IS
      SELECT b.cod_tip_documento, c.abreviatura, b.nro_documento, b.nom_completo
        FROM pr_fad_rel_che_lib a, pr_chq_libradores b, ba_tip_documentos c
       WHERE a.cod_tip_documento = b.cod_tip_documento
         AND a.nro_documento = b.nro_documento
         AND b.cod_tip_documento = c.cod_tip_documento
         AND a.nro_solicitud = p_nro_solicitud
         AND a.nro_cuota = p_nro_cuota
         AND a.cod_banco = p_cod_banco
         AND a.nro_cheque = p_nro_cheque
         AND a.cta_libradora  = p_cta_libradora
         AND rownum <=3;
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   FOR rche IN cheques LOOP
      v_abr_tip_documento1 := null;
      v_nro_documento1     := null;
      v_nom_completo1      := null;
      v_abr_tip_documento2 := null;
      v_nro_documento2     := null;
      v_nom_completo2      := null;
      v_abr_tip_documento3 := null;
      v_nro_documento3     := null;
      v_nom_completo3      := null;
      v_cont               := 1;
      FOR rlib IN libradores(rche.nro_cuota, rche.cod_banco, rche.nro_cheque, rche.cta_libradora) LOOP
         IF v_cont = 1 THEN
            v_abr_tip_documento1 := rlib.abreviatura;
            v_nro_documento1     := rlib.nro_documento;
            v_nom_completo1      := rlib.nom_completo;
         ELSIF v_cont = 2 THEN
            v_abr_tip_documento2 := rlib.abreviatura;
            v_nro_documento2     := rlib.nro_documento;
            v_nom_completo2      := rlib.nom_completo;
         ELSIF v_cont = 3 THEN
            v_abr_tip_documento3 := rlib.abreviatura;
            v_nro_documento3     := rlib.nro_documento;
            v_nom_completo3      := rlib.nom_completo;
         END IF;
         v_cont := v_cont + 1;
      END LOOP;
      INSERT INTO pr_dat_cheques_tmp (nro_cuota, fec_deposito, cod_banco, nro_cheque, cta_libradora,
                  monto, fec_emision, fec_vencimiento, observacion,
                  abr_tip_documento1, nro_documento1, nom_completo1,
                  abr_tip_documento2, nro_documento2, nom_completo2,
                  abr_tip_documento3, nro_documento3, nom_completo3)
      VALUES (rche.nro_cuota, rche.fec_deposito, rche.cod_banco, rche.nro_cheque, rche.cta_libradora,
              rche.monto, rche.fec_emision, rche.fec_vencimiento, rche.observacion,
              v_abr_tip_documento1, v_nro_documento1, v_nom_completo1,
              v_abr_tip_documento2, v_nro_documento2, v_nom_completo2,
              v_abr_tip_documento3, v_nro_documento3, v_nom_completo3);
   END LOOP;
   COMMIT;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'Error al insertar en PR_DAT_CHEQUES_TMP - '||sqlerrm);
END;

/* Cancelaci¿n Masiva de Operacion por Vencimiento */
PROCEDURE PR_CAN_MAS_VALIDACION (P_TIPO IN VARCHAR2,
                                 P_CANT OUT NUMBER) IS
   v_can_dias   number(3) := to_number(fug_obt_pardinamico('FAD_CAN_DIA_VIGENCIA'));
   v_fec_actual ge_calendarios.fec_actual%type := pae_cnf.fu_obt_fec_actual(6);
BEGIN
   IF p_tipo = 'C' THEN -- Consulta
      SELECT nvl(count(1), 0)
        INTO P_CANT
        FROM pr_fad_solicitudes a
       WHERE a.fecha + v_can_dias < v_fec_actual
         AND a.estado IN ('I', 'V', 'E', 'A');
   ELSIF p_tipo = 'A' THEN -- cAncelar
      BEGIN
         UPDATE pr_fad_solicitudes
            SET estado = 'C'
          WHERE fecha + v_can_dias < v_fec_actual
            AND estado IN ('I', 'V', 'E', 'A');
         P_CANT := 0;
      EXCEPTION
         WHEN others THEN
            P_CANT := 99;
            raise_application_error(-20000,'Error en la Cancelaci¿n Masiva - '||sqlerrm);
      END;
   END IF;
EXCEPTION
   WHEN others THEN
      P_CANT := 99;
      raise_application_error(-20000,'Error al consultar Operacion - '||sqlerrm);
END;

/* Procesar consultas a Informconf */
PROCEDURE PR_PRO_INFORMCONF (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE) IS

   v_fec_con_informconf ge_cli_antecedentes.fec_ult_informconf%type;
   v_nro_documento      pr_fad_rel_che_lib.nro_documento%type;
   v_cod_persona        ba_personas.cod_persona%type;
   v_fec_actual         ge_calendarios.fec_actual%type := pae_cnf.fu_obt_fec_actual(6);
   v_faj_buro           ge_cli_antecedentes.faj_buro%type;
   v_fec_vig_inf        number(5) := to_number(fug_obt_pardinamico('FAD_VIG_INF_COMERCIALES'));
   v_con_informconf     varchar2(1) := 'S';
   v_err_informcomf     varchar2(4000);
   
   CURSOR libradores IS
      SELECT DISTINCT a.cod_tip_documento, a.nro_documento, a.nro_solicitud
        FROM pr_fad_rel_che_lib a, pr_chq_libradores b
       WHERE a.cod_tip_documento=b.cod_tip_documento
         AND a.nro_documento=b.nro_documento
         AND nro_solicitud = p_nro_solicitud;
BEGIN

   FOR rlib IN libradores LOOP
      IF fu_val_lib_consulta(rlib.nro_solicitud, rlib.cod_tip_documento, rlib.nro_documento) = 'S' THEN
         v_nro_documento := rlib.nro_documento;
         BEGIN
            SELECT a.cod_persona
              INTO v_cod_persona
              FROM ba_personas a
             WHERE a.cod_tip_documento=rlib.cod_tip_documento
               AND a.nro_documento=rlib.nro_documento;
         EXCEPTION
            WHEN others THEN
               v_cod_persona := null;
         END;

         BEGIN
            SELECT fec_ult_informconf, faj_buro
              INTO v_fec_con_informconf, v_faj_buro
              FROM ge_cli_antecedentes
             WHERE cod_persona = v_cod_persona;
         EXCEPTION
            WHEN others THEN
               v_fec_con_informconf := null;
               v_faj_buro           := null;
         END;
         --** Validar Informconf
         IF v_fec_con_informconf IS NULL THEN
            v_con_informconf := 'S';
         ELSIF v_fec_actual - trunc(v_fec_con_informconf) > v_fec_vig_inf THEN
            v_con_informconf := 'S';
         ELSIF v_faj_buro IS NULL THEN
            v_con_informconf := 'S';
         ELSIF v_faj_buro IS NOT NULL THEN
            v_con_informconf := 'N';
         END IF;
         IF v_con_informconf = 'S' THEN
            v_err_informcomf := pag_eqf.fu_pro_dat_informconf(v_cod_persona, 'N', 99);
         END IF;
      END IF;
   END LOOP;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'Error al consultar Informconf del Librador. Doc. Nro= '||v_nro_documento||' - '||sqlerrm);
END;

/* Procesar consultas a Infocheck */
PROCEDURE PR_PRO_INFOCHECK (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE) IS

   v_fec_con_infocheck ge_cli_antecedentes.fec_ult_infocheck%type;
   v_nro_documento      pr_fad_rel_che_lib.nro_documento%type;
   v_cod_persona        ba_personas.cod_persona%type;
   v_fec_actual         ge_calendarios.fec_actual%type := pae_cnf.fu_obt_fec_actual(6);
   v_sit_infocheck      ge_cli_antecedentes.sit_infocheck%type;
   v_fec_vig_inf        number(5) := to_number(fug_obt_pardinamico('FAD_VIG_INF_COMERCIALES'));
   v_con_infocheck      varchar2(1) := 'S';
   v_err_infocheck      varchar2(4000);

   CURSOR libradores IS
      SELECT DISTINCT a.cod_tip_documento, a.nro_documento, a.nro_solicitud
        FROM pr_fad_rel_che_lib a, pr_chq_libradores b
       WHERE a.cod_tip_documento=b.cod_tip_documento
         AND a.nro_documento=b.nro_documento
         AND nro_solicitud = p_nro_solicitud;
BEGIN

   FOR rlib IN libradores LOOP
      IF fu_val_lib_consulta(rlib.nro_solicitud, rlib.cod_tip_documento, rlib.nro_documento) = 'S' THEN
         v_nro_documento := rlib.nro_documento;
         BEGIN
            SELECT a.cod_persona
              INTO v_cod_persona
              FROM ba_personas a
             WHERE a.cod_tip_documento=rlib.cod_tip_documento
               AND a.nro_documento=rlib.nro_documento;
         EXCEPTION
            WHEN others THEN
               v_cod_persona := null;
         END;

         BEGIN
            SELECT fec_ult_infocheck, sit_infocheck
              INTO v_fec_con_infocheck, v_sit_infocheck
              FROM ge_cli_antecedentes
             WHERE cod_persona = v_cod_persona;
         EXCEPTION
            WHEN others THEN
               v_fec_con_infocheck := null;
               v_sit_infocheck     := null;
         END;
         --** Validar Infocheck
         IF v_fec_con_infocheck IS NULL THEN
            v_con_infocheck := 'S';
         ELSIF v_fec_actual - trunc(v_fec_con_infocheck) > v_fec_vig_inf THEN
            v_con_infocheck := 'S';
         ELSIF v_sit_infocheck IS NULL THEN
            v_con_infocheck := 'S';
         ELSIF v_sit_infocheck IS NOT NULL THEN
            v_con_infocheck := 'N';
         END IF;
         IF v_con_infocheck = 'S' THEN
            v_err_infocheck := pag_eqf.fu_pro_dat_infocheck(v_cod_persona, 'N', 1);
         END IF;
      END IF;
   END LOOP;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'Error al consultar Infocheck del Librador. Doc. Nro= '||v_nro_documento||' - '||sqlerrm);
END;

END PAP_FAD;
/

