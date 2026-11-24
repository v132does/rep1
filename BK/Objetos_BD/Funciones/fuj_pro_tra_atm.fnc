CREATE OR REPLACE FUNCTION IT.fuj_pro_tra_atm(p_pedido VARCHAR2) RETURN VARCHAR2 IS
   ---
   v_cod_entidad     NUMBER(3);
   v_es_banco        VARCHAR2(1) := 'N';
   v_clt_deb_nuestro VARCHAR2(1) := 'N';
   v_clt_cre_nuestro VARCHAR2(1) := 'N';
   v_atm_nuestro     VARCHAR2(1) := 'N';
   v_hor_limite      VARCHAR2(8) := '999999';
   v_est_modulo      ba_modulos.estado%TYPE;
   v_est_cuenta      ge_cuentas.estado%TYPE;
   v_est_cta_cre     ge_cuentas.estado%TYPE;
   -- Variables de la Cuenta
   v_mod_cta_deb         ge_movimientos.cod_modulo%TYPE;
   v_mad_cta_deb         ge_movimientos.cod_modalidad%TYPE;
   v_mon_cta_deb         ge_movimientos.cod_moneda%TYPE;
   v_ofi_cta_deb         ge_movimientos.cod_oficina%TYPE;
   v_cod_rub_caja        ge_movimientos.cod_rubro%TYPE;
   v_mod_cta_cre         ge_movimientos.cod_modulo%TYPE;
   v_mad_cta_cre         ge_movimientos.cod_modalidad%TYPE;
   v_mon_cta_cre         ge_movimientos.cod_moneda%TYPE;
   v_ofi_cta_cre         ge_movimientos.cod_oficina%TYPE;
   v_ind_ctacontable     VARCHAR2(1) := 'N';
   v_cod_tra_contable    ge_movimientos.cod_transaccion%TYPE;
   v_mod_contable        ge_movimientos.cod_modulo%TYPE;
   v_mad_contable        ge_movimientos.cod_modalidad%TYPE;
   v_cod_rubro           ge_movimientos.cod_rubro%TYPE;
   v_cta_com             ah_cta_vistas.cta_combinada%TYPE; --Indicador si es cta. combinada
   v_nro_cta_combinada   varchar2(30) := '';--nro cuenta combinada
   v_sal_dis_debito      number(18,2) := 0;--para cuenta combinada
   v_est_cta_comb        ge_cuentas.estado%type := '';--para cuenta combinada
   v_cod_cliente         ge_cta_clientes.cod_persona%TYPE;
   v_cod_seg_funcionario ge_seg_clientes.cod_seg_cliente%TYPE := fug_obt_pardinamico('GEN_COD_SEG_FUNCIONARIO');
   v_exo_mto_minimo VARCHAR2(1) := 'N';
   --- Variables del movimiento...
   v_fec_proceso    ge_movimientos.fecha%TYPE;
   v_fec_valor      ge_movimientos.fecha%TYPE;
   v_cod_moneda     ba_monedas.cod_moneda%TYPE;
   v_acu_sobregiro  cc_cta_corrientes.acu_sobregiro%TYPE;
   v_importe        ge_movimientos.monto%TYPE := 0;
   v_imp_debito      number(18,2);
   v_imp_credito     number(18,2);
   v_cot_debito      ge_movimientos.cotizacion%type;
   v_cot_credito     ge_movimientos.cotizacion%type;
   v_nro_caja       cj_movimientos.nro_caja%TYPE;
   v_ofi_origen     cj_movimientos.cod_oficina%TYPE;
   v_hora           cj_movimientos.hora%TYPE;
   v_cod_tra_padre  cj_movimientos.cod_tra_padre%TYPE;
   v_nro_documento  ge_movimientos.nro_documento%TYPE;
   v_nro_documento3 ge_movimientos.nro_documento3%TYPE;
   v_nro_secuencia  ge_movimientos.nro_secuencia%TYPE;
   v_tipo           cj_movimientos.tipo%TYPE; -- indicador de si entrega o recibe (e=entrega, r=recibe)
   v_tip_monto      cj_movimientos.tip_monto%TYPE; -- tipo de monto (e=efectivo, c=cargo nuestro, o=cargo otros)
   v_concepto       ge_movimientos.concepto%TYPE;
   v_cod_modulo     ge_movimientos.cod_modulo%TYPE := 9; -- Caja
   v_cod_modalidad  ge_movimientos.cod_modalidad%TYPE := 91; -- Caja
   --v_cod_usuario    ge_movimientos.cod_usuario%TYPE := upper(USER);
   v_cod_usuario    ge_movimientos.cod_usuario%TYPE;
   -- Variables para cobros de cargos por extraccion.
   v_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE;
   v_val_tas_cargo    ge_movimientos.val_tasa%TYPE;
   v_val_cargo        ge_movimientos.val_tasa%TYPE;
   v_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE;
   v_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE;
   v_val_tas_impuesto ge_movimientos.val_tasa%TYPE;
   v_val_impuesto     ge_movimientos.val_tasa%TYPE;
   v_cargos           ge_movimientos.monto%TYPE;
   v_msj_error        cj_log_atm.msj_error%TYPE;
   v_fec_inicio       cj_log_atm.fec_inicio%TYPE := SYSDATE;
   v_nro_cta_ueno     ge_cuentas.nro_cuenta%TYPE;
   --
   -- Posibles Respuestas --
   vr_aprobado         VARCHAR2(2) := '00';
   vr_reintente        VARCHAR2(2) := '19';
   vr_no_aprobado      VARCHAR2(2) := '05';
   vr_cta_inexistente  VARCHAR2(2) := '14';
   vr_ope_invalida     VARCHAR2(2) := '12';
   vr_sal_insuficiente VARCHAR2(2) := '51';
   vr_otr_error        VARCHAR2(2) := '99';
   vr_en_cierre        VARCHAR2(2) := '91';
   vr_mes_incorrecto   VARCHAR2(2) := '50';
   vr_mto_limite       VARCHAR2(2) := '61';
   --
   g_cod_error pag_cta.g_cod_error%TYPE;
   -- Variables para manejar los parametros --
   vp_cta_debito    VARCHAR2(10);
   vp_bco_debito    VARCHAR2(3);
   vp_cta_credito   VARCHAR2(10);
   vp_bco_credito   VARCHAR2(3);
   vp_operacion     VARCHAR2(2);
   vp_extorno       VARCHAR2(2);
   vp_tra_entidad   VARCHAR2(15);
   vp_transaccion   VARCHAR2(15);
   vp_importe       VARCHAR2(15);
   vp_importe2      VARCHAR2(15);
   vp_importe3      VARCHAR2(15);
   vp_can_cheques   VARCHAR2(4);
   vp_moneda        VARCHAR2(2);
   vp_nro_atm       VARCHAR2(3);
   vp_nro_pos       VARCHAR2(2);
   vp_tra_pos       VARCHAR2(4);
   vp_tip_hora      VARCHAR2(3);
   vp_negocio       VARCHAR2(40);
   vp_tra_extornado VARCHAR2(15);
   vp_bco_atm       VARCHAR2(3);
   vp_fecha         VARCHAR2(8);
   vp_hora          VARCHAR2(6);
   vp_servicio      VARCHAR2(3);
   vp_prestacion    VARCHAR2(4);
   vp_marca         VARCHAR2(3);
   vp_producto      VARCHAR2(3);
   vp_med_pago      VARCHAR2(2);
   vp_car_inicial   VARCHAR2(1);
   vp_mes_nacimiento VARCHAR2(11);
   vp_relacion       VARCHAR2(2);
   vp_val_mes_nac    varchar2(1);

   -- De salida...
   vp_cod_respuesta  VARCHAR2(2);
   vp_sal_disponible VARCHAR2(15);
   vp_sig_disponible VARCHAR2(1);
   vp_sal_contable   VARCHAR2(15);
   vp_sig_contable   VARCHAR2(1);
   vp_can_extractos  VARCHAR2(3);
   vp_extractos      VARCHAR2(512);
   vp_respuesta      VARCHAR2(2000);

   v_horario          VARCHAR2(1) := 'D'; -- (D) Dia, (T) Tarde, (N) Nocturno
   v_es_nocturno      VARCHAR2(1) := 'N';
   v_es_cta_noc       VARCHAR2(1) := 'N';
   v_ind_cob_comision VARCHAR2(1) := fug_obt_pardinamico('CAJ_IND_COB_COMISION');
   r_gmovi            ge_movimientos%ROWTYPE;
   v_pedido           varchar2(3000) := p_pedido;--substr(p_pedido,2);
   v_nro_cuenta       ge_cuentas.nro_cuenta%type;
   v_cod_gru_transaccion  NUMBER;
   v_cod_transaccion      NUMBER;
   v_par_dinamico         GE_PARAMETROS.PARAMETRO%TYPE;
   v_ntr_atm              VARCHAR2(1);
   v_car_mas_iva          NUMBER(18,2) := 0;
   v_bncmsg               VARCHAR2(408) := '';
   v_lon                  NUMBER(3);
   v_lon_total            NUMBER(3);
   n_bncmsg               VARCHAR2(408) := '';
   v_doceli               VARCHAR2(480) := '';
   v_scrdta               VARCHAR2(322) := '';
   v_can_letras           NUMBER := 0;
   v_tip_transaccion      GE_TRANSACCIONES.TIPO%type;
   v_gru_reversiones      GE_PAR_DINAMICOS.VAL_PARAMETRO%type:=fug_obt_pardinamico('CJ_GRU_TRA_ATM_REVERSIONES');
   v_retorno              varchar2(1);


   ---------- Definicion de procesos y funciones locales
   FUNCTION lf_obt_mes_nac(p_nro_cuenta varchar2, p_relacion varchar2) RETURN VARCHAR2 IS
      v_mes VARCHAR2(3) := null;
      v_cta_principal ge_cuentas.nro_cuenta%type;

   BEGIN
       SELECT mes INTO v_mes FROM
       (SELECT DECODE(substr(TO_CHAR(TO_DATE(b.fec_nacimiento), 'MONTH'), 1, 3),
              'SEP',
              'SET',
              substr(TO_CHAR(TO_DATE(b.fec_nacimiento), 'MONTH'), 1, 3))
              mes
         FROM ah_tar_debitos a, ba_per_fisicas b
        WHERE a.cod_persona = b.cod_persona
        and a.adherente = p_relacion
        and a.nro_cuenta = p_nro_cuenta
        and rownum = 1
       UNION
       SELECT DECODE(substr(TO_CHAR(TO_DATE(b.fec_apertura), 'MONTH'), 1, 3),
              'SEP',
              'SET',
              substr(TO_CHAR(TO_DATE(b.fec_apertura), 'MONTH'), 1, 3))
              mes
         FROM ah_tar_debitos a, ba_per_juridicas b
        WHERE a.cod_persona = b.cod_persona
          and a.adherente = p_relacion
          and a.nro_cuenta = p_nro_cuenta
          and rownum = 1
          );
      --
      RETURN v_mes;
   EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          select nro_cuenta
            into v_cta_principal
            from ah_tar_deb_cuentas
           where nro_cta_relacionada = p_nro_cuenta;

          SELECT mes
            INTO v_mes
            FROM (SELECT DECODE(substr(TO_CHAR(TO_DATE(b.fec_nacimiento),
                                               'MONTH'),
                                       1,
                                       3),
                                'SEP',
                                'SET',
                                substr(TO_CHAR(TO_DATE(b.fec_nacimiento),
                                               'MONTH'),
                                       1,
                                       3)) mes
                    FROM ah_tar_debitos a, ba_per_fisicas b
                   WHERE a.cod_persona = b.cod_persona
                     and a.adherente = p_relacion
                     and a.nro_cuenta = v_cta_principal
                     and rownum = 1
                  UNION
                  SELECT DECODE(substr(TO_CHAR(TO_DATE(b.fec_apertura),
                                               'MONTH'),
                                       1,
                                       3),
                                'SEP',
                                'SET',
                                substr(TO_CHAR(TO_DATE(b.fec_apertura),
                                               'MONTH'),
                                       1,
                                       3)) mes
                    FROM ah_tar_debitos a, ba_per_juridicas b
                   WHERE a.cod_persona = b.cod_persona
                     and a.adherente = p_relacion
                     and a.nro_cuenta = v_cta_principal
                     and rownum = 1);
          RETURN v_mes;
        EXCEPTION
          WHEN no_data_found THEN
            RETURN v_mes;
        END;
   END;

   FUNCTION lf_obt_tipo
   (
      p_cod_transaccion ge_transacciones.cod_transaccion%TYPE,
      p_cod_modulo      ge_cuentas.cod_modulo%TYPE,
      p_cod_modalidad   ge_cuentas.cod_modalidad%TYPE
   ) RETURN VARCHAR2 IS
      v_tipo ge_transacciones.tipo%TYPE := '';
   BEGIN
      SELECT tipo
        INTO v_tipo
        FROM ge_transacciones
       WHERE cod_transaccion = p_cod_transaccion
         AND cod_modulo = p_cod_modulo
         AND cod_modalidad = p_cod_modalidad;
      RETURN v_tipo;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN v_tipo;
   END;

   FUNCTION lf_es_sponsor(p_nro_cuenta VARCHAR2) RETURN VARCHAR2 IS
      v_es_sponsor VARCHAR2(1) := 'N';
   BEGIN
      SELECT 'S'
        INTO v_es_sponsor
        FROM ge_par_entes p, ge_entes e
       WHERE e.tipo = 'SP' -- Sponsor
         AND p.cod_ente = e.cod_ente
         AND p.parametro = 'NRO_CUENTA'
         AND p.val_parametro = p_nro_cuenta;
      --
      RETURN v_es_sponsor;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN v_es_sponsor;
   END lf_es_sponsor;
   ---
   FUNCTION lf_exi_banco(p_cod_banco NUMBER) RETURN VARCHAR2 IS
      v_exi_banco VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         SELECT 'B'
           INTO v_exi_banco
           FROM ge_bancos
          WHERE cod_banco = p_cod_banco;
      EXCEPTION
         WHEN no_data_found THEN
            SELECT 'F'
              INTO v_exi_banco
              FROM ge_entes e, ge_par_entes p
             WHERE e.tipo = 'FI'
               AND e.cod_ente = p.cod_ente
               AND p.parametro = 'COD_ENT_FINANCIERA'
               AND p.val_parametro = p_cod_banco;
      END;
      --
      RETURN v_exi_banco;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN v_exi_banco;
   END lf_exi_banco;

  --DA-5403
  FUNCTION fu_obt_mov_user_atm(p_tip_user in ba_cod_referencias.abreviatura%type)
    return varchar2 is
    v_nro_sec  number;
    v_can_user number;
    v_nro_user number;
    v_user     ba_usuarios.cod_usuario%type;

  BEGIN
    select count(*)
      into v_can_user
      from ba_cod_referencias
     where dominio = 'USU_MOV_SERVICIO'
       and abreviatura = p_tip_user;

    v_nro_sec  := fue_obt_sig_secuencia('S_SER_USER');
    v_nro_user := mod(v_nro_sec, v_can_user);
    v_user     := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO', v_nro_user, p_tip_user);
    return v_user;
  EXCEPTION
    WHEN OTHERS THEN
      null;
  END;

  --DA-5403
  FUNCTION fu_obt_hora_atm(p_cod_usuario varchar2) return varchar2 is
    v_hora        ge_movimientos.hora%type;
    v_nro_sec     number;
    v_nro_hor     number;
    v_ind_usuario number;

  BEGIN
    if instr(p_cod_usuario, '_', 1) = 0 then
      v_ind_usuario := 0;
    else
      v_ind_usuario := substr(p_cod_usuario, instr(p_cod_usuario, '_', 1) + 1, 1);
    end if;

    if v_ind_usuario > 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_mov' /*||'_'*/|| v_ind_usuario);
    elsif v_ind_usuario = 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_mov');
    end if;

    v_nro_hor := mod(v_nro_sec, 86400);

    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

    return v_hora;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'No se puede obtener la hora del movimiento. ' || sqlerrm);
  END;

   ---
   PROCEDURE lp_ver_horario IS
   BEGIN
      v_horario     := 'D'; -- Dia
      v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
      v_es_cta_noc  := 'N';
      v_fec_proceso := pag_cal.fu_obt_fec_actual(3);
      IF v_est_modulo = 2 THEN
         -- El modulo esta abierto
         -- Verifica la hora --
         IF (vp_hora > v_hor_limite AND v_fec_proceso = to_date(vp_fecha, 'ddmmyyyy')) /*OR
             v_fec_proceso < to_date(vp_fecha, 'ddmmyyyy')*/ THEN
            v_horario     := 'T'; -- Tarde
            v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1, 1, v_ofi_origen);
            v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
         END IF;
      ELSE
         v_horario     := 'N'; -- Noche
         v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1, 1, v_ofi_origen);
         v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
         v_es_cta_noc  := 'S'; -- Solo para que llavee la cuenta nocturna
      END IF;
      v_fec_valor := trunc(SYSDATE); -- para que sea fecha la fecha real de la transaccion --v_fec_proceso;
   END lp_ver_horario;

   PROCEDURE lp_upd_cta_debito(p_mod_cta_deb in number default null, 
                               p_mad_cta_deb in number default null ,
                               p_cta_debito in varchar2 default null, 
                               p_imp_debito in number default null) is
   BEGIN
      IF v_ind_ctacontable = 'N' THEN
         IF v_horario = 'D' THEN
            -- Horario normal --
            IF nvl(p_mad_cta_deb,v_mad_cta_deb) in (31,38,39,334) THEN
               UPDATE ah_cta_vistas
                  SET sal_total          = nvl(sal_total, 0) - nvl(p_imp_debito,v_importe),
                      fec_ult_movimiento = v_fec_proceso,
                      hor_ult_movimiento = v_hora,
                      estado             = decode(estado, 'I', 'N', estado)
                WHERE nro_cuenta         = nvl(p_cta_debito, vp_cta_debito);
            ELSIF nvl(p_mad_cta_deb,v_mad_cta_deb) = 41 THEN
               UPDATE cc_cta_corrientes
                  SET sal_total          = nvl(sal_total, 0) - nvl(p_imp_debito,v_importe),
                      fec_ult_movimiento = v_fec_proceso,
                      hor_ult_movimiento = v_hora,
                      estado             = decode(estado, 'I', 'N', estado)
                WHERE nro_cuenta         = nvl(p_cta_debito,vp_cta_debito);
            /*ELSIF v_mod_cta_deb = 4 THEN
            -- Mejoras ATM HA-3339
            -- No Actualizar Saldo de la Cuenta de Debito cuando sea Cuenta Bancaria.
               UPDATE cc_cta_bancarias
                  SET sal_total          = nvl(sal_total, 0) - v_importe,
                      fec_ult_movimiento = v_fec_proceso,
                      hor_ult_movimiento = v_hora,
                      estado             = decode(estado, 'I', 'N', estado)
                WHERE nro_cuenta = vp_cta_debito;*/
            END IF;
         ELSIF v_horario = 'T' THEN
            -- A la Tarde --
            IF nvl(p_mad_cta_deb,v_mad_cta_deb) in (31,38,39,334) THEN
               UPDATE ah_cta_vistas
                  SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + nvl(p_imp_debito,v_importe)
                WHERE nro_cuenta         = nvl(p_cta_debito, vp_cta_debito);
            ELSIF nvl(p_mad_cta_deb,v_mad_cta_deb) = 41 THEN
               UPDATE cc_cta_corrientes
                  SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + nvl(p_imp_debito,v_importe)
                WHERE nro_cuenta         = nvl(p_cta_debito, vp_cta_debito);
            /*ELSIF v_mod_cta_deb = 4 THEN
            -- Mejoras ATM HA-3339
            -- No Actualizar Saldo de la Cuenta de Debito cuando sea Cuenta Bancaria.
               UPDATE cc_cta_bancarias
                  SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + v_importe
                WHERE nro_cuenta = vp_cta_debito;*/
            END IF;
         ELSE
            -- A la Noche o despues del cierre --
            IF nvl(p_mad_cta_deb,v_mad_cta_deb) in (31,38,39,334) THEN
               UPDATE ah_cta_vistas_noc
                  SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + nvl(p_imp_debito,v_importe)
                WHERE nro_cuenta = nvl(p_cta_debito,vp_cta_debito);
            ELSIF v_mad_cta_deb = 41 THEN
               UPDATE cc_cta_corrientes_noc
                  SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + nvl(p_imp_debito,v_importe)
                WHERE nro_cuenta = nvl(p_cta_debito,vp_cta_debito);
            /*ELSIF v_mod_cta_deb = 4 THEN
            -- Mejoras ATM HA-3339
            -- No Actualizar Saldo de la Cuenta de Debito cuando sea Cuenta Bancaria.
               UPDATE cc_cta_bancarias
                  SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + v_importe
                WHERE nro_cuenta = vp_cta_debito;*/
            END IF;
         END IF;
      END IF;
   END lp_upd_cta_debito;
   --
   PROCEDURE lp_upd_cta_credito IS
   BEGIN
      IF v_horario = 'D' THEN
         -- Horario normal --
         IF v_mad_cta_cre in (31,38,39,334) THEN
            UPDATE ah_cta_vistas
               SET sal_total = nvl(sal_total, 0) + v_imp_credito,
                   estado    = decode(estado,'I','N','A','N',estado)
             WHERE nro_cuenta = vp_cta_credito;
         ELSIF v_mad_cta_cre = 41 THEN
            UPDATE cc_cta_corrientes
               SET sal_total = nvl(sal_total, 0) + v_imp_credito,
                   estado    = decode(estado, 'I', 'N', estado)
             WHERE nro_cuenta = vp_cta_credito;
         /*ELSIF v_mod_cta_cre = 4 THEN
         -- Mejoras ATM HA-3339
         -- No Actualizar Saldo de la Cuenta de Debito cuando sea Cuenta Bancaria.
            UPDATE cc_cta_bancarias
               SET sal_total = nvl(sal_total, 0) + v_importe,
                   estado    = decode(estado, 'I', 'N', estado)
             WHERE nro_cuenta = vp_cta_credito;*/
         END IF;
      ELSIF v_horario = 'T' THEN
         -- A la Tarde --
         IF v_mad_cta_cre in (31,38,39,334) THEN
            UPDATE ah_cta_vistas
               SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
             WHERE nro_cuenta = vp_cta_credito;
         ELSIF v_mad_cta_cre = 41 THEN
            UPDATE cc_cta_corrientes
               SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
             WHERE nro_cuenta = vp_cta_credito;
         /*ELSIF v_mod_cta_cre = 4 THEN
         -- Mejoras ATM HA-3339
         -- No Actualizar Saldo de la Cuenta de Debito cuando sea Cuenta Bancaria.
            UPDATE cc_cta_bancarias
               SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe
             WHERE nro_cuenta = vp_cta_credito;*/
         END IF;
      ELSE
         -- A la Noche o despues del Cierre --
         IF v_mad_cta_cre in (31,38,39,334) THEN
            UPDATE ah_cta_vistas_noc
               SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
             WHERE nro_cuenta = vp_cta_credito;
         ELSIF v_mad_cta_cre = 41 THEN
            UPDATE cc_cta_corrientes_noc
               SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_imp_credito
             WHERE nro_cuenta = vp_cta_credito;
         /*ELSIF v_mod_cta_cre = 4 THEN
         -- Mejoras ATM HA-3339
         -- No Actualizar Saldo de la Cuenta de Debito cuando sea Cuenta Bancaria.
            UPDATE cc_cta_bancarias
               SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe
             WHERE nro_cuenta = vp_cta_credito;*/
         END IF;
      END IF;
   END lp_upd_cta_credito;
   procedure lp_env_notificacion (p_nro_cuenta in varchar2,
                                  p_monto      in number,
                                  p_nro_boleta in number,
                                  p_operacion  in number,
                                  p_hora       in varchar2)
   is
     v_concepto varchar2(50);
   begin
     select case
              when p_operacion = 0 then
               'compra'
              when p_operacion = 5 then
               'extraccion'
              when p_operacion = 41 then
               'transferencia'
              when p_operacion in (50, 51, 54, 55) then
               'transaccion en el extranjero'
              else
               'transaccion'
            end
       into v_concepto
       from dual;
       --comentado para bankitti
       /*If p_monto > 0 then
         paw_not.pr_pro_servicio_002(p_nro_cuenta, p_monto, vp_negocio, v_concepto,'N', p_hora);
       else -- reversion de la operacion
         paw_not.pr_pro_servicio_002(p_nro_cuenta, abs(p_monto), vp_negocio, v_concepto,'S', p_hora);
       End if;*/
   end;
   PROCEDURE lp_upd_caja IS
      v_existe     VARCHAR2(1) := 'N';
      v_nro_cuenta cj_movimientos.nro_cuenta%TYPE := NULL;
   BEGIN
      v_tipo := 'E';
      -------------
      IF v_clt_deb_nuestro = 'S' THEN
         v_nro_cuenta := to_char(to_number(vp_cta_debito));
      ELSE
         v_nro_cuenta := NULL;
      END IF;
      -------------
      IF to_number(vp_operacion) = 99 THEN
         -- Extorno
         v_tipo := 'R';
      END IF;
      -- genero el movimiento por la extraccion
      IF v_horario = 'D' THEN
         -- Es un dia normal y es de mañana...
         INSERT INTO cj_movimientos
            (fecha, hora, cod_usuario, nro_secuencia, cod_tra_padre, cod_mod_padre, cod_mad_padre,
             cod_oficina, cod_moneda, nro_caja, nro_documento, nro_cuenta, monto, tip_monto, tipo)
         VALUES
            (v_fec_proceso, v_hora, v_cod_usuario, 1, v_cod_tra_padre, v_cod_modulo,
             v_cod_modalidad, v_ofi_origen, v_cod_moneda, v_nro_caja, v_nro_documento, v_nro_cuenta,
             v_importe, v_tip_monto /* efectivo */, v_tipo); /* es debito */
      ELSE
         INSERT INTO cj_movimientos_noc
            (fecha, hora, cod_usuario, nro_secuencia, cod_tra_padre, cod_mod_padre, cod_mad_padre,
             cod_oficina, cod_moneda, nro_caja, nro_documento, nro_cuenta, monto, tip_monto, tipo)
         VALUES
            (v_fec_proceso, v_hora, v_cod_usuario, 1, v_cod_tra_padre, v_cod_modulo,
             v_cod_modalidad, v_ofi_origen, v_cod_moneda, v_nro_caja, v_nro_documento, v_nro_cuenta,
             v_importe, v_tip_monto /* efectivo */, v_tipo); /* es debito */
      END IF;
      -- Verifico si existe el control de caja para la fecha de proceso...
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM cj_controles
          WHERE nro_caja = v_nro_caja
            AND cod_moneda = v_cod_moneda
            AND fecha = v_fec_proceso;
         -- Actualizo el control de caja
         UPDATE cj_controles
            SET sal_actual   = nvl(sal_actual, 0) - nvl(v_importe, 0),
                tot_creditos = nvl(tot_creditos, 0) + nvl(v_importe, 0),
                can_creditos = nvl(can_creditos, 0) + 1,
                estado       = 1 -- abierto
          WHERE nro_caja = v_nro_caja
            AND cod_moneda = v_cod_moneda
            AND fecha = v_fec_proceso;
      EXCEPTION
         WHEN no_data_found THEN
            -- Si no existe debe insertar el control...
            INSERT INTO cj_controles
               (nro_caja, cod_moneda, fecha, mto_apertura, sal_actual, mto_cierre, tot_debitos,
                tot_creditos, tot_che_nue_bco, tot_che_otr_bco, det_che_nue_bco, det_che_otr_bco,
                can_debitos, can_creditos, estado, cod_usu_actual)
            VALUES
               (v_nro_caja, v_cod_moneda, v_fec_proceso, 0, v_importe, 0, 0, v_importe, 0, 0, 0, 0,
                0, 1, 1, USER);
      END;
   END lp_upd_caja;

   PROCEDURE lp_car_salida IS
   BEGIN
         vp_respuesta := vp_cod_respuesta || vp_sal_disponible || vp_sig_disponible ||
                         vp_sal_contable || vp_sig_contable || vp_transaccion || vp_tra_entidad ||
                         vp_can_extractos;
   END lp_car_salida;

   PROCEDURE lp_obt_respuesta IS
   BEGIN
      v_doceli := FUG_OBT_MENSAJE(FUG_OBT_PARDINAMICO('ATM_TEX_IMP_TICKET'));
      v_scrdta := FUG_OBT_MENSAJE(FUG_OBT_PARDINAMICO('ATM_TEX_IMP_PANTALLA'));

      if v_doceli is null or trim(v_doceli) = '' then
        for i in 1..480 loop
           v_doceli := v_doceli || ' ';
        end loop;
      end if;
      if v_scrdta is null or trim(v_scrdta) = '' then
        for j in 1..322 loop
           v_scrdta := v_scrdta || ' ';
        end loop;
      end if;

      --se deben devolver los textos sin acentos
      if v_car_mas_iva != 0 then
        v_bncmsg := 'Por la operacion solicitada pagara un gasto de ' || TO_CHAR(v_car_mas_iva, '999G999G999D99') || ' ' || v_mon_cta_deb || '.';
      else
        v_bncmsg := ' ';
      end if;
      v_lon := length(v_bncmsg);
      v_lon_total := 408;
      for k in v_lon+1..408 loop
         v_bncmsg := v_bncmsg || ' ';
      end loop;

      vp_respuesta := vp_respuesta || v_doceli || v_scrdta || v_bncmsg;

      IF vp_can_extractos != '000' THEN
        vp_respuesta := vp_respuesta || rpad(nvl(vp_extractos, ' '), 512, ' ');
      END IF;
   END;

   procedure lp_reg_operacion(p_men_recibido      in varchar2 default null,
                              p_respuesta         in varchar2 default null,
                              p_msj_error         in varchar2 default null,
                              p_fec_inicio        in date default null,
                              p_cod_extorno       in varchar2 default null,
                              p_fec_valor         in date default null,
                              p_nro_transaccion   in number default null,
                              p_nro_cta_debito    in varchar2 default null,
                              p_hora              in varchar2 default null,
                              p_cod_bco_debito    in number default null,
                              p_nro_cta_credito   in varchar2 default null,
                              p_cod_bco_credito   in number default null,
                              p_cod_operacion     in varchar2 default null,
                              p_mto_total         in number default null,
                              p_cod_moneda        in varchar2 default null,
                              p_nro_atm           in number default null,
                              p_nro_pos           in number default null,
                              p_tra_pos           in number default null,
                              p_tip_hora          in varchar2 default null,
                              p_nom_comercio      in varchar2 default null,
                              p_nro_tra_extornado in varchar2 default null,
                              p_cod_bco_atm       in number default null,
                              p_servicio          in varchar2 default null,
                              p_prestacion        in varchar2 default null,
                              p_marca             in varchar2 default null,
                              p_producto          in varchar2 default null,
                              p_med_pago          in varchar2 default null) is

     PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
   begin
     INSERT INTO cj_log_atm
        (fec_sistema,
         pedido,
         respuesta,
         msj_error,
         fec_inicio,
         cod_extorno,
         fecha,
         nro_transaccion,
         nro_cta_debito,
         hora,
         cod_bco_debito,
         nro_cta_credito,
         cod_bco_credito,
         cod_operacion,
         mto_total,
         cod_moneda,
         nro_atm,
         nro_pos,
         tra_pos,
         tip_hora,
         nom_comercio,
         nro_tra_extornado,
         cod_bco_atm,
         servicio,
         prestacion,
         marca,
         producto,
         med_pago)
     VALUES
        (SYSDATE,
         p_men_recibido,
         p_respuesta,
         p_msj_error,
         p_fec_inicio,
         p_cod_extorno,
         p_fec_valor,
         p_nro_transaccion,
         p_nro_cta_debito,
         p_hora,
         p_cod_bco_debito,
         p_nro_cta_credito,
         p_cod_bco_credito,
         p_cod_operacion,
         p_mto_total,
         p_cod_moneda,
         p_nro_atm,
         p_nro_pos,
         p_tra_pos,
         p_tip_hora,
         p_nom_comercio,
         p_nro_tra_extornado,
         p_cod_bco_atm,
         p_servicio,
         p_prestacion,
         p_marca,
         p_producto,
         p_med_pago);
     COMMIT;
   exception
     when others then
       null;
   end;

   PROCEDURE lp_car_parametros IS
      v_indice NUMBER(3) := 1;
      v_cod_oficina ba_oficinas.cod_oficina%type;

   BEGIN
      if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_DEB_COMPUESTA'),'N') = 'S' then
         v_cod_oficina    := to_char(to_number(substr(v_pedido,1,2)));
         vp_cta_debito    := to_char(to_number(substr(v_pedido, 3, 8)));
         if v_cod_oficina <> '0' then
            vp_cta_debito    := v_cod_oficina||vp_cta_debito;
         end if;
      elsif nvl(fug_obt_pardinamico('CAJ_ATM_CTA_ALFANUMERICO'),'N') = 'S' then
         vp_cta_debito    := to_char(substr(v_pedido, 1, 10));
      else
         vp_cta_debito    := to_char(to_number(substr(v_pedido, 1, 10)));
      end if;

      v_indice         := v_indice + 10;
      vp_bco_debito    := substr(v_pedido, v_indice, 3);
      v_indice         := v_indice + 3;

      if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_DEB_COMPUESTA'),'N') = 'S' then
         v_cod_oficina    := to_char(to_number(substr(v_pedido,v_indice,2)));

     vp_cta_credito    := to_char(to_number(substr(v_pedido, v_indice+2, 8)));

     if v_cod_oficina <> '0' then
      vp_cta_credito    := v_cod_oficina||vp_cta_credito;
     end if;

      else
         vp_cta_credito    := to_char(to_number(substr(v_pedido, v_indice, 10)));
      end if;

      v_indice         := v_indice + 10;
      vp_bco_credito   := substr(v_pedido, v_indice, 3);
      v_indice         := v_indice + 3;
      vp_operacion     := substr(v_pedido, v_indice, 2);
      v_indice         := v_indice + 2;
      vp_extorno       := substr(v_pedido, v_indice, 2);
      v_indice         := v_indice + 2;
      vp_tra_entidad   := substr(v_pedido, v_indice, 15);
      v_indice         := v_indice + 15;
      vp_transaccion   := substr(v_pedido, v_indice, 15);
      v_indice         := v_indice + 15;
      vp_importe       := substr(v_pedido, v_indice, 15);
      v_indice         := v_indice + 15;
      vp_importe2      := substr(v_pedido, v_indice, 15);
      v_indice         := v_indice + 15;
      vp_importe3      := substr(v_pedido, v_indice, 15);
      v_indice         := v_indice + 15;
      vp_can_cheques   := substr(v_pedido, v_indice, 4);
      v_indice         := v_indice + 4;
      vp_moneda        := substr(v_pedido, v_indice, 2);
      v_indice         := v_indice + 2;
      vp_nro_atm       := substr(v_pedido, v_indice, 3);
      v_indice         := v_indice + 3;
      vp_nro_pos       := substr(v_pedido, v_indice, 2);
      v_indice         := v_indice + 2;
      vp_tra_pos       := substr(v_pedido, v_indice, 4);
      v_indice         := v_indice + 4;
      vp_tip_hora      := substr(v_pedido, v_indice, 3);
      v_indice         := v_indice + 3;

      if nvl(fug_obt_pardinamico('CAJ_ATM_VAL_MES_NAC'),'N') = 'S' then
          vp_negocio       := substr(v_pedido, v_indice, 40);
          vp_car_inicial   := substr(v_pedido, v_indice, 1);--varia caracter recibido en esta posicion
          v_indice         := v_indice + 40;

          vp_val_mes_nac := 'N';
          if substr(vp_negocio, 1, 4) = '#MC#' then
             vp_val_mes_nac := 'S';
          end if;

          vp_mes_nacimiento := substr(vp_negocio, 5, 11);
          vp_relacion := substr(vp_negocio, 17, 2);
      else
          vp_negocio       := substr(v_pedido, v_indice, 40);
          v_indice         := v_indice + 40;
      end if;

      vp_tra_extornado := substr(v_pedido, v_indice, 15);
      v_indice         := v_indice + 15;
      vp_bco_atm       := substr(v_pedido, v_indice, 3);
      v_indice         := v_indice + 3;
      vp_fecha         := substr(v_pedido, v_indice, 8);
      v_indice         := v_indice + 8;
      vp_hora          := substr(v_pedido, v_indice, 6);
      v_indice         := v_indice + 6;

      v_indice         := v_indice + 35;
      vp_servicio      := (case when trim(substr(v_pedido, v_indice, 3)) is null then 'ATM' else substr(v_pedido, v_indice, 3) end);
      v_indice         := v_indice + 3;
      vp_prestacion    := substr(v_pedido, v_indice, 4);
      v_indice         := v_indice + 4;
      vp_marca         := substr(v_pedido, v_indice, 3);
      v_indice         := v_indice + 3;
      vp_producto      := substr(v_pedido, v_indice, 3);
      v_indice         := v_indice + 3;
      vp_med_pago      := substr(v_pedido, v_indice, 2);
      v_indice         := v_indice + 2;
   END lp_car_parametros;
   
   --se extrae la funcion del pas_bce para que al realizar el pase sel mismo no sea necesario bajar el atm
   function lf_obt_cotizacion(p_cod_moneda in ba_monedas.cod_moneda%type,
                               p_tipo       in varchar2 -- C-COMPRA o V-VENTA
                               ) return number is

      v_cotizacion ge_cotizaciones.val_conversion%type;
    begin
      select decode(p_tipo,
                    'C',
                    val_com_electronica,
                    'V',
                    val_ven_electronica,
                    null)
        into v_cotizacion
        from ge_cotizaciones a
       where fecha = (select max(fecha)
                        from ge_cotizaciones
                       where cod_moneda = a.cod_moneda
                         and fecha <= v_fec_proceso)
         and cod_moneda = p_cod_moneda;
      return v_cotizacion;
   exception
      when no_data_found then
      return 1;
    when others then
      return 1;
  end lf_obt_cotizacion;
  
  
  procedure lp_con_mon_a_moneda(p_cod_mon_debito  in ba_monedas.cod_moneda%type,
                                p_cod_mon_credito in ba_monedas.cod_moneda%type,
                                p_fecha           in date,
                                p_mto_mon_debito  in out number,
                                p_mto_mon_credito in out number,
                                p_cot_mon_debito  out number,
                                p_cot_mon_credito out number) is
    v_lugar         varchar2(100);
    v_cod_mon_local varchar2(3) := pag_gen.fu_obt_mon_local;


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
        p_cot_mon_credito := lf_obt_cotizacion(p_cod_mon_credito, 'V');
        if p_mto_mon_debito is null then
          p_mto_mon_debito  := round(p_mto_mon_credito * p_cot_mon_credito, 0);
        else
          p_mto_mon_credito := round(p_mto_mon_debito / p_cot_mon_credito, 2);
          p_cot_mon_credito := round(p_mto_mon_debito / p_mto_mon_credito, 4);  -- relacula la cotizacion
        end if;
      elsif p_cod_mon_credito = v_cod_mon_local then -- COMPRA
        p_cot_mon_debito  :=  lf_obt_cotizacion(p_cod_mon_debito, 'C'); --DYDMR-4929 Se pasa como parametro la moneda de debito para las compras
        p_cot_mon_credito := null;
        if p_mto_mon_debito is null then
          p_mto_mon_debito  := round(p_mto_mon_credito / p_cot_mon_debito, 2);
          p_cot_mon_debito  := round(p_mto_mon_credito / p_mto_mon_debito, 4); -- relacula la cotizacion
        else
          p_mto_mon_credito := round(p_mto_mon_debito * p_cot_mon_debito, 0);
        end if;
      else -- ARBITRAJE
        v_cod_modulo := 7;
        v_cod_modalidad := 73;
        p_cot_mon_debito  := lf_obt_cotizacion(p_cod_mon_debito, 'C');
        if p_mto_mon_debito is null then
          p_mto_mon_debito  := round(round(p_mto_mon_credito *  lf_obt_cotizacion(p_cod_mon_credito, 'V'), 0)/ p_cot_mon_debito, 2);
        else
          p_mto_mon_credito := round(round(p_mto_mon_debito * p_cot_mon_debito, 0) /  lf_obt_cotizacion(p_cod_mon_credito, 'V'), 2);
        end if;
        p_cot_mon_credito := round(round(p_mto_mon_debito * p_cot_mon_debito, 0) / p_mto_mon_credito, 4);
      end if;
    end if;
  exception
    when others then
      raise_application_error(-20000, v_lugar || ' - ' || sqlerrm);
  end lp_con_mon_a_moneda;

   PROCEDURE lp_dat_cta
   (
      p_nro_cuenta    IN OUT VARCHAR2,
      p_cod_modulo    OUT NUMBER,
      p_cod_modalidad OUT NUMBER,
      p_cod_oficina   OUT NUMBER,
      p_cod_moneda    OUT VARCHAR2
   ) IS

   BEGIN
      IF p_nro_cuenta IS NULL THEN
         -- Es una cuenta contable...
         p_cod_modulo    := v_mod_contable;
         p_cod_modalidad := v_mad_contable;
         p_cod_oficina   := v_ofi_origen;
         p_cod_moneda    := v_cod_moneda;
         v_acu_sobregiro := 'N';
         v_cta_com       := 'N';
      ELSE
         v_cta_com := 'N';
         
         BEGIN
            SELECT cod_modulo, cod_modalidad, cod_oficina
              INTO p_cod_modulo, p_cod_modalidad, p_cod_oficina
              FROM ge_cuentas
             WHERE nro_cuenta = p_nro_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               IF fug_obt_tip_implementacion = 9 THEN
                  BEGIN
                     --la cuenta tiene 0 inicial si la oficina esta entre el 1 y 9
                     p_nro_cuenta := concat('0', p_nro_cuenta);
                     SELECT cod_modulo, cod_modalidad, cod_oficina
                       INTO p_cod_modulo, p_cod_modalidad, p_cod_oficina
                       FROM ge_cuentas
                      WHERE nro_cuenta = p_nro_cuenta;
                     --asigna al parametro la cuenta con el 0 delante
                     p_nro_cuenta := p_nro_cuenta;
                  EXCEPTION
                     WHEN no_data_found THEN
                        RAISE no_data_found;
                  END;
               ELSE
                  RAISE no_data_found;
               END IF;
         END;
         v_cod_cliente := fug_obt_cli_principal(p_nro_cuenta);
         IF p_cod_modalidad = 31 THEN
            SELECT nvl(cta_combinada, 'N'), cod_moneda, 'N'
              INTO v_cta_com, p_cod_moneda, v_acu_sobregiro
              FROM ah_cta_vistas
             WHERE nro_cuenta = P_nro_cuenta;
         ELSIF p_cod_modalidad = 41 THEN
            SELECT cod_moneda, acu_sobregiro
              INTO p_cod_moneda, v_acu_sobregiro
              FROM cc_cta_corrientes
             WHERE nro_cuenta = P_nro_cuenta;
         END IF;
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         vp_cod_respuesta := vr_cta_inexistente;
         v_msj_error := 'Cuenta Inexistente(' || p_nro_cuenta || ')';
   END lp_dat_cta;
   FUNCTION lf_es_banco RETURN VARCHAR2 IS
   BEGIN
      IF to_number(substr(pag_gen.fu_obt_cod_entidad, 1, 2)) = 10 THEN
         RETURN 'S';
      ELSE
         RETURN 'S'; --Siempre es banco, para Solar
      END IF;
   END;
   FUNCTION lf_obt_concepto RETURN VARCHAR2 IS
     v_ret ge_movimientos.concepto%type;
     v_descripcion cj_cajas.descripcion%type;
     v_cod_ent_financiera ge_par_entes.cod_ente%type;

   BEGIN
           IF to_number(vp_bco_atm) IN (v_cod_entidad,39) THEN--= v_cod_entidad THEN
               -- Si es banco debe verificar la cuenta corriente
               BEGIN
                  SELECT b.descripcion
                    INTO v_descripcion
                    FROM cc_cta_cajeros a, cj_cajas b
                   WHERE a.nro_caja=b.nro_caja
                     and nro_caj_externo = v_nro_caja
                     AND cod_moneda = v_cod_moneda;
               EXCEPTION
                  WHEN no_data_found THEN
                        NULL;
               END;
            END IF;

            IF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0, 39) THEN
               -- Es el atm de otro banco y es una extraccion.
               BEGIN
                  /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                  En la Procesadora Parametrizado.*/
                  SELECT cod_ente
                    INTO v_cod_ent_financiera
                    FROM ge_par_entes a
                   WHERE a.parametro = 'COD_ENT_FINANCIERA'
                     AND to_number(a.val_parametro) = to_number(vp_bco_atm);
               EXCEPTION
                  WHEN no_data_found THEN
                     v_cod_ent_financiera := NULL;
               END;
               BEGIN
                  SELECT denominacion
                    INTO v_descripcion
                    FROM cc_cta_bancarias
                   where (cod_banco = vp_bco_atm or cod_ente = v_cod_ent_financiera)
                     AND cod_modalidad = 42 -- Financieras y Bancos Bankitti
                     AND cod_moneda = v_cod_moneda;
               EXCEPTION
                  WHEN no_data_found THEN
                     NULL;
               END;
         END IF;
         IF to_number(vp_operacion) IN (0) THEN
            v_ret := 'POS-COMPRAS';
         ELSIF to_number(vp_operacion) IN (41) THEN
           v_ret := 'TRANSF.CTAS';
         ELSIF to_number(vp_operacion) IN (23) THEN
           v_ret := 'ATM-PAGO.FACT.CEL.';
         ELSIF to_number(vp_operacion) IN (24) THEN
           v_ret := 'ATM-COMPRA.MIN.CEL.';
         ELSIF to_number(vp_operacion) IN (72) THEN
           v_ret := 'PAGOS-INFONET COB.';
         ELSIF to_number(vp_operacion) IN (2) THEN
           v_ret := 'CONSULTA SALDOS';
         ELSIF to_number(vp_operacion) IN (52) THEN
           v_ret := 'CONSULTA SALDO EXTRAN.';
         ELSIF to_number(vp_operacion) IN (93) THEN
           v_ret := 'ATM-MEN.BCO';
         ELSIF to_number(vp_operacion) = 5 THEN
           v_ret := 'ATM-EXTRAC.EFECTIVO';
         ELSIF to_number(vp_operacion) = 6 THEN
            v_ret := 'SOLICIT.EXTRACTOS';
         END IF;
      return v_ret||' '||v_descripcion;
   END;

   PROCEDURE lp_car_val_inicial IS
      v_cod_ent_financiera ge_par_entes.cod_ente%TYPE;
      v_mes                varchar2(3);

   BEGIN
      -- Verifica si la entidad es un banco o una financiera
      v_es_banco := lf_es_banco;
      -- Obtiene que entidad le corresponde para poder procesar --
      v_cod_entidad    := to_number(fug_obt_pardinamico('COD_ENT_INFONET', NULL, NULL, NULL, NULL));
      vp_cod_respuesta := vr_aprobado;

      v_concepto       := substr(TRIM(vp_negocio), 1, 35);

      v_est_modulo     := pae_cnf.fu_obt_est_modulo(3);
      -- Verifica el horario.
      lp_ver_horario;

      BEGIN
         -- Obtiene la oficina de Casa Matriz.
         SELECT cod_ofi_matriz
           INTO v_ofi_origen
           FROM ge_par_generales;
      END;
      --no es necesario para ueno bankitti
      /*IF fug_obt_tip_implementacion IN (1, 7) THEN
         IF to_number(vp_bco_credito) = v_cod_entidad THEN
            vp_cta_credito := TRIM(to_char(to_number(substr(vp_cta_credito, -7))));

         END IF;
         IF to_number(vp_bco_debito) = v_cod_entidad THEN
            vp_cta_debito := TRIM(to_char(to_number(substr(vp_cta_debito, -7))));

         END IF;
      END IF;*/
      v_nro_caja := NULL;
      -------- Verifica la moneda de la tarjeta...-------
      IF vp_moneda = '01' THEN
         v_cod_moneda := pag_gen.fu_obt_mon_fuerte;
      ELSE
         v_cod_moneda := pag_gen.fu_obt_mon_local;
      END IF;
      --
      --v_hora := substr(vp_hora, 1, 2) || ':' || substr(vp_hora, 3, 2) || ':' || substr(vp_hora, 5, 2);
      IF instr(fug_obt_pardinamico('COD_USU_SEC_HABILITADAS'),USER) > 0 THEN --PQYN-856
        v_cod_usuario := fu_obt_mov_user_atm(USER);
      ELSE
        v_cod_usuario := fu_obt_mov_user_atm('INFONET'); --DA-5403
      END IF;
      v_hora := fu_obt_hora_atm(v_cod_usuario);        --DA-5403
      ---------------------------------------------------
      -- Al Cargar los importes
      IF nvl(v_ind_cob_comision, 'N') = 'S' THEN
         -- Dividir entre 100 el importe porque envian con 2 decimales...
         v_importe := (to_number(vp_importe) + to_number(vp_importe2) + to_number(vp_importe3)) / 100;
      ELSE
         v_importe := to_number(vp_importe) / 100;
      END IF;
      v_nro_documento  := vp_transaccion;
      v_nro_documento3 := vp_transaccion;
      v_nro_secuencia  := to_char(systimestamp, 'ff3');
      IF v_nro_secuencia > 996 THEN
         v_nro_secuencia := 996;
      END IF;
      v_tip_monto := 'E'; -- Siempre es efectivo
      -- Verifico la moneda
      IF to_number(vp_bco_credito) IN (v_cod_entidad,39) THEN
         v_clt_cre_nuestro := 'S';
      END IF;
      IF vp_bco_atm = '000' OR vp_bco_credito <> '000' THEN
         --es pos
         vp_bco_atm := vp_bco_credito;
      END IF;
      -- Verifica si el ATM es de la Entidad --
      IF to_number(vp_bco_atm) IN (v_cod_entidad,39) THEN
         v_atm_nuestro := 'S';
         v_nro_caja    := to_number(vp_nro_atm);
      END IF;
      -- Si es banco...
      IF v_es_banco = 'S' THEN
         IF to_number(vp_operacion) NOT IN (40, 41, 51, 52, 54, 58) THEN
            IF to_number(vp_bco_atm) IN (v_cod_entidad,39) THEN
               -- Si es banco debe verificar la cuenta corriente
               BEGIN
                  SELECT cod_oficina, nro_cuenta, cod_rubro, nro_caja
                    INTO v_ofi_origen, vp_cta_credito, v_cod_rub_caja, v_nro_caja
                    FROM cc_cta_cajeros
                   WHERE nro_caj_externo = v_nro_caja
                     AND cod_moneda = v_cod_moneda;
                  vp_bco_credito := vp_bco_atm;
               EXCEPTION
                  WHEN no_data_found THEN
                     IF vp_cta_credito = '0' AND to_number(vp_bco_credito) IN (v_cod_entidad,39) THEN
                        vp_cod_respuesta := vr_cta_inexistente;
                        v_msj_error := 'Cuenta Cajero Inexistente';
                     END IF;
               END;
            END IF;
            -- verifica
            IF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0, 39) THEN
               -- Es el atm de otro banco y es una extraccion.
               BEGIN
                  /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                  En la Procesadora Parametrizado.*/
                  SELECT cod_ente
                    INTO v_cod_ent_financiera
                    FROM ge_par_entes a
                   WHERE a.parametro = 'COD_ENT_FINANCIERA'
                     AND to_number(a.val_parametro) = to_number(vp_bco_atm);
               EXCEPTION
                  WHEN no_data_found THEN
                     v_cod_ent_financiera := NULL;
               END;
               BEGIN
                  SELECT nro_cuenta, cod_oficina
                    INTO vp_cta_credito, v_ofi_origen
                    FROM cc_cta_bancarias
                   WHERE (cod_banco = vp_bco_atm or cod_ente = v_cod_ent_financiera)
                     AND cod_modalidad = 42 -- Financieras y Bancos Bankitti
                     AND cod_moneda = v_cod_moneda;
                  vp_bco_credito := vp_bco_atm;
               EXCEPTION
                  WHEN no_data_found THEN
                     NULL;
               END;
            ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad,39) AND to_number(vp_operacion) IN (3, 7, 31, 32) THEN
               -- Se considera mensaje al banco.
               vp_operacion := 93;
            END IF;
         ELSIF to_number(vp_operacion) IN (40) THEN
            IF vp_bco_credito IN (v_cod_entidad,39) THEN
               v_clt_cre_nuestro := 'S';
            ELSE
               v_clt_cre_nuestro := 'N';
            END IF;
            IF vp_bco_debito IN (v_cod_entidad,39) THEN
               v_clt_deb_nuestro := 'S';
            ELSE
               v_clt_deb_nuestro := 'N';
            END IF;
            IF to_number(vp_bco_atm) IN (v_cod_entidad,39) AND v_clt_deb_nuestro = 'N' AND v_clt_cre_nuestro = 'N' THEN
               -- El ATM es nuestro pero ninguno de los clientes es nuestro.
               -- por lo tanto se considera como un mensaje.
               vp_operacion := 93;
            ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0,39) AND v_clt_deb_nuestro = 'N' THEN
               --
               BEGIN
                  /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                  En la Procesadora Parametrizado.*/
                  SELECT cod_ente
                    INTO v_cod_ent_financiera
                    FROM ge_par_entes a
                   WHERE a.parametro = 'COD_ENT_FINANCIERA'
                     AND to_number(a.val_parametro) = to_number(vp_bco_atm);
               EXCEPTION
                  WHEN no_data_found THEN
                     v_cod_ent_financiera := NULL;
               END;
               BEGIN
                  SELECT nro_cuenta, cod_oficina
                    INTO vp_cta_debito, v_ofi_origen
                    FROM cc_cta_bancarias
                   WHERE (cod_banco = vp_bco_atm or cod_ente = v_cod_ent_financiera)
                     AND cod_modalidad = 42 -- Financieras y Bancos Bankitti
                     AND cod_moneda = v_cod_moneda;
               EXCEPTION
                  WHEN no_data_found THEN
                     vp_cod_respuesta := vr_cta_inexistente;
                     v_msj_error := 'Cuenta Bancaria Inexistente';
               END;

               --Obtiene la Cta de Credito para transferencia a Otras Entidades Financieras 10-12-2014
            ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0,39) AND v_clt_cre_nuestro = 'N' THEN
               --
               BEGIN
                  SELECT nro_cuenta, cod_oficina
                    INTO vp_cta_credito, v_ofi_origen
                    FROM cc_cta_bancarias
                   WHERE cod_banco = to_number(vp_bco_credito)
                     AND cod_modalidad = 42 -- Cuenta bancaria de credito
                     AND cod_moneda = v_cod_moneda;
               EXCEPTION
                  WHEN no_data_found THEN
                     vp_cod_respuesta := vr_cta_inexistente;
                     v_msj_error := 'Cuenta Bancaria Inexistente';
               END;
            END IF;
         ELSIF to_number(vp_operacion) IN (41) THEN
            IF vp_bco_credito IN (v_cod_entidad,39) THEN
               v_clt_cre_nuestro := 'S';
            ELSE
               v_clt_cre_nuestro := 'N';
            END IF;
            IF vp_bco_debito IN (v_cod_entidad,39) THEN
               v_clt_deb_nuestro := 'S';
            ELSE
               v_clt_deb_nuestro := 'N';
            END IF;
            IF to_number(vp_bco_atm) IN (v_cod_entidad,39) AND v_clt_deb_nuestro = 'N' AND v_clt_cre_nuestro = 'N' THEN
               -- El ATM es nuestro pero ninguno de los clientes es nuestro.
               -- por lo tanto se considera como un mensaje.
               vp_operacion := 93;
            ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0,39) AND v_clt_deb_nuestro = 'N' THEN
               --es nuestro credito
                     BEGIN
                        /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                        En la Procesadora Parametrizado.*/
                        SELECT cod_ente
                          INTO v_cod_ent_financiera
                          FROM ge_par_entes a
                         WHERE a.parametro = 'COD_ENT_FINANCIERA'
                           AND to_number(a.val_parametro) = to_number(vp_bco_atm);
                     EXCEPTION
                        WHEN no_data_found THEN
                           v_cod_ent_financiera := NULL;
                     END;
                     BEGIN
                        SELECT nro_cuenta, cod_oficina
                          INTO vp_cta_debito, v_ofi_origen
                          FROM cc_cta_bancarias
                         WHERE (cod_banco = vp_bco_atm or cod_ente = v_cod_ent_financiera)
                           AND cod_modalidad = 42 -- Financieras y Bancos Bankitti
                           AND cod_moneda = v_cod_moneda;
                     EXCEPTION
                        WHEN no_data_found THEN
                           vp_cod_respuesta := vr_cta_inexistente;
                           v_msj_error := 'Cuenta Bancaria Inexistente';
                     END;

               --Obtiene la Cta de Credito para transferencia a Otras Entidades Financieras 10-12-2014
            ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0,39) AND v_clt_cre_nuestro = 'N' THEN
               -- si es nuestro debito
                     BEGIN
                        /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                        En la Procesadora Parametrizado.*/
                        SELECT cod_ente
                          INTO v_cod_ent_financiera
                          FROM ge_par_entes a
                         WHERE a.parametro = 'COD_ENT_FINANCIERA'
                           AND to_number(a.val_parametro) = to_number(vp_bco_atm);
                     EXCEPTION
                        WHEN no_data_found THEN
                           v_cod_ent_financiera := NULL;
                     END;
                     BEGIN
                        SELECT nro_cuenta, cod_oficina
                          INTO vp_cta_credito, v_ofi_origen
                          FROM cc_cta_bancarias
                         WHERE (cod_banco = vp_bco_atm or cod_ente = v_cod_ent_financiera)
                           AND cod_modalidad = 42 -- Financieras y Bancos Bankitti
                           AND cod_moneda = v_cod_moneda;
                     EXCEPTION
                        WHEN no_data_found THEN
                           vp_cod_respuesta := vr_cta_inexistente;
                           v_msj_error := 'Cuenta Bancaria Inexistente';
                     END;

             ELSIF to_number(vp_bco_atm) IN (v_cod_entidad, 0,39) AND v_clt_deb_nuestro = 'N' THEN
               BEGIN
                  /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                  En la Procesadora Parametrizado.*/
                  SELECT cod_ente
                    INTO v_cod_ent_financiera
                    FROM ge_par_entes a
                   WHERE a.parametro = 'COD_ENT_FINANCIERA'
                     AND to_number(a.val_parametro) = to_number(vp_bco_debito);
               EXCEPTION
                  WHEN no_data_found THEN
                     v_cod_ent_financiera := NULL;
               END;
               BEGIN
                  SELECT nro_cuenta, cod_oficina
                    INTO vp_cta_debito, v_ofi_origen
                    FROM cc_cta_bancarias
                   WHERE (cod_banco = vp_bco_atm or cod_ente = v_cod_ent_financiera)
                     AND cod_modalidad = 42 -- Financieras y Bancos Bankitti
                     AND cod_moneda = v_cod_moneda;
               EXCEPTION
                  WHEN no_data_found THEN
                     vp_cod_respuesta := vr_cta_inexistente;
                     v_msj_error := 'Cuenta Bancaria Inexistente';
               END;
            ELSIF to_number(vp_bco_atm) IN (v_cod_entidad, 0,39) AND v_clt_deb_nuestro = 'S' AND v_clt_cre_nuestro = 'S' THEN
                null;
            END IF;
         END IF;
         -- Si es nuestro ATM o nuestro POST...
         IF to_number(vp_bco_atm) IN (v_cod_entidad, 0,39) THEN
            -- Si la Cuenta de credito no es del Banco.
            IF to_number(vp_bco_credito) NOT IN (v_cod_entidad, 0,39) and to_number(vp_operacion) NOT IN (41) THEN
               BEGIN
                  /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                  En la Procesadora Parametrizado.*/
                  SELECT cod_ente
                    INTO v_cod_ent_financiera
                    FROM ge_par_entes a
                   WHERE a.parametro = 'COD_ENT_FINANCIERA'
                     AND to_number(a.val_parametro) = to_number(vp_bco_atm);
               EXCEPTION
                  WHEN no_data_found THEN
                     v_cod_ent_financiera := NULL;
               END;
               BEGIN
                  SELECT nro_cuenta, cod_oficina
                    INTO vp_cta_credito, v_ofi_origen
                    FROM cc_cta_bancarias
                   WHERE (cod_banco = vp_bco_atm or cod_ente = v_cod_ent_financiera)
                     AND cod_modalidad = 42 -- Financieras y Bancos Bankitti
                     AND cod_moneda = v_cod_moneda;
               EXCEPTION
                  WHEN no_data_found THEN
                     vp_cod_respuesta := vr_cta_inexistente;
                     v_msj_error := 'Cuenta Bancaria Inexistente';
               END;
            END IF;
            -- Si la Cuenta de debito no es del Banco.
            IF to_number(vp_bco_debito) NOT IN (v_cod_entidad, 0,39) AND to_number(vp_operacion) NOT IN (41) THEN
               BEGIN
                  /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                  En la Procesadora Parametrizado.*/
                  SELECT cod_ente
                    INTO v_cod_ent_financiera
                    FROM ge_par_entes a
                   WHERE a.parametro = 'COD_ENT_FINANCIERA'
                     AND to_number(a.val_parametro) = to_number(vp_bco_debito);
               EXCEPTION
                  WHEN no_data_found THEN
                     v_cod_ent_financiera := NULL;
               END;
               BEGIN
                  SELECT nro_cuenta, cod_oficina
                    INTO vp_cta_debito, v_ofi_origen
                    FROM cc_cta_bancarias
                   WHERE (cod_banco = vp_bco_debito or cod_ente = v_cod_ent_financiera)
                     AND cod_modalidad = 42 -- Financieras y Bancos Bankitti 
                     AND cod_moneda = v_cod_moneda;
               EXCEPTION
                  WHEN no_data_found THEN
                     vp_cod_respuesta := vr_cta_inexistente;
                     v_msj_error := 'Cuenta Bancaria Inexistente';
               END;

            END IF;
         END IF;
      END IF;

      --Busco cuenta por alias
      IF nvl(fug_obt_pardinamico('AH_CTA_ALIAS_VI_ACT'),'N')='S' THEN  
        BEGIN
          SELECT x.nro_cta_ueno
            INTO v_nro_cta_ueno
            FROM it.ah_cta_alias_vi x
           WHERE x.nro_cta_alias = to_number(vp_cta_debito)
             AND x.cod_estado = 'A';--Solo los alias activos
             vp_cta_debito := v_nro_cta_ueno;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
      END IF;
      
      --verifica la cuenta de debito si se toma el primer cero de la cadena
      if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_ALFANUMERICO'),'N') = 'S' then
         --vp_cta_debito
         pag_cta.pr_obt_cuenta(vp_cta_debito);
         g_cod_error := pag_cta.g_cod_error;
         IF g_cod_error = 12 THEN
             vp_cta_debito := to_number(vp_cta_debito);
             pag_cta.pr_obt_cuenta(vp_cta_debito);
             g_cod_error := pag_cta.g_cod_error;
             IF g_cod_error = 12 THEN
                vp_cod_respuesta := vr_cta_inexistente;
                v_msj_error := 'Cuenta Bancaria Inexistente';
             END IF;
         end if;
      end if;

      -- Verifica de vuelta si es nuestro cliente...
      IF vp_bco_credito IN (v_cod_entidad,39) THEN
         v_clt_cre_nuestro := 'S';
      ELSE
         v_clt_cre_nuestro := 'N';
      END IF;
      IF vp_bco_debito IN (v_cod_entidad,39) THEN
         v_clt_deb_nuestro := 'S';
      ELSE
         v_clt_deb_nuestro := 'N';
      END IF;

      --verifica si supera el importe maximo de transferencias por dia
      IF vp_operacion IN (41) THEN
        IF vp_bco_debito IN (v_cod_entidad,39) THEN
           v_retorno := fuj_ctr_mto_tra_atm(vp_cta_debito, v_importe);
           if nvl(v_retorno,'N') = 'N' then
              vp_cod_respuesta := vr_mto_limite;
           end if;
        end if;
      end if;

      IF vp_cod_respuesta = vr_aprobado  then
        -- Verifica si la cuenta es una cuenta ficticia...
        --
        v_ind_ctacontable  := 'N';
        v_cod_tra_contable := NULL;
        v_mod_contable     := NULL;
        v_mad_contable     := NULL;
        v_cod_rubro        := NULL;
        --
        BEGIN
           SELECT 'S', cod_transaccion, cod_modulo, cod_modalidad, cod_rubro
             INTO v_ind_ctacontable, v_cod_tra_contable, v_mod_contable, v_mad_contable, v_cod_rubro
             FROM cc_cta_ficticias
            WHERE nro_cuenta = vp_cta_debito;
           vp_cta_debito := NULL;
        EXCEPTION
           WHEN no_data_found THEN
              v_ind_ctacontable := 'N';
        END;


           IF vp_servicio = 'ATM' then
             IF to_number(vp_bco_debito) IN (v_cod_entidad,39) THEN
                IF vp_cta_debito IS NOT NULL AND vp_cta_debito != '0' THEN
                   if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_DEB_COMPUESTA'),'N') = 'S' then
                      vp_cta_debito := to_char(to_number(vp_cta_debito));
                   end if;

                   if nvl(fug_obt_pardinamico('CAJ_ATM_VAL_MES_NAC'),'N') = 'S' and nvl(vp_val_mes_nac,'N') = 'S' then
                       v_mes := lf_obt_mes_nac(vp_cta_debito, vp_relacion);
                       --lp_reg_operacion('ANTES VAL '||vp_mes_nacimiento, v_mes, '', v_fec_inicio);
                       if instr(vp_mes_nacimiento, v_mes)>0 then
                          --lp_reg_operacion('SI CONTIENE '||vp_mes_nacimiento, v_mes, '', v_fec_inicio);
                          vp_cod_respuesta := vr_aprobado;
                       else
                          --lp_reg_operacion('NO CONTIENE '||vp_mes_nacimiento, v_mes, '', v_fec_inicio);
                          vp_cod_respuesta := vr_mes_incorrecto;
                       end if;
                   end if;
                END IF;
              END IF;
            END IF;
         END IF;


      IF vp_cod_respuesta = vr_aprobado  then
          -- Llavea las cuentas
          -- Verifica si la cuenta de debito es de la Entidad --
          IF v_ind_ctacontable = 'N' THEN
             IF to_number(vp_bco_debito) IN (v_cod_entidad,39) THEN
                v_clt_deb_nuestro := 'S';
             END IF;

             IF vp_cta_debito IS NOT NULL AND vp_cta_debito != '0' THEN
                if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_DEB_COMPUESTA'),'N') = 'S' then
                   IF v_clt_deb_nuestro = 'S' THEN
                      vp_cta_debito := to_char(to_number(vp_cta_debito));
                   END IF;
                end if;

                lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb);

                IF vp_cod_respuesta = vr_aprobado AND to_number(vp_operacion) NOT IN (2, 52, 93, 6) THEN
                   IF pag_cta.fu_llavear_cuenta(v_mad_cta_deb, vp_cta_debito, v_es_cta_noc) = 'N' THEN
                      vp_cod_respuesta := vr_reintente;
                      v_msj_error := 'No se pudo llavear la Cuenta Debito';
                   END IF;
                END IF;
             END IF;

          END IF;
          IF vp_cta_credito IS NOT NULL AND vp_cta_credito != '0' THEN
             IF to_number(vp_bco_credito) IN (v_cod_entidad,39) THEN
                v_clt_cre_nuestro := 'S';
             END IF;
             
          --Busco cuenta por alias
          IF nvl(fug_obt_pardinamico('AH_CTA_ALIAS_VI_ACT'),'N')='S' THEN  
            BEGIN
              SELECT x.nro_cta_ueno
                INTO v_nro_cta_ueno
                FROM it.ah_cta_alias_vi x
               WHERE x.nro_cta_alias = to_number(vp_cta_credito)
                 AND x.cod_estado = 'A';--Solo los alias activos
                 vp_cta_credito := v_nro_cta_ueno;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;
             
             lp_dat_cta(vp_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre);
             IF vp_cod_respuesta = vr_aprobado AND to_number(vp_operacion) NOT IN (2, 52, 93, 6) THEN
                IF pag_cta.fu_llavear_cuenta(v_mad_cta_cre, vp_cta_credito, v_es_cta_noc) = 'N' THEN
                   vp_cod_respuesta := vr_reintente;
                   v_msj_error := 'No se pudo llavear la Cuenta Credito';
                END IF;
             END IF;
          END IF;
      end if;
      
           -- tys: realiza la conversion de montos
     if vp_cod_respuesta = vr_aprobado and to_number(vp_operacion) not in (2, 52, 93, 6) then
       if v_cod_moneda <> v_mon_cta_deb then -- si la moneda de la operacion es distinta a la moneda de la cuenta de debito
         -- realiza la conversión de monto credito -> debito. el importe de debito de estar nulo
         v_imp_debito  := null;
         v_imp_credito := v_importe;
         lp_con_mon_a_moneda(v_mon_cta_deb, v_cod_moneda, v_fec_proceso, v_imp_debito, v_imp_credito, v_cot_debito, v_cot_credito);
       end if;
       if v_imp_debito is null then
         v_imp_debito := v_importe;
       end if;
       if v_mon_cta_cre <> v_mon_cta_deb then
         -- realiza la conversion de monto debito -> credito
         lp_con_mon_a_moneda(v_mon_cta_deb, v_mon_cta_cre, v_fec_proceso, v_imp_debito, v_imp_credito, v_cot_debito, v_cot_credito);
       end if;
       if v_imp_credito is null then
         v_imp_credito := v_importe;
       end if;
     end if;

      if nvl(fug_obt_pardinamico('CAJ_ATM_VAL_MES_NAC'),'N') = 'S' and nvl(vp_val_mes_nac,'N') = 'S' then
         v_concepto :=case when vp_servicio='ATM' THEN
                        case when substr(vp_negocio,1,1)= '#' then
                             lf_obt_concepto
                        else
                            vp_negocio
                        end
                      ELSE
                        vp_negocio
                      END;
      end if;
      -- Carga respuesta por defecto --
      vp_can_extractos  := '000';
      vp_sig_disponible := '+';
      vp_sig_contable   := '+';
      vp_sal_disponible := lpad('0', 15, '0');
      vp_sal_contable   := lpad('0', 15, '0');
   END lp_car_val_inicial;
   --
   PROCEDURE lp_ver_operacion_00 IS
      -- Compra en Pos --
      v_sal_disponible  ah_cta_vistas.sal_total%TYPE;
      v_sal_contable    ah_cta_vistas.sal_total%TYPE;
      v_mto_acuerdo     cc_lin_sobregiros.monto%TYPE;
      v_man_mto_min_cta NUMBER(18, 2);
   BEGIN
      -- Hace las verificaciones si es clte de debito es nuestro....
      IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
         vp_cod_respuesta := vr_aprobado;
         -- Obtiene los datos principales de la cuenta
         lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb);
         pag_cta.pr_obt_cuenta(vp_cta_debito);
         v_man_mto_min_cta := fug_obt_pardinamico('AHO_MTO_MIN_CUENTA', v_mod_cta_deb, v_mad_cta_deb, v_mon_cta_deb);
         IF to_number(vp_operacion) not in (50) THEN         
             IF v_mon_cta_deb != v_cod_moneda THEN
                -- Se responde que la cuenta no existe...
                vp_cod_respuesta := vr_cta_inexistente;
                v_msj_error := 'La cuenta Debito no Existe';

             END IF;
         END IF;    
         IF vp_cod_respuesta = vr_aprobado THEN
            IF v_mad_cta_deb NOT IN (31, 41, 42, 46, 48, 38, 39,334) AND v_ind_ctacontable = 'N' THEN
               -- Ahorro a la Vista/ Cta. Corrientes
               vp_cod_respuesta := vr_no_aprobado;
               v_msj_error := 'Tipo de Cuenta Debito Invalido. Modalidad: ' || v_mad_cta_deb;
            END IF;
         END IF;
         -- Debe verificar el monto de la operacion
         v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) - nvl(v_imp_debito, 0);
         v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0) - nvl(v_imp_debito, 0);
         /*Prueba para funcionamiento para operar con cuenta combinada*/
         --Si la Cuenta no tiene Disponible se verifica el Disponible de la Cuenta Combinada
         if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado then
            v_sal_disponible := nvl(pag_cta.g_ctas.SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
         end if;
         --Si aun no tiene disponible se verifica el Disponible de las dos cuentas 
         if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado then
            v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
         end if;
         IF v_sal_disponible < 0 AND vp_cod_respuesta = vr_aprobado AND
            v_mad_cta_deb NOT IN (42, 46) AND v_ind_ctacontable = 'N' THEN
            IF v_mad_cta_deb = 41 THEN
               -- Si es Cuenta Corriente debe verificar si no tiene acuerdo de Sobregiro.
               -- Debe buscar el monto del acuerdo para verificar nuevamente
               v_mto_acuerdo := pag_cta.fu_obt_lin_sobregiro(vp_cta_debito, v_fec_proceso);
               IF nvl(v_mto_acuerdo, 0) + nvl(v_sal_disponible, 0) < 0 THEN
                  -- Sigue siendo insuficiente su acuerdo...
                  vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
               ELSE
                  -- Sino mantiene aprobado.
                  vp_cod_respuesta := vr_aprobado;
               END IF;
            ELSE
               -- Si no es Cta Corriente debe responder Saldo Insuficiente...
               vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
            END IF;
         ELSE
           v_exo_mto_minimo := fug_obt_paradicional(vp_cta_debito,'EXO_MTO_MINIMO');
           --hay que agregar el parametro en pag_cta
            IF pag_cta.g_ctas.cod_seg_cliente <> v_cod_seg_funcionario AND
               v_sal_disponible < v_man_mto_min_cta AND NVL(V_EXO_MTO_MINIMO,'N') <> 'S' THEN
               -- Si es Cta. Ahorro y no es funcionario debe de mantener un monto minimo en su cta....
               vp_cod_respuesta := vr_sal_insuficiente;
            END IF;
         END IF;
         -- Carga la respuesta --
         IF v_mad_cta_deb IN (42, 46) OR v_ind_ctacontable = 'S' THEN
            v_sal_disponible := 0;
            v_sal_contable   := 0;
         END IF;
         vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))), 15, '0');
         IF v_sal_disponible < 0 THEN
            vp_sig_disponible := '-';
         END IF;
         vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))), 15, '0');
         IF v_sal_contable < 0 THEN
            vp_sig_contable := '-';
         END IF;
      END IF;
      -- Hace las verificaciones si el clte de credito es nuestro....
      IF nvl(to_number(vp_cta_credito), 0) != 0 AND vp_cod_respuesta = vr_aprobado THEN
         -- Obtiene los datos de la cuenta de credito...
         IF vp_cta_credito IS NOT NULL THEN
            lp_dat_cta(vp_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre);
            pag_cta.pr_obt_cuenta(vp_cta_credito);
            g_cod_error := pag_cta.g_cod_error;
         ELSE
            v_mon_cta_cre := v_cod_moneda;
            v_mod_cta_cre := v_mod_cta_deb;
            v_mad_cta_cre := v_mad_cta_deb;
            v_ofi_cta_cre := v_ofi_origen;
         END IF;
         IF g_cod_error = 12 THEN
            -- Cuenta inexistente
            vp_cod_respuesta := vr_cta_inexistente; -- Tarjeta desconocida
            v_msj_error := 'Cuenta Credito Inexistente';
         END IF;
         IF v_mon_cta_cre != v_cod_moneda AND vp_cod_respuesta = vr_aprobado THEN
            -- Se responde que la cuenta no existe...
            vp_cod_respuesta := vr_cta_inexistente;
            v_msj_error := 'Moneda de la Cuenta Credito distinto a la Moneda de la Transaccion';
         END IF;
         v_est_cta_cre := pag_cta.fu_obt_est_cuenta;
         IF (v_est_cta_cre NOT IN ('N', 'S', 'I') OR v_mad_cta_cre NOT IN (31, 41, 42, 46, 48, 38, 39,334)) AND
            vp_cod_respuesta = vr_aprobado THEN
            -- No es normal o con bloqueo de saldo
            -- Estado Inactiva tambien debe permitir.
            vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
            v_msj_error := 'Estado o Tipo de Cuenta Credito Invalido. Estado: ' || v_est_cta_cre || ' Modalidad: ' || v_mad_cta_cre;
         END IF;
      END IF;
   END lp_ver_operacion_00;
   --
   PROCEDURE lp_ver_operacion_02 IS
      -- Consulta de Saldo --
      v_sal_disponible ah_cta_vistas.sal_total%TYPE;
      v_sal_contable   ah_cta_vistas.sal_total%TYPE;
   BEGIN
      IF v_clt_deb_nuestro = 'S' THEN
         vp_cod_respuesta := vr_aprobado;
         v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0);
         v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0);
         lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb);
         -- Carga la respuesta --
         vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))), 15, '0');
         IF v_sal_disponible < 0 THEN
            vp_sig_disponible := '-';
         END IF;
         vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))), 15, '0');
         IF v_sal_contable < 0 THEN
            vp_sig_contable := '-';
         END IF;
      ELSE
         vp_cod_respuesta  := vr_aprobado;
         vp_sal_disponible := lpad('0', 15, '0');
         vp_sal_contable   := lpad('0', 15, '0');
      END IF;
   END lp_ver_operacion_02;
   --
   PROCEDURE lp_ver_operacion_05 IS
      -- Extraccion de Efectivo --
      v_sal_disponible  ah_cta_vistas.sal_total%TYPE;
      v_sal_contable    ah_cta_vistas.sal_total%TYPE;
      v_mto_acuerdo     cc_lin_sobregiros.monto%TYPE := 0;
      v_man_mto_min_cta NUMBER(18, 2);
   BEGIN
      -- Hace las verificaciones si es clte de debito es nuestro....
      IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
         vp_cod_respuesta := vr_aprobado;
         -- Obtiene los datos principales de la cuenta
         lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb);
         pag_cta.pr_obt_cuenta(vp_cta_debito);
         v_man_mto_min_cta := fug_obt_pardinamico('AHO_MTO_MIN_CUENTA', v_mod_cta_deb, v_mad_cta_deb, v_mon_cta_deb);

         -- Debe verificar el monto de la operacion
         if to_number(vp_operacion) in (5) then
             IF v_mon_cta_deb != v_cod_moneda THEN
                -- Se responde que la cuenta no existe...
                vp_cod_respuesta := vr_cta_inexistente;
                v_msj_error:= 'Cuenta Debito Inexistente';
             END IF;
         end if;    
         IF vp_cod_respuesta = vr_aprobado THEN
            IF v_mad_cta_deb NOT IN (31, 41, 42, 46, 38, 39,334) AND v_ind_ctacontable = 'N' THEN
               -- Ahorro a la Vista/ Cta. Corrientes
               vp_cod_respuesta := vr_no_aprobado;
               v_msj_error:= 'Tipo de Cuenta Debito Invalido. Modalidad: ' || v_mad_cta_deb;
            END IF;
         END IF;

         v_cargos := nvl(v_val_cargo, 0) + nvl(v_val_impuesto, 0);
         v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) - (nvl(v_imp_debito, 0) + nvl(v_cargos, 0));
         v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0) - (nvl(v_imp_debito, 0) + nvl(v_cargos, 0));
         /*Prueba para funcionamiento para operar con cuenta combinada*/
         --Si la Cuenta no tiene Disponible se verifica el Disponible de la Cuenta Combinada
         if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado then
            v_sal_disponible := nvl(pag_cta.g_ctas.SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
         end if;
         --Si aun no tiene disponible se verifica el Disponible de las dos cuentas 
         if v_sal_disponible < 0 and vp_cod_respuesta = vr_aprobado then
            v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
         end if;
         IF v_sal_disponible < 0 AND vp_cod_respuesta = vr_aprobado AND v_mad_cta_deb NOT IN (42, 46) AND v_ind_ctacontable = 'N' THEN
            IF v_mad_cta_deb = 41 THEN
               -- Si es Cuenta Corriente debe verificar si no tiene acuerdo de Sobregiro.
               -- Debe buscar el monto del acuerdo para verificar nuevamente
               v_mto_acuerdo := pag_cta.fu_obt_lin_sobregiro(vp_cta_debito, v_fec_proceso);
               IF nvl(v_mto_acuerdo, 0) + nvl(v_sal_disponible, 0) < 0 THEN
                  -- Sigue siendo insuficiente su acuerdo...
                  vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
                  v_msj_error := 'Cuenta con Saldo Insuficiente';
               ELSE
                  -- Sino mantiene aprobado.
                  vp_cod_respuesta := vr_aprobado;

               END IF;
            ELSE
               -- Si no es Cta Corriente debe responder Saldo Insuficiente...
               vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
               v_msj_error := 'Cuenta con Saldo Insuficiente';
            END IF;
         ELSIF v_mad_cta_deb in (31,38,39,334) THEN
            v_exo_mto_minimo := fug_obt_paradicional(vp_cta_debito,'EXO_MTO_MINIMO');
            --hay que agregar el parametro en pag_cta
            IF v_sal_disponible < v_man_mto_min_cta THEN
               IF (pag_cta.g_ctas.cod_seg_cliente <> v_cod_seg_funcionario AND NVL(V_EXO_MTO_MINIMO,'N') <> 'S') THEN
                  -- Si es Cta. Ahorro y no es funcionario debe de mantener un monto minimo en su cta....
                  vp_cod_respuesta := vr_sal_insuficiente;
                  v_msj_error := 'Cuenta con Saldo Insuficiente';
               END IF;
            END IF;
         END IF;
         IF v_mad_cta_deb IN (42, 46) OR v_ind_ctacontable = 'S' THEN
            v_sal_disponible := 0;
            v_sal_contable   := 0;
         END IF;
         IF vp_cod_respuesta <> vr_aprobado THEN
            -- extraccion rechazada, debe mostrar el saldo sin el debito
            v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0);
            v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0);
         END IF;
         -- Carga la respuesta --
         vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))), 15, '0');
         IF v_sal_disponible < 0 THEN
            vp_sig_disponible := '-';
         END IF;
         vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))), 15, '0');
         IF v_sal_contable < 0 THEN
            vp_sig_contable := '-';
         END IF;
      END IF;
      -- Hace las verificaciones si el clte de credito es nuestro....
      IF nvl(to_number(vp_cta_credito), 0) != 0 AND vp_cod_respuesta = vr_aprobado THEN
         -- Obtiene los datos de la cuenta de credito...
         IF vp_cta_credito IS NOT NULL THEN
            lp_dat_cta(vp_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre);
            pag_cta.pr_obt_cuenta(vp_cta_credito);
            g_cod_error := pag_cta.g_cod_error;
         ELSE
            v_mon_cta_cre := v_cod_moneda;
            v_mod_cta_cre := v_mod_cta_deb;
            v_mad_cta_cre := v_mad_cta_deb;
            v_ofi_cta_cre := v_ofi_origen;
         END IF;
         IF v_mon_cta_cre != v_cod_moneda AND vp_cod_respuesta = vr_aprobado THEN
            -- Se responde que la cuenta no existe...
            vp_cod_respuesta := vr_cta_inexistente;
            v_msj_error := 'Moneda de la Cuenta Credito distinto a la Moneda de la Transaccion';
         END IF;
         v_est_cta_cre := pag_cta.fu_obt_est_cuenta;
         IF (v_est_cta_cre NOT IN ('N', 'S', 'I') OR v_mad_cta_cre NOT IN (31, 41, 42, 46, 48, 38, 39,334)) AND
            vp_cod_respuesta = vr_aprobado THEN
            -- No es normal o con bloqueo de saldo
            vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
            v_msj_error := 'Estado o Tipo de Cuenta Credito Invalido. Estado: ' || v_est_cta_cre || ' Modalidad: ' || v_mad_cta_cre;
         END IF;
      END IF;
   END lp_ver_operacion_05;
   --
   PROCEDURE lp_ver_operacion_06 IS
      v_sal_disponible ah_cta_vistas.sal_total%TYPE;
      v_sal_contable   ah_cta_vistas.sal_total%TYPE;
      v_cantidad       NUMBER(2) := 0;
      v_monto          VARCHAR2(15);
      v_saldo          VARCHAR2(15);
      v_sal_act        NUMBER(18, 2);
      -- Extracto --
      CURSOR c_movim IS
         SELECT m.fecha,
                m.fec_valor,
                m.hora,
                m.nro_cuenta,
                m.nro_documento,
                m.cod_mod_padre,
                m.cod_mad_padre,
                m.cod_tra_padre,
                decode(t.cod_transaccion, 515, 'C', 560, 'C', t.tipo) tipo,
                decode(t.cod_transaccion, 515, m.monto, 560, m.monto,
                       decode(t.tipo, 'D', m.monto * -1, m.monto)) monto,
                t.abreviatura,
                (decode(t.cod_transaccion, 515, 0, 560, 0, decode(t.tipo, 'D', nvl(m.monto, 0), 0))) debito,
                (decode(t.cod_transaccion, 515, nvl(m.monto, 0), 560, nvl(m.monto, 0),
                        decode(t.tipo, 'C', nvl(m.monto, 0), 0))) credito
           FROM ge_transacciones t, gv_movimientos m
          WHERE m.nro_cuenta = vp_cta_debito
            AND m.fecha > v_fec_proceso - 7
            AND m.reversado = 'N'
            AND m.estado = 'N'
            AND m.cod_modulo = t.cod_modulo
            AND m.cod_modalidad = t.cod_modalidad
            AND m.cod_transaccion = t.cod_transaccion
            AND t.ve_cliente = 'S'
            AND t.tipo IN ('C', 'D')
          ORDER BY m.fecha DESC, m.hora DESC;
      --
   BEGIN
      vp_cod_respuesta := vr_aprobado;
      -- Obtiene los datos principales de la cuenta
      lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb);
      IF lf_es_sponsor(vp_cta_debito) = 'S' OR to_number(vp_bco_debito) NOT IN (v_cod_entidad,39) THEN
         v_sal_disponible  := 0;
         v_sal_contable    := 0;
         vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))), 15, '0');
         vp_sal_contable   := lpad(TRIM(to_char(abs(v_sal_contable * 100))), 15, '0');
         vp_extractos      := '';
      ELSE
         -- Debe verificar el monto de la operacion
         v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) - nvl(v_importe, 0);
         v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0) - nvl(v_importe, 0);
         IF v_sal_disponible < 0 AND vp_cod_respuesta = vr_aprobado AND
            v_mad_cta_deb NOT IN (42, 46) AND v_ind_ctacontable = 'N' THEN
            vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
         END IF;
         -- Carga la respuesta --
         vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))), 15, '0');
         IF v_sal_disponible < 0 THEN
            vp_sig_disponible := '-';
            vp_sal_disponible := lpad('0', 15, '0');
         END IF;
         vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))), 15, '0');
         IF v_sal_contable < 0 THEN
            vp_sig_contable := '-';
            vp_sal_contable := lpad('0', 15, '0');
         END IF;
         vp_extractos := '';
         v_sal_act    := v_sal_disponible;
         FOR r_movim IN c_movim LOOP
            IF v_cantidad < 10 THEN
               v_cantidad := v_cantidad + 1;
               IF r_movim.monto < 0 THEN
                  v_monto := '-' || lpad(r_movim.monto * -100, 14, '0');
               ELSE
                  v_monto := '+' || lpad(r_movim.monto * 100, 14, '0');
               END IF;
               IF v_sal_act < 0 THEN
                  v_saldo := '-' || lpad(v_sal_act * -100, 14, '0');
               ELSE
                  v_saldo := '+' || lpad(v_sal_act * 100, 14, '0');
               END IF;
               v_sal_act    := v_sal_act + r_movim.monto;
               vp_extractos := vp_extractos ||
                              ---
                               lpad(nvl(r_movim.nro_documento, '0'), 8, '0') ||
                               TRIM(to_char(r_movim.fecha, 'DDMM')) || v_monto || v_saldo ||
                               rpad(nvl(r_movim.abreviatura, ' '), 9, ' ');
            ELSE
               EXIT;
            END IF;
         END LOOP;
         IF v_cantidad > 0 THEN
            vp_can_extractos := '001';
         END IF;
         vp_extractos := rpad(lpad(TRIM(to_char(v_cantidad)), 2, '0') || vp_extractos, 512, '0');
      END IF;
   END lp_ver_operacion_06;
   --
   PROCEDURE lp_ver_operacion_99 IS
      v_sal_disponible ah_cta_vistas.sal_total%TYPE;
      v_sal_contable   ah_cta_vistas.sal_total%TYPE;
   BEGIN
      -- Un extorno no se puede desaprobar...
      vp_cod_respuesta := vr_aprobado; -- Aprobado
      -- Cambia el signo del importe...
      v_importe := v_importe * -1;
      -- tys: montos de debitos y creditos
      v_imp_debito  := v_imp_debito * -1;
      v_imp_credito := v_imp_credito * -1;
      --v_imp_comision := v_imp_comision * -1;
      -- fin tys

      IF v_clt_deb_nuestro = 'S' THEN
         -- Obtiene los datos principales de la cuenta
         lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb);

         v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) - nvl(v_imp_debito, 0);
         v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0) - nvl(v_imp_debito, 0);

         vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))), 15, '0');
         IF v_sal_disponible < 0 THEN
            vp_sig_disponible := '-';
         END IF;
         vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))), 15, '0');
         IF v_sal_contable < 0 THEN
            vp_sig_contable := '-';
         END IF;
      ELSE
         vp_sal_disponible := lpad('0', 15, '0');
         vp_sal_contable   := lpad('0', 15, '0');
      END IF;
      IF nvl(to_number(vp_cta_credito), 0) != 0 THEN
         lp_dat_cta(vp_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre);
      END IF;
   END lp_ver_operacion_99;
   ------------------
   --- Procesos... --
   ------------------
   PROCEDURE lp_pro_operacion_00 IS
      -- Compra en Pos --
   BEGIN
      IF vp_operacion IN (41) THEN
         v_cod_tra_padre := 385;
      elsif to_number(vp_operacion) = 50 then
      -- compra en pos extranjero
      v_cod_tra_padre := 374;    
      ELSE
         v_cod_tra_padre := 380;
      END IF;

      IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
         -- Carga lños parametros de movimientos de Debito
         r_gmovi.cod_modulo    := v_mod_cta_deb;
         r_gmovi.cod_modalidad := v_mad_cta_deb;
         r_gmovi.cod_oficina   := v_ofi_cta_deb;
         r_gmovi.nro_cuenta    := vp_cta_debito;
         r_gmovi.cod_moneda    := nvl(v_mon_cta_deb, v_cod_moneda);
         r_gmovi.cod_usuario   := v_cod_usuario;
         r_gmovi.hora          := v_hora;
         r_gmovi.fecha         := v_fec_proceso;
         r_gmovi.nro_secuencia := v_nro_secuencia;
         --
         r_gmovi.fec_valor     := v_fec_valor;
         r_gmovi.cod_tra_padre := v_cod_tra_padre;
         r_gmovi.cod_mod_padre := v_cod_modulo;
         r_gmovi.cod_mad_padre := v_cod_modalidad;
         IF v_ind_ctacontable = 'S' THEN
            r_gmovi.cod_transaccion := v_cod_tra_contable;
            r_gmovi.tip_mov_rubro   := 'D';
            r_gmovi.cod_rubro       := v_cod_rubro;
         ELSE
            IF vp_operacion IN (41) THEN
               r_gmovi.cod_transaccion := 503;
            ELSE
               r_gmovi.cod_transaccion := 578;
            END IF;

            IF lf_exi_banco(vp_bco_credito) = 'B' THEN
               r_gmovi.cod_banco := vp_bco_credito;
            ELSE
               r_gmovi.nro_documento2 := vp_bco_credito;
            END IF;
         END IF;
         r_gmovi.monto          := v_imp_debito;
         r_gmovi.nro_documento  := v_nro_documento;
         r_gmovi.nro_documento3 := v_nro_documento3;

         r_gmovi.cod_tasa       := NULL;
         r_gmovi.val_tasa       := NULL;
         r_gmovi.cotizacion     := v_cot_debito;
         r_gmovi.mto_equ_local  := round(r_gmovi.monto * r_gmovi.cotizacion);
         r_gmovi.cod_ofi_origen := v_ofi_origen;
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.concepto       := v_concepto;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
         --lp_upd_cta_debito;
         IF v_est_cuenta = 'I' THEN
            -- Debo cambiar el estado de la cuenta
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := NULL;
            r_gmovi.est_cuenta      := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
         END IF;
         lp_env_notificacion(vp_cta_debito, v_importe, v_nro_documento, to_number(vp_operacion), v_hora);
      /*Prueba para procesamiento de cuenta combinada*/
      -- cuenta combinada ----------------------------------
           if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              IF v_sal_dis_debito < 0 then
                 r_gmovi.monto           := v_imp_debito;
              else
                 r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
              end if;
              r_gmovi.concepto        := 'Transferencia de la Cta '||v_nro_cta_combinada;
              r_gmovi.cod_tra_padre   := 309;
              r_gmovi.cod_transaccion := 602;
              ---
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
              --lp_ins_ge_movimiento;
              -- acredito el monto que le falta
              lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb, vp_cta_debito, r_gmovi.monto * -1);
           end if;

           lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb, vp_cta_debito, v_imp_debito);

           If v_est_cuenta = 'I' Then -- Debo cambiar el estado de la cuenta
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.monto           := null;
              r_gmovi.est_cuenta      := 'N';
              r_gmovi.cod_tra_padre   := 425;
              r_gmovi.cod_transaccion := 425;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
           End If;

           if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
              IF v_sal_dis_debito < 0 then
                 r_gmovi.monto           := v_imp_debito;
              else
                 r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
              end if;
              pag_cta.PR_OBT_CUENTA(v_nro_cta_combinada);
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.concepto        := 'Transferencia a la Cta '||vp_cta_debito;
              r_gmovi.cod_tra_padre   := 309;
              r_gmovi.cod_transaccion := 503;
              r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
              r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
              r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
              r_gmovi.nro_cuenta      := pag_cta.g_ctas.nro_cuenta;
              ---
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);

              --DYDMR-2055: ITGF - Saldo de Cuenta 0102194039 SC 17595
              lp_upd_cta_debito(pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,
                                pag_cta.g_ctas.nro_cuenta, r_gmovi.monto);

              --FB AP 927 Actualizo el estado de la cta.comb.
              v_est_cta_comb := pag_cta.FU_OBT_EST_CUENTA; 
              IF v_est_cta_comb = 'I' AND g_cod_error = 00 then
                  v_nro_secuencia := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.monto := null;
                  r_gmovi.est_cuenta := 'N';
                  r_gmovi.cod_tra_padre   := 425;
                  r_gmovi.cod_transaccion := 425;
                  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
                  --lp_ins_ge_movimiento;
              END IF;
              --
             /* lp_upd_cta_debito(pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,
                                pag_cta.g_ctas.nro_cuenta, r_gmovi.monto);*/
           end if;
 
      
      /*Prueba para procesamiento de cuenta combinada*/  
      END IF;
      IF nvl(to_number(vp_cta_credito), 0) != 0 THEN
         -- Carga los parametros de movimientos de Credito
         v_nro_secuencia       := v_nro_secuencia + 1;
         r_gmovi.cod_modulo    := v_mod_cta_cre;
         r_gmovi.cod_modalidad := v_mad_cta_cre;
         r_gmovi.cod_oficina   := v_ofi_cta_cre;
         r_gmovi.nro_cuenta    := vp_cta_credito;
         r_gmovi.cod_moneda    := nvl(v_mon_cta_cre, v_cod_moneda);
         r_gmovi.cod_usuario   := v_cod_usuario;
         r_gmovi.hora          := v_hora;
         r_gmovi.fecha         := v_fec_proceso;
         r_gmovi.nro_secuencia := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := v_cod_modulo;
         r_gmovi.cod_mad_padre   := v_cod_modalidad;
         r_gmovi.cod_transaccion := 602;
         IF lf_exi_banco(vp_bco_credito) = 'B' THEN
            r_gmovi.cod_banco := vp_bco_credito;
         ELSE
            r_gmovi.nro_documento2 := vp_bco_credito;
         END IF;
         r_gmovi.monto          := v_imp_credito;
         r_gmovi.nro_documento  := v_nro_documento;
         r_gmovi.nro_documento3 := v_nro_documento3;

         r_gmovi.cod_tasa       := NULL;
         r_gmovi.val_tasa       := NULL;
         r_gmovi.cotizacion     := v_cot_credito;
         r_gmovi.mto_equ_local  := round(r_gmovi.monto * r_gmovi.cotizacion);                    
         r_gmovi.cod_ofi_origen := v_ofi_origen;
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.concepto       := v_concepto;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);

         if v_mod_cta_cre = 4 then
             if fug_obt_tip_modalidad(v_mod_cta_cre, v_mad_cta_cre) = 'A' then
                 v_tip_transaccion := lf_obt_tipo(r_gmovi.cod_transaccion, v_mod_cta_cre, v_mad_cta_cre);
                 if v_tip_transaccion = 'C' then
                    v_importe := v_importe * (-1);
                 end if;
             end if ;
          end if;

         lp_upd_cta_credito;
         IF v_est_cta_cre = 'I' THEN
            -- Debo cambiar el estado de la cuenta
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := NULL;
            r_gmovi.est_cuenta      := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
         END IF;
      END IF;
   END lp_pro_operacion_00;
   --
   PROCEDURE lp_pro_operacion_02 IS
      -- Consulta de Saldo --
   BEGIN
      v_cod_tra_padre := 389;
      IF v_clt_deb_nuestro = 'S' THEN
         -- Carga los parametros de movimientos de Debito
         r_gmovi.cod_modulo    := v_mod_cta_deb;
         r_gmovi.cod_modalidad := v_mad_cta_deb;
         r_gmovi.cod_oficina   := v_ofi_cta_deb;
         r_gmovi.nro_cuenta    := vp_cta_debito;
         r_gmovi.cod_moneda    := nvl(v_mon_cta_deb, v_cod_moneda);
         r_gmovi.cod_usuario   := v_cod_usuario;
         r_gmovi.hora          := v_hora;
         r_gmovi.fecha         := v_fec_proceso;
         r_gmovi.nro_secuencia := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := v_cod_modulo;
         r_gmovi.cod_mad_padre   := v_cod_modalidad;
         r_gmovi.cod_transaccion := v_cod_tra_padre;
         r_gmovi.monto           := NULL;
         r_gmovi.nro_documento   := v_nro_documento;
         r_gmovi.nro_documento3  := v_nro_documento3;

         IF lf_exi_banco(vp_bco_atm) = 'B' THEN
            r_gmovi.cod_banco := vp_bco_atm;
         ELSE
            r_gmovi.nro_documento2 := vp_bco_atm;
         END IF;

         r_gmovi.cod_tasa       := NULL;
         r_gmovi.val_tasa       := NULL;
         r_gmovi.cotizacion     := NULL;
         r_gmovi.cod_ofi_origen := v_ofi_origen;
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.concepto       := v_concepto;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
      END IF;
   END lp_pro_operacion_02;
   --
   PROCEDURE lp_pro_operacion_05 IS
      -- Extraccion de Efectivo --
   BEGIN
      IF to_number(vp_operacion) = 5 THEN
         v_cod_tra_padre := 382;
      ELSIF to_number(vp_operacion) = 27 THEN
         v_cod_tra_padre := 990;
      elsif to_number(vp_operacion) = 55 then -- extraccion en atm extranjero
         v_cod_tra_padre := 375;   
      END IF;
      IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
         -- Carga los parametros de movimientos de Debito
         r_gmovi.cod_modulo    := v_mod_cta_deb;
         r_gmovi.cod_modalidad := v_mad_cta_deb;
         r_gmovi.cod_oficina   := v_ofi_cta_deb;
         r_gmovi.nro_cuenta    := vp_cta_debito;
         r_gmovi.cod_moneda    := nvl(v_mon_cta_deb, v_cod_moneda);
         r_gmovi.cod_usuario   := v_cod_usuario;
         r_gmovi.hora          := v_hora;
         r_gmovi.fecha         := v_fec_proceso;
         r_gmovi.nro_secuencia := v_nro_secuencia;
         --
         r_gmovi.fec_valor     := v_fec_valor;
         r_gmovi.cod_tra_padre := v_cod_tra_padre;
         r_gmovi.cod_mod_padre := v_cod_modulo;
         r_gmovi.cod_mad_padre := v_cod_modalidad;
         IF v_ind_ctacontable = 'S' THEN
            r_gmovi.cod_transaccion := v_cod_tra_contable;
            r_gmovi.tip_mov_rubro   := 'D';
            r_gmovi.cod_rubro       := v_cod_rubro;
         ELSE
            r_gmovi.cod_transaccion := 578;
            IF lf_exi_banco(vp_bco_atm) = 'B' THEN
               r_gmovi.cod_banco := vp_bco_atm;
            ELSE
               r_gmovi.nro_documento2 := vp_bco_atm;
            END IF;
         END IF;
         r_gmovi.monto          := v_imp_debito;
         r_gmovi.nro_documento  := v_nro_documento;
         r_gmovi.nro_documento3 := v_nro_documento3;

         r_gmovi.cod_tasa       := NULL;
         r_gmovi.val_tasa       := NULL;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion      := v_cot_debito;
         r_gmovi.mto_equ_local   := round(r_gmovi.monto * r_gmovi.cotizacion);
         --
         r_gmovi.cod_ofi_origen := v_ofi_origen;
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.concepto       := v_concepto;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
         IF v_val_cargo > 0 THEN
            ---
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := v_val_cargo;
            r_gmovi.cod_tasa        := v_cod_tas_cargo;
            r_gmovi.val_tasa        := v_val_tas_cargo;
            r_gmovi.concepto        := 'Cargo por Extraccion';
            r_gmovi.cod_tra_padre   := 137;
            r_gmovi.cod_transaccion := 137;
            ---
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
            IF v_val_impuesto > 0 THEN
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.monto           := v_val_impuesto;
               r_gmovi.cod_tasa        := v_cod_tas_impuesto;
               r_gmovi.val_tasa        := v_val_tas_impuesto;
               r_gmovi.concepto        := 'IVA s/Cargo por Extraccion';
               r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
               r_gmovi.cod_transaccion := v_cod_tra_impuesto;
               pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
            END IF;
            v_importe := v_importe + nvl(v_cargos, 0);
            --lp_upd_cta_debito;
            IF v_est_cuenta = 'I' THEN
               -- Debo cambiar el estado de la cuenta
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.monto           := NULL;
               r_gmovi.est_cuenta      := 'N';
               r_gmovi.cod_tra_padre   := 425;
               r_gmovi.cod_transaccion := 425;
               pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
            END IF;
            v_importe := v_importe - nvl(v_cargos, 0); -- para el credito debe ser solo por el monto extraido
         ELSE
            --lp_upd_cta_debito;
            IF v_est_cuenta = 'I' THEN
               -- Debo cambiar el estado de la cuenta
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.monto           := NULL;
               r_gmovi.est_cuenta      := 'N';
               r_gmovi.cod_tra_padre   := 425;
               r_gmovi.cod_transaccion := 425;
               pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
            END IF;
         END IF;
         lp_env_notificacion(vp_cta_debito, v_imp_debito, v_nro_documento, to_number(vp_operacion), v_hora);
         /*para cuenta combinada*/
         if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            IF v_sal_dis_debito < 0 then
               r_gmovi.monto           := v_imp_debito;
            else
               r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
            end if;
            r_gmovi.concepto        := 'Transferencia de la Cta '||v_nro_cta_combinada;
            r_gmovi.cod_tra_padre   := 309;
            r_gmovi.cod_transaccion := 602;
            ---
            --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            --DYDMR-3914  06/2016 si es extorno y el movimiento tiene mas de dos registros
            --se consulta nro_secuencia original del movimiento
            /*if nvl(v_rev_can_mov,0) > 2 and to_number(vp_extorno) = 99 then
              lp_obt_nro_secuencia;
            end if;*/
            --lp_ins_ge_movimiento;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            -- acredito el monto que le falta
            lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb,vp_cta_debito, r_gmovi.monto * -1);
         end if;
         lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb,vp_cta_debito, v_imp_debito);
         if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
              IF v_sal_dis_debito < 0 then
                 r_gmovi.monto           := v_imp_debito;
              else
                 r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
              end if;
              pag_cta.PR_OBT_CUENTA(v_nro_cta_combinada);
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.concepto        := 'Transferencia a la Cta '||vp_cta_debito;
              r_gmovi.cod_tra_padre   := 309;
              r_gmovi.cod_transaccion := 503;
              r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
              r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
              r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
              r_gmovi.nro_cuenta      := pag_cta.g_ctas.nro_cuenta;
              ---
              --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
              --DYDMR-3914  06/2016 si es extorno y el movimiento tiene mas de dos registros
              --se consulta nro_secuencia original del movimiento
              /*if nvl(v_rev_can_mov,0) > 2 and to_number(vp_extorno) = 99 then
                lp_obt_nro_secuencia;
              end if;*/
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
              --lp_ins_ge_movimiento;
              --
              lp_upd_cta_debito( pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                 pag_cta.g_ctas.nro_cuenta, r_gmovi.monto);
           end if;
           /* fin cuenta combinada*/
      END IF;
      IF v_es_banco = 'S' AND to_number(vp_cta_credito) <> 0 THEN
         -- Carga los parametros de movimientos de Credito
         v_nro_secuencia       := v_nro_secuencia + 1;
         r_gmovi.cod_modulo    := v_mod_cta_cre;
         r_gmovi.cod_modalidad := v_mad_cta_cre;
         r_gmovi.cod_oficina   := v_ofi_cta_cre;
         r_gmovi.nro_cuenta    := vp_cta_credito;
         r_gmovi.cod_moneda    := nvl(v_mon_cta_cre, v_cod_moneda);
         r_gmovi.cod_usuario   := v_cod_usuario;
         r_gmovi.hora          := v_hora;
         r_gmovi.fecha         := v_fec_proceso;
         r_gmovi.nro_secuencia := v_nro_secuencia;
         --
         r_gmovi.fec_valor     := v_fec_valor;
         r_gmovi.cod_tra_padre := v_cod_tra_padre;
         r_gmovi.cod_mod_padre := v_cod_modulo;
         r_gmovi.cod_mad_padre := v_cod_modalidad;
         IF v_cod_rub_caja IS NOT NULL THEN
            r_gmovi.cod_transaccion := 602;
            r_gmovi.tip_mov_rubro   := 'C';
            r_gmovi.cod_rubro       := v_cod_rub_caja;
         ELSE
            r_gmovi.cod_transaccion := 602;
         END IF;
         IF lf_exi_banco(vp_bco_atm) = 'B' THEN
            r_gmovi.cod_banco := vp_bco_atm;
         ELSE
            r_gmovi.nro_documento2 := vp_bco_atm;
         END IF;
         r_gmovi.monto          := v_imp_credito;
         r_gmovi.nro_documento  := v_nro_documento;
         r_gmovi.nro_documento3 := v_nro_documento3;

         r_gmovi.cod_tasa       := NULL;
         r_gmovi.val_tasa       := NULL;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion      := v_cot_credito;
         r_gmovi.mto_equ_local   := round(r_gmovi.monto * r_gmovi.cotizacion);
         --
         r_gmovi.cod_ofi_origen := v_ofi_origen;
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.concepto       := v_concepto;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);

         if v_mod_cta_cre = 4 then
             if fug_obt_tip_modalidad(v_mod_cta_cre, v_mad_cta_cre) = 'A' then
                 v_tip_transaccion := lf_obt_tipo(r_gmovi.cod_transaccion, v_mod_cta_cre, v_mad_cta_cre);
                 if v_tip_transaccion = 'C' then
                    v_importe := v_importe * (-1);
                 end if;
             end if ;
         end if;

         lp_upd_cta_credito;
         IF v_est_cta_cre = 'I' THEN
            -- Debo cambiar el estado de la cuenta
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := NULL;
            r_gmovi.est_cuenta      := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
         END IF;
      END IF;
   END lp_pro_operacion_05;
   --
   PROCEDURE lp_pro_operacion_06 IS
      -- Extracto --
   BEGIN
      v_cod_tra_padre := 390;
      IF nvl(to_number(vp_cta_debito), 0) != 0 AND v_mad_cta_deb NOT IN (42, 46) THEN
         -- Carga los parametros de movimientos de Debito
         r_gmovi.cod_modulo    := v_mod_cta_deb;
         r_gmovi.cod_modalidad := v_mad_cta_deb;
         r_gmovi.cod_oficina   := v_ofi_cta_deb;
         r_gmovi.nro_cuenta    := vp_cta_debito;
         r_gmovi.cod_moneda    := nvl(v_mon_cta_deb, v_cod_moneda);
         r_gmovi.cod_usuario   := v_cod_usuario;
         r_gmovi.hora          := v_hora;
         r_gmovi.fecha         := v_fec_proceso;
         r_gmovi.nro_secuencia := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := v_cod_modulo;
         r_gmovi.cod_mad_padre   := v_cod_modalidad;
         r_gmovi.cod_transaccion := v_cod_tra_padre;
         r_gmovi.monto           := NULL;
         r_gmovi.nro_documento   := v_nro_documento;
         r_gmovi.nro_documento3  := v_nro_documento3;
         IF lf_exi_banco(vp_bco_atm) = 'B' THEN
            r_gmovi.cod_banco := vp_bco_atm;
         ELSE
            r_gmovi.nro_documento2 := vp_bco_atm;
         END IF;
         r_gmovi.cod_tasa       := NULL;
         r_gmovi.val_tasa       := NULL;
         r_gmovi.cotizacion     := NULL;
         r_gmovi.cod_ofi_origen := v_ofi_origen;
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.concepto       := v_concepto;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
      END IF;
   END lp_pro_operacion_06;
   --
 PROCEDURE lp_pro_operacion_99 IS
    v_exi_movi VARCHAR2(1) := 'N';
      v_fec_anterior ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_ant_hab(v_fec_proceso, NULL, 1);
 BEGIN
    -- Un extorno no se puede desaprobar...
    -- Se busca el siguiente segundo para no tener problemas...
    v_hora           := pag_gen.fu_obt_sig_segundo(v_hora);
    vp_cod_respuesta := vr_aprobado; -- Aprobado
    BEGIN
       SELECT DISTINCT 'S'
         INTO v_exi_movi
         FROM ge_movimientos a
        WHERE a.nro_documento = v_nro_documento
          AND (fup_exi_gru_transac(v_gru_reversiones, a.cod_tra_padre, a.cod_mod_padre,
                                     a.cod_mad_padre) = 'S')
          AND NOT EXISTS (SELECT DISTINCT 'S'
                 FROM ge_movimientos
                WHERE nro_documento = a.nro_documento
                  AND monto < 0
                  AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                     cod_mad_padre) = 'S'))
          AND NOT EXISTS (SELECT DISTINCT 'S'
                       FROM ge_movimientos_noc
                      WHERE nro_documento = a.nro_documento
                        AND monto < 0
                        AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                     cod_mad_padre) = 'S'));

    EXCEPTION
       WHEN no_data_found THEN
          BEGIN
             SELECT DISTINCT 'S'
               INTO v_exi_movi
               FROM ge_movimientos_noc a
              WHERE a.nro_documento = v_nro_documento
              AND (fup_exi_gru_transac(v_gru_reversiones, a.cod_tra_padre, a.cod_mod_padre,
                                     a.cod_mad_padre) = 'S')
                AND NOT EXISTS (SELECT DISTINCT 'S'
                       FROM ge_movimientos_noc
                      WHERE nro_documento = a.nro_documento
                        AND monto < 0
                        AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                     cod_mad_padre) = 'S'))
                AND NOT EXISTS (SELECT DISTINCT 'S'
                      FROM ge_movimientos
                     WHERE nro_documento = a.nro_documento
                       AND monto < 0
                       AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                     cod_mad_padre) = 'S'));
          EXCEPTION
             WHEN no_data_found THEN
                  BEGIN
                     SELECT DISTINCT 'S'
                       INTO v_exi_movi
                       FROM gv_movimientos a
                      WHERE a.nro_documento = v_nro_documento
                        AND a.fecha BETWEEN v_fec_anterior AND v_fec_proceso
                        AND (fup_exi_gru_transac(v_gru_reversiones, a.cod_tra_padre, a.cod_mod_padre,
                                     a.cod_mad_padre) = 'S')
                        AND NOT EXISTS (SELECT DISTINCT 'S'
                               FROM ge_movimientos_noc
                              WHERE nro_documento = a.nro_documento
                                AND monto < 0
                                AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                     cod_mad_padre) = 'S'))
                        AND NOT EXISTS (SELECT DISTINCT 'S'
                               FROM ge_movimientos
                              WHERE nro_documento = a.nro_documento
                               AND monto < 0
                               AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                     cod_mad_padre) = 'S'))
                        AND NOT EXISTS
                      (SELECT DISTINCT 'S'
                               FROM gv_movimientos
                              WHERE nro_documento = a.nro_documento
                                AND monto < 0
                                AND fecha BETWEEN v_fec_anterior AND v_fec_proceso
                                AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                     cod_mad_padre) = 'S'));
                  EXCEPTION
                     WHEN no_data_found THEN
                        v_exi_movi := 'N';
                        vp_cod_respuesta := vr_otr_error;
                  END;
            END;
            lp_car_salida;
    END;
    IF to_number(vp_operacion) IN (0, 23, 24, 41, 72, 50) AND v_exi_movi = 'S' THEN
       lp_pro_operacion_00;
    ELSIF to_number(vp_operacion) in (05, 55) AND v_exi_movi = 'S' THEN
       lp_pro_operacion_05;
    END IF;
 END lp_pro_operacion_99;

   PROCEDURE lp_obt_dat_tra_atm
    (
       p_cod_tra_padre       IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
       p_cod_modulo          IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE,
       p_cod_modalidad       IN GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE,
       p_ntr_atm             IN VARCHAR2,
       p_cod_gru_transaccion OUT ge_gru_transacciones_det.cod_gru_transaccion%TYPE,
       p_cod_tra_cargo       OUT NUMBER,
       p_par_dinamico        OUT VARCHAR2
    ) IS
    BEGIN
      SELECT cod_gru_transaccion,
             decode(cod_gru_transaccion, 51, 148, 52, 145, 53, 146, 54, 147),
             decode(cod_gru_transaccion, 51, 'CAN_MAX_EXT_PRO_ATM', 52, 'CAN_MAX_EXT_OTR_ATM', 53, 'CAN_MAX_CON_PRO_ATM', 54, 'CAN_MAX_CON_OTR_ATM')
             into p_cod_gru_transaccion, p_cod_tra_cargo, p_par_dinamico
        FROM ge_gru_transacciones_det g
       WHERE cod_modulo = p_cod_modulo
         AND cod_modalidad = p_cod_modalidad
         AND cod_transaccion = p_cod_tra_padre
         and ((p_ntr_atm = 'S' and cod_gru_transaccion in(51,53))
         or (p_ntr_atm = 'N' and cod_gru_transaccion in(52,54)));
    EXCEPTION
       WHEN OTHERS THEN
         p_cod_gru_transaccion := NULL;
         p_cod_tra_cargo := NULL;
         p_par_dinamico := NULL;
    END lp_obt_dat_tra_atm;

   PROCEDURE lp_obt_cargos IS
        v_ent_codigo number(5) := to_number(fug_obt_pardinamico('COD_ENT_INFONET', NULL, NULL, NULL, NULL));
        v_pos_cadena number(2);
        v_cadena     ge_par_dinamicos.val_parametro%type;
   BEGIN
      v_cadena := FUG_OBT_PARDINAMICO('ATM_TRA_SIN_COSTO');
      v_pos_cadena := instr(v_cadena, v_cod_tra_padre);
      IF v_pos_cadena > 0 THEN
           v_car_mas_iva := 0;
      else
        if r_gmovi.cod_banco is not null then
           if r_gmovi.cod_banco = v_ent_codigo then
              v_ntr_atm := 'S';
           else
              v_ntr_atm := 'N';
           end if;
        else
           if r_gmovi.nro_documento2 is not null then
               if r_gmovi.nro_documento2 = v_ent_codigo then
                  v_ntr_atm := 'S';
               else
                  v_ntr_atm := 'N';
               end if;
           end if;
        end if;
        /* comentado para bankitti
        lp_obt_dat_tra_atm(v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_ntr_atm, v_cod_gru_transaccion, v_cod_transaccion, v_par_dinamico);
        --retorna el cargo e iva a ser cobrado por el uso de nuetros atms
        if v_cod_gru_transaccion is not null and v_cod_transaccion is not null and v_par_dinamico is not null then
          if v_ntr_atm = 'S' then
             prg_obt_car_uso_pro_atm(vp_cta_debito, v_cod_gru_transaccion, v_cod_transaccion, v_par_dinamico, 'N', v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);
          else
             prg_obt_car_uso_otr_atm(vp_cta_debito, v_cod_gru_transaccion, v_cod_transaccion, v_par_dinamico, 'N', v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);
          end if;
        end if;
        v_car_mas_iva := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
        */
      end if;
   END lp_obt_cargos;

   FUNCTION lf_ver_cta_cnb RETURN VARCHAR2 IS
     v_cta_cnb VARCHAR2(10);
     v_marca   VARCHAR2(1) := '9';
     v_pre_cta VARCHAR2(10);
     v_pos_cta VARCHAR2(10);
     v_cod_ente VARCHAR2(10);
   BEGIN
     -- Retorna S si es cuenta CNB no debe realizar nada mas responder ok 00
     -- Si no retorna N y debe realizar la autorizacion normal
     -- vp_cta_debito-- cta que viene en el mensaje
     -- verificar si es cnb
  --   v_pre_cta := to_char((substr(vp_cta_debito,1,7)));
   --  v_pos_cta := to_char((substr(vp_cta_debito,9)));

     v_cta_cnb := to_number(vp_cta_debito);

     BEGIN
       SELECT a.cod_ente
         INTO v_cod_ente
         FROM ge_entes a --,ge_par_entes b
        WHERE a.tipo = 'CN'
          AND a.cod_ente = v_cta_cnb
        --  AND b.val_parametro = v_cta_cnb
        --  AND b.parametro IN ('CTA_AH_CNB_GS','CTA_AH_CNB_USD')
          AND rownum = 1;

     IF v_cod_ente IS NOT NULL THEN
       --vp_cta_debito := v_cta_it;
       RETURN 'S';
     ELSE
       RETURN 'N'; --
     END IF;

     EXCEPTION
         -- tomar cuenta de la mensajeria
       WHEN OTHERS THEN
         -- Buscar las cuentas nuevas
         -- para cuentas CNB nuevas no hace falta cambiar la marca. Buscar si existe como ente
     /*
         v_cta_cnb := to_number(vp_cta_debito);

         BEGIN
           SELECT b.val_parametro
             INTO v_cta_it
             FROM ge_entes a,ge_par_entes b
            WHERE a.tipo = 'CN'
              AND a.cod_ente = b.cod_ente
              AND b.val_parametro = v_cta_cnb
              AND b.parametro IN ('CTA_AH_CNB_GS','CTA_AH_CNB_USD')
              AND rownum = 1;
         EXCEPTION
           WHEN no_data_found THEN
             RETURN 'N'; -- tomar cuenta de la mensajeria
           WHEN OTHERS THEN
             RETURN 'N';
         END;
      */
      --   IF v_cta_it IS NOT NULL THEN
      --     RETURN 'S';
      --  ELSE
           RETURN 'N';
      --  END IF;
     END;
   END;

