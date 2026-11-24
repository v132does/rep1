CREATE OR REPLACE PACKAGE BODY IT.paj_glo IS

  v_cod_respuesta    VARCHAR2(200);
  v_cod_estado       VARCHAR(3) := '200';
  v_cod_rep_aprobado VARCHAR2(200) := 'approved';
  v_cod_rep_cta_ina  VARCHAR2(200) := 'rejected_account_inactive';
  v_cod_rep_mto_inv  VARCHAR2(200) := 'rejected_invalid_amount';
  v_cod_rep_rec_otr  VARCHAR2(200) := 'rejected_other_reason';
  v_msj_error        cj_log_glo_pro.msj_error%TYPE;
  v_cod_ofi_origen   cj_movimientos.cod_oficina%TYPE;
  v_accion           VARCHAR2(200);
  v_accion_rev       VARCHAR2(200);
  v_cod_resp         NUMBER;
  v_cod_usuario      ba_usuarios.cod_usuario%type:= fug_obt_pardinamico('USU_GLO_ACTUAL');
  v_cod_usu_proceso  ba_usuarios.cod_usuario%type;

  -- Funcion verificamos que la cuenta que recibimos no sea conjunta
  function fu_cta_conjunta(p_nro_cuenta in varchar2) return varchar2 is
    v_can_conjunta number;
  begin

    select count('S')
      into v_can_conjunta
      from ge_cta_clientes
     where nro_cuenta = p_nro_cuenta
       and relacion = 'Y'
       and rownum = 1;

    if nvl(v_can_conjunta, 0) > 0 then
      return 'S';
    else
      return 'N';
    end if;
  end;
  --Verificamos el horario
  PROCEDURE pr_ver_horario(p_fec_proceso IN date,
                           p_hor_proceso IN varchar2,
                           p_es_nocturno OUT VARCHAR2,
                           p_fecha out date ) IS
    v_es_nocturno VARCHAR2(1) := 'N';
    v_fec_proceso ge_movimientos.fecha%TYPE;
    v_est_modulo  ba_modulos.estado%TYPE := pae_cnf.FU_OBT_EST_MODULO(3);
    v_hor_limite  varchar2(8) := '999999';
  BEGIN
    v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
    v_fec_proceso := pag_cal.fu_obt_fec_actual(3);
    p_fecha := v_fec_proceso;
    IF v_est_modulo = 2 THEN
      -- El modulo esta abierto
      -- Verifica la hora --
      IF (p_hor_proceso > v_hor_limite AND v_fec_proceso = p_fec_proceso) OR
        v_fec_proceso < p_fec_proceso THEN
        v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,
                                                  1,
                                                  v_cod_ofi_origen);
        p_fecha := v_fec_proceso;
        v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
      END IF;
    ELSE
      v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,
                                                1,
                                                v_cod_ofi_origen);
      p_fecha := v_fec_proceso;
      v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
    END IF;
    p_es_nocturno := v_es_nocturno;
  END;
  --Proceso de conversion de monto a moneda

  procedure lp_con_mon_a_moneda(p_cod_mon_debito  in ba_monedas.cod_moneda%type,
                                p_cod_mon_credito in ba_monedas.cod_moneda%type,
                                p_mto_mon_debito  in out number,
                                p_mto_mon_credito in out number,
                                p_cot_mon_debito  out number,
                                p_cot_mon_credito out number) is
    v_lugar         varchar2(100);
    v_cod_mon_local varchar2(3) := pag_gen.fu_obt_mon_local;
    v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(3);
  begin
    v_lugar := 'obtener moneda base';
    if p_cod_mon_debito = p_cod_mon_credito then
      if p_mto_mon_debito is null then
        p_mto_mon_debito  := p_mto_mon_credito;
      else
        p_mto_mon_credito := p_mto_mon_debito;
      end if;
      p_cot_mon_credito := null;
      p_cot_mon_debito  := null;
    else
      if p_cod_mon_debito = v_cod_mon_local then -- VENTA
        p_cot_mon_debito  := null;
        p_cot_mon_credito := fuj_obt_cot_autorizador(p_cod_mon_credito,'C',v_fec_actual);
        if p_mto_mon_debito is null then
          p_mto_mon_debito  := round(p_mto_mon_credito * p_cot_mon_credito, 0);
        else
          p_mto_mon_credito := round(p_mto_mon_debito / p_cot_mon_credito, 2);
          p_cot_mon_credito := round(p_mto_mon_debito / p_mto_mon_credito, 4);  -- relacula la cotizacion
        end if;
      elsif p_cod_mon_credito = v_cod_mon_local then -- COMPRA
        p_cot_mon_debito  :=  fuj_obt_cot_autorizador(p_cod_mon_debito,'V' /*VENTA */,v_fec_actual);

        p_cot_mon_credito := null;
        if p_mto_mon_debito is null then
          p_mto_mon_debito  := round(p_mto_mon_credito / p_cot_mon_debito, 2);
          p_cot_mon_debito  := round(p_mto_mon_credito / p_mto_mon_debito, 4); -- relacula la cotizacion
        else
          p_mto_mon_credito := round(p_mto_mon_debito * p_cot_mon_debito, 0);
        end if;
      else -- ARBITRAJE
        p_cot_mon_debito  := fuj_obt_cot_autorizador(p_cod_mon_debito,'C',v_fec_actual);
        if p_mto_mon_debito is null then
          p_mto_mon_debito  := round(round(p_mto_mon_credito *  fuj_obt_cot_autorizador(p_cod_mon_credito, 'V',v_fec_actual), 0)/ p_cot_mon_debito, 2);
        else
          p_mto_mon_credito := round(round(p_mto_mon_debito * p_cot_mon_debito, 0) /  fuj_obt_cot_autorizador(p_cod_mon_credito, 'V',v_fec_actual), 2);
        end if;
        p_cot_mon_credito := round(round(p_mto_mon_debito * p_cot_mon_debito, 0) / p_mto_mon_credito, 4);
      end if;
    end if;
  exception
    when others then
      raise_application_error(-20000, v_lugar || ' - ' || sqlerrm);
  end;


  -- Funcion verificamos si que tipo de entidad somos
  FUNCTION fu_es_banco RETURN VARCHAR2 IS
  BEGIN
    IF to_number(substr(pag_gen.fu_obt_cod_entidad, 1, 2)) = 10 THEN
      RETURN 'S';
    ELSE
      RETURN 'S'; -- PORQUE SIEMPRE ES BANCO
    END IF;
  END;

  FUNCTION fu_ins_cod_tra_ext(p_cod_tra         cj_log_ext_glo_pro.cod_transaccion%type,
                              P_accion          cj_log_ext_glo_pro.cod_accion%TYPE,
                              p_mot_cancelacion cj_log_ext_glo_pro.motivo%TYPE)
    RETURN VARCHAR2 IS
    pragma AUTONOMOUS_TRANSACTION;

    v_continua VARCHAR2(1);
  BEGIN
    BEGIN
      insert into cj_log_ext_glo_pro
        (COD_TRANSACCION, COD_ACCION, MOTIVO)
      VALUES
        (p_cod_tra, P_accion, p_mot_cancelacion);
      commit;
      v_continua := 'S';
    EXCEPTION
      when DUP_VAL_ON_INDEX then
        v_continua      := 'N';
        v_cod_estado    := 206;
        v_cod_respuesta := v_cod_rep_rec_otr;
        v_msj_error     := 'Transaccion Duplicada para reversion.';
      when others then
        v_continua      := 'N';
        v_cod_estado    := 206;
        v_cod_respuesta := v_cod_rep_rec_otr;
        v_msj_error     := 'Error al realizar la reversion.';
    END;
    return(v_continua);
  END;

  PROCEDURE pr_del_tra_ext (p_cod_tra_cancelacion cj_log_ext_glo_pro.cod_transaccion%type,
                            p_accion cj_log_ext_glo_pro.cod_accion%type) IS
    pragma AUTONOMOUS_TRANSACTION;
  BEGIN
    BEGIN
     delete from cj_log_ext_glo_pro t
      where cod_transaccion = p_cod_tra_cancelacion
        and t.cod_accion = p_accion;
      commit;
    EXCEPTION
      when OTHERS then
        null;
    END;
  END;

  FUNCTION fu_obt_hora(p_ind_usuario number) return varchar2 is
    v_hora ge_movimientos.hora%type;
    v_nro_sec number;
    v_nro_hor number;
  BEGIN

    v_nro_sec := fue_obt_sig_secuencia('s_nro_hora'||p_ind_usuario);

    if v_nro_sec < 86400 then
      v_nro_hor := v_nro_sec;
    else
      v_nro_hor := mod(v_nro_sec, 86400);
    end if;

    v_hora := TO_CHAR(trunc(v_nro_hor/3600), 'FM9900')|| ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor,3600)/60),'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor,60),'FM00');

    return v_hora;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'No se puede obtener la hora del movimiento. ' || sqlerrm);
  END;

  --Proceso principal
  PROCEDURE pr_principal(p_monto               IN NUMBER, --amount
                         p_cod_comercio        IN VARCHAR2, --commerce.code
                         p_nom_comercio        IN VARCHAR2, --commerce.name
                         p_mcc                 IN VARCHAR2, --commerce.mcc
                         p_cod_postal          IN VARCHAR2, --commerce.postal_code
                         p_id_cuenta           IN VARCHAR2, --account_id
                         p_nro_tarjeta         IN VARCHAR2, --trunc_card_number
                         p_cod_mon_transaccion IN VARCHAR2, --original_currency_id
                         p_fec_proceso         IN VARCHAR2, --date_time
                         p_hor_proceso         IN VARCHAR2, --date_time
                         p_cod_terminal        IN VARCHAR2, --stan
                         p_accion              IN VARCHAR2, --action
                         p_cod_transaccion     IN VARCHAR2, --request_id
                         p_cod_moneda          IN VARCHAR2, --currency_id
                         p_cod_tra_cancelacion IN VARCHAR2, --request_id_to_cancel
                         p_mot_cancelacion     IN VARCHAR2, --reason_id
                         p_tag_internacional   IN VARCHAR2 DEFAULT NULL, --tag international_auth
                         p_men_json            IN VARCHAR2 DEFAULT NULL, --Request json Global
                         p_estado              OUT VARCHAR2,
                         p_codigo              OUT VARCHAR2,
                         p_id_interno          OUT VARCHAR2,
                         p_fec_creado          OUT VARCHAR2,
                         p_hor_creado          OUT VARCHAR2,
                         p_id_respuesta        OUT VARCHAR2,
                         --netamente balance
                         p_sal_disponible      OUT VARCHAR2,
                         p_cod_mon_id          OUT VARCHAR2,
                         --OPI 2.43.3
                         p_id_mon_orig         IN VARCHAR2,
                         p_cod_adquiriente     IN VARCHAR2,
                         p_mod_entrada         IN VARCHAR2,
                         p_3ds                 IN VARCHAR2,
                         p_mon_original        IN VARCHAR2,
                         p_liq_moneda          IN VARCHAR2,
                         p_mon_liquidacion     IN VARCHAR2,
                         p_fac_tit_mon_id      IN VARCHAR2,
                         p_fac_ti_monto        IN VARCHAR2,
                         p_otr_montos          IN VARCHAR2,
                         p_fec_liquidacion     IN NUMBER,
                         p_cod_reenvio         IN NUMBER,
                         p_ref_recuperacion    IN VARCHAR2,
                         p_ter_id              IN VARCHAR2,
                         p_dat_red             IN VARCHAR2,
                         p_id_externo          OUT VARCHAR2,
                         p_pai_comercio        IN VARCHAR2,
                         p_ciu_comercio      IN VARCHAR2
                         ) IS
    v_mod_con_credito     ge_movimientos.cod_modulo%TYPE;
    v_mad_con_credito     ge_movimientos.cod_modalidad%TYPE;
    v_mon_cta_cre         ge_movimientos.cod_moneda%TYPE;
    v_cod_rub_credito     ge_movimientos.cod_rubro%TYPE;
    v_nro_cta_cre         ge_cuentas.nro_cuenta%TYPE;
    v_imp_credito         number(18, 2);
    v_cot_credito         ge_movimientos.cotizacion%type;
    v_nro_cta_deb         varchar2(100);
    v_mod_cta_deb         ge_movimientos.cod_modulo%TYPE;
    v_mad_cta_deb         ge_movimientos.cod_modalidad%TYPE;
    v_mon_cta_deb         ge_movimientos.cod_moneda%TYPE;
    v_ofi_cta_deb         ge_movimientos.cod_oficina%TYPE;
    v_est_cta_deb         ge_est_cuentas.estado%TYPE;
    v_imp_debito          number(18, 2);
    v_cod_error           varchar2(2);
    v_cot_debito          ge_movimientos.cotizacion%type;
    v_sal_disponible      ah_cta_vistas.sal_total%type;
    v_ind_usuario         number;
    v_mon_local           varchar2(3) := pag_gen.fu_obt_mon_local;
    v_cargos              ge_movimientos.monto%TYPE;
    v_est_modulo          ba_modulos.estado%TYPE;
    v_fec_proceso         date;
    v_hor_proceso         ge_movimientos.hora%TYPE;
    v_es_nocturno         VARCHAR2(1);
    v_nro_ope_int         number;
    v_nro_ope_int_rev     number;
    v_cod_gru_transaccion number;
    v_cod_transaccion     number;
    v_par_dinamico        ge_parametros.parametro%type;
    v_cod_tra_padre       cj_movimientos.cod_tra_padre%TYPE;
    v_cod_modulo          cj_movimientos.cod_mod_padre%TYPE := 9;
    v_cod_modalidad       cj_movimientos.cod_mad_padre%TYPE := 91;
    v_atm_pro             varchar2(1) := 'N';
    -- Variables para cobros de cargos por extraccion.
    v_cod_tas_cargo       ge_movimientos.cod_tasa%TYPE;
    v_val_tas_cargo       ge_movimientos.val_tasa%TYPE;
    v_val_cargo           ge_movimientos.val_tasa%TYPE;
    v_cod_tra_impuesto    ge_movimientos.cod_transaccion%TYPE;
    v_cod_tas_impuesto    ge_movimientos.cod_tasa%TYPE;
    v_val_tas_impuesto    ge_movimientos.val_tasa%TYPE;
    v_val_impuesto        ge_movimientos.val_tasa%TYPE;
    v_exi_movi            VARCHAR2(1) := 'N';
    v_gru_reversiones     GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_parentes(fug_obt_pardinamico('COD_ENT_GLOBAL'), 'CJ_GRU_TRA_GLP_REVERSIONES');
    v_fec_anterior        ge_movimientos.fecha%TYPE;
    v_rev_continua        varchar2(1) := 'S';
    v_cod_mon_transaccion ba_monedas.cod_moneda%TYPE;
    v_mon_iso             VARCHAR2(6);
    v_repetido            VARCHAR2(1);
    v_mto_a_reversar      ge_movimientos.monto%TYPE;
    v_hor_mov_reversado   ge_movimientos.hora%TYPE;
    v_fec_mov_reversado   ge_movimientos.fecha%TYPE;
    v_min_tol_cancelacion number := fug_obt_pardinamico('MIN_TOL_CANCELACION');
    v_ind_con_hor_can     varchar2(1) := fug_obt_pardinamico('IND_ACT_CON_HOR_CAN_GLO');
    v_fec_ope_ori         cj_log_glo_pro.fec_insercion%type;
    v_min_dif             number;
    v_hor_global          ge_movimientos.nro_documento3%type;
    v_cod_tra_pad_ext     ge_transacciones.cod_transaccion%type;
    v_cod_tra_pad_com     ge_transacciones.cod_transaccion%type;
    v_cod_tra_debito      ge_transacciones.cod_transaccion%type;
    v_cod_tra_credito     ge_transacciones.cod_transaccion%type;
    v_nom_comercio        ge_movimientos.concepto%type;
    -- Servicio digital
    v_imp_digital         VARCHAR2(1)    := 'N';
    v_tag_internacional   cj_log_glo_pro.tag_internacional%TYPE;
    v_mcc                 cj_log_glo_pro.mcc%TYPE;
    v_fec_transaccion     cj_log_glo_pro.fecha%TYPE;

  BEGIN
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 9;

    v_cod_estado          := '200';
    v_repetido            := 'N';
    v_cod_tra_pad_ext     := 382;
    v_cod_tra_pad_com     := 380;
    v_cod_tra_credito     := 602;
    v_cod_tra_debito      := 503;
    v_msj_error           := null;
    v_hor_global          := to_number(p_hor_proceso);
    v_cod_resp            := 0;
    v_cod_respuesta       := v_cod_rep_aprobado;
    v_accion              := p_accion;
    v_cod_mon_transaccion := v_mon_local;
    v_nro_cta_deb         := p_id_cuenta;

    BEGIN
      SELECT s_nro_ope_glo_pro.nextval INTO v_nro_ope_int FROM dual;
    EXCEPTION
      WHEN no_data_found THEN
        v_nro_ope_int := 1;
    END;
    --
    IF upper(p_accion) != 'CANCEL' THEN
      BEGIN
        SELECT 'S'
          INTO v_repetido
          FROM it.cj_log_glo_pro a
         WHERE a.nro_transaccion = p_cod_transaccion
           AND upper(a.pedido) != 'CANCEL';
      EXCEPTION
        WHEN no_data_found THEN
          v_repetido := 'N';
        WHEN too_many_rows THEN
          v_repetido := 'S';
      END;
    END IF;

    IF v_repetido = 'S' THEN
      v_cod_estado    := '207';
      v_cod_respuesta := v_cod_rep_rec_otr;
      v_msj_error     := 'Nro. Transaccion Duplicada';
    END IF;
    --Verificamos el estado del modulo.
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);
    IF v_est_modulo in (6) THEN
      -- Se esta corriendo el proceso de cierre
      v_cod_estado    := '208';
      v_cod_respuesta := v_cod_rep_rec_otr;
      v_msj_error     := 'Modulo en proceso de cierre';
    END IF;

    --Verificamos el horario.
    v_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(3);
    pr_ver_horario(v_fec_proceso, p_hor_proceso, v_es_nocturno, v_fec_proceso);
    v_fec_anterior := pag_cal.fu_obt_fec_ant_hab(v_fec_proceso, NULL, 1);

    -- Obtiene la oficina de Casa Matriz.
    Begin
      Select cod_ofi_matriz into v_cod_ofi_origen from ge_par_generales;
    end;
    -- Verificamos primeramente si no es una cuenta de debito y no es ficticia
    IF nvl(to_number(v_nro_cta_deb), 0) != 0 AND
       v_cod_respuesta = v_cod_rep_aprobado THEN
      -- Verificamos si existe la cuenta
      pag_cta.pr_obt_cuenta(v_nro_cta_deb);
      --Obtenemos los datos de la cuenta
      pr_obt_dat_cta(v_nro_cta_deb,
                     v_mod_cta_deb,
                     v_mad_cta_deb,
                     v_ofi_cta_deb,
                     v_mon_cta_deb);

      v_cod_error := pag_cta.g_cod_error;
      IF v_cod_error = 12 THEN
        -- Cuenta inexistente
        v_cod_estado    := 203;
        v_cod_respuesta := v_cod_rep_rec_otr; -- Tarjeta desconocida
        v_msj_error     := 'Cuenta Debito Inexistente';
      ELSIF v_cod_error in (13,14) THEN
         -- Se esta corriendo el proceso de cierre
        v_cod_estado    := '208';
        v_cod_respuesta := v_cod_rep_rec_otr;
        v_msj_error     := 'Modulo en proceso de cierre';
      END IF;

      IF nvl(to_number(v_nro_cta_deb), 0) != 0 AND
        v_cod_respuesta = v_cod_rep_aprobado THEN
        IF pag_cta.fu_llavear_cuenta(v_mad_cta_deb,
                                     v_nro_cta_deb,
                                     v_es_nocturno) = 'N' THEN
          v_cod_estado    := 205;
          v_cod_respuesta := v_cod_rep_rec_otr;
          v_msj_error     := 'No se pudo llavear la Cuenta Debito';
        END IF;
      END IF;
    END IF;

    --Verificamos si existe una cuenta de credito ficticia
    if v_cod_respuesta = v_cod_rep_aprobado THEN
      v_nro_cta_cre     := fug_obt_pardinamico('GEN_NRO_CTA_FIC',NULL, NULL, 'GS');
      v_mod_con_credito := null;
      v_mad_con_credito := null;
      v_cod_rub_credito := null;

      --
      BEGIN
        SELECT cod_modulo, cod_modalidad, cod_rubro
          INTO v_mod_con_credito,
               v_mad_con_credito,
               v_cod_rub_credito
          FROM cc_cta_ficticias
         WHERE nro_cuenta = v_nro_cta_cre;
      EXCEPTION
        WHEN no_data_found THEN
          v_mod_con_credito := '0';
      END;
      --
      v_imp_credito := p_monto;
      v_imp_debito  := p_monto;
    END IF;

    IF v_cod_respuesta = v_cod_rep_aprobado THEN
       if p_monto <> round(p_monto,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_transaccion,null)) then
          v_cod_estado    := 204;
          v_cod_respuesta := v_cod_rep_mto_inv;
          v_msj_error     := 'Importe en Moneda EXTRANJERA posee redondeo erroneo de acuerdo a la moneda del movimiento.';
       end if;
    end if;
    IF v_cod_respuesta = v_cod_rep_aprobado THEN
      -- si la moneda de la operacion es distinta a la moneda de la cuenta de debito
      -- realiza la conversion de monto credito -> debito. el importe de debito debe estar nulo
      IF v_cod_mon_transaccion <> v_mon_cta_deb and upper(p_accion) != 'CANCEL' THEN
        v_imp_debito := null;
        paj_glo.lp_con_mon_a_moneda(v_mon_cta_deb,
                                    v_cod_mon_transaccion,
                                    v_imp_debito,
                                    v_imp_credito,
                                    v_cot_debito,
                                    v_cot_credito);
      END IF;
    END IF;

    IF nvl(to_number(v_nro_cta_deb), 0) != 0 AND
      v_cod_respuesta = v_cod_rep_aprobado THEN
      -- Verificamos si existe la cuenta
      pag_cta.pr_obt_cuenta(v_nro_cta_deb);
      -- Verifica el estado de la cuenta
       v_cod_error := pag_cta.g_cod_error;
      IF v_cod_error = 12 THEN
        -- Cuenta inexistente
        v_cod_estado    := 203;
        v_cod_respuesta := v_cod_rep_rec_otr; -- Tarjeta desconocida
        v_msj_error     := 'Cuenta Debito Inexistente';
      ELSIF v_cod_error in (13,14) THEN
         -- Se esta corriendo el proceso de cierre
        v_cod_estado    := '208';
        v_cod_respuesta := v_cod_rep_rec_otr;
        v_msj_error     := 'Modulo en proceso de cierre';
      END IF;
      v_est_cta_deb := pag_cta.FU_OBT_EST_CUENTA;
      IF v_est_cta_deb not in ('N', 'S', 'I', 'A') AND
         v_cod_respuesta = v_cod_rep_aprobado THEN
        -- No es normal o con bloqueo de saldo
        -- Estado Inactivo tambien debe permitir.
        v_cod_estado    := 203;
        v_cod_respuesta := v_cod_rep_cta_ina; -- Transaccion no aprobada
        v_msj_error     := 'Transacción no aprobada por estado de la cuenta: '||' '||v_nro_cta_deb;
      END IF;
    END IF;

    IF v_cod_estado = '200' THEN
      IF upper(p_accion) in ('AUTHORIZATION','PAYMENT') THEN
        IF v_cod_respuesta = v_cod_rep_aprobado THEN
          IF v_mad_cta_deb not in (31, 41, 42, 48, 46, 49, 334) THEN
            -- Ahorro a la Vista/ Cta. Corrientes
            v_cod_estado    := 205;
            v_cod_respuesta := v_cod_rep_rec_otr;
            v_msj_error     := 'No pertenece a una cuenta corriente o de ahorro.';
          END IF;
        END IF;
        --validamos la moneda de la transaccion, para dolares no debe permitir
        if fug_obt_pardinamico('TAR_COM_POS_MON') = 'S' then
          if p_cod_moneda <> '600' then
            v_cod_estado    := 205;
            v_cod_respuesta := v_cod_rep_rec_otr;
            v_msj_error     := 'El tipo de moneda de la cuenta no esta permitida';
          end if;
        end if;
        --validamos que la cta no sea tipo conjunta--
        if fug_cta_conjunta(p_id_cuenta) = 'S' then
          v_cod_estado    := 205;
          v_cod_respuesta := v_cod_rep_rec_otr;
          v_msj_error     := 'No tiene permitido operar con cuenta conjunta';
        end if;

        -- Marca si corresponde impuesto a servicio digital y corresponde a un codigo valido
        if upper(p_tag_internacional) = v_ser_digital
           and p_mcc = fue_obt_val_max_referencia('COD_MCC_GLOBAL',  p_mcc) then
            PRG_OBT_CARGOS
                      (v_ofi_cta_deb
                      ,v_nro_cta_deb
                      ,v_mon_cta_deb
                      ,p_monto
                      ,v_mod_cta_deb
                      ,v_mad_cta_deb
                      ,v_cod_trn_digital
                      ,v_cod_tas_cargo
                      ,v_val_tas_cargo
                      ,v_val_cargo
                      ,v_cod_tra_impuesto
                      ,v_cod_tas_impuesto
                      ,v_val_tas_impuesto
                      ,v_val_impuesto);

            v_imp_digital := 'S';
        end if;
        v_cargos         := nvl(v_val_cargo, 0) + nvl(v_val_impuesto, 0);

        -- Debe verificar el monto de la operacion
        v_sal_disponible := nvl(pag_cta.FU_SAL_DISPONIBLE, 0) - (
                            nvl(v_imp_debito, 0) + nvl(v_cargos,0));
        /*Validacion que rechaza Compra Infonet Cobranzas con monto 0*/
        IF nvl(v_imp_debito, 0) <= 0 then
          v_cod_estado    := 204;
          v_cod_respuesta := v_cod_rep_mto_inv;
          v_msj_error     := 'Monto invalido.';
        end IF;
        if v_sal_disponible < 0 and v_cod_respuesta = v_cod_rep_aprobado and
           v_mad_cta_deb not in (42, 48, 46, 49) then
          If v_mad_cta_deb != 41 then
            -- Si no es Cta Corriente debe responder Saldo Insuficiente...
            v_cod_estado    := 204;
            v_cod_respuesta := v_cod_rep_mto_inv; -- No tiene saldo
            v_msj_error     := 'Saldo Insuficiente.';
          END IF;
        END IF;

      ELSIF upper(p_accion) = 'WITHDRAW' THEN
        IF v_cod_respuesta = v_cod_rep_aprobado THEN
          IF v_mad_cta_deb NOT IN (31, 41, 42, 46, 334) THEN
            -- Ahorro a la Vista/ Cta. Corrientes
            v_cod_estado    := 205;
            v_cod_respuesta := v_cod_rep_cta_ina;
            v_msj_error     := 'Tipo de Cuenta Debito Indebido. Modalidad: ' ||
                               v_mad_cta_deb;
          END IF;
            --validamos que la cta no sea tipo conjunta--
          if fug_cta_conjunta(p_id_cuenta) = 'S' then
            v_cod_estado    := 205;
            v_cod_respuesta := v_cod_rep_rec_otr;
            v_msj_error     := 'No tiene permitido operar con cuenta conjunta';
          end if;
             --validamos la moneda de la transaccion, para dolares no debe permitir
          if fug_obt_pardinamico('TAR_COM_POS_MON') = 'S' then
            if p_cod_moneda <> '600' then
              v_cod_estado    := 205;
              v_cod_respuesta := v_cod_rep_rec_otr;
              v_msj_error     := 'El tipo de moneda de la cuenta no esta permitida';
            end if;
          end if;

        END IF;
        IF nvl(v_imp_debito, 0) <= 0 then
          v_cod_estado    := 204;
          v_cod_respuesta := v_cod_rep_mto_inv;
          v_msj_error     := 'Monto invalido.';
        end IF;
        pr_obt_dat_tra_atm(v_cod_tra_padre,
                           v_cod_modulo,
                           v_cod_modalidad,
                           v_atm_pro,
                           v_cod_gru_transaccion,
                           v_cod_transaccion,
                           v_par_dinamico);

        v_cargos         := nvl(v_val_cargo, 0) + nvl(v_val_impuesto, 0);
        v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) -
                            (nvl(v_imp_debito, 0) +  nvl(v_cargos,0));
        if v_sal_disponible < 0 and v_cod_respuesta = v_cod_rep_aprobado and
           v_mad_cta_deb not in (42, 48, 46, 49) then
          If v_mad_cta_deb != 41 then
            -- Si no es Cta Corriente debe responder Saldo Insuficiente...
            v_cod_estado    := 204;
            v_cod_respuesta := v_cod_rep_mto_inv; -- No tiene saldo
            v_msj_error     := 'Saldo Insuficiente.';
          END IF;
        END IF;
      ELSIF upper(p_accion) = 'CANCEL' THEN
        BEGIN
          SELECT p.nro_documento, p.pedido, p.fec_insercion, p.fecha, p.nom_comercio, p.tag_internacional, p.mcc
            INTO v_nro_ope_int_rev, v_accion_rev, v_fec_ope_ori, v_fec_transaccion, v_nom_comercio, v_tag_internacional, v_mcc
            FROM it.cj_log_glo_pro p
           WHERE p.nro_transaccion = p_cod_tra_cancelacion
             AND upper(p.pedido) != 'CANCEL'
             AND p.nro_documento =
                 (SELECT max(to_number(a.nro_documento))
                    FROM it.cj_log_glo_pro a
                   WHERE a.nro_transaccion = p_cod_tra_cancelacion
                     AND upper(a.pedido) != 'CANCEL');
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              SELECT p.nro_documento, p.pedido, p.fec_insercion, p.fecha, p.nom_comercio, p.tag_internacional, p.mcc
                INTO v_nro_ope_int_rev, v_accion_rev, v_fec_ope_ori, v_fec_transaccion, v_nom_comercio, v_tag_internacional, v_mcc
                FROM cj_log_glo_pro_his p
               WHERE p.nro_transaccion = p_cod_tra_cancelacion
                 AND upper(p.pedido) != 'CANCEL'
                 AND p.nro_documento =
                     (SELECT max(to_number(a.nro_documento))
                        FROM it.cj_log_glo_pro_his a
                       WHERE a.nro_transaccion = p_cod_tra_cancelacion
                         AND upper(a.pedido) != 'CANCEL');
            EXCEPTION
              WHEN no_data_found THEN
                v_nro_ope_int_rev := null;
                v_accion_rev      := null;
              WHEN too_many_rows THEN
                SELECT p.nro_documento, p.pedido, p.fec_insercion, p.fecha, p.nom_comercio, p.tag_internacional, p.mcc
                  INTO v_nro_ope_int_rev, v_accion_rev, v_fec_ope_ori, v_fec_transaccion, v_nom_comercio, v_tag_internacional, v_mcc
                  FROM cj_log_glo_pro_his p
                 WHERE p.nro_transaccion = p_cod_tra_cancelacion
                   AND upper(p.pedido) != 'CANCEL'
                   AND p.nro_documento =
                       (SELECT max(to_number(a.nro_documento))
                          FROM it.cj_log_glo_pro_his a
                         WHERE a.nro_transaccion = p_cod_tra_cancelacion
                           AND upper(a.pedido) != 'CANCEL')
                   AND rownum = 1;
            END;
        END;
        /*Verificar si impuesto digital*/
        IF upper(v_tag_internacional) = v_ser_digital AND v_mcc = fue_obt_val_max_referencia('COD_MCC_GLOBAL', v_mcc) THEN
           v_imp_digital := 'S';
        END IF;
        v_rev_continua := fu_ins_cod_tra_ext(p_cod_tra_cancelacion,
                                             v_accion_rev,
                                             p_mot_cancelacion);
        IF v_rev_continua = 'S' THEN
          BEGIN
            SELECT DISTINCT 'S',
                            a.cod_tra_padre,
                            a.cod_moneda,
                            a.referencia,
                            a.monto,
                            a.fecha,
                            a.hora
              INTO v_exi_movi,
                   v_cod_tra_padre,
                   v_mon_cta_cre,
                   v_nro_cta_deb,
                   v_mto_a_reversar,
                   v_fec_mov_reversado,
                   v_hor_mov_reversado
              FROM ge_movimientos a
             WHERE a.nro_documento = v_nro_ope_int_rev
               AND EXISTS (SELECT 1
                      FROM cc_cta_ficticias c
                     WHERE c.cod_rubro = a.cod_rubro)
               AND (fup_exi_gru_transac(v_gru_reversiones,
                                        a.cod_tra_padre,
                                        a.cod_mod_padre,
                                        a.cod_mad_padre) = 'S')
               AND NOT EXISTS (SELECT DISTINCT 'S'
                      FROM ge_movimientos
                     WHERE nro_documento = a.nro_documento
                       AND monto < 0
                       AND (fup_exi_gru_transac(v_gru_reversiones,
                                                cod_tra_padre,
                                                cod_mod_padre,
                                                cod_mad_padre) = 'S'))
               AND NOT EXISTS
             (SELECT DISTINCT 'S'
                      FROM ge_movimientos_noc
                     WHERE nro_documento = a.nro_documento
                       AND monto < 0
                       AND (fup_exi_gru_transac(v_gru_reversiones,
                                                cod_tra_padre,
                                                cod_mod_padre,
                                                cod_mad_padre) = 'S'));

          EXCEPTION
            WHEN no_data_found THEN
              BEGIN
                SELECT DISTINCT 'S',
                                a.cod_tra_padre,
                                a.cod_moneda,
                                a.referencia,
                                a.monto,
                                a.fecha,
                                a.hora
                  INTO v_exi_movi,
                       v_cod_tra_padre,
                       v_mon_cta_cre,
                       v_nro_cta_deb,
                       v_mto_a_reversar,
                       v_fec_mov_reversado,
                       v_hor_mov_reversado
                  FROM ge_movimientos_noc a
                 WHERE a.nro_documento = v_nro_ope_int_rev
                   AND EXISTS (SELECT 1
                          FROM cc_cta_ficticias c
                         WHERE c.cod_rubro = a.cod_rubro)
                   AND (fup_exi_gru_transac(v_gru_reversiones,
                                            a.cod_tra_padre,
                                            a.cod_mod_padre,
                                            a.cod_mad_padre) = 'S')
                   AND NOT EXISTS
                 (SELECT DISTINCT 'S'
                          FROM ge_movimientos_noc
                         WHERE nro_documento = a.nro_documento
                           AND monto < 0
                           AND (fup_exi_gru_transac(v_gru_reversiones,
                                                    cod_tra_padre,
                                                    cod_mod_padre,
                                                    cod_mad_padre) = 'S'))
                   AND NOT EXISTS
                 (SELECT DISTINCT 'S'
                          FROM ge_movimientos
                         WHERE nro_documento = a.nro_documento
                           AND monto < 0
                           AND (fup_exi_gru_transac(v_gru_reversiones,
                                                    cod_tra_padre,
                                                    cod_mod_padre,
                                                    cod_mad_padre) = 'S'));
              EXCEPTION
                WHEN no_data_found THEN
                  BEGIN
                    SELECT DISTINCT 'S',
                                    a.cod_tra_padre,
                                    a.cod_moneda,
                                    a.referencia,
                                    a.monto,
                                    a.FECHA,
                                    a.HORA
                      INTO v_exi_movi,
                           v_cod_tra_padre,
                           v_mon_cta_cre,
                           v_nro_cta_deb,
                           v_mto_a_reversar,
                           v_fec_mov_reversado,
                           v_hor_mov_reversado
                      FROM gv_movimientos a
                     WHERE a.nro_documento = v_nro_ope_int_rev
                       AND EXISTS
                     (SELECT 1
                              FROM cc_cta_ficticias c
                             WHERE c.cod_rubro = a.cod_rubro)
                       AND a.fecha BETWEEN v_fec_transaccion AND v_fec_proceso
                       AND (fup_exi_gru_transac(v_gru_reversiones,
                                                a.cod_tra_padre,
                                                a.cod_mod_padre,
                                                a.cod_mad_padre) = 'S')
                       AND NOT EXISTS
                     (SELECT DISTINCT 'S'
                              FROM ge_movimientos_noc
                             WHERE nro_documento = a.nro_documento
                               AND monto < 0
                               AND (fup_exi_gru_transac(v_gru_reversiones,
                                                        cod_tra_padre,
                                                        cod_mod_padre,
                                                        cod_mad_padre) = 'S'))
                       AND NOT EXISTS
                     (SELECT DISTINCT 'S'
                              FROM ge_movimientos
                             WHERE nro_documento = a.nro_documento
                               AND monto < 0
                               AND (fup_exi_gru_transac(v_gru_reversiones,
                                                        cod_tra_padre,
                                                        cod_mod_padre,
                                                        cod_mad_padre) = 'S'))
                       AND NOT EXISTS
                     (SELECT DISTINCT 'S'
                              FROM gv_movimientos
                             WHERE nro_documento = a.nro_documento
                               AND monto < 0
                               AND fecha BETWEEN v_fec_transaccion AND
                                   v_fec_proceso
                               AND (fup_exi_gru_transac(v_gru_reversiones,
                                                        cod_tra_padre,
                                                        cod_mod_padre,
                                                        cod_mad_padre) = 'S'));
                  EXCEPTION
                    WHEN no_data_found THEN
                      v_exi_movi      := 'N';
                      v_cod_estado    := 205;
                      v_cod_respuesta := v_cod_rep_rec_otr;
                      v_msj_error     := 'Movimiento no encontrado para reversion.';
                  END;
              END;

          END;
          ---

          if nvl(v_ind_con_hor_can,'N')= 'S' then
            begin
              v_min_dif := 1440 * (sysdate - v_fec_ope_ori);
            exception
              when others then
                v_min_dif := 0;
            end;
            if v_min_dif > nvl(v_min_tol_cancelacion,0) then
              v_cod_estado := 205;
              v_cod_respuesta := v_cod_rep_rec_otr;
              v_msj_error := 'Tiempo de tolerancia de Cancelacion superado.';
            end if;
          end if;
          ---
          IF v_mto_a_reversar <> p_monto and v_cod_respuesta = v_cod_rep_aprobado THEN
            v_cod_estado := 204;
            v_cod_respuesta := v_cod_rep_mto_inv;
            v_msj_error := 'Monto ingresado invalido.';
          END IF;
          v_nro_cta_cre := fug_obt_pardinamico('GEN_NRO_CTA_FIC',NULL, NULL, 'GS');

          IF nvl(to_number(v_nro_cta_deb), 0) != 0 AND
             v_cod_respuesta = v_cod_rep_aprobado THEN
            -- Verificamos si existe la cuenta
            pag_cta.pr_obt_cuenta(v_nro_cta_deb);
            --Obtenemos los datos de la cuenta
            pr_obt_dat_cta(v_nro_cta_deb,
                           v_mod_cta_deb,
                           v_mad_cta_deb,
                           v_ofi_cta_deb,
                           v_mon_cta_deb);
            v_cod_error := pag_cta.g_cod_error;
            IF v_cod_error = 12 THEN
              -- Cuenta inexistente
              v_cod_estado    := 203;
              v_cod_respuesta := v_cod_rep_rec_otr; -- Tarjeta desconocida
              v_msj_error     := 'Cuenta Debito Inexistente';
            ELSIF v_cod_error in (13,14) THEN
               -- Se esta corriendo el proceso de cierre
              v_cod_estado    := '208';
              v_cod_respuesta := v_cod_rep_rec_otr;
              v_msj_error     := 'Modulo en proceso de cierre';
            END IF;

            IF nvl(to_number(v_nro_cta_deb), 0) != 0 AND
              v_cod_respuesta = v_cod_rep_aprobado THEN
              IF pag_cta.fu_llavear_cuenta(v_mad_cta_deb,
                                           v_nro_cta_deb,
                                           v_es_nocturno) = 'N' THEN
                v_cod_estado    := 205;
                v_cod_respuesta := v_cod_rep_rec_otr;
                v_msj_error     := 'No se pudo llavear la Cuenta Debito';
              END IF;
            END IF;
          END IF;

          --
          BEGIN
            SELECT cod_modulo,
                   cod_modalidad,
                   cod_rubro
              into v_mod_con_credito,
                   v_mad_con_credito,
                   v_cod_rub_credito
              FROM cc_cta_ficticias
             WHERE nro_cuenta = v_nro_cta_cre;
          EXCEPTION
            WHEN no_data_found THEN
              v_mod_con_credito := '0';
          END;
          --
          v_imp_credito := p_monto;
          v_imp_debito  := p_monto;
          IF v_mon_cta_cre <> v_mon_cta_deb THEN
             v_imp_debito := null;
             paj_glo.lp_con_mon_a_moneda(v_mon_cta_deb,
                                         v_mon_cta_cre,
                                         v_imp_debito,
                                         v_imp_credito,
                                         v_cot_debito,
                                         v_cot_credito);
          END IF;

        END IF;
      ELSIF upper(p_accion) = 'BALANCE' THEN
        IF v_cod_respuesta = v_cod_rep_aprobado THEN
          IF v_mad_cta_deb NOT IN (31, 41, 42, 46, 334) THEN
            -- Ahorro a la Vista/ Cta. Corrientes
            v_cod_estado    := 203;
            v_cod_respuesta := v_cod_rep_cta_ina;
            v_msj_error     := 'Tipo de Cuenta Debito Invalido. Modalidad: ' ||
                               v_mad_cta_deb;
          END IF;
        END IF;
        pr_obt_dat_tra_atm(v_cod_tra_padre,
                           v_cod_modulo,
                           v_cod_modalidad,
                           v_atm_pro,
                           v_cod_gru_transaccion,
                           v_cod_transaccion,
                           v_par_dinamico);

        v_cargos         := nvl(v_val_cargo, 0) + nvl(v_val_impuesto, 0);
        v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) -
                            nvl(v_cargos, 0);
      END IF;
    END IF;

    IF v_cod_estado = '200' THEN
      v_cod_usu_proceso  := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
      v_ind_usuario      := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
      v_hor_proceso      := fu_obt_hora(v_ind_usuario);
      IF v_cod_respuesta = v_cod_rep_aprobado THEN
        IF upper(p_accion) in ('AUTHORIZATION','PAYMENT') THEN
          pr_car_aut_operacion(v_nro_cta_deb,
                               v_nro_cta_cre,
                               v_cod_tra_pad_com,
                               v_cod_tra_debito,
                               v_cod_tra_credito,
                               v_mod_cta_deb,
                               v_mad_cta_deb,
                               v_ofi_cta_deb,
                               v_mon_cta_deb,
                               v_mod_con_credito,
                               v_mad_con_credito,
                               v_cod_ofi_origen,
                               v_cod_mon_transaccion,
                               v_hor_proceso,
                               v_fec_proceso,
                               null,
                               null,
                               p_cod_transaccion,
                               fug_obt_ofi_cuenta(v_nro_cta_deb),
                               p_nom_comercio,
                               v_est_cta_deb,
                               v_nro_ope_int,
                               v_imp_debito,
                               v_imp_credito,
                               v_val_cargo,
                               v_cod_tas_cargo,
                               v_val_tas_cargo,
                               v_cod_tra_impuesto,
                               v_cod_tas_impuesto,
                               v_val_tas_impuesto,
                               v_val_impuesto,
                               v_hor_global,
                               v_cod_usu_proceso,
                               v_ind_usuario,
                               v_cot_debito,
                               v_cot_credito,
                               v_es_nocturno,
                               p_mcc,
                               v_imp_digital);
          IF v_cod_resp = 0 THEN
            v_cod_estado    := 200;
            v_cod_respuesta := v_cod_rep_aprobado;
            v_msj_error     := 'Transaccion realizada correctamente.';
          ELSE
            v_cod_estado := 205;
            v_cod_respuesta := v_cod_rep_rec_otr;
          END IF;

        ELSIF upper(p_accion) = 'WITHDRAW' THEN
          pr_car_aut_operacion(v_nro_cta_deb,
                               v_nro_cta_cre,
                               v_cod_tra_pad_ext,
                               v_cod_tra_debito,
                               v_cod_tra_credito,
                               v_mod_cta_deb,
                               v_mad_cta_deb,
                               v_ofi_cta_deb,
                               v_mon_cta_deb,
                               v_mod_con_credito,
                               v_mad_con_credito,
                               v_cod_ofi_origen,
                               v_cod_mon_transaccion,
                               v_hor_proceso,
                               v_fec_proceso,
                               null,
                               null,
                               v_nro_ope_int,
                               fug_obt_ofi_cuenta(v_nro_cta_deb),
                               p_nom_comercio,
                               v_est_cta_deb,
                               v_nro_ope_int,
                               v_imp_debito,
                               v_imp_credito,
                               v_val_cargo,
                               v_cod_tas_cargo,
                               v_val_tas_cargo,
                               v_cod_tra_impuesto,
                               v_cod_tas_impuesto,
                               v_val_tas_impuesto,
                               v_val_impuesto,
                               v_hor_global,
                               v_cod_usu_proceso,
                               v_ind_usuario,
                               v_cot_debito,
                               v_cot_credito,
                               v_es_nocturno,
                               p_mcc,
                               v_imp_digital);
          IF v_cod_resp = 0 THEN
            v_cod_estado    := 200;
            v_cod_respuesta := v_cod_rep_aprobado;
            v_msj_error     := 'Transaccion realizada correctamente.';
          ELSE
            v_cod_estado := 205;
            v_cod_respuesta := v_cod_rep_rec_otr;
          END IF;

        ELSIF upper(p_accion) = 'CANCEL' THEN
          IF nvl(v_exi_movi, 'N') = 'S' THEN
            v_imp_debito  := v_imp_debito * -1;
            v_imp_credito := v_imp_credito * -1;
            IF upper(v_accion_rev) in ('AUTHORIZATION','PAYMENT') THEN
              pr_car_aut_operacion(v_nro_cta_deb,
                                   v_nro_cta_cre,
                                   v_cod_tra_padre,
                                   v_cod_tra_debito,
                                   v_cod_tra_credito,
                                   v_mod_cta_deb,
                                   v_mad_cta_deb,
                                   v_ofi_cta_deb,
                                   v_mon_cta_deb,
                                   v_mod_con_credito,
                                   v_mad_con_credito,
                                   v_cod_ofi_origen,
                                   nvl(v_cod_mon_transaccion, v_mon_cta_cre),
                                   v_hor_proceso,
                                   v_fec_proceso,
                                   null,
                                   null,
                                   v_nro_ope_int,
                                   fug_obt_ofi_cuenta(v_nro_cta_deb),
                                   nvl(p_nom_comercio,v_nom_comercio),
                                   v_est_cta_deb,
                                   v_nro_ope_int_rev,
                                   v_imp_debito,
                                   v_imp_credito,
                                   v_val_cargo,
                                   v_cod_tas_cargo,
                                   v_val_tas_cargo,
                                   v_cod_tra_impuesto,
                                   v_cod_tas_impuesto,
                                   v_val_tas_impuesto,
                                   v_val_impuesto,
                                   v_hor_global,
                                   v_cod_usu_proceso,
                                   v_ind_usuario,
                                   v_cot_debito,
                                   v_cot_credito,
                                   v_es_nocturno,
                                   p_mcc,
                                   v_imp_digital);
          IF v_cod_resp = 0 THEN
            v_cod_estado    := 200;
            v_cod_respuesta := v_cod_rep_aprobado;
            v_msj_error     := 'Transaccion realizada correctamente.';
          ELSE
            v_cod_estado := 205;
            v_cod_respuesta := v_cod_rep_rec_otr;
          END IF;

            ELSE
              pr_car_aut_operacion(v_nro_cta_deb,
                                   v_nro_cta_cre,
                                   v_cod_tra_padre,
                                   v_cod_tra_debito,
                                   v_cod_tra_credito,
                                   v_mod_cta_deb,
                                   v_mad_cta_deb,
                                   v_ofi_cta_deb,
                                   v_mon_cta_deb,
                                   v_mod_con_credito,
                                   v_mad_con_credito,
                                   v_cod_ofi_origen,
                                   nvl(v_cod_mon_transaccion, v_mon_cta_cre),
                                   v_hor_proceso,
                                   v_fec_proceso,
                                   null,
                                   null,
                                   v_nro_ope_int,
                                   fug_obt_ofi_cuenta(v_nro_cta_deb),
                                   p_nom_comercio,
                                   v_est_cta_deb,
                                   v_nro_ope_int_rev,
                                   v_imp_debito,
                                   v_imp_credito,
                                   v_val_cargo,
                                   v_cod_tas_cargo,
                                   v_val_tas_cargo,
                                   v_cod_tra_impuesto,
                                   v_cod_tas_impuesto,
                                   v_val_tas_impuesto,
                                   v_val_impuesto,
                                   v_hor_global,
                                   v_cod_usu_proceso,
                                   v_ind_usuario,
                                   v_cot_debito,
                                   v_cot_credito,
                                   v_es_nocturno,
                                   p_mcc,
                                   v_imp_digital);
              IF v_cod_resp = 0 THEN
                v_cod_estado    := 200;
                v_cod_respuesta := v_cod_rep_aprobado;
                v_msj_error     := 'Transaccion realizada correctamente.';
              ELSE
                v_cod_estado := 205;
                v_cod_respuesta := v_cod_rep_rec_otr;
              END IF;
            END IF;
          END IF;
        ELSIF upper(p_accion) = 'BALANCE' THEN
          BEGIN
            SELECT a.val_minimo
              INTO v_mon_iso
              FROM ba_cod_referencias a
             WHERE a.dominio = 'COD_ISO_PAI_MON'
               AND a.val_maximo = v_mon_cta_deb;
          EXCEPTION
            WHEN no_data_found THEN
              v_mon_iso       := 'S/R';
              v_cod_estado    := '206';
              v_cod_respuesta := v_cod_rep_rec_otr;
              v_msj_error     := 'MONEDA NO DEFINIDA EN ISO.';
          END;
        ELSE
          v_cod_estado    := 206;
          v_cod_respuesta := v_cod_rep_rec_otr;
          v_msj_error     := 'Accion no habilitada.';
        END IF;
      END IF;
    END IF;
    pr_ins_log(trunc(sysdate),
               v_accion,
               v_cod_respuesta,
               v_msj_error,
               v_fec_proceso,
               v_hor_proceso,
               p_cod_transaccion,
               v_nro_cta_deb,
               null,
               null,
               null,
               p_accion,
               nvl(p_monto, v_sal_disponible),
               v_cod_mon_transaccion,
               p_cod_terminal,
               null,
               null,
               null,
               null,
               p_nom_comercio,
               v_nro_ope_int,
               p_cod_tra_cancelacion,
               p_mot_cancelacion,
               v_cod_estado,
               p_cod_comercio,
               p_mcc,
               p_cod_postal,
               p_nro_tarjeta,
               p_cod_moneda,
               p_cod_mon_transaccion,
               p_fec_proceso,
               p_hor_proceso,
               v_cod_usu_proceso,
               p_tag_internacional,
               p_men_json);
    -- Salida de parametros.
    p_estado       := v_cod_estado;
    p_codigo       := v_cod_respuesta;
    p_id_interno   := lpad(v_nro_ope_int, 6, '0');
    p_fec_creado   := trunc(sysdate);
    p_hor_creado   := to_char(sysdate,'hh24:mi:ss');
    p_id_respuesta := p_cod_transaccion;
    IF upper(p_accion) IN ('BALANCE','WITHDRAW','AUTHORIZATION','PAYMENT') THEN
      p_sal_disponible := v_sal_disponible;
      p_cod_mon_id := v_mon_iso;
      if v_cod_estado = 200 then
        v_msj_error     := 'Transaccion realizada correctamente.';
      end if;
    END IF;
    --  RETURN(v_cod_estado || ' ' || v_cod_respuesta);
    if v_cod_estado not in (200) and upper(p_accion) = 'CANCEL' then
      pr_del_tra_ext(p_cod_tra_cancelacion, v_accion_rev);
    end if;
  EXCEPTION
    WHEN OTHERS THEN
      if v_cod_estado not in (200) and upper(p_accion) = 'CANCEL' then
        pr_del_tra_ext(p_cod_tra_cancelacion, v_accion_rev);
      end if;
      v_cod_estado := 206;
      v_cod_respuesta := v_cod_rep_rec_otr;
      v_msj_error := substr(sqlerrm,1,4000);
     
      pr_ins_log(trunc(sysdate),
                 v_accion,
                 v_cod_respuesta,
                 v_msj_error,
                 v_fec_proceso,
                 v_hor_proceso,
                 p_cod_transaccion,
                 v_nro_cta_deb,
                 null,
                 null,
                 null,
                 p_accion,
                 nvl(p_monto, v_sal_disponible),
                 v_cod_mon_transaccion,
                 p_cod_terminal,
                 null,
                 null,
                 null,
                 null,
                 p_nom_comercio,
                 v_nro_ope_int,
                 p_cod_tra_cancelacion,
                 p_mot_cancelacion,
                 v_cod_estado,
                 p_cod_comercio,
                 p_mcc,
                 p_cod_postal,
                 p_nro_tarjeta,
                 p_cod_moneda,
                 p_cod_mon_transaccion,
                 p_fec_proceso,
                 p_hor_proceso,
                 v_cod_usu_proceso,
                 p_tag_internacional,
                 p_men_json);
      -- Salida de parametros.
      p_estado       := v_cod_estado;
      p_codigo       := v_cod_respuesta;
      p_id_interno   := lpad(v_nro_ope_int, 6, '0');
      p_fec_creado   := trunc(sysdate);
      p_hor_creado   := to_char(sysdate,'hh24:mi:ss');
      p_id_respuesta := p_cod_transaccion;
      IF upper(p_accion) IN ('BALANCE','WITHDRAW','AUTHORIZATION','PAYMENT') THEN
        p_sal_disponible := v_sal_disponible;
        p_cod_mon_id := v_mon_iso;
      END IF;
  END;

  PROCEDURE pr_obt_dat_cta(p_nro_cuenta    IN OUT VARCHAR2,
                           p_cod_modulo    OUT NUMBER,
                           p_cod_modalidad OUT NUMBER,
                           p_cod_oficina   OUT NUMBER,
                           p_cod_moneda    OUT VARCHAR2) IS

  BEGIN
    IF p_nro_cuenta IS NOT NULL THEN

      BEGIN
        SELECT cod_modulo, cod_modalidad, cod_oficina
          INTO p_cod_modulo, p_cod_modalidad, p_cod_oficina
          FROM ge_cuentas
         WHERE nro_cuenta = p_nro_cuenta;
      EXCEPTION
        WHEN no_data_found THEN
          IF fug_obt_tip_implementacion = 9 THEN
            BEGIN
              --la cuenta tiene 0 inicial si la oficina est? entre el 1 y 9
              p_nro_cuenta := concat('0', p_nro_cuenta);
              SELECT cod_modulo, cod_modalidad, cod_oficina
                INTO p_cod_modulo, p_cod_modalidad, p_cod_oficina
                FROM ge_cuentas
               WHERE nro_cuenta = p_nro_cuenta;
              --asigna al par?metro la cuenta con el 0 delante
              p_nro_cuenta := p_nro_cuenta;
            EXCEPTION
              WHEN no_data_found THEN
                RAISE no_data_found;
            END;
          ELSE
            RAISE no_data_found;
          END IF;
      END;

      IF p_cod_modalidad IN (31, 334) THEN
        SELECT cod_moneda
          INTO p_cod_moneda
          FROM ah_cta_vistas
         WHERE nro_cuenta = P_nro_cuenta;
      ELSIF p_cod_modalidad = 41 THEN
        SELECT cod_moneda
          INTO p_cod_moneda
          FROM cc_cta_corrientes
         WHERE nro_cuenta = P_nro_cuenta;
      END IF;
    END IF;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_respuesta := v_cod_rep_rec_otr;
      v_msj_error     := 'Cuenta Inexistente(' || p_nro_cuenta || ')';
  END pr_obt_dat_cta;

  -- Proceso de generacion de movimientos
  PROCEDURE pr_car_aut_operacion(p_nro_cta_deb      ge_movimientos.nro_cuenta%TYPE,
                                 p_nro_cta_cre      ge_movimientos.nro_cuenta%TYPE,
                                 p_cod_tra_padre    ge_movimientos.cod_tra_padre%TYPE,
                                 p_cod_tra_debito   ge_movimientos.cod_transaccion%TYPE,
                                 p_cod_tra_credito  ge_movimientos.cod_transaccion%TYPE,
                                 p_cod_mod_cta_deb  ge_movimientos.cod_modulo%TYPE,
                                 p_cod_mad_cta_deb  ge_movimientos.cod_modalidad%TYPE,
                                 p_cod_ofi_cta_deb  ge_movimientos.cod_oficina%TYPE,
                                 p_cod_mon_deb      ge_movimientos.cod_moneda%TYPE,
                                 p_cod_mod_cta_cre  ge_movimientos.cod_modulo%TYPE,
                                 p_cod_mad_cta_cre  ge_movimientos.cod_modalidad%TYPE,
                                 p_cod_ofi_cta_cre  ge_movimientos.cod_oficina%TYPE,
                                 p_cod_mon_cre      ge_movimientos.cod_moneda%TYPE,
                                 p_hor_proceso      ge_movimientos.hora%TYPE,
                                 p_fec_proceso      ge_movimientos.fecha%TYPE,
                                 p_cod_bco_credito  ge_movimientos.cod_banco%TYPE,
                                 p_cod_bco_debito   ge_movimientos.cod_banco%TYPE,
                                 p_nro_transaccion  ta_dig_cobrados.referencia%TYPE,
                                 p_ofi_origen       ge_movimientos.cod_oficina%TYPE,
                                 p_concepto         ge_movimientos.concepto%TYPE,
                                 p_est_cuenta       ge_movimientos.est_cuenta%TYPE,
                                 p_cod_ope_int      ge_movimientos.nro_documento%TYPE,
                                 p_imp_debito       ge_movimientos.monto%TYPE,
                                 p_imp_credito      ge_movimientos.monto%TYPE,
                                 p_val_cargo        ge_movimientos.val_tasa%TYPE,
                                 p_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE,
                                 p_val_tas_cargo    ge_movimientos.val_tasa%TYPE,
                                 p_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE,
                                 p_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE,
                                 p_val_tas_impuesto ge_movimientos.val_tasa%TYPE,
                                 p_val_impuesto     ge_movimientos.val_tasa%TYPE,
                                 p_hor_global       ge_movimientos.nro_documento3%type,
                                 p_cod_usuario      ba_usuarios.cod_usuario%type,
                                 p_ind_usuario      number,
                                 p_cot_debito       ge_movimientos.cotizacion%type default null,
                                 p_cot_credito      ge_movimientos.cotizacion%type default null,
                                 p_es_nocturno      varchar2 default 'N',
                                 p_mcc              varchar2 default null,
                                 p_imp_digital      varchar2) IS


    -- Compra en Pos --
    v_cod_tra_padre ge_movimientos.cod_tra_padre%TYPE;
    v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;
    v_cod_modulo    ge_movimientos.cod_modulo%TYPE := 9; -- Caja
    v_cod_modalidad ge_movimientos.cod_modalidad%TYPE := 91; -- Caja
    v_cod_rubro     cb_rubros.cod_rubro%type;
    v_es_ficticia   varchar2(1);
    v_es_nocturno   VARCHAR2(1);
    v_ind_usuario   number;
    r_gmovi         ge_movimientos%ROWTYPE;
    v_hora          ge_movimientos.hora%type;
    v_cod_tra_rubro ge_transacciones.cod_transaccion%type;

    --Variales para impuesto
    v_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE;
    v_val_tas_cargo    ge_movimientos.val_tasa%TYPE;
    v_val_cargo        ge_movimientos.val_tasa%TYPE;
    v_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE;
    v_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE;
    v_val_tas_impuesto ge_movimientos.val_tasa%TYPE;
    v_val_impuesto     ge_movimientos.val_tasa%TYPE;

    -- Log para insert cobrados
    v_lugar varchar2(50) := '500';
    v_cod_programa  varchar2(30):= 'paj_glo.PR_CAR_AUT_OPERACION';
    p_men_error     varchar2(500);
    --
  BEGIN
    v_cod_tra_padre   := p_cod_tra_padre;
    v_cod_tra_rubro   := 101;
    v_nro_secuencia   := nvl(v_nro_secuencia, 0) + 1;
    v_hora            := p_hor_proceso;
    v_cod_usu_proceso := p_cod_usuario;
    v_ind_usuario     := p_ind_usuario;
    v_es_nocturno     := nvl(p_es_nocturno, 'N');

    if v_nro_secuencia > 996 then
       v_nro_secuencia := -999;
    end if;
   -- para mov de debito
    IF nvl(to_number(p_nro_cta_deb), 0) != 0 THEN
      begin
        select distinct 'S', c.cod_rubro
          into v_es_ficticia, v_cod_rubro
          from cc_cta_ficticias c
         where nro_cuenta = p_nro_cta_deb;
      exception
        when others then
          v_es_ficticia := 'N';
          v_cod_rubro   := null;
      end;
      savepoint inicio;
      -- Carga los parametros de movimientos de Debito
      r_gmovi.cod_modulo    := p_cod_mod_cta_deb;
      r_gmovi.cod_modalidad := p_cod_mad_cta_deb;
      r_gmovi.cod_oficina   := p_ofi_origen;

      if nvl(v_es_ficticia, 'N') = 'N' then
        r_gmovi.nro_cuenta      := p_nro_cta_deb;
        r_gmovi.cod_transaccion := p_cod_tra_debito;
      else
        r_gmovi.nro_cuenta      := NULL;
        r_gmovi.cod_transaccion := v_cod_tra_rubro;
        r_gmovi.cod_rubro       := v_cod_rubro;
        r_gmovi.tip_mov_rubro   := 'D';
      end IF;
      r_gmovi.cod_moneda    := p_cod_mon_deb;
      r_gmovi.cod_usuario   := v_cod_usu_proceso;
      r_gmovi.hora          := v_hora;
      r_gmovi.fecha         := p_fec_proceso;
      r_gmovi.nro_secuencia := v_nro_secuencia;

      r_gmovi.fec_valor     := trunc(sysdate);
      r_gmovi.cod_tra_padre := v_cod_tra_padre;
      r_gmovi.cod_mod_padre := v_cod_modulo;
      r_gmovi.cod_mad_padre := v_cod_modalidad;

      r_gmovi.cod_banco := p_cod_bco_debito;

      r_gmovi.monto          := p_imp_debito;
      r_gmovi.nro_documento  := substr(p_cod_ope_int, 1, 15);
      r_gmovi.nro_documento3 := p_hor_global;
      r_gmovi.referencia     := p_nro_cta_cre;

      r_gmovi.cod_tasa       := NULL; --
      r_gmovi.val_tasa       := NULL;
      r_gmovi.cotizacion     := p_cot_debito;
      r_gmovi.cod_ofi_origen := p_ofi_origen;
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.concepto       := p_concepto;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      begin
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
      exception
        when others then       
            begin
             v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
             v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
             v_hora              := fu_obt_hora(v_ind_usuario);
             r_gmovi.cod_usuario := v_cod_usu_proceso;
             r_gmovi.hora        := v_hora;
             pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
            exception
              when others then
                begin
                 v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                 v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                 v_hora              := fu_obt_hora(v_ind_usuario);
                 r_gmovi.cod_usuario := v_cod_usu_proceso;
                 r_gmovi.hora        := v_hora;
                 pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                exception
                  when others then
                    begin
                     v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                     v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                     v_hora              := fu_obt_hora(v_ind_usuario);
                     r_gmovi.cod_usuario := v_cod_usu_proceso;
                     r_gmovi.hora        := v_hora;
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                    exception
                      when others then
                        if sqlerrm like '%ORA-00001%' then
                         v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                         v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                         v_hora              := fu_obt_hora(v_ind_usuario);
                         r_gmovi.cod_usuario := v_cod_usu_proceso;
                         r_gmovi.hora        := v_hora;
                         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                        else
                          v_cod_resp := 999;
                          v_msj_error:='Error al insertar mov. debito del nro de cuenta: '||p_nro_cta_deb;
                          prg_ins_log_programas(v_cod_programa,substr(
                                            'Error al insertar mov. debito del nro de cuenta: ' ||
                                            p_nro_cta_deb || '.MsgErr: ' || sqlerrm,1,4000));
                        end if;
                   end;
               end;
           end;
      end;

      -- Carga los parametros de movimientos de Debito por cargo
        if p_imp_digital = 'S' then
           -- Obtengo el impuesto deacuerdo a la transacción correspondiente a el impuesto digital
           PRG_OBT_CARGOS (p_cod_ofi_cta_deb
                           ,p_nro_cta_deb
                           ,p_cod_mon_deb
                           ,p_imp_debito
                           ,p_cod_mod_cta_deb
                           ,p_cod_mad_cta_deb
                           ,v_cod_trn_digital
                           ,v_cod_tas_cargo
                           ,v_val_tas_cargo
                           ,v_val_cargo
                           ,v_cod_tra_impuesto
                           ,v_cod_tas_impuesto
                           ,v_val_tas_impuesto
                           ,v_val_impuesto);

           -- Aumenta secuenca.
           v_nro_secuencia := v_nro_secuencia + 1;

            r_gmovi.cod_modulo    := p_cod_mod_cta_deb;
            r_gmovi.cod_modalidad := p_cod_mad_cta_deb;
            r_gmovi.cod_oficina   := p_ofi_origen;

            if nvl(v_es_ficticia, 'N') = 'N' then
              r_gmovi.nro_cuenta      := p_nro_cta_deb;
              r_gmovi.cod_transaccion := to_number(v_cod_trn_digital);
            else
              r_gmovi.nro_cuenta      := NULL;
              r_gmovi.cod_transaccion := NULL;
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.tip_mov_rubro   := 'D';
            end IF;
            r_gmovi.cod_moneda    := p_cod_mon_deb;
            r_gmovi.cod_usuario   := v_cod_usu_proceso;
            r_gmovi.hora          := v_hora;
            r_gmovi.fecha         := p_fec_proceso;
            r_gmovi.nro_secuencia := v_nro_secuencia;

            r_gmovi.fec_valor     := trunc(sysdate);
            r_gmovi.cod_tra_padre := v_cod_tra_padre;
            r_gmovi.cod_mod_padre := v_cod_modulo;
            r_gmovi.cod_mad_padre := v_cod_modalidad;

            r_gmovi.cod_banco := p_cod_bco_debito;

            r_gmovi.monto          := v_val_cargo;
            r_gmovi.nro_documento  := substr(p_cod_ope_int, 1, 15);
            r_gmovi.nro_documento3 := p_hor_global;
            r_gmovi.referencia     := p_nro_cta_cre;

            r_gmovi.cod_tasa       := v_cod_tas_cargo;
            r_gmovi.val_tasa       := v_val_tas_cargo;
            r_gmovi.cotizacion     := p_cot_debito;
            r_gmovi.cod_ofi_origen := p_ofi_origen;
            r_gmovi.emi_aviso      := 'N';
          r_gmovi.concepto       := 'IVA LEY 6380-SERVICIO DIGITAL';--p_concepto;
            r_gmovi.estado         := 'N';
            r_gmovi.reversado      := 'N';
        begin
          pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        exception
          when others then
            v_cod_resp := 999;
            v_msj_error:='Error al insertar mov. debito por cargo del nro de cuenta: ' ||p_nro_cta_deb;
            prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al insertar mov. debito por cargo del nro de cuenta: ' ||
                                  p_nro_cta_deb || '.MsgErr: ' || sqlerrm,1,4000));
        end;

      -- Registro datos de cobros de servicios digitales
       begin
          insert into it.ta_dig_cobrados
            (
              cod_persona,
              nro_cuenta,
              nro_documento,
              fec_proceso,
              des_servicio,
              cod_moneda,
              importe,
              mto_impuesto,
              referencia,
              usu_insercion,
              fec_insercion,
              usu_modificacion,
              fec_modificacion
             )

          values
            (
             Null,
             p_nro_cta_deb,
             r_gmovi.nro_documento, -- Numero de operacion del movimiento.
             p_fec_proceso,
             p_concepto,
             p_cod_mon_deb,
             p_imp_debito,
             v_val_cargo,
             p_nro_transaccion,
             user,
             sysdate,
             user,
             sysdate);

        EXCEPTION
          WHEN OTHERS THEN

              p_men_error := 'Error en proceso : ' || v_cod_programa || '-'||v_lugar||'-'||
                    to_char(p_fec_proceso, 'dd/mm/yyyy') || ' - ' || sqlerrm;

              prg_ins_log_programas(v_cod_programa,substr( 'Error en programa.'||chr(13)||
                'MsgErr: '||sqlerrm||' - '||p_men_error,1,4000));
        END;
        end if;
      if nvl(v_es_ficticia, 'N') = 'N' then
       begin
        pr_upd_cta_debito('N',
                           v_es_nocturno,
                           p_cod_mod_cta_deb,
                           p_cod_mad_cta_deb,
                           p_nro_cta_deb,
                           p_fec_proceso,
                           v_hora,
                           p_imp_debito + nvl(v_val_cargo,0));
       exception
          when others then
            v_cod_resp := 999;
            v_msj_error:= 'Error al debitar saldo al nro de cuenta: ' ||p_nro_cta_deb;
            prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al debitar saldo al nro de cuenta: ' ||
                                  p_nro_cta_deb || '.MsgErr: ' || sqlerrm,1,4000));
        end;
        IF p_est_cuenta = 'I' THEN
          -- Debo cambiar el estado de la cuenta
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.monto           := NULL;
          r_gmovi.est_cuenta      := 'N';
          r_gmovi.cod_tra_padre   := 425;
          r_gmovi.cod_transaccion := 425;
          begin
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
          exception
            when others then
              v_cod_resp := 999;
              v_msj_error:='Error al insertar movimiento de cambio de estado, nro de cuenta: '||p_nro_cta_deb;
              prg_ins_log_programas(v_cod_programa,substr(
                                    'Error al insertar movimiento de cambio de estado, nro de cuenta: ' ||
                                    p_nro_cta_deb || '.MsgErr: ' || sqlerrm,1,4000));
          end;
        END IF;
      end if;
    END IF;
    -- para mov de credito
   IF v_cod_resp = 0 THEN
      IF nvl(to_number(p_nro_cta_cre), 0) != 0 THEN
        begin
          select distinct 'S', c.cod_rubro
            into v_es_ficticia, v_cod_rubro
            from cc_cta_ficticias c
           where nro_cuenta = p_nro_cta_cre;
        exception
          when others then
            v_es_ficticia := 'N';
            v_cod_rubro   := null;
        end;
        -- Carga los parametros de movimientos de Credito
        v_nro_secuencia       := v_nro_secuencia + 1;
        r_gmovi.cod_modulo    := p_cod_mod_cta_cre;
        r_gmovi.cod_modalidad := p_cod_mad_cta_cre;
        r_gmovi.cod_oficina   := p_cod_ofi_cta_cre;

        if nvl(v_es_ficticia, 'N') = 'N' then
          r_gmovi.nro_cuenta      := p_nro_cta_cre;
          r_gmovi.cod_transaccion := p_cod_tra_credito;
        else
          r_gmovi.nro_cuenta      := NULL;
          r_gmovi.cod_transaccion := v_cod_tra_rubro;
          r_gmovi.cod_rubro       := v_cod_rubro;
          r_gmovi.tip_mov_rubro   := 'C';
        end IF;
        r_gmovi.cod_moneda    := p_cod_mon_cre;
        r_gmovi.cod_usuario   := v_cod_usu_proceso;
        r_gmovi.hora          := v_hora;
        r_gmovi.fecha         := p_fec_proceso;
        r_gmovi.nro_secuencia := v_nro_secuencia;

        r_gmovi.fec_valor     := trunc(sysdate);
        r_gmovi.cod_tra_padre := v_cod_tra_padre;
        r_gmovi.cod_mod_padre := v_cod_modulo;
        r_gmovi.cod_mad_padre := v_cod_modalidad;

        r_gmovi.cod_banco := p_cod_bco_debito;

        r_gmovi.monto          := p_imp_credito;
        r_gmovi.nro_documento  := substr(p_cod_ope_int, 1, 15);
        r_gmovi.nro_documento3 := p_hor_global;
        r_gmovi.referencia     := p_nro_cta_deb;

        r_gmovi.cod_tasa       := NULL;
        r_gmovi.val_tasa       := NULL;
        r_gmovi.cotizacion     := p_cot_credito;
        r_gmovi.cod_ofi_origen := p_ofi_origen;
        r_gmovi.emi_aviso      := 'N';
        r_gmovi.concepto       := p_concepto;
        r_gmovi.estado         := 'N';
        r_gmovi.reversado      := 'N';
        begin
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        exception
            when others then
              v_cod_resp := 999;
              v_msj_error:='Error al insertar movimientos de Credito, nro de cuenta: '||p_nro_cta_cre;
              prg_ins_log_programas(v_cod_programa,substr(
                                    'Error al insertar movimiento de cambio de estado, nro de cuenta: ' ||
                                    p_nro_cta_cre || '.MsgErr: ' || sqlerrm,1,4000));
          end;
        IF nvl(v_es_ficticia, 'N') = 'N' THEN
          begin
            pr_upd_cta_credito('N',
                               v_es_nocturno,
                               p_cod_mod_cta_cre,
                               p_cod_mad_cta_cre,
                               p_nro_cta_cre,
                               p_fec_proceso,
                               v_hora,
                               p_imp_credito);
         exception
            when others then
              v_cod_resp := 999;
              v_msj_error:='Error al acreditar saldo a la cuenta ' ||p_nro_cta_cre;
              prg_ins_log_programas(v_cod_programa,substr(
                                    'Error al acreditar saldo a la cuenta ' ||
                                    p_nro_cta_cre || '.MsgErr: ' || sqlerrm,1,4000));
          end;
          IF p_est_cuenta = 'I' THEN
            -- Debo cambiar el estado de la cuenta
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := NULL;
            r_gmovi.est_cuenta      := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            begin
              pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
            exception
              when others then
                v_cod_resp := 999;
                v_msj_error:='Error al insertar movimiento de cambio de estado, nro de cuenta: '||p_nro_cta_cre;
                prg_ins_log_programas(v_cod_programa,substr(
                                      'Error al insertar movimiento de cambio de estado, nro de cuenta: ' ||
                                      p_nro_cta_cre || '.MsgErr: ' ||
                                      sqlerrm,1,4000));
            end;
          END IF;
        END IF;
      END IF;
    END IF;
  if v_cod_resp != 0 then
      rollback to inicio;
    end if;
  EXCEPTION
    when others then
      v_cod_resp := 999;
      v_msj_error:='Error en procedimiento.';
      rollback to inicio;
      prg_ins_log_programas(v_cod_programa,
                            'Error en procedimiento.' || '.MsgErr: ' ||
                            sqlerrm);
  END pr_car_aut_operacion;

  -- Proceso de generacion de movimientos para consulta de saldos.!
  PROCEDURE pr_car_aut_ope_consulta(p_nro_cta_deb      ge_movimientos.nro_cuenta%TYPE,
                                    p_cod_tra_padre    ge_movimientos.cod_tra_padre%TYPE,
                                    p_cod_tra_debito   ge_movimientos.cod_transaccion%TYPE,
                                    p_cod_mod_cta_deb  ge_movimientos.cod_modulo%TYPE,
                                    p_cod_mad_cta_deb  ge_movimientos.cod_modalidad%TYPE,
                                    p_cod_ofi_cta_deb  ge_movimientos.cod_oficina%TYPE,
                                    p_cod_mon_deb      ge_movimientos.cod_moneda%TYPE,
                                    p_hor_proceso      ge_movimientos.hora%TYPE,
                                    p_fec_proceso      ge_movimientos.fecha%TYPE,
                                    p_cod_bco_debito   ge_movimientos.cod_banco%TYPE,
                                    p_nro_transaccion  ge_movimientos.nro_documento%TYPE,
                                    p_ofi_origen       ge_movimientos.cod_oficina%TYPE,
                                    p_concepto         ge_movimientos.concepto%TYPE,
                                    p_est_cuenta       ge_movimientos.est_cuenta%TYPE,
                                    p_cod_ope_int      ge_movimientos.nro_documento%TYPE,
                                    p_imp_debito       ge_movimientos.monto%TYPE,
                                    p_val_cargo        ge_movimientos.val_tasa%TYPE,
                                    p_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE,
                                    p_val_tas_cargo    ge_movimientos.val_tasa%TYPE,
                                    p_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE,
                                    p_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE,
                                    p_val_tas_impuesto ge_movimientos.val_tasa%TYPE,
                                    p_val_impuesto     ge_movimientos.val_tasa%TYPE,
                                    p_hor_global       ge_movimientos.nro_documento3%type,
                                    p_cod_usuario      ba_usuarios.cod_usuario%type,
                                    p_ind_usuario      number,
                                    p_es_nocturno      varchar2 default 'N') IS

    -- Compra en Pos --
    v_cod_tra_padre       ge_movimientos.cod_tra_padre%TYPE;
    v_nro_secuencia       ge_movimientos.nro_secuencia%TYPE;
    v_cod_modulo          ge_movimientos.cod_modulo%TYPE := 9; -- Caja
    v_cod_modalidad       ge_movimientos.cod_modalidad%TYPE := 91; -- Caja
    v_es_ficticia         varchar2(1);
    v_es_nocturno         VARCHAR2(1);
    v_ind_usuario         number;
    v_imp_debito          ge_movimientos.monto%TYPE;
    v_hora                ge_movimientos.hora%type;
    r_gmovi               ge_movimientos%ROWTYPE;
    v_cod_programa        varchar2(30):= 'PAJ_GLO.PR_CAR_AUT_OPE_CONSULTA';
  BEGIN
    v_cod_tra_padre   := p_cod_tra_padre;
    v_cod_usu_proceso := p_cod_usuario;
    v_ind_usuario     := p_ind_usuario;
    v_nro_secuencia   := nvl(v_nro_secuencia, 0) + 1;
    v_hora            := p_hor_proceso;
    v_es_nocturno     := nvl(p_es_nocturno, 'N');

    if v_nro_secuencia > 996 then
       v_nro_secuencia := -999;
    end if;

    IF nvl(to_number(p_nro_cta_deb), 0) != 0 THEN
      begin
        select distinct 'S'
          into v_es_ficticia
          from cc_cta_ficticias c
         where nro_cuenta = p_nro_cta_deb;
      exception
        when others then
          v_es_ficticia := 'N';
      end;
      -- Carga los parametros de movimientos de Debito
      r_gmovi.cod_modulo      := p_cod_mod_cta_deb;
      r_gmovi.cod_modalidad   := p_cod_mad_cta_deb;
      r_gmovi.cod_oficina     := p_cod_ofi_cta_deb;
      r_gmovi.nro_cuenta      := p_nro_cta_deb;
      r_gmovi.cod_transaccion := v_cod_tra_padre;

      r_gmovi.cod_moneda    := p_cod_mon_deb;
      r_gmovi.cod_usuario   := v_cod_usu_proceso;
      r_gmovi.hora          := v_hora;
      r_gmovi.fecha         := p_fec_proceso;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      --
      r_gmovi.fec_valor     := trunc(sysdate);
      r_gmovi.cod_tra_padre := v_cod_tra_padre;
      r_gmovi.cod_mod_padre := v_cod_modulo;
      r_gmovi.cod_mad_padre := v_cod_modalidad;

      r_gmovi.monto          := null;
      r_gmovi.nro_documento  := substr(p_cod_ope_int, 1, 15);
      r_gmovi.nro_documento3 := p_hor_global;

      r_gmovi.cod_tasa       := NULL;
      r_gmovi.val_tasa       := NULL;
      r_gmovi.cotizacion     := null;
      r_gmovi.cod_ofi_origen := p_ofi_origen;
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.concepto       := p_concepto;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      begin
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
      exception
        when others then
          begin
           v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
           v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
           v_hora              := fu_obt_hora(v_ind_usuario);
           r_gmovi.cod_usuario := v_cod_usu_proceso;
           r_gmovi.hora        := v_hora;
           pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
          exception
            when others then
              begin
               v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
               v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
               v_hora              := fu_obt_hora(v_ind_usuario);
               r_gmovi.cod_usuario := v_cod_usu_proceso;
               r_gmovi.hora        := v_hora;
               pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
              exception
                when others then
                  begin
                   v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                   v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                   v_hora              := fu_obt_hora(v_ind_usuario);
                   r_gmovi.cod_usuario := v_cod_usu_proceso;
                   r_gmovi.hora        := v_hora;
                   pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                  exception
                    when others then
                      if sqlerrm like '%ORA-00001%' then
                       v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                       v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                       v_hora              := fu_obt_hora(v_ind_usuario);
                       r_gmovi.cod_usuario := v_cod_usu_proceso;
                       r_gmovi.hora        := v_hora;
                       pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                       else
                         prg_ins_log_programas(v_cod_programa, 
                                               substr('Error al insertar el movimiento. ' || sqlerrm,
                                               1,
                                               4000),
                                               NULL,
                                               p_nro_cta_deb);
                         raise_application_error(-20000, 'Error al insertar el movimiento. ' || sqlerrm);
                       end if;
                  end;
              end;
          end;
      end;
      IF p_val_cargo > 0 THEN
        ---
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.monto           := p_val_cargo;
        r_gmovi.cod_tasa        := p_cod_tas_cargo;
        r_gmovi.val_tasa        := p_val_tas_cargo;
        r_gmovi.concepto        := 'Cargo por Extraccion';
        r_gmovi.cod_tra_padre   := 137;
        r_gmovi.cod_transaccion := 137;
        ---
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        IF p_val_impuesto > 0 THEN
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.monto           := p_val_impuesto;
          r_gmovi.cod_tasa        := p_cod_tas_impuesto;
          r_gmovi.val_tasa        := p_val_tas_impuesto;
          r_gmovi.concepto        := 'IVA s/Cargo por Extraccion';
          r_gmovi.cod_tra_padre   := p_cod_tra_impuesto;
          r_gmovi.cod_transaccion := p_cod_tra_impuesto;
          pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        END IF;
        v_imp_debito := nvl(p_imp_debito, 0) + nvl(p_val_cargo, 0) +
                        nvl(p_val_impuesto, 0);
        if nvl(v_es_ficticia, 'N') = 'N' then
          pr_upd_cta_debito('N',
                            v_es_nocturno,
                            p_cod_mod_cta_deb,
                            p_cod_mad_cta_deb,
                            p_nro_cta_deb,
                            p_fec_proceso,
                            v_hora,
                            v_imp_debito);
          IF p_est_cuenta = 'I' THEN
            -- Debo cambiar el estado de la cuenta
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := NULL;
            r_gmovi.est_cuenta      := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
          END IF;
        end if;
      END IF;
    END IF;
  END;
  --Actualizamos la cuenta de credito y debito.
  PROCEDURE pr_upd_cta_debito(p_ind_cta_contable VARCHAR2,
                              p_es_nocturno      VARCHAR2,
                              p_cod_mod_cta      ge_movimientos.cod_modulo%TYPE,
                              p_cod_mad_cta      ge_movimientos.cod_modalidad%TYPE,
                              p_nro_cuenta       ge_movimientos.nro_cuenta%TYPE,
                              p_fec_proceso      ge_movimientos.fecha%TYPE,
                              p_hor_proceso      ge_movimientos.hora%TYPE,
                              p_importe          ge_movimientos.monto%TYPE) IS
  v_cod_programa varchar2(40):='PAJ_GLO.PR_UPD_CTA_DEBITO';
  BEGIN
    IF p_ind_cta_contable = 'N' THEN
      IF nvl(p_es_nocturno, 'N') = 'N' THEN
        -- Horario normal --
        IF nvl(fug_obt_pardinamico('MAD_TAR_GLOBAL',p_cod_mod_cta, p_cod_mad_cta),'N') = 'S' THEN
          BEGIN
            UPDATE ah_cta_vistas
               SET sal_total          = nvl(sal_total, 0) - p_importe,
                   fec_ult_movimiento = p_fec_proceso,
                   hor_ult_movimiento = p_hor_proceso,
                   estado             = decode(estado, 'I', 'N', estado)
             WHERE nro_cuenta = p_nro_cuenta;
           EXCEPTION
             WHEN OTHERS THEN
               v_cod_resp := 999;
               v_msj_error := 'Error al actualizar saldo de cuenta';
               prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
           END;
        ELSIF p_cod_mad_cta = 41 THEN
          BEGIN
            UPDATE cc_cta_corrientes
               SET sal_total          = nvl(sal_total, 0) - p_importe,
                   fec_ult_movimiento = p_fec_proceso,
                   hor_ult_movimiento = p_hor_proceso,
                   estado             = decode(estado, 'I', 'N', estado)
             WHERE nro_cuenta = p_nro_cuenta;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
              prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        ELSIF p_cod_mod_cta = 4 THEN
          BEGIN
            UPDATE cc_cta_bancarias
               SET sal_total          = nvl(sal_total, 0) - p_importe,
                   fec_ult_movimiento = p_fec_proceso,
                   hor_ult_movimiento = p_hor_proceso,
                   estado             = decode(estado, 'I', 'N', estado)
             WHERE nro_cuenta = p_nro_cuenta;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
             prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        END IF;
      ELSE
        -- A la Noche o despues del cierre --
        IF nvl(fug_obt_pardinamico('MAD_TAR_GLOBAL',p_cod_mod_cta, p_cod_mad_cta),'N') = 'S' THEN
          BEGIN
            UPDATE ah_cta_vistas_noc
               SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + p_importe
             WHERE nro_cuenta = p_nro_cuenta;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
              prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        ELSIF p_cod_mad_cta = 41 THEN
          BEGIN
            UPDATE cc_cta_corrientes_noc
               SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + p_importe
             WHERE nro_cuenta = p_nro_cuenta;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
              prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        ELSIF p_cod_mod_cta = 4 THEN
          BEGIN
            UPDATE cc_cta_bancarias
               SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + p_importe
             WHERE nro_cuenta = p_nro_cuenta;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
               prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        END IF;
      END IF;
    END IF;
  END pr_upd_cta_debito;

  --Actualizamos la cuenta de credito y debito.
  PROCEDURE pr_upd_cta_credito(p_ind_cta_contable VARCHAR2,
                               p_es_nocturno      VARCHAR2,
                               p_cod_mod_cta      ge_movimientos.cod_modulo%TYPE,
                               p_cod_mad_cta      ge_movimientos.cod_modalidad%TYPE,
                               p_nro_cuenta       ge_movimientos.nro_cuenta%TYPE,
                               p_fec_proceso      ge_movimientos.fecha%TYPE,
                               p_hor_proceso      ge_movimientos.hora%TYPE,
                               p_importe          ge_movimientos.monto%TYPE) IS
  v_cod_programa varchar2(40):='PAJ_GLO.PR_UPD_CTA_CREDITO';
  BEGIN
    IF p_ind_cta_contable = 'N' THEN
      IF nvl(p_es_nocturno, 'N') = 'N' THEN
        -- Horario normal --
        IF nvl(fug_obt_pardinamico('MAD_TAR_GLOBAL',p_cod_mod_cta, p_cod_mad_cta),'N') = 'S' THEN
          BEGIN
          UPDATE ah_cta_vistas
             SET sal_total          = nvl(sal_total, 0) + p_importe,
                 fec_ult_movimiento = p_fec_proceso,
                 hor_ult_movimiento = p_hor_proceso,
                 estado             = decode(estado, 'I', 'N', estado)
           WHERE nro_cuenta = p_nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp  := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
              prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        ELSIF p_cod_mad_cta = 41 THEN
         BEGIN
          UPDATE cc_cta_corrientes
             SET sal_total          = nvl(sal_total, 0) + p_importe,
                 fec_ult_movimiento = p_fec_proceso,
                 hor_ult_movimiento = p_hor_proceso,
                 estado             = decode(estado, 'I', 'N', estado)
           WHERE nro_cuenta = p_nro_cuenta;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp  := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
              prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        ELSIF p_cod_mod_cta = 4 THEN
          BEGIN
          UPDATE cc_cta_bancarias
             SET sal_total          = nvl(sal_total, 0) + p_importe,
                 fec_ult_movimiento = p_fec_proceso,
                 hor_ult_movimiento = p_hor_proceso,
                 estado             = decode(estado, 'I', 'N', estado)
           WHERE nro_cuenta = p_nro_cuenta;
           EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp  := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
              prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        END IF;
      ELSE
        -- A la Noche o despues del cierre --
        IF nvl(fug_obt_pardinamico('MAD_TAR_GLOBAL',p_cod_mod_cta, p_cod_mad_cta),'N') = 'S' THEN
          BEGIN
          UPDATE ah_cta_vistas_noc
             SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + p_importe
           WHERE nro_cuenta = p_nro_cuenta;
           EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp  := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
              prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        ELSIF p_cod_mad_cta = 41 THEN
          BEGIN
          UPDATE cc_cta_corrientes_noc
             SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + p_importe
           WHERE nro_cuenta = p_nro_cuenta;
           EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp  := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
              prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        ELSIF p_cod_mod_cta = 4 THEN
         BEGIN
          UPDATE cc_cta_bancarias
             SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + p_importe
           WHERE nro_cuenta = p_nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
              v_cod_resp  := 999;
              v_msj_error := 'Error al actualizar saldo de cuenta';
              prg_ins_log_programas(v_cod_programa,substr(
                                  'Error al actualizar saldo de cuenta:' ||
                                  p_nro_cuenta || '.MsgErr:' || sqlerrm,1,4000));
          END;
        END IF;
      END IF;
    END IF;
  END pr_upd_cta_credito;

  --Insertamos el log.
  PROCEDURE pr_ins_log(p_fec_sistema       IN cj_log_glo_pro.fec_sistema%TYPE,
                       p_pedido            IN cj_log_glo_pro.pedido%TYPE,
                       p_respuesta         IN cj_log_glo_pro.respuesta%TYPE,
                       p_msj_error         IN cj_log_glo_pro.msj_error%TYPE,
                       p_fecha             IN cj_log_glo_pro.fecha%TYPE,
                       p_hora              IN cj_log_glo_pro.hora%TYPE,
                       p_nro_transaccion   IN cj_log_glo_pro.nro_transaccion%TYPE,
                       p_nro_cta_debito    IN cj_log_glo_pro.nro_cta_debito%TYPE,
                       p_cod_bco_debito    IN cj_log_glo_pro.cod_bco_debito%TYPE,
                       p_nro_cta_credito   IN cj_log_glo_pro.nro_cta_credito%TYPE,
                       p_cod_bco_credito   IN cj_log_glo_pro.cod_bco_credito%TYPE,
                       p_cod_operacion     IN cj_log_glo_pro.cod_operacion%TYPE,
                       p_mto_total         IN cj_log_glo_pro.mto_total%TYPE,
                       p_cod_moneda        IN cj_log_glo_pro.cod_moneda%TYPE,
                       p_nro_atm           IN cj_log_glo_pro.nro_atm%TYPE,
                       p_cod_bco_atm       IN cj_log_glo_pro.cod_bco_atm%TYPE,
                       p_nro_pos           IN cj_log_glo_pro.nro_pos%TYPE,
                       p_tra_pos           IN cj_log_glo_pro.tra_pos%TYPE,
                       p_tip_hora          IN cj_log_glo_pro.tip_hora%TYPE,
                       p_nom_comercio      IN cj_log_glo_pro.nom_comercio%TYPE,
                       p_nro_documento     IN cj_log_glo_pro.nro_documento%TYPE,
                       p_nro_tra_cancelado IN cj_log_glo_pro.nro_tra_cancelado%TYPE,
                       p_mot_cancelado     IN cj_log_glo_pro.mot_cancelacion%TYPE,
                       p_cod_estado        IN cj_log_glo_pro.cod_estado%TYPE,
                       p_cod_comercio      IN cj_log_glo_pro.cod_comercio%type,
                       p_mcc               IN cj_log_glo_pro.mcc%type,
                       p_cod_postal        IN cj_log_glo_pro.cod_postal%type,
                       p_nro_tarjeta       IN cj_log_glo_pro.nro_tarjeta%type,
                       p_cod_mon_iso       IN cj_log_glo_pro.cod_mon_iso%type,
                       p_cod_mon_iso_tra   IN cj_log_glo_pro.cod_mon_iso_tra%type,
                       p_fec_proceso       IN cj_log_glo_pro.fec_proceso%type,
                       p_hor_proceso       IN cj_log_glo_pro.hor_proceso%type,
                       p_cod_usuario       IN cj_log_glo_pro.cod_usuario%type,
                       p_tag_internacional IN cj_log_glo_pro.tag_internacional%type,
                       p_men_json          IN cj_log_glo_pro.men_json%type) IS
    pragma AUTONOMOUS_TRANSACTION;
    v_nom_programa varchar2(30):='PAJ_GLO.PR_INS_LOG';
  BEGIN
    BEGIN
      insert into it.cj_log_glo_pro
        (fec_sistema,
         pedido,
         respuesta,
         msj_error,
         fecha,
         hora,
         nro_transaccion,
         nro_cta_debito,
         cod_bco_debito,
         nro_cta_credito,
         cod_bco_credito,
         cod_operacion,
         mto_total,
         cod_moneda,
         nro_atm,
         cod_bco_atm,
         nro_pos,
         tra_pos,
         tip_hora,
         nom_comercio,
         nro_documento,
         nro_tra_cancelado,
         mot_cancelacion,
         cod_estado,
         cod_comercio,
         mcc,
         cod_postal,
         nro_tarjeta,
         cod_mon_iso,
         cod_mon_iso_tra,
         fec_proceso,
         hor_proceso,
         cod_usuario,
         tag_internacional,
         men_json)
      VALUES
        (p_fec_sistema,
         p_pedido,
         p_respuesta,
         p_msj_error,
         p_fecha,
         p_hora,
         p_nro_transaccion,
         p_nro_cta_debito,
         p_cod_bco_debito,
         p_nro_cta_credito,
         p_cod_bco_credito,
         p_cod_operacion,
         p_mto_total,
         p_cod_moneda,
         p_nro_atm,
         p_cod_bco_atm,
         p_nro_pos,
         p_tra_pos,
         p_tip_hora,
         p_nom_comercio,
         p_nro_documento,
         p_nro_tra_cancelado,
         p_mot_cancelado,
         p_cod_estado,
         p_cod_comercio,
         p_mcc,
         p_cod_postal,
         p_nro_tarjeta,
         p_cod_mon_iso,
         p_cod_mon_iso_tra,
         p_fec_proceso,
         p_hor_proceso,
         p_cod_usuario,
         p_tag_internacional,
         p_men_json
         );
      commit;
    EXCEPTION
      WHEN OTHERS THEN
           prg_ins_log_programas(v_nom_programa,
                                  substr(p_nro_cta_debito || ' ' ||
                                         SQLERRM,
                                         1,
                                         4000),
                                  NULL,
                                  p_nro_cta_debito);
           raise_application_error(-20000, 'No se puede realizar la inserción del log - ' || sqlerrm);
    END;
  END pr_ins_log;


  -- Obtener datos transaccion atm
  PROCEDURE pr_obt_dat_tra_atm(p_cod_tra_padre       IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
                               p_cod_modulo          IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE,
                               p_cod_modalidad       IN GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE,
                               p_ntr_atm             IN VARCHAR2,
                               p_cod_gru_transaccion OUT ge_gru_transacciones_det.cod_gru_transaccion%TYPE,
                               p_cod_tra_cargo       OUT NUMBER,
                               p_par_dinamico        OUT VARCHAR2) IS
  BEGIN
    SELECT cod_gru_transaccion,
           decode(cod_gru_transaccion, 51, 148, 52, 145, 53, 146, 54, 147),
           decode(cod_gru_transaccion,
                  51,
                  'CAN_MAX_EXT_PRO_ATM',
                  52,
                  'CAN_MAX_EXT_OTR_ATM',
                  53,
                  'CAN_MAX_CON_PRO_ATM',
                  54,
                  'CAN_MAX_CON_OTR_ATM')
      into p_cod_gru_transaccion, p_cod_tra_cargo, p_par_dinamico
      FROM ge_gru_transacciones_det g
     WHERE cod_modulo = p_cod_modulo
       AND cod_modalidad = p_cod_modalidad
       AND cod_transaccion = p_cod_tra_padre
       and ((p_ntr_atm = 'S' and cod_gru_transaccion in (51, 53)) or
           (p_ntr_atm = 'N' and cod_gru_transaccion in (52, 54)));
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_gru_transaccion := NULL;
      p_cod_tra_cargo       := NULL;
      p_par_dinamico        := NULL;
  END pr_obt_dat_tra_atm;

  PROCEDURE pr_web_cotizacion(p_tipo             IN VARCHAR2,
                              p_pagaOtorEntiCodi IN VARCHAR2,
                              p_date             IN DATE,
                              p_bidPrice         IN number,
                              p_askPrice         IN NUMBER,
                              p_cod_error        OUT NUMBER,
                              p_men_error        OUT VARCHAR2) is
  v_content      varchar2(4000);
  v_url          ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('WS_COTIZACION_GLP'); --url alta/modif. cotizacion global
  v_metodo       varchar2(10);
  v_cod_error    varchar2(10);
  v_men_error    varchar2(4000);
  v_cod_programa varchar2(30) := 'paj_glo.PR_WEB_COTIZACION';
  v_lugar        varchar2(3) := '00';

  begin
    -- inicio --
   v_lugar   := '01';
   -- se construye el json --
   v_content := '{"pagaOtorEntiCodi": '||p_pagaOtorEntiCodi ||','||
                 '"date": "'||to_char(p_date,'yyyy-mm-dd')||'",'||
                 '"bidPrice": '||p_bidPrice||','||
                 '"askPrice": '||p_askPrice||'}';
   -- valida el tipo
   if p_tipo = 'A' then
    v_lugar  := '02';
    v_accion := 'A';
    v_metodo := 'POST';
   elsif p_tipo = 'M' then
    v_lugar  := '03';
    v_accion := 'M';
    v_metodo := 'PUT';
   end if;

    -- Invoca al servicio
    pat_tgl.pr_ws_conector(v_content, v_url, '000000000', '0000000', v_accion, v_metodo, v_cod_error, v_men_error);

   -- verifica si hubo error --
   if v_cod_error != v_cod_msg_exito then
    p_cod_error := v_cod_error;
    p_men_error := 'json= '||v_content||' # '||v_men_error;
    -- guarda en el log de errores --
    prg_ins_log_programas(v_cod_programa, 'Error de metodo '||p_tipo||'->'||v_metodo||chr(13)||
                          'URL: '||v_url||chr(13)||
                          'MsgErr: '||p_cod_error||' - '||p_men_error);
   else
     -- sin error al invocar el servicio
    p_cod_error := v_pro_correcto;
    p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),'Transaccion Exitosa!');
   end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'json= '||v_content||' # '||v_cod_programa||' # '||'Lugar: '||v_lugar||' # sqlerrm: '||substr(sqlerrm,1,3800);
      prg_ins_log_programas(v_cod_programa, 'Error en programa.'||chr(13)||
                            'servicio: '||v_url||chr(13)||
                            'MsgErr: '||p_cod_error||' - '||p_men_error);
  end;


END paj_glo;
/
