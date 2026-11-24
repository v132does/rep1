CREATE OR REPLACE PROCEDURE IT.PRC_DEB_SEG_VID_SOBREGIRO(p_nro_cuenta IN VARCHAR2) IS

   v_transaccion   ge_movimientos.cod_transaccion%TYPE;
   v_hora          ge_movimientos.hora%TYPE;
   v_nro_secuencia ge_movimientos.nro_secuencia%TYPE;
   v_mto_cargo     ge_movimientos.monto%TYPE;
   v_tra_iva       ge_movimientos.cod_transaccion%TYPE;
   v_importe       ge_movimientos.monto%TYPE;
   v_cotizacion    ge_movimientos.cotizacion%TYPE;
   v_imp_restante  ge_movimientos.monto%TYPE;
   r_gmovi         ge_movimientos%ROWTYPE;
   v_cod_mon_local ge_movimientos.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_mto_promedio  ge_movimientos.monto%TYPE;

   v_fcdehoy 	     ge_calendarios.fec_actual%TYPE;
   v_fcproxi 	     ge_calendarios.fec_proxima%TYPE;
   rv_gcale  	     ge_calendarios%ROWTYPE;

   v_cod_tas_cargo ge_tasas.cod_tasa%TYPE;
   v_cod_tas_iva   ge_tasas.cod_tasa%TYPE;
   v_val_tas_cargo ge_tas_fechas.val_tasa%TYPE;
   v_val_tas_iva   ge_tas_fechas.val_tasa%TYPE;

   v_modulo         ge_cuentas.cod_modulo%TYPE;
   v_modalidad      ge_cuentas.cod_modalidad%TYPE;
   v_oficina        ge_cuentas.cod_oficina%TYPE;
   v_cod_ofi_origen ge_cuentas.cod_oficina%TYPE;
   v_moneda         ge_cuentas.cod_moneda%TYPE;
   v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%TYPE;

   v_sal_disponible cc_cta_corrientes.sal_total%TYPE;
   v_mto_iva        cc_cta_corrientes.sal_total%TYPE;
   v_mto_mov        cc_cta_corrientes.sal_total%TYPE;
   v_mto_sobregiro  cc_cta_corrientes.sal_total%TYPE;
   v_cod_ente       cc_cta_corrientes.cod_ente%TYPE;
   v_cod_persona    ge_cta_clientes.cod_persona%TYPE;

   v_redondeo_ml       NUMBER(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 1, NULL,
                                                        v_cod_mon_local);
   v_redondeo          NUMBER(2);
   v_porc_char         VARCHAR2(8) := fug_obt_pardinamico('POR_ASEGURADORA');
   v_porc_aseg         NUMBER(7, 2);
   v_cod_error         NUMBER;
   v_hubo_error        VARCHAR2(1);
   e_errores_lote      EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_errores_lote, -24381);
   v_lugar             VARCHAR2(100);
   v_tas_personalizada VARCHAR2(1);
   v_tas_personalizada_2 VARCHAR2(1);
   v_iva_incluido      VARCHAR2(1);
   l_error_count    PLS_INTEGER;
   ---
   v_fre_proceso VARCHAR2(1) := fug_obt_fre_proceso('PRC_LIQ_CAR_SOBREGIROS');
   v_db_prod     VARCHAR2(1) := fug_ind_produccion;
   c_limit CONSTANT PLS_INTEGER := 15000;
   v_mto_max_sobregiro ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MTO_MAX_SOBREGIRO');
   v_eda_max_sobregiro ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('EDA_MAX_SEG_SOBREGIRO');
   v_dia_inact       ge_par_dinamicos.val_parametro%type;
   v_dia_inact_global ge_par_dinamicos.val_parametro%type;
   TYPE t_par_dinamico IS RECORD (
      cod_modulo    ge_par_dinamicos.cod_modulo%TYPE,
      cod_modalidad ge_par_dinamicos.cod_modalidad%TYPE,
      cod_moneda    ge_par_dinamicos.cod_moneda%TYPE,
      cod_oficina   ge_par_dinamicos.cod_oficina%TYPE,
      val_parametro ge_par_dinamicos.val_parametro%TYPE
   );
   TYPE t_tab_par_dinamico IS TABLE OF t_par_dinamico;
   v_tab_par_dinamico t_tab_par_dinamico;
   ---
   v_rowcount PLS_INTEGER := 0;
   v_mensaje varchar2(3000);
   TYPE t_sobregiro_info IS RECORD (
        cod_persona         ba_personas.cod_persona%TYPE,
        nro_cuenta          ge_cuentas.nro_cuenta%TYPE,
        cod_moneda          ge_cuentas.cod_moneda%TYPE,
        max_sobregiro       cc_sobregiros.saldo%TYPE,
        promedio            NUMBER, 
        tas_personalizada   ge_cuentas.tas_personalizada%TYPE,
        cod_modulo          ge_cuentas.cod_modulo%TYPE,
        cod_modalidad       ge_cuentas.cod_modalidad%TYPE,
        cod_oficina         ge_cuentas.cod_oficina%TYPE,
        cod_sub_modalidad   ge_cuentas.cod_sub_modalidad%TYPE,
        tas_personalizada_2 ba_personas.tas_personalizada%TYPE,
      cod_ente            cc_cta_corrientes.cod_ente%TYPE,
      can_dias            cc_sobregiros_res.can_dias%TYPE,
      fec_nacimiento      ba_per_fisicas.fec_nacimiento%TYPE
    );
   TYPE t_sobregiro_tab IS TABLE OF t_sobregiro_info;
   v_sobregiros t_sobregiro_tab := t_sobregiro_tab();
   CURSOR c_sob (p_nro_cuenta ge_cuentas.nro_cuenta%TYPE default NULL) IS
      SELECT p.cod_persona,
             s.nro_cuenta,
             c.cod_moneda,
             MAX(s.saldo) max_sobregiro,
             SUM(s.saldo) / COUNT(*) promedio,
             c.tas_personalizada,
             c.cod_modulo,
             c.cod_modalidad,
             c.cod_oficina,
             c.cod_sub_modalidad,
             p.tas_personalizada tas_personalizada_2,
             b.cod_ente,
             r.can_dias,
             pf.fec_nacimiento
            FROM ba_personas p, ge_cta_clientes cl, ge_cuentas c, cc_sobregiros_res r, cc_sobregiros s, cc_cta_corrientes b,
                 ba_per_fisicas pf
       WHERE s.liquidado = 'N'
         AND s.fecha BETWEEN
             to_date('01' || to_char(v_fcdehoy, 'mmyyyy'), 'ddmmyyyy') AND
             last_day(v_fcdehoy)
         AND (s.nro_cuenta = p_nro_cuenta OR p_nro_cuenta IS NULL)
         AND r.nro_cuenta(+) = s.nro_cuenta
         AND r.sit_deuda <> 'I'
         AND c.nro_cuenta = s.nro_cuenta
         AND c.nro_cuenta = b.nro_cuenta
         AND pf.cod_persona(+) = p.cod_persona
         AND c.estado NOT IN ('C', 'P', 'A', 'T', 'D', 'X')
         AND cl.nro_cuenta = s.nro_cuenta
         AND cl.relacion = 'P'
         AND p.cod_persona = cl.cod_persona
         AND p.tipo = 'F' -- Solo para personas fisicas
       GROUP BY p.cod_persona, s.nro_cuenta, c.cod_moneda, cl.cod_persona, c.tas_personalizada,c.cod_modulo,
                   c.cod_modalidad, c.cod_oficina, c.cod_sub_modalidad, p.tas_personalizada, b.cod_ente, r.can_dias, pf.fec_nacimiento;

   -- Cache por corrida; las tablas de tasas no cambian durante el proceso.
   TYPE t_cache_cod_tasa IS TABLE OF ge_tasas.cod_tasa%TYPE INDEX BY VARCHAR2(200);
   TYPE t_cache_tip_valor IS TABLE OF ge_tasas.tip_valor%TYPE INDEX BY VARCHAR2(200);
   TYPE t_cache_tipo IS TABLE OF ge_tasas.tipo%TYPE INDEX BY VARCHAR2(200);
   TYPE t_cache_val_tasa IS TABLE OF ge_tas_fechas.val_tasa%TYPE INDEX BY VARCHAR2(200);
   v_cache_cod_tasa  t_cache_cod_tasa;
   v_cache_tip_valor t_cache_tip_valor;
   v_cache_tipo      t_cache_tipo;
   v_cache_val_tasa  t_cache_val_tasa;
   TYPE t_cache_tra_hijo IS TABLE OF ge_transacciones_det.cod_tra_hijo%TYPE INDEX BY VARCHAR2(100);
   v_cache_tra_hijo  t_cache_tra_hijo;
   v_cache_sin_hijo  t_cache_tra_hijo;
   TYPE t_cache_exoneracion IS RECORD (
      valor  ge_tas_fechas.val_tasa%TYPE,
      minimo ge_tas_fechas.val_minimo%TYPE,
      maximo ge_tas_fechas.val_maximo%TYPE
   );
   TYPE t_cache_exoneraciones IS TABLE OF t_cache_exoneracion INDEX BY VARCHAR2(200);
   v_cache_exoneraciones t_cache_exoneraciones;
   -- Movimientos 1633/1634 pendientes; deben grabarse antes de buscar una hora libre.
   TYPE t_movs IS TABLE OF ge_movimientos%ROWTYPE INDEX BY PLS_INTEGER;
   v_movs_pend t_movs;
   c_lim_movs CONSTANT PLS_INTEGER := 1000;
   TYPE t_sus_cuenta IS TABLE OF cc_sob_suspenso.nro_cuenta%TYPE INDEX BY PLS_INTEGER;
   TYPE t_sus_monto IS TABLE OF cc_sob_suspenso.monto%TYPE INDEX BY PLS_INTEGER;
   TYPE t_sus_modulo IS TABLE OF cc_sob_suspenso.cod_modulo%TYPE INDEX BY PLS_INTEGER;
   TYPE t_sus_modalidad IS TABLE OF cc_sob_suspenso.cod_modalidad%TYPE INDEX BY PLS_INTEGER;
   v_sus_cuenta    t_sus_cuenta;
   v_sus_monto     t_sus_monto;
   v_sus_modulo    t_sus_modulo;
   v_sus_modalidad t_sus_modalidad;
   
  -----------
  --Funciones Internas
  -----------
    PROCEDURE pr_reg_error_lote(
    p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
    p_mensaje    IN VARCHAR2
  ) IS
  BEGIN
    pag_cie.pr_ins_log(
      'PRC_DEB_SEG_VID_SOBREGIRO cuenta ' || p_nro_cuenta || ': ' || p_mensaje,
      pag_cie.c_log_error,
      'AUTONOMOUS_TRANSACTION'
    );
  END pr_reg_error_lote;
  FUNCTION LF_OBT_HOR_DISPONIBLE(p_fecha       in date,
                                 p_hora        in varchar2,
                                 p_cod_usuario in varchar2,
                                 p_es_nocturno in varchar2)
  return varchar2 is
    -- funcion para obtener la hora que no esté utilizado en movimientos 
    v_existe varchar2(1);
    v_hora   varchar2(8) := p_hora;
    v_can_bus_hora number := 0;
    v_hor_agotada varchar2(1) := 'N';
  begin
    if p_es_nocturno = 'N' then
      loop
        v_can_bus_hora := v_can_bus_hora + 1;
        begin
          select 'S'
            into v_existe
            from ge_movimientos
           where fecha = p_fecha
             and hora = v_hora
             and cod_usuario = p_cod_usuario
             and rownum <= 1;
        exception
          when no_data_found then
            v_existe := 'N';
        end;
        exit when ((v_existe = 'N') or (v_hor_agotada = 'S'));
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
        if v_can_bus_hora >= 85000 then
           v_hor_agotada := 'S';
        end if;
      end loop;
    else -- es nocturno
      loop
        v_can_bus_hora := v_can_bus_hora + 1;
        begin
          select 'S'
            into v_existe
            from ge_movimientos_noc
           where fecha = p_fecha
             and hora = v_hora
             and cod_usuario = p_cod_usuario
             and rownum <= 1;
        exception
          when no_data_found then
            v_existe := 'N';
        end;
        exit when ((v_existe = 'N') or (v_hor_agotada = 'S'));
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
        if v_can_bus_hora >= 85000 then
           v_hor_agotada := 'S';
        end if;
      end loop;
    end if;
    if v_hor_agotada = 'S' then
      raise_application_error(-20000,'Error de Hora. No existe segundo disponible para el usuario');
    end if;
    return v_hora;
  end LF_OBT_HOR_DISPONIBLE;

  PROCEDURE lp_grabar_movs IS
  BEGIN
    IF v_movs_pend.COUNT = 0 THEN
      RETURN;
    END IF;
   FORALL k IN 1 .. v_movs_pend.COUNT
      INSERT INTO ge_movimientos(
             cod_usuario, hora, nro_secuencia, cod_modulo, cod_modalidad, cod_oficina,
             nro_cuenta, cod_moneda, cod_tra_padre, cod_transaccion, fecha, fec_valor, nro_documento,
             monto, cod_autorizacion, cod_usu_autorizador, cod_error, cod_retencion, fec_fin_retencion, est_cuenta,
             nro_documento2, nro_documento3, estado, cod_causa, cod_banco, cod_ofi_origen,
             cod_bco_central, concepto, cod_tip_ope_cambio, cod_tasa, val_tasa, reversado, cod_usu_reversion,
             hor_reversion, emi_aviso, protegido, cod_mod_padre, cod_mad_padre, tip_mov_rubro, cod_rubro,
             mto_equ_local, cotizacion, nro_documento4, nro_caja, cod_ref_cambio,
             referencia, cod_persona, cod_sit_contable)
      VALUES (
             v_movs_pend(k).cod_usuario, v_movs_pend(k).hora, v_movs_pend(k).nro_secuencia, v_movs_pend(k).cod_modulo,
             v_movs_pend(k).cod_modalidad, v_movs_pend(k).cod_oficina, v_movs_pend(k).nro_cuenta, v_movs_pend(k).cod_moneda,
             v_movs_pend(k).cod_tra_padre, v_movs_pend(k).cod_transaccion, v_movs_pend(k).fecha, v_movs_pend(k).fec_valor,
             v_movs_pend(k).nro_documento, v_movs_pend(k).monto, v_movs_pend(k).cod_autorizacion,
             v_movs_pend(k).cod_usu_autorizador, v_movs_pend(k).cod_error, v_movs_pend(k).cod_retencion,
             v_movs_pend(k).fec_fin_retencion, v_movs_pend(k).est_cuenta, v_movs_pend(k).nro_documento2,
             v_movs_pend(k).nro_documento3, v_movs_pend(k).estado, v_movs_pend(k).cod_causa, v_movs_pend(k).cod_banco,
             v_movs_pend(k).cod_ofi_origen, v_movs_pend(k).cod_bco_central, v_movs_pend(k).concepto,
             v_movs_pend(k).cod_tip_ope_cambio, v_movs_pend(k).cod_tasa, v_movs_pend(k).val_tasa, v_movs_pend(k).reversado,
             v_movs_pend(k).cod_usu_reversion, v_movs_pend(k).hor_reversion, v_movs_pend(k).emi_aviso,
             v_movs_pend(k).protegido, v_movs_pend(k).cod_mod_padre, v_movs_pend(k).cod_mad_padre,
             v_movs_pend(k).tip_mov_rubro, v_movs_pend(k).cod_rubro, v_movs_pend(k).mto_equ_local,
             v_movs_pend(k).cotizacion, v_movs_pend(k).nro_documento4, v_movs_pend(k).nro_caja,
             v_movs_pend(k).cod_ref_cambio, v_movs_pend(k).referencia, v_movs_pend(k).cod_persona,
             v_movs_pend(k).cod_sit_contable);
    v_movs_pend.DELETE;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'insertar en GE_MOVIMIENTOS (lote 1633/1634) ' || SQLERRM);
  END lp_grabar_movs;

  -- Mismo filtro que PAG_GEN.PR_INS_GE_MOVIMIENTO.
  PROCEDURE lp_encolar_mov(p_mov IN ge_movimientos%ROWTYPE) IS
  BEGIN
    IF nvl(p_mov.cod_modalidad, 0) != 149 AND nvl(p_mov.cod_mad_padre, 0) != 149 THEN
      v_movs_pend(v_movs_pend.COUNT + 1) := p_mov;
      IF v_movs_pend.COUNT >= c_lim_movs THEN
        lp_grabar_movs;
      END IF;
    END IF;
  END lp_encolar_mov;

  FUNCTION lf_obt_hora_libre(p_fecha IN DATE, p_hora IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    lp_grabar_movs;
    RETURN LF_OBT_HOR_DISPONIBLE(p_fecha, p_hora, user, 'N');
  END lf_obt_hora_libre;

    PROCEDURE lp_grabar_suspensos IS
      v_indice PLS_INTEGER;
      v_error_count PLS_INTEGER := 0;
   BEGIN
      IF v_sus_cuenta.COUNT = 0 THEN
         RETURN;
      END IF;
      BEGIN
         FORALL k IN 1 .. v_sus_cuenta.COUNT SAVE EXCEPTIONS
            INSERT INTO cc_sob_suspenso
               (nro_cuenta, fecha, cod_modulo, cod_modalidad, cod_transaccion, monto)
            VALUES
               (v_sus_cuenta(k), v_fcdehoy, v_sus_modulo(k), v_sus_modalidad(k),
                983, v_sus_monto(k));
      EXCEPTION
         WHEN e_errores_lote THEN
            FOR k IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
               v_indice := SQL%BULK_EXCEPTIONS(k).ERROR_INDEX;
               v_error_count := v_error_count + 1;
               pr_reg_error_lote(
                 v_sus_cuenta(v_indice),
                 'cc_sob_suspenso INSERT: ' || sqlerrm(-SQL%BULK_EXCEPTIONS(k).ERROR_CODE)
               );
               v_sus_cuenta.DELETE(v_indice);
               v_sus_monto.DELETE(v_indice);
               v_sus_modulo.DELETE(v_indice);
               v_sus_modalidad.DELETE(v_indice);
            END LOOP;
            if v_error_count > 0 then
              raise_application_error(-20095, 'lp_grabar_suspensos: ' || v_error_count || 
                ' error(es) en INSERT cc_sob_suspenso - revisar logs de error');
            end if;
      END;

      IF v_sus_cuenta.COUNT > 0 THEN
         BEGIN
            FORALL k IN INDICES OF v_sus_cuenta SAVE EXCEPTIONS
               UPDATE cc_sobregiros_res
                  SET mto_sob_suspenso = NVL(mto_sob_suspenso, 0) + NVL(v_sus_monto(k), 0)
                WHERE nro_cuenta = v_sus_cuenta(k);
         EXCEPTION
            WHEN e_errores_lote THEN
               DECLARE
                  v_update_errors PLS_INTEGER := 0;
               BEGIN
                  FOR k IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                     v_indice := SQL%BULK_EXCEPTIONS(k).ERROR_INDEX;
                     v_update_errors := v_update_errors + 1;
                     pr_reg_error_lote(
                       v_sus_cuenta(v_indice),
                       'cc_sobregiros_res UPDATE: ' || sqlerrm(-SQL%BULK_EXCEPTIONS(k).ERROR_CODE)
                     );
                  END LOOP;
                  raise_application_error(-20098, 'lp_grabar_suspensos: ' || v_update_errors || 
                    ' error(es) en UPDATE cc_sobregiros_res mto_sob_suspenso - revisar logs de error');
               END;
         END;
      END IF;
      v_sus_cuenta.DELETE;
      v_sus_monto.DELETE;
      v_sus_modulo.DELETE;
      v_sus_modalidad.DELETE;
   END lp_grabar_suspensos;

   FUNCTION lf_obt_val_exoneracion(
      p_cod_modulo    IN ge_cuentas.cod_modulo%TYPE,
      p_cod_modalidad IN ge_cuentas.cod_modalidad%TYPE,
      p_cod_oficina   IN ge_cuentas.cod_oficina%TYPE,
      p_cod_moneda    IN ge_cuentas.cod_moneda%TYPE,
      p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE
   ) RETURN ge_tas_fechas.val_tasa%TYPE IS
      v_clave VARCHAR2(200);
      v_cache t_cache_exoneracion;
      v_valor ge_tas_fechas.val_tasa%TYPE;
   BEGIN
      v_clave := p_cod_modulo || '|' || p_cod_modalidad || '|' || p_cod_oficina || '|' ||
                 p_cod_moneda || '|' || p_cod_transaccion || '|' || TO_CHAR(v_fcdehoy, 'YYYYMMDD');
      IF v_cache_exoneraciones.EXISTS(v_clave) THEN
         v_cache := v_cache_exoneraciones(v_clave);
         PAG_GEN.G_VAL_MINIMO := v_cache.minimo;
         PAG_GEN.G_VAL_MAXIMO := v_cache.maximo;
         RETURN v_cache.valor;
      END IF;

      v_valor := fug_obt_val_tasa(
         p_cod_modulo, p_cod_modalidad, p_cod_oficina, NULL, p_cod_moneda,
         0, 'N', NULL, p_cod_transaccion, v_fcdehoy);
      v_cache.valor  := v_valor;
      v_cache.minimo := PAG_GEN.G_VAL_MINIMO;
      v_cache.maximo := PAG_GEN.G_VAL_MAXIMO;
      v_cache_exoneraciones(v_clave) := v_cache;
      RETURN v_valor;
   END lf_obt_val_exoneracion;

   -----
   -- Procedimientos Internos
   ----
      /* Obtiene el Valor de la tasa a aplicar */
 PROCEDURE LP_OBT_VAL_TASA
     (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
     ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
     ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
     ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
     ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
     ,P_MTO_TRANSACCION IN NUMBER default 0
     ,P_TAS_PERSONALIZADA IN GE_CUENTAS.TAS_PERSONALIZADA%TYPE
     ,P_COD_TASA IN OUT GE_TASAS.COD_TASA%TYPE
     ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
     ,P_FEC_FINAL IN DATE
     ,P_VAL_TASA OUT GE_TAS_FECHAS.VAL_TASA%TYPE
     ,P_FEC_VIGENCIA OUT GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
     ,P_TIP_VALOR OUT GE_TASAS.TIP_VALOR%TYPE
     ,P_TIPO OUT GE_TASAS.TIPO%TYPE
     ,P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL
     ,P_COD_SUB_MODALIDAD IN NUMBER) 
     IS
     
     --v_cod_tasa         ge_transacciones.cod_tasa%type;
     v_clave_cache VARCHAR2(200);
   BEGIN
     v_lugar := 'LP_OBT_VAL_TASA: Mad '||p_cod_modalidad||' Tra '||P_COD_TASA;
     -- Recupera el codigo de tasa 
     BEGIN
       v_clave_cache := 'T|' || p_cod_modulo || '|' || p_cod_modalidad || '|' || p_cod_transaccion;
       IF v_cache_cod_tasa.EXISTS(v_clave_cache) THEN
          p_cod_tasa := v_cache_cod_tasa(v_clave_cache);
       ELSE
          SELECT cod_tasa
            INTO p_cod_tasa
            FROM ge_transacciones
           WHERE cod_modulo      = p_cod_modulo
             AND cod_modalidad   = p_cod_modalidad
             AND cod_transaccion = P_COD_TRANSACCION;
          v_cache_cod_tasa(v_clave_cache) := p_cod_tasa;
       END IF;
     EXCEPTION
            WHEN OTHERS THEN
             RAISE_APPLICATION_ERROR(-20001,v_lugar||' '||SQLERRM);
     END;
     -- Lee la Tabla de tasas para saber si es tarifa o porcentaje.
     BEGIN
       v_lugar := 'lp_obt_val_tasa: GE_TASAS';
       v_clave_cache := 'G|' || p_cod_tasa;
       IF v_cache_tip_valor.EXISTS(v_clave_cache) THEN
          p_tip_valor := v_cache_tip_valor(v_clave_cache);
          p_tipo      := v_cache_tipo(v_clave_cache);
       ELSE
          SELECT tip_valor, tipo
            INTO p_tip_valor, p_tipo
            FROM ge_tasas
           WHERE cod_tasa = P_COD_TASA;
          v_cache_tip_valor(v_clave_cache) := p_tip_valor;
          v_cache_tipo(v_clave_cache)      := p_tipo;
       END IF;
     EXCEPTION
          WHEN OTHERS THEN
              RAISE_APPLICATION_ERROR(-20002,' Tasa '||TO_CHAR(p_cod_tasa)||' '||p_cod_moneda||
                                     to_char(p_cod_oficina,'999')||' '||p_nro_cuenta||' '||v_lugar||' '||SQLERRM);
     END;
     /*IF P_COD_PERSONA is not null THEN
       -- ver si la persona tiene personalización de tasas
       BEGIN
         v_lugar := 'lp_obt_val_tasa: Buscando Personalización de Tasas';
          select nvl(tas_personalizada,'N')
            into v_tas_personalizada
            from ba_personas
           where cod_persona = v_cod_persona;
       EXCEPTION
          when others then
             raise_application_error(-20003,' Persona '||v_cod_persona||' '||v_lugar||' '||SQLERRM);
       END;
     END IF;*/
     if v_tas_personalizada = 'N' and v_tas_personalizada_2 = 'N' then
       DECLARE CURSOR fijas IS
           SELECT nvl(val_tasa,0)--, fec_vigencia, val_minimo, val_maximo
             FROM ge_tas_fechas
            WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
              AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
              AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
              AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
              AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
              AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
              --and nvl(tip_iva,nvl(v_tip_iva,'x'))                    = nvl(v_tip_iva,'x')
              AND cod_tasa                                           = p_cod_tasa
              AND nro_cuenta  IS NULL
              and cod_persona IS NULL
              and fec_vigencia                                      <= P_FEC_FINAL
         ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                  DECODE(COD_MODALIDAD, NULL, 0, 1) +
                  DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC;

          BEGIN
            
            v_lugar := 'lp_obt_val_tasa: GE_TAS_FECHAS (gral)';
            v_clave_cache := 'F|' || p_cod_modulo || '|' || p_cod_modalidad || '|' || v_cod_sub_modalidad || '|' ||
                             p_cod_oficina || '|' || v_cod_ente || '|' || p_cod_moneda || '|' || p_cod_tasa || '|' ||
                             TO_CHAR(p_fec_final, 'YYYYMMDD');
            IF v_cache_val_tasa.EXISTS(v_clave_cache) THEN
               p_val_tasa := v_cache_val_tasa(v_clave_cache);
            ELSE
               IF fijas%isopen THEN
                  CLOSE fijas;
               END IF;
               OPEN fijas;
                  FETCH fijas INTO p_val_tasa;--, p_fec_vigencia, v_aux_val_min, v_aux_val_max;
               IF FIJAS%NOTFOUND THEN
                  --No es un error propiamente, por eso se omite el SQLERRM (ORA-0000, Normal succesful completion)
                  RAISE_APPLICATION_ERROR(-20006,'No se han recuperado datos para la Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                                  v_lugar||'- para '||p_cod_moneda);
               END IF;
               CLOSE FIJAS;
               v_cache_val_tasa(v_clave_cache) := p_val_tasa;
            END IF;
          END;
     else
       if v_tas_personalizada = 'S' then
         --buscar tasa personalizada x cuenta
          BEGIN
             v_lugar := 'lp_obt_val_tasa: GE_TAS_FECHAS (personalizado fijo x cuenta)';
             SELECT nvl(val_tasa,-999)--, fec_vigencia, val_minimo, val_maximo, val_extension
               INTO p_val_tasa--, p_fec_vigencia, g_val_minimo, g_val_maximo, v_spread
               FROM ge_tas_fechas
              WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                --AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x') DYDMR-5313 La personalizacion por cuentas asume la moneda de la cuenta automaticamente
                AND nro_cuenta                                         = p_nro_cuenta --cuenta
                AND cod_tasa                                           = p_cod_tasa
                AND fec_vigencia                                       =(SELECT MAX(fec_vigencia)
                                                                           FROM  ge_tas_fechas
                                                                          WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                                                                            AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                                                                            AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                                                                            AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                                                                            AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                                                                           -- AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x') DYDMR-5313
                                                                            AND nro_cuenta                                         = p_nro_cuenta --cuenta
                                                                            AND cod_tasa                                           = p_cod_tasa
                                                                            AND fec_vigencia                                      <= P_FEC_FINAL);
         EXCEPTION 
           WHEN NO_DATA_FOUND THEN
             DECLARE CURSOR fijas IS
               SELECT nvl(val_tasa,0)--, fec_vigencia, val_minimo, val_maximo
                 FROM ge_tas_fechas
                WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                  AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                  AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                  AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                  AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                  AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                  --and nvl(tip_iva,nvl(v_tip_iva,'x'))                    = nvl(v_tip_iva,'x')
                  AND cod_tasa                                           = p_cod_tasa
                  AND nro_cuenta  IS NULL
                  and cod_persona IS NULL
                  and fec_vigencia                                      <= P_FEC_FINAL
             ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                      DECODE(COD_MODALIDAD, NULL, 0, 1) +
                      DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC;

              BEGIN
                
                v_lugar := 'lp_obt_val_tasa: GE_TAS_FECHAS (gral)';
                IF fijas%isopen THEN
                   CLOSE fijas;
                END IF;
                OPEN fijas;
                   FETCH fijas INTO p_val_tasa;--, p_fec_vigencia, v_aux_val_min, v_aux_val_max;
                IF FIJAS%NOTFOUND THEN
                   --No es un error propiamente, por eso se omite el SQLERRM (ORA-0000, Normal succesful completion)
                   RAISE_APPLICATION_ERROR(-20006,'No se han recuperado datos para la Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                                   v_lugar||'- para '||p_cod_moneda);
                END IF;
                CLOSE FIJAS;
              END;
         END;
       else
         if v_tas_personalizada_2 = 'S' then
           --buscar tasa personalizada x persona
           v_lugar := 'lp_obt_val_tasa: GE_TAS_FECHAS (personalizado fijo x persona)';
           --begin
             SELECT nvl(val_tasa,-999)--, fec_vigencia, val_minimo, val_maximo, val_extension
               INTO p_val_tasa--, p_fec_vigencia, g_val_minimo, g_val_maximo, v_spread
               FROM ge_tas_fechas
              WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                AND nro_cuenta IS NULL
                AND cod_tasa                                           = p_cod_tasa
                and cod_persona                                        = v_cod_persona  --persona
                AND fec_vigencia                                       =(SELECT MAX(fec_vigencia)
                                                                           FROM  ge_tas_fechas
                                                                          WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                                                                            AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                                                                            AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                                                                            AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                                                                            AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                                                                            AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                                                                            AND nro_cuenta IS NULL
                                                                            AND cod_tasa                                           = p_cod_tasa
                                                                            and cod_persona                                        = p_cod_persona --persona
                                                                            AND fec_vigencia                                      <= P_FEC_FINAL);
         end if;
       end if;
     end if; 
 END LP_OBT_VAL_TASA;
   
   PROCEDURE pr_obt_cargos
   (
      p_cod_ofi_origen   IN ge_cuentas.cod_oficina%TYPE,
      p_nro_cuenta       IN ge_cuentas.nro_cuenta%TYPE,
      p_cod_moneda       IN ge_cuentas.cod_moneda%TYPE,
      p_monto            IN ge_movimientos.monto%TYPE,
      p_cod_modulo       IN ge_cuentas.cod_modulo%TYPE,
      p_cod_modalidad    IN ge_cuentas.cod_modalidad%TYPE,
      p_cod_tra_cargo    IN ge_movimientos.cod_transaccion%TYPE,
      p_iva_incluido     IN VARCHAR2 DEFAULT 'S',
      p_tas_personalizada IN ge_cuentas.tas_personalizada%TYPE,
      p_cod_tas_cargo    OUT ge_movimientos.cod_tasa%TYPE,
      p_val_tas_cargo    OUT ge_movimientos.val_tasa%TYPE,
      p_val_cargo        OUT ge_movimientos.val_tasa%TYPE,
      p_cod_tra_impuesto OUT ge_movimientos.cod_transaccion%TYPE,
      p_cod_tas_impuesto OUT ge_movimientos.cod_tasa%TYPE,
      p_val_tas_impuesto OUT ge_movimientos.val_tasa%TYPE,
      p_val_impuesto     OUT ge_movimientos.val_tasa%TYPE
   ) IS
      v_val_base          NUMBER(18, 2) := p_monto;
      v_fec_vigencia      DATE;
      v_tip_valor         VARCHAR2(1);
      v_tipo              VARCHAR2(1);
      --v_redondeo          NUMBER(1);
      --v_tas_personalizada VARCHAR2(1);
      ---
      v_val_exo_cargo    ge_movimientos.val_tasa%type;
      v_val_exo_impuesto ge_movimientos.val_tasa%type;
      v_clave_tra        VARCHAR2(100);
      v_cargo_prohibido  VARCHAR2(1);
   BEGIN
      -- busco el valor de la tasa
      LP_OBT_VAL_TASA(p_cod_modulo
                     ,p_cod_modalidad
                     ,p_cod_ofi_origen
                     ,p_nro_cuenta
                     ,p_cod_moneda
                     ,v_val_base
                     ,V_TAS_PERSONALIZADA
                     ,p_cod_tas_cargo
                     ,p_cod_tra_cargo
                     ,trunc(SYSDATE)
                     ,p_val_tas_cargo
                     ,v_fec_vigencia
                     ,v_tip_valor
                     ,v_tipo
                     ,V_COD_PERSONA
                     ,V_COD_SUB_MODALIDAD);
                     
      IF v_tip_valor = 'V' THEN
         -- si es un valor, se toma directamente
         p_val_cargo := nvl(p_val_tas_cargo, 0);
      ELSE
         -- es un porcentaje
         p_val_cargo := round(nvl(v_val_base, 0) * nvl(p_val_tas_cargo, 0) / 100, v_redondeo);
         --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
         p_val_cargo := pag_gen.fu_obt_val_final(p_val_cargo);
      END IF;

      /*
      || PCC-Exoneración y Extorno de Comisiones y Tasas
      || Se ejecuta si el proceso no es mensual
      || o la base de datos no es producción
      */
      IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
         -- busco el valor de la tasa
         begin
            v_val_exo_cargo := lf_obt_val_exoneracion(p_cod_modulo,
                                                      p_cod_modalidad,
                                                      p_cod_ofi_origen,
                                                      p_cod_moneda,
                                                      p_cod_tra_cargo);
         exception
            when others then
               raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
         end;
         IF v_tip_valor = 'V' THEN
            -- si es un valor, se toma directamente
            v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
         ELSE
            -- es un porcentaje
            v_val_exo_cargo := round(nvl(v_val_base, 0) * nvl(v_val_exo_cargo, 0) / 100, v_redondeo);
            --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
            v_val_exo_cargo := pag_gen.fu_obt_val_final(v_val_exo_cargo);
         END IF;
      end if;
      ---
      -- busco el impuesto asociado a este cargo
      BEGIN
         v_clave_tra := p_cod_modulo || '|' || p_cod_modalidad || '|' || p_cod_tra_cargo;
         IF v_cache_tra_hijo.EXISTS(v_clave_tra) THEN
            p_cod_tra_impuesto := v_cache_tra_hijo(v_clave_tra);
         ELSIF v_cache_sin_hijo.EXISTS(v_clave_tra) THEN
            RAISE NO_DATA_FOUND;
         ELSE
            BEGIN
               SELECT cod_tra_hijo
                 INTO p_cod_tra_impuesto
                 FROM ge_transacciones_det
                WHERE cod_modulo = p_cod_modulo
                  AND cod_modalidad = p_cod_modalidad
                  AND cod_transaccion = p_cod_tra_cargo
                  AND cod_mod_hijo = p_cod_modulo
                  AND cod_mad_hijo = p_cod_modalidad
                  AND rownum = 1;
               v_cache_tra_hijo(v_clave_tra) := p_cod_tra_impuesto;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_cache_sin_hijo(v_clave_tra) := NULL;
                  RAISE;
            END;
         END IF;
         -- veo si la cuenta tiene exoneracion de impuestos
         --IF pag_cta.fu_ver_tra_prohibida(p_nro_cuenta, p_cod_tra_impuesto, p_cod_modulo,
         --                                p_cod_modalidad) = 'N' THEN
         -- Se encontró impuesto asociado, se calcula
         LP_OBT_VAL_TASA(p_cod_modulo
                        ,p_cod_modalidad
                        ,p_cod_ofi_origen
                        ,p_nro_cuenta
                        ,p_cod_moneda
                        ,p_val_cargo
                        ,V_TAS_PERSONALIZADA
                        ,p_cod_tas_impuesto
                        ,p_cod_tra_impuesto
                        ,trunc(SYSDATE)
                        ,p_val_tas_impuesto
                        ,v_fec_vigencia
                        ,v_tip_valor
                        ,v_tipo
                        ,V_COD_PERSONA
                        ,V_COD_SUB_MODALIDAD);
                        
         IF v_tip_valor = 'V' THEN
            -- si es un valor, se toma directamente
            p_val_impuesto := nvl(p_val_tas_impuesto, 0);
         ELSE
            -- es un porcentaje, se considera incluido en el cargo
            p_val_impuesto := round(nvl(p_val_cargo, 0) * nvl(p_val_tas_impuesto, 0) /
                                    (100 + p_val_tas_impuesto), v_redondeo);
            --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
            p_val_impuesto := pag_gen.fu_obt_val_final(p_val_impuesto);
         END IF;
         IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
            begin
               v_val_exo_impuesto := lf_obt_val_exoneracion(p_cod_modulo,
                                                            p_cod_modalidad,
                                                            p_cod_ofi_origen,
                                                            p_cod_moneda,
                                                            p_cod_tra_impuesto);
            exception
               when others then
                  raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
            end;
            IF v_tip_valor = 'V' THEN
               -- si es un valor, se toma directamente
               v_val_exo_impuesto := nvl(v_val_exo_impuesto, 0);
            ELSE
               -- es un porcentaje, se considera incluido en el cargo
               v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_exo_impuesto, 0) /
                                       (100 + v_val_exo_impuesto), v_redondeo);
               --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
               v_val_exo_impuesto := pag_gen.fu_obt_val_final(v_val_exo_impuesto);
            END IF;
         END IF;
         -- resto el monto del impuesto al cargo, porque va incluido
         IF nvl(p_iva_incluido, 'S') = 'S' THEN
            p_val_cargo := nvl(p_val_cargo, 0) - nvl(p_val_impuesto, 0);
            IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
               v_val_exo_cargo := nvl(v_val_exo_cargo, 0) - nvl(v_val_exo_impuesto, 0);
            END IF;
         END IF;
         IF p_val_cargo < 0 THEN
            raise_application_error(-20000, 'Impuesto mas alto que el Cargo');
         END IF;
         v_cargo_prohibido := pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                                            p_cod_tra_cargo,
                                                            p_cod_modulo,
                                                            p_cod_modalidad);
         if v_cargo_prohibido = 'S' then
            p_val_cargo := 0;
            IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
               prg_ins_exoneracion(p_cod_tra_cargo, p_cod_modulo,
                                   p_cod_modalidad, p_cod_moneda,
                                   p_nro_cuenta, null, p_cod_tas_cargo,
                                   nvl(v_val_exo_cargo, 0),
                                   nvl(v_val_exo_cargo, 0), null,
                                   nvl(v_val_exo_cargo, 0));
            end if;
         elsif (nvl(v_val_exo_cargo, 0) <> nvl(p_val_cargo, 0)) or
               (nvl(p_val_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
            IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
               prg_ins_exoneracion(p_cod_tra_cargo, p_cod_modulo,
                                   p_cod_modalidad, p_cod_moneda,
                                   p_nro_cuenta, null, p_cod_tas_cargo,
                                   (nvl(v_val_exo_cargo, 0) - nvl(p_val_cargo, 0)),
                                    v_val_exo_cargo, null,
                                   (nvl(v_val_exo_cargo, 0) - nvl(p_val_cargo, 0)));
            end if;
         end if;
         --ELSE
         if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                         p_cod_tra_impuesto,
                                         p_cod_modulo,
                                         p_cod_modalidad) = 'S' then
            p_val_impuesto := 0;
            IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
               prg_ins_exoneracion(p_cod_tra_impuesto, p_cod_modulo,
                                   p_cod_modalidad, p_cod_moneda,
                                   p_nro_cuenta, null, p_cod_tas_impuesto,
                                   nvl(v_val_exo_impuesto, 0),
                                   nvl(v_val_exo_impuesto, 0), null,
                                   nvl(v_val_exo_impuesto, 0));
            end if;
         elsif v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
            if v_cargo_prohibido = 'S' then
               null;
            elsif (nvl(v_val_exo_impuesto, 0) <> nvl(p_val_impuesto, 0)) or
                  (nvl(p_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
               prg_ins_exoneracion(p_cod_tra_impuesto, p_cod_modulo,
                                   p_cod_modalidad, p_cod_moneda,
                                   p_nro_cuenta, null, p_cod_tas_impuesto,
                                   (nvl(v_val_exo_impuesto, 0) - nvl(p_val_impuesto, 0)),
                                    v_val_exo_impuesto, null,
                                   (nvl(v_val_exo_impuesto, 0) - nvl(p_val_impuesto, 0)));
            end if;
         end if;
         ---
      EXCEPTION
         WHEN no_data_found THEN
            p_val_impuesto := 0;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al leer Impuesto ' || SQLERRM);
      END;
      ---END IF;
   END;

   --------------------------------------------------------------------------------------------

   PROCEDURE lp_act_sal_mensual
   (
      p_total   IN NUMBER,
      p_cdmodul IN NUMBER,
      p_cdmodal IN NUMBER,
      p_cdofici IN NUMBER,
      p_nrcuent IN VARCHAR2
   ) IS
      v_dias    NUMBER(2, 0);
      v_salinic cc_cta_corrientes.sal_total%TYPE;
      v_atransf cc_cta_corrientes.sal_total%TYPE;
      v_ctacomb VARCHAR2(1);
   BEGIN
      SELECT nvl(cc.sal_total, 0) - nvl(cc.sal_retenido, 0),
             decode(nro_cta_cte, '', 0, nvl(cco.sal_minimo, fug_obt_sal_min_traspaso(nro_cta_cte))),
             nvl(cc.cta_combinada, 'N')
        INTO v_salinic, v_atransf, v_ctacomb
        FROM cc_cta_combinadas cco, cc_cta_corrientes cc
       WHERE cco.nro_cta_cte(+) = cc.nro_cuenta
         AND cc.cod_modulo = p_cdmodul
         AND cc.cod_modalidad = p_cdmodal
         AND cc.cod_oficina = p_cdofici
         AND cc.nro_cuenta = p_nrcuent;
      IF v_ctacomb = 'S' AND v_salinic > v_atransf THEN
         v_salinic := v_atransf;
      END IF;
      UPDATE cc_sal_mensuales
         SET sal_ini_mes = nvl(v_salinic, 0)
       WHERE cod_modulo = p_cdmodul
         AND cod_modalidad = p_cdmodal
         AND cod_oficina = p_cdofici
         AND nro_cuenta = p_nrcuent
         AND ano = to_number(to_char(v_fcproxi, 'YYYY'))
         AND mes = to_number(to_char(v_fcproxi, 'MM'));
      IF v_fcdehoy + 1 <> v_fcproxi THEN
         v_dias := to_number(to_char(v_fcproxi, 'DD')) - 1;
         /* Actualiza valores saldo acumulado del mes*/
         UPDATE cc_sal_mensuales
            SET sal_acu_diario = v_dias * nvl(v_salinic, 0)
          WHERE cod_modulo = p_cdmodul
            AND cod_modalidad = p_cdmodal
            AND cod_oficina = p_cdofici
            AND nro_cuenta = p_nrcuent
            AND ano = to_number(to_char(v_fcproxi, 'YYYY'))
            AND mes = to_number(to_char(v_fcproxi, 'MM'));
         -- SALDOS DEUDORES --
         ------------------------------------------------------------
         IF nvl(v_salinic, 0) < 0 THEN
            UPDATE cc_sal_mensuales
               SET sal_acu_deudor   = v_dias * nvl(v_salinic, 0) * -1,
                   can_dia_deudor   = v_dias,
                   sal_acu_acreedor = 0,
                   can_dia_acreedor = 0
             WHERE cod_modulo = p_cdmodul
               AND cod_modalidad = p_cdmodal
               AND cod_oficina = p_cdofici
               AND nro_cuenta = p_nrcuent
               AND ano = to_number(to_char(v_fcproxi, 'YYYY'))
               AND mes = to_number(to_char(v_fcproxi, 'MM'));
            -- SALDOS ACREEDORES -- menor a cero
            ------------------------------------------------------------
         ELSE
            UPDATE cc_sal_mensuales
               SET sal_acu_acreedor = v_dias * nvl(v_salinic, 0),
                   can_dia_acreedor = v_dias,
                   sal_acu_deudor   = 0,
                   can_dia_deudor   = 0
             WHERE cod_modulo = p_cdmodul
               AND cod_modalidad = p_cdmodal
               AND cod_oficina = p_cdofici
               AND nro_cuenta = p_nrcuent
               AND ano = to_number(to_char(v_fcproxi, 'YYYY'))
               AND mes = to_number(to_char(v_fcproxi, 'MM'));
         END IF;
      END IF;
      --  IF SQL%NOTFOUND THEN
      --  raise_application_error(-20000,'No existe reg de mes proximo en CC_SAL_MENSUALES');
      --  END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error ' || p_nrcuent || ' ' || SQLERRM);
   END;

   ---------------------------------------------------------------------------------
   FUNCTION fu_redondear_centena(p_importe IN NUMBER) RETURN NUMBER IS
      v_imp     NUMBER;
      v_imp_cen NUMBER;

   BEGIN
      IF p_importe / 100 = trunc(p_importe / 100) THEN
         -- esta bien
         v_imp_cen := p_importe;
      ELSE
         v_imp     := round(p_importe / 100);
         v_imp_cen := v_imp * 100;
         LOOP
            IF v_imp_cen > p_importe THEN
               EXIT;
            END IF;
            v_imp_cen := v_imp_cen + 100;
         END LOOP;
      END IF;
      RETURN v_imp_cen;
   END;
   --------------------------------------------------------------------------------------------
   -- PROCEDIMIENTO PRINCIPAL
   --------------------------------------------------------------------------------------------
BEGIN
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 4;
   END;
   DBMS_APPLICATION_INFO.SET_ACTION('PRC_LIQ_CAR_SOBREGIROS');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRC_LIQ_CAR_SOBREGIROS ejec PRC_DEB_SEG_VID_SOBREGIRO');
   --v_hora          := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   v_hora := to_char(sysdate,'HH24:MI:SS');
   v_nro_secuencia := -999;
   v_fcdehoy       := pag_cal.fu_obt_fec_actual(4);
   ---
   v_hora := LF_OBT_HOR_DISPONIBLE(v_fcdehoy,v_hora,user,'N');
   --
   rv_gcale        := pag_cal.fu_obt_reg_cal(1);
   v_fcproxi       := rv_gcale.fec_proxima;

   --busco oficina origen
   BEGIN
      SELECT cod_oficina INTO v_cod_ofi_origen FROM ba_usuarios WHERE cod_usuario = USER;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(20009, 'Al recup. oficina del usuario ' || SQLERRM);
   END;

      SELECT cod_modulo, cod_modalidad, cod_moneda, cod_oficina, val_parametro
        BULK COLLECT INTO v_tab_par_dinamico
        FROM ge_par_dinamicos
       WHERE parametro = 'DIA_INA_CAR_SOBREGIROS'
       ORDER BY DECODE(cod_modulo, NULL, 0, 1) +
                DECODE(cod_modalidad, NULL, 0, 1) +
                DECODE(cod_moneda, NULL, 0, 1) +
                DECODE(cod_oficina, NULL, 0, 1) DESC;

      IF v_tab_par_dinamico.COUNT = 0 THEN
         v_dia_inact_global := '9999';
      ELSIF v_tab_par_dinamico.COUNT = 1
         AND v_tab_par_dinamico(1).cod_modulo IS NULL
         AND v_tab_par_dinamico(1).cod_modalidad IS NULL
         AND v_tab_par_dinamico(1).cod_moneda IS NULL
         AND v_tab_par_dinamico(1).cod_oficina IS NULL THEN
         v_dia_inact_global := NVL(v_tab_par_dinamico(1).val_parametro, '9999');
      ELSE
         v_dia_inact_global := NULL;
      END IF;

   IF c_sob%ISOPEN THEN
      CLOSE c_sob;
   END IF;
   --------
   OPEN c_sob(p_nro_cuenta);
   LOOP
     FETCH c_sob BULK COLLECT INTO v_sobregiros LIMIT c_limit;
     --FOR reg IN c_sob LOOP
     FOR i IN 1 .. v_sobregiros.COUNT LOOP
        v_rowcount := v_rowcount + 1;
        v_hubo_error := 'N';
        IF v_dia_inact_global IS NOT NULL THEN
           v_dia_inact := v_dia_inact_global;
        ELSE
           v_dia_inact := '9999';
           FOR p IN 1 .. v_tab_par_dinamico.COUNT LOOP
              IF (v_tab_par_dinamico(p).cod_modulo IS NULL OR v_tab_par_dinamico(p).cod_modulo = v_sobregiros(i).cod_modulo)
                 AND (v_tab_par_dinamico(p).cod_modalidad IS NULL OR v_tab_par_dinamico(p).cod_modalidad = v_sobregiros(i).cod_modalidad)
                 AND (v_tab_par_dinamico(p).cod_moneda IS NULL OR v_tab_par_dinamico(p).cod_moneda = v_sobregiros(i).cod_moneda)
                 AND (v_tab_par_dinamico(p).cod_oficina IS NULL OR v_tab_par_dinamico(p).cod_oficina = v_sobregiros(i).cod_oficina) THEN
                 v_dia_inact := v_tab_par_dinamico(p).val_parametro;
                 EXIT;
              END IF;
           END LOOP;
        END IF;
        IF v_sobregiros(i).can_dias >= NVL(TO_NUMBER(v_dia_inact), 9999) THEN
           GOTO siguiente;
        END IF;
        -- Solo entra aquí cada 10,000 registros
        IF MOD(v_rowcount, 10000) = 0 THEN
          v_mensaje := v_rowcount||' cuentas procesadas';
          DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
        END IF;
        
        /* El cargo es solo para personas menores a lo parametrizado en EDA_MAX_SEG_SOBREGIRO */
        if v_eda_max_sobregiro is not null then
          IF trunc((trunc(SYSDATE) - v_sobregiros(i).fec_nacimiento) / 365) >= v_eda_max_sobregiro THEN
            GOTO siguiente;
          END IF;
        end if;
        --- Recuperar datos de la cuenta
        pag_cta.pr_obt_cuenta(v_sobregiros(i).nro_cuenta);
        v_moneda    := pag_cta.g_ctas.cod_moneda;
        v_modulo    := pag_cta.g_ctas.cod_modulo;
        v_modalidad := pag_cta.g_ctas.cod_modalidad;
        v_oficina   := pag_cta.g_ctas.cod_oficina;
        v_cod_persona := v_sobregiros(i).cod_persona;
        v_cod_sub_modalidad := v_sobregiros(i).cod_sub_modalidad;
        v_cod_ente  := v_sobregiros(i).cod_ente;
        IF pag_cta.g_cod_error <> 0 THEN
           v_cod_error  := 104;
           v_lugar      := 'Recup. datos de la cuenta ' || v_sobregiros(i).nro_cuenta || ' - ' ||
                           pag_cta.g_msj_error;
           v_hubo_error := 'S';
           GOTO siguiente;
        END IF;
        -- Verificar si la cuenta tiene tasa personalizada
        v_tas_personalizada := v_sobregiros(i).tas_personalizada;-- de ge_cuentas
        v_taS_personalizada_2 := v_sobregiros(i).tas_personalizada_2;-- de ba_personas
        -- Verifico el estado del sobregiro, si esta en gestion se genera el movimiento
        -- con otra transaccion
        IF nvl(pac_sob.fu_sit_sobregiro(v_sobregiros(i).nro_cuenta), 'S') NOT IN ('S', 'V') THEN
           -- En gestion, mayor a 60 dias
           v_transaccion := 983; --Transaccion para sobregiros en gestion
        ELSE
           v_transaccion := 989; --Transaccion para el cargo
        END IF;
        --
        v_sal_disponible := pag_cta.g_ctas.sal_disponible;
        v_mto_sobregiro  := v_sobregiros(i).max_sobregiro;
        -- Redondea el promedio de acuerdo a la moneda de la cuenta
        if v_sobregiros(i).cod_moneda = v_cod_mon_local then
          v_redondeo     := v_redondeo_ml;--fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 1, NULL, v_sobregiros(i).cod_moneda);
        else
          v_redondeo     := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 1, NULL, v_sobregiros(i).cod_moneda);
        end if;
        v_mto_promedio := round(v_sobregiros(i).promedio, v_redondeo);
        --calcular el monto e impuesto, en base al monto imponible
        BEGIN
           DBMS_APPLICATION_INFO.SET_ACTION('SEG_PR_OBT_CARGOS');
           v_lugar := 'cta : ' || v_sobregiros(i).nro_cuenta || ' pr_obt_Cargos';
           -- Si el monto del sobregisto supera lo parametizado como monto maximo
           -- cobrar el cargo solo hasta ese monto maximo, el parametro se asume esta en moneda local,
           -- convertir a la moneda local
           IF v_sobregiros(i).cod_moneda = v_cod_mon_local THEN
              -- Con igual moneda FU_CON_MON_A_MONEDA devuelve el mismo monto.
              IF v_mto_promedio > v_mto_max_sobregiro THEN
                 v_mto_sobregiro := v_mto_max_sobregiro;
              END IF;
           ELSIF pag_gen.fu_con_mon_a_moneda(v_sobregiros(i).cod_moneda, v_cod_mon_local, v_mto_promedio) >
              v_mto_max_sobregiro THEN
              v_mto_sobregiro := pag_gen.fu_con_mon_a_moneda(v_cod_mon_local, v_sobregiros(i).cod_moneda,
                                                             v_mto_max_sobregiro);
           END IF;
           pr_obt_cargos(v_oficina, v_sobregiros(i).nro_cuenta, v_sobregiros(i).cod_moneda, v_mto_sobregiro,
                         pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_transaccion,
                         v_iva_incluido, v_tas_personalizada, v_cod_tas_cargo, v_val_tas_cargo, v_mto_cargo, v_tra_iva,
                         v_cod_tas_iva, v_val_tas_iva, v_mto_iva);
        EXCEPTION
           WHEN OTHERS THEN
              v_cod_error  := 107;
              v_lugar      := SQLERRM;
              v_hubo_error := 'S';
              GOTO siguiente;
        END;
        --monto operación es el cargo + el impuesto
        v_mto_mov := nvl(v_mto_cargo, 0) + nvl(v_mto_iva, 0);
        IF v_mto_mov = 0 THEN
           GOTO siguiente;
        END IF;

        --si el saldo es suficiente, genera el movimiento, sino le sobregira
        --if v_mto_cargo > 0 and v_sal_disponible >= v_mto_mov then
        --- Actualizar los datos de las cuentas con movimientos.
        IF v_nro_secuencia > 990 THEN
           --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
           v_hora := lf_obt_hora_libre(v_fcdehoy, v_hora);
           v_nro_secuencia := -999;
        END IF;
        pag_cta.g_sobregira := 'S';
      DBMS_APPLICATION_INFO.SET_ACTION('SEG_PR_ACT_OPERACION');
      v_lugar             := '1- PR_aCT_OPERACION';
      IF nvl(v_mto_cargo, 0) > 0 THEN
      BEGIN
      pag_cta.pr_act_operacion(v_sobregiros(i).nro_cuenta -- P_NRO_CUENTA
                                , v_hora
                                 -- P_HORA
                                , 'D'
                                 -- P_TIP_MOVIMIENTO
                                , pag_cta.g_ctas.cod_moneda
                                 -- P_COD_MONEDA
                                , v_mto_cargo
                                 -- P_MONTO
                                , v_transaccion
                                 -- P_COD_TRA_PADRE
                                , v_transaccion
                                 -- P_COD_TRANSACCION
                                , NULL
                                 --P_NRO_DOCUMENTO
                                , NULL
                                 --P_COTIZACION
                                , pag_cta.g_ctas.cod_oficina
                                 -- P_COD_OFI_ORIGEN
                                , pag_cta.g_ctas.cod_modulo
                                 -- P_COD_MOD_PADRE
                                , pag_cta.g_ctas.cod_modalidad
                                 -- P_COD_MAD_PADRE
                                , v_cod_tas_cargo
                                 --P_COD_TASA
                                , v_val_tas_cargo
                                 --P_VAL_TASA
                                , 'CARGO SEGURO DE VIDA SOBRE SOBREGIRO'
                                 -- P_CONCEPTO
                                , 'N'
                                 -- p_EMI_AVISO
                                , v_nro_secuencia
                                 -- P_NRO_SECUENCIA IN OUT
                                , v_fcdehoy
                                 -- P_FEC_VALOR
                                , NULL
                                 -- P_COD_BANCO
                                , NULL
                                 -- P_COD_CAUSA
                                 , NULL); -- P_MTO_EQU_LOCAL
        EXCEPTION
           WHEN OTHERS THEN
              RAISE;
        END;

        IF pag_cta.fu_obt_cod_error() <> 0 THEN
           v_cod_error  := pag_cta.g_cod_error;
           v_lugar      := 'Mov.Cta.(cargo) ' || pag_cta.fu_obt_msj_error();
           v_hubo_error := 'S';
           GOTO siguiente;
        END IF;
         END IF;
        IF v_mto_iva > 0 THEN
           --generar movimiento x el iva
           --- Actualizar los datos de las cuentas con movimientos.
           IF v_nro_secuencia > 990 THEN
              --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
              v_hora := lf_obt_hora_libre(v_fcdehoy, v_hora);
              v_nro_secuencia := -999;
           END IF;
           DBMS_APPLICATION_INFO.SET_ACTION('SEG_PR_ACT_OPERACION');
           v_lugar := '2- PR_ACT_OPERACION';
           BEGIN
           pag_cta.pr_act_operacion(v_sobregiros(i).nro_cuenta -- P_NRO_CUENTA
                                   , v_hora
                                    -- P_HORA
                                   , 'D'
                                    -- P_TIP_MOVIMIENTO
                                   , pag_cta.g_ctas.cod_moneda
                                    -- P_COD_MONEDA
                                   , v_mto_iva
                                    -- P_MONTO
                                    --                 ,v_transaccion -- P_COD_TRA_PADRE
                                   , v_tra_iva
                                    --  P_COD_TRA_PADRE
                                   , v_tra_iva
                                    --  P_COD_TRANSACCION
                                   , NULL
                                    --P_NRO_DOCUMENTO
                                   , NULL
                                    --P_COTIZACION
                                   , pag_cta.g_ctas.cod_oficina
                                    -- P_COD_OFI_ORIGEN
                                   , pag_cta.g_ctas.cod_modulo
                                    -- P_COD_MOD_PADRE
                                   , pag_cta.g_ctas.cod_modalidad
                                    -- P_COD_MAD_PADRE
                                   , v_cod_tas_iva
                                    --P_COD_TASA
                                   , v_val_tas_iva
                                    --P_VAL_TASA
                                   , 'IVA S/ CARGO SEGURO DE VIDA SOBRE SOBREGIRO'
                                    -- P_CONCEPTO
                                   , 'N'
                                    -- p_EMI_AVISO
                                   , v_nro_secuencia
                                    -- P_NRO_SECUENCIA IN OUT
                                   , v_fcdehoy
                                    -- P_FEC_VALOR
                                   , NULL
                                    -- P_COD_BANCO
                                   , NULL
                                    -- P_COD_CAUSA
                                   , NULL); -- P_MTO_EQU_LOCAL
           EXCEPTION
              WHEN OTHERS THEN
                 RAISE;
           END;

           IF pag_cta.fu_obt_cod_error() <> 0 THEN
              v_cod_error  := pag_cta.g_cod_error;
              v_lugar      := 'Mov.Cta.(iva) ' || pag_cta.fu_obt_msj_error();
              v_hubo_error := 'S';
              GOTO siguiente;
           END IF;
        END IF;

        -- actualizar el acumulado de saldos mensuales
        IF to_char(v_fcproxi, 'mmyyyy') <> to_char(v_fcdehoy, 'mmyyyy') THEN
           lp_act_sal_mensual(v_mto_mov, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                              pag_cta.g_ctas.cod_oficina, v_sobregiros(i).nro_cuenta);
        END IF;
        ---
        ---  GENERAR LOS MOVIMIENTOS CONTABLES
        ---
        ---  El cargo total se debita al cliente y el crédito se divide entre el Banco
        ---  y la Compañía Aseguradora.
        ---  A la Compañía Aseguradora se le acredita en una cuenta transitoria y cuando viene la factura
        ---  se hace el crédito en la cuenta de la aseguradora y el resto se contabiliza
        ---  como ganancia para el Banco.
        ---
        -- Traigo el porcentaje de la prima que le corresponde a la aseguradora.
        -- A la Aseguradora le corresponde el pocentaje parametrizado pero sobre el saldo promedio deudor
        -- del mes.
        --v_porc_char := fug_obt_pardinamico('POR_ASEGURADORA');
        IF instr(v_porc_char, '.') <> 0 THEN
           v_porc_aseg := to_number(v_porc_char, '999.99');
        ELSIF instr(v_porc_char, ',') <> 0 THEN
           v_porc_aseg := to_number(v_porc_char, '999,99');
        ELSE
           v_porc_aseg := to_number(v_porc_char);
        END IF;
        -- Hacer el calculo por la porcion que le corresponde a la aseguradora

        v_importe      := round((v_mto_promedio * v_porc_aseg) / 100, v_redondeo);
        v_imp_restante := v_mto_mov - v_importe;
        /*
        -- Grabar el movimiento por la porcion de la Aseguradora en una cuenta transitoria
        */
        v_nro_secuencia := v_nro_secuencia + 1;
        IF v_nro_secuencia > 990 THEN
           --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
           v_hora := lf_obt_hora_libre(v_fcdehoy, v_hora);
           v_nro_secuencia := -999;
        END IF;
        --
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_usuario     := USER;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fcdehoy;
        r_gmovi.cod_modulo      := v_modulo;
        r_gmovi.cod_modalidad   := v_modalidad;
        r_gmovi.cod_oficina     := v_oficina;
        r_gmovi.nro_cuenta      := NULL;
        r_gmovi.cod_moneda      := v_moneda;
        r_gmovi.est_cuenta      := NULL;
        r_gmovi.cod_tra_padre   := v_transaccion;
        r_gmovi.cod_transaccion := 1633;
        r_gmovi.concepto        := 'Cargos por Seguro s/Sobregiro.';
        r_gmovi.monto           := v_importe;
        IF v_moneda <> v_cod_mon_local THEN
           v_cotizacion          := pag_gen.fu_obt_cotizacion(v_moneda, v_fcdehoy);
           r_gmovi.cotizacion    := v_cotizacion;
           r_gmovi.mto_equ_local := round(trunc(v_importe, 2) * v_cotizacion, v_redondeo_ml);
        ELSE
           v_cotizacion          := NULL;
           r_gmovi.cotizacion    := NULL;
           r_gmovi.mto_equ_local := NULL;
        END IF;
        r_gmovi.fec_valor      := v_fcdehoy;
        r_gmovi.emi_aviso      := 'N';
        r_gmovi.reversado      := 'N';
        r_gmovi.protegido      := 'N';
        r_gmovi.estado         := 'N';
        r_gmovi.cod_ofi_origen := v_oficina;
        r_gmovi.cod_mod_padre  := v_modulo;
        r_gmovi.cod_mad_padre  := v_modalidad;
        r_gmovi.nro_documento  := v_sobregiros(i).nro_cuenta;
        r_gmovi.val_tasa       := NULL;
        lp_encolar_mov(r_gmovi);
        /*
        -- Grabar el movimiento por la porcion restante
        */
        v_nro_secuencia := v_nro_secuencia + 1;
        IF v_nro_secuencia > 990 THEN
           --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
           v_hora := lf_obt_hora_libre(v_fcdehoy, v_hora);
           v_nro_secuencia := -999;
        END IF;
        --
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_usuario     := USER;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fcdehoy;
        r_gmovi.cod_modulo      := v_modulo;
        r_gmovi.cod_modalidad   := v_modalidad;
        r_gmovi.cod_oficina     := v_oficina;
        r_gmovi.nro_cuenta      := NULL;
        r_gmovi.cod_moneda      := v_moneda;
        r_gmovi.est_cuenta      := NULL;
        r_gmovi.cod_tra_padre   := v_transaccion;
        r_gmovi.cod_transaccion := 1634;
        r_gmovi.concepto        := 'Cargos por Seguro s/Sobregiro';
        r_gmovi.monto           := v_imp_restante;
        IF v_moneda <> v_cod_mon_local THEN
           v_cotizacion          := pag_gen.fu_obt_cotizacion(v_moneda, v_fcdehoy);
           r_gmovi.cotizacion    := v_cotizacion;
           r_gmovi.mto_equ_local := round(trunc(v_imp_restante, 2) * v_cotizacion, v_redondeo_ml);
        ELSE
           v_cotizacion          := NULL;
           r_gmovi.cotizacion    := NULL;
           r_gmovi.mto_equ_local := NULL;
        END IF;
        r_gmovi.fec_valor      := v_fcdehoy;
        r_gmovi.emi_aviso      := 'N';
        r_gmovi.reversado      := 'N';
        r_gmovi.protegido      := 'N';
        r_gmovi.estado         := 'N';
        r_gmovi.cod_ofi_origen := v_oficina;
        r_gmovi.cod_mod_padre  := v_modulo;
        r_gmovi.cod_mad_padre  := v_modalidad;
        r_gmovi.nro_documento  := v_sobregiros(i).nro_cuenta;
        r_gmovi.val_tasa       := NULL;
        lp_encolar_mov(r_gmovi);
        --
        -- Si el sobregiro está en gestion se graba con transaccion
        -- diferenciada (983) y se inserta en la tabla de cargos en suspenso
        IF nvl(v_hubo_error, 'N') = 'N' THEN
           IF v_transaccion = 983 THEN
              v_sus_cuenta(v_sus_cuenta.COUNT + 1) := v_sobregiros(i).nro_cuenta;
              v_sus_monto(v_sus_monto.COUNT + 1) := nvl(v_mto_cargo, 0);
              v_sus_modulo(v_sus_modulo.COUNT + 1) := pag_cta.g_ctas.cod_modulo;
              v_sus_modalidad(v_sus_modalidad.COUNT + 1) := pag_cta.g_ctas.cod_modalidad;
           END IF;
        END IF;
        --    End if;
        --- Siguiente registro
        <<siguiente>>
        NULL;

     END LOOP;
     EXIT WHEN c_sob%NOTFOUND;
   END LOOP;
   CLOSE c_sob;
   DBMS_APPLICATION_INFO.SET_ACTION('SEG_SUSPENSOS_FORALL');
   lp_grabar_suspensos;
   DBMS_APPLICATION_INFO.SET_ACTION('SEG_MOV_FORALL');
   lp_grabar_movs;
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
   pag_cta.g_sobregira := 'N';
EXCEPTION
   when no_data_found then
      raise_application_error(-20000,'Error en Procedimiento PRC_DEB_SEG_VID_SOBREGIRO : '||SQLERRM);
   when others then
      pag_cta.g_sobregira := 'N';
      raise_application_error(-20001,'Error en Procedimiento PRC_DEB_SEG_VID_SOBREGIRO : '||SQLERRM);
END;
/