BEGIN
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 9;
   END;
   -- Carga el parametro en variables
   lp_car_parametros;

   -- Verificar si la cuenta corresponde a CNB, si es responder ok directamente sin realizar ningun mov
   IF lf_ver_cta_cnb = 'S' THEN
     -- es CNB responder ok
     -- Carga respuesta por defecto --
     vp_cod_respuesta := vr_aprobado;
     vp_can_extractos  := '000';
     vp_sig_disponible := '+';
     vp_sig_contable   := '+';
     vp_sal_disponible := lpad('0', 15, '0');
     vp_sal_contable   := lpad('0', 15, '0');
     lp_car_salida;
     lp_obt_respuesta;
   ELSE -- no es CNB realiza la autorizacion de siempre

     -- Carga los valores iniciales
     lp_car_val_inicial;
     ---
     IF nvl(to_number(vp_cta_debito), 0) != 0 AND vp_cod_respuesta = vr_aprobado THEN
        -- Debo verificar si existe la cuenta
        IF v_ind_ctacontable = 'N' THEN
           pag_cta.pr_obt_cuenta(vp_cta_debito);
           --recupera datos para cuenta combinada
           v_nro_cta_combinada := pag_cta.G_CTAS.nro_cta_combinada;
           v_sal_dis_debito    := pag_cta.FU_SAL_DISPONIBLE;
        ELSE
           pag_cta.g_ctas.sal_disponible := 0;
           pag_cta.g_ctas.sal_actual     := 0;
        END IF;
        lp_dat_cta(vp_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb);
        g_cod_error := pag_cta.g_cod_error;
        IF g_cod_error = 12 THEN
           -- Cuenta inexistente
           vp_cod_respuesta := vr_cta_inexistente; -- Tarjeta desconocida
           v_msj_error := 'Cuenta Debito Inexistente';
        END IF;
     END IF;
     IF vp_cod_respuesta = vr_aprobado THEN
        -- Verifica el estado de la cuenta
        v_est_cuenta := pag_cta.fu_obt_est_cuenta;
        IF v_est_cuenta NOT IN ('N', 'S', 'I') THEN
           -- No es normal o con bloqueo de saldo
           -- Estado Inactivo tambien debe permitir.
           vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
           v_msj_error := 'Estado de la Cuenta Debito Invalido. Estado: ' || v_est_cuenta;
        /*ELSE
           --Verifica si es una cta. combinada
           IF v_cta_com = 'S' THEN
              vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
           END IF;*/
        END IF;
     END IF;
     IF vp_operacion IN (41) AND nvl(to_number(vp_cta_credito), 0) != 0 AND vp_cod_respuesta = vr_aprobado THEN
        -- Debo verificar si existe la cuenta
        IF v_ind_ctacontable = 'N' THEN
           pag_cta.pr_obt_cuenta(vp_cta_credito);
           --recupera datos para cuenta combinada
           v_nro_cta_combinada := pag_cta.G_CTAS.nro_cta_combinada;
           v_sal_dis_debito    := pag_cta.FU_SAL_DISPONIBLE;
        ELSE
           pag_cta.g_ctas.sal_disponible := 0;
           pag_cta.g_ctas.sal_actual     := 0;
        END IF;
        lp_dat_cta(vp_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre);
        g_cod_error := pag_cta.g_cod_error;
        IF g_cod_error = 12 THEN
           -- Cuenta inexistente
           vp_cod_respuesta := vr_cta_inexistente; -- Tarjeta desconocida
           v_msj_error := 'Cuenta Credito Inexistente';
        END IF;

        IF vp_cod_respuesta = vr_aprobado THEN
            -- Verifica el estado de la cuenta
            v_est_cuenta := pag_cta.fu_obt_est_cuenta;
            IF v_est_cuenta NOT IN ('N', 'S', 'I') THEN
               -- No es normal o con bloqueo de saldo
               -- Estado Inactivo tambien debe permitir.
               vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
               v_msj_error := 'Estado de la Cuenta Credito Invalido. Estado: ' || v_est_cuenta;
            /*ELSE
               --Verifica si es una cta. combinada
               IF v_cta_com = 'S' THEN
                  vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
               END IF;*/
            END IF;
        END IF;
     END IF;

     IF vp_cod_respuesta = vr_aprobado THEN
        IF to_number(vp_extorno) != 99 THEN
           IF to_number(vp_operacion) IN (0, 23, 41, 24, 50, 72) THEN
              -- Compras
              lp_ver_operacion_00;
           ELSIF to_number(vp_operacion) IN (2, 52, 93) THEN
              -- Consulta de Saldo
              lp_ver_operacion_02;
           ELSIF to_number(vp_operacion) IN (5,55) THEN
              -- Extraccion
              lp_ver_operacion_05;
           ELSIF to_number(vp_operacion) = 6 THEN
              -- Extracto
              lp_ver_operacion_06;
           ELSIF v_clt_deb_nuestro = 'S' THEN
              vp_cod_respuesta := vr_ope_invalida;
           END IF;
        ELSE
           -- Reversion
           lp_ver_operacion_99;
        END IF;

     END IF;
     -- Verifica el estado del modulo por si se este haciendo el cierre
     v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
     IF v_est_modulo IN (1, 6) THEN
        -- Se esta corriendo el proceso de cierre
        vp_cod_respuesta := vr_en_cierre; -- En cierre
     END IF;
     -- Carg? los datos de salida
     lp_car_salida;
     -- Si la respuesta fue aprobado, Debe procesar la transaccion --
     IF vp_cod_respuesta = vr_aprobado THEN
        IF to_number(vp_extorno) != 99 THEN
           IF to_number(vp_operacion) IN (0, 23, 24, 41, 50, 72) THEN
              -- Compras
              lp_pro_operacion_00;
           ELSIF to_number(vp_operacion) IN (2, 52, 93) THEN
              -- Consulta de Saldo
              lp_pro_operacion_02;
           ELSIF to_number(vp_operacion) IN (05, 55) THEN
              -- Extraccion
              lp_pro_operacion_05;
           ELSIF to_number(vp_operacion) = 6 THEN
              -- Extracto
              lp_pro_operacion_06;
           END IF;
           lp_obt_cargos;
        ELSE
           lp_pro_operacion_99;
        END IF;
     END IF;
     lp_obt_respuesta;
   END IF;
   --
   lp_reg_operacion(substr(v_pedido, 1, 4000), substr(vp_respuesta, 1, 4000), substr(v_msj_error, 1, 4000), v_fec_inicio,
                    vp_extorno, v_fec_valor, v_nro_documento, vp_cta_debito, v_hora, vp_bco_debito, vp_cta_credito, vp_bco_credito,
                    vp_operacion, v_importe, vp_moneda, vp_nro_atm, vp_nro_pos, vp_tra_pos, vp_tip_hora, vp_negocio, vp_tra_extornado,
                    vp_bco_atm,vp_servicio, vp_prestacion, vp_marca, vp_producto, vp_med_pago);
   -- Una vez procesado responde
   RETURN vp_respuesta;
EXCEPTION
   WHEN OTHERS THEN
      v_msj_error := SQLERRM;
      ROLLBACK;
      vp_cod_respuesta := vr_otr_error;
      -- Carga respuesta por defecto --
      vp_can_extractos  := '000';
      vp_sig_disponible := '+';
      vp_sig_contable   := '+';
      vp_sal_disponible := lpad('0', 15, '0');
      vp_sal_contable   := lpad('0', 15, '0');
      vp_extractos      := '';
      lp_car_salida;
      lp_obt_respuesta;
      lp_reg_operacion(substr(v_pedido, 1, 4000), substr(vp_respuesta, 1, 4000), substr(v_msj_error, 1, 4000), v_fec_inicio);
      RETURN vp_respuesta;
END;
/
