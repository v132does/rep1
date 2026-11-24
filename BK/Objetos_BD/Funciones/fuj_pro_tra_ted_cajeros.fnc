CREATE OR REPLACE FUNCTION it.fuj_pro_tra_ted_cajeros(p_pedido VARCHAR2) 
  RETURN VARCHAR2 IS
  --
  v_cod_entidad     NUMBER(3);
  v_es_banco        VARCHAR2(1) := 'N';
  v_clt_deb_nuestro VARCHAR2(1) := 'N';
  v_clt_cre_nuestro VARCHAR2(1) := 'N';
  v_atm_nuestro     VARCHAR2(1) := 'N';
  v_hor_limite      VARCHAR2(8) := '999999';
  v_est_modulo      ba_modulos.estado%TYPE;
  v_est_cuenta      ge_cuentas.estado%TYPE;
  v_est_cta_ant     ge_cuentas.estado%TYPE;
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
  v_cod_cliente         ge_cta_clientes.cod_persona%TYPE;
  v_cod_seg_funcionario ge_seg_clientes.cod_seg_cliente%TYPE := fug_obt_pardinamico('GEN_COD_SEG_FUNCIONARIO');
  v_exo_mto_minimo      VARCHAR2(1) := 'N';
  v_sal_disponible  ah_cta_vistas.sal_total%TYPE;
  v_sal_contable    ah_cta_vistas.sal_total%TYPE;
    
  --- Variables del movimiento...
  v_fec_proceso    ge_movimientos.fecha%TYPE;
  v_fec_valor      ge_movimientos.fecha%TYPE;
  v_cod_moneda     ba_monedas.cod_moneda%TYPE;
  v_acu_sobregiro  cc_cta_corrientes.acu_sobregiro%TYPE;
  v_importe        ge_movimientos.monto%TYPE := 0;
  v_nro_caja       cc_cta_cajeros.nro_caj_externo%TYPE;
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
  v_cod_usuario    ge_movimientos.cod_usuario%TYPE := upper(USER);
  -- Variables para cobros de cargos por extraccion.
  v_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE;
  v_val_tas_cargo    ge_movimientos.val_tasa%TYPE;
  v_val_cargo        ge_movimientos.val_tasa%TYPE;
  v_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE;
  v_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE;
  v_val_tas_impuesto ge_movimientos.val_tasa%TYPE;
  v_val_impuesto     ge_movimientos.val_tasa%TYPE;
  v_cargos           ge_movimientos.monto%TYPE;
  v_msj_error        CJ_LOG_ATM_CAJ.msj_error%TYPE;
  v_fec_inicio       CJ_LOG_ATM_CAJ.fec_inicio%TYPE := SYSDATE;
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
  --Nuevos mensajes de error
  vr_negocio_inv        VARCHAR2(2) := '03';
  vr_no_aprob_min_25    VARCHAR2(2) := '10';
  vr_no_aprob_cli_vip   VARCHAR2(2) := '11';
  vr_mto_invalido       VARCHAR2(2) := '13';
  vr_emi_inexistente    VARCHAR2(2) := '15';
  vr_reg_duplicado      VARCHAR2(2) := '26';
  vr_bco_inexistente    VARCHAR2(2) := '31';
  vr_cta_bloqueada      VARCHAR2(2) := '36';
  vr_oper_no_soportada  VARCHAR2(2) := '40';
  vr_cta_inexistentee   VARCHAR2(2) := '45';
  vr_cta_inex_corriente VARCHAR2(2) := '52';
  vr_cta_inex_ahorro    VARCHAR2(2) := '53';
  vr_exc_cant_oper      VARCHAR2(2) := '65';
  vr_fecha_invalida     VARCHAR2(2) := '72';
  vr_rev_no_encontrada  VARCHAR2(2) := '76';

  --
  g_cod_error pag_cta.g_cod_error%TYPE;
  -- Variables para manejar los parametros --
  vp_cta_debito     VARCHAR2(10);
  v_cta_portavalor     VARCHAR2(10);
  vp_bco_debito     VARCHAR2(3);
  vp_cta_credito    VARCHAR2(10);
  vp_bco_credito    VARCHAR2(3);
  vp_operacion      VARCHAR2(2);
  vp_extorno        VARCHAR2(2);
  vp_tra_entidad    VARCHAR2(15);
  vp_transaccion    VARCHAR2(15);
  vp_importe        VARCHAR2(18);
  vp_importe2       VARCHAR2(18);
  vp_importe3       VARCHAR2(18);
  vp_can_cheques    VARCHAR2(4);
  vp_moneda         VARCHAR2(2);
  vp_nro_atm        VARCHAR2(6);
  vp_nro_pos        VARCHAR2(2);
  vp_tra_pos        VARCHAR2(4);
  vp_tip_hora       VARCHAR2(3);
  vp_negocio        VARCHAR2(40);
  vp_tra_extornado  VARCHAR2(15);
  vp_bco_atm        VARCHAR2(3);
  vp_fecha          VARCHAR2(8);
  vp_hora           VARCHAR2(6);
  vp_servicio       VARCHAR2(3);
  vp_prestacion     VARCHAR2(4);
  vp_marca          VARCHAR2(3);
  vp_producto       VARCHAR2(3);
  vp_med_pago       VARCHAR2(2);
  vp_car_inicial    VARCHAR2(1);
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

  v_horario             VARCHAR2(1) := 'D'; -- (D) Dia, (T) Tarde, (N) Nocturno
  v_es_nocturno         VARCHAR2(1) := 'N';
  v_es_cta_noc          VARCHAR2(1) := 'N';
  v_ind_cob_comision    VARCHAR2(1) := fug_obt_pardinamico('CAJ_IND_COB_COMISION');
  r_gmovi               ge_movimientos%ROWTYPE;
  G_CTAS                PAG_CTA.RG_CTAS;
  v_pedido              varchar2(3000) := p_pedido; --substr(p_pedido,2);
  v_nro_cuenta          ge_cuentas.nro_cuenta%type;
  v_car_mas_iva         NUMBER(18, 2) := 0;
  v_bncmsg              VARCHAR2(408) := '';
  v_lon                 NUMBER(3);
  v_lon_total           NUMBER(3);
  v_doceli              VARCHAR2(480) := '';
  v_scrdta              VARCHAR2(322) := '';
  v_can_letras          NUMBER := 0;
  v_tip_transaccion     GE_TRANSACCIONES.TIPO%type;
  v_cod_retencion       ge_movimientos.cod_retencion%type := 1;
  v_fec_fin_retencion   ge_movimientos.fec_fin_retencion%type;
  v_gru_reversiones     GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_GRU_TRA_ATM_REVERSIONES');
  v_retorno             varchar2(1);
  v_dep_ret_mark        NUMBER := 0;
  v_dep_ret_ope         VARCHAR(1);
  v_dep_ret_cta         NUMBER := 0;
  v_cod_ban_chq         VARCHAR2(2);
  v_mto_loa             ge_movimientos.monto%TYPE := 0; --Monto LOA
  v_mto_acumulado       ge_movimientos.monto%TYPE := 0; --Monto acumulado MEs
  v_mto_total           ge_movimientos.monto%TYPE := 0; --Monto total
  v_deposita             VARCHAR(1);--S Deposita N: No deposita
  ---
  --Transacciones parametrizadas para recepción de WU
  v_cod_tra_pad_rec_wu GE_PAR_DINAMICOS.VAL_PARAMETRO%type     := fug_obt_pardinamico('CJ_TRA_PAD_RWU');--1121
  v_cod_tra_hij_rec_wu GE_PAR_DINAMICOS.VAL_PARAMETRO%type     := fug_obt_pardinamico('CJ_TRA_HIJ_RWU_CLI');--3678
  v_cod_tra_hij_rec_wu_ted GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_RWU_TED'); --602
  --Transacciones parametrizadas para Vuelto(Extraccion de Dinero)
  v_cod_tra_pad_vuelto GE_PAR_DINAMICOS.VAL_PARAMETRO%type     := fug_obt_pardinamico('CJ_TRA_PAD_VUE');--1123
  v_cod_tra_hij_vuelto GE_PAR_DINAMICOS.VAL_PARAMETRO%type     := fug_obt_pardinamico('CJ_TRA_HIJ_VUE_CLI');--3679
  v_cod_tra_hij_vuelto_ted GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_VUE_TED');--602
  --Transacciones parametrizadas para Pagos Servicios(Depósito de Dinero)
  v_cod_tra_pad_dep     GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_PAD_PAG_SER');--1122
  v_cod_tra_hij_dep     GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_PAG_SER');--3679
  v_cod_tra_hij_dep_ted GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_PAG_SER_TED');--503
  --Transacciones parametrizadas para Extracción Pagos Servicios(Extracción de Dinero)
  v_cod_tra_hij_ext_ser     GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_EXT_SER');--4615
  v_cod_tra_hij_ext_ser_ted GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_EXT_SER_TED');--602
  --Transacciones parametrizadas para Descarga portavalores TED GDR-242
  v_cod_tra_pad_tcd  GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_PAD_TED_TCD');--1125 
  v_cod_tra_hij_trd  GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_TED_TRD');--3692 DESCARGA
  v_cod_tra_hij_trc  GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_TED_TRC');--3691 CARGA
  v_cod_tra_trd_ted  GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_COD_TRA_TRD_TED');-- 602
  --Transacciones parametrizadas para Extraccion con Tarjetas CREDITO / DEBITO  TED GDR-242
  v_cod_tra_pad_tet  GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_PAD_TED_TET');--1230
  v_cod_tra_hij_etd  GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_TED_ETD');--3870 debito
  v_cod_tra_hij_etc  GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_TED_ETC');--3871 credito
  v_cod_tra_tet_ted  GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_COD_TRA_TRD_TED');-- 602

  --Códigos de operaciones excluidas en depósitos usd TED validación umbral
  v_cod_ope_ted_umb GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_OPE_TED_UMB');
  --Códigos de operaciones admitidas en TED
  v_cod_ope_ted GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_COD_OPE_TED');
  --Variables de transacciones hijo Cliente/TED
  v_cod_tra_hijo_cta  cj_movimientos.cod_tra_padre%TYPE;
  v_cod_tra_hijo_ted  cj_movimientos.cod_tra_padre%TYPE;
  --Transacciones parametrizadas para Depósitos playeros(Depósito de Dinero con retencion de saldo)
  v_cod_tra_pad_dep_ret  GE_PAR_DINAMICOS.VAL_PARAMETRO%type    := fug_obt_pardinamico('COD_TRA_PADRE_DEP_EFE_TED_RET');--393
  v_cod_tra_hij_dep_ret  GE_PAR_DINAMICOS.VAL_PARAMETRO%type    := fug_obt_pardinamico('COD_TRA_HIJO_DEP_EFE_TED_RET');--613
  v_cod_tra_hij_dep_ted_ret GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('COD_TRA_CTA_TED_DP_EF_TED_RET');--503
 --Transacciones parametrizadas para extraccion de efectivo Otras Entidades(Extracción de Dinero)  
  v_cod_tra_pad_oen GE_PAR_DINAMICOS.VAL_PARAMETRO%type     := fug_obt_pardinamico('CJ_TRA_PAD_OTE');--1126
  v_cod_tra_hij_oen GE_PAR_DINAMICOS.VAL_PARAMETRO%type     := fug_obt_pardinamico('CJ_TRA_HIJ_OTE_CLI');--3683
  v_cod_tra_hij_oen_ted GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_OTE_TED');--602
  --Transacciones parametrizadas para deposito de efectivo Otras Entidades(Deposito de Dinero)  
  v_cod_tra_pad_dep_oen GE_PAR_DINAMICOS.VAL_PARAMETRO%type     := fug_obt_pardinamico('CJ_TRA_PAD_DEP_OEN');--1127
  v_cod_tra_hij_dep_oen GE_PAR_DINAMICOS.VAL_PARAMETRO%type     := fug_obt_pardinamico('CJ_TRA_HIJ_DEP_OEN');--4614
  v_cod_tra_hij_dep_oen_ted GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_DEP_OEN_TED');--503
  --
   ---------- Definicion de procesos y funciones locales
  FUNCTION lf_obt_mes_nac(p_nro_cuenta varchar2, p_relacion varchar2)
    RETURN VARCHAR2 IS
    v_mes           VARCHAR2(3) := null;
    v_cta_principal ge_cuentas.nro_cuenta%type;
  
  BEGIN
    SELECT mes
      INTO v_mes
      FROM (SELECT DECODE(substr(TO_CHAR(TO_DATE(b.fec_nacimiento), 'MONTH'),
                                 1,
                                 3),
                          'SEP',
                          'SET',
                          substr(TO_CHAR(TO_DATE(b.fec_nacimiento), 'MONTH'),
                                 1,
                                 3)) mes
              FROM ah_tar_debitos a, ba_per_fisicas b
             WHERE a.cod_persona = b.cod_persona
               and a.adherente = p_relacion
               and a.nro_cuenta = p_nro_cuenta
               and rownum = 1
            UNION
            SELECT DECODE(substr(TO_CHAR(TO_DATE(b.fec_apertura), 'MONTH'),
                                 1,
                                 3),
                          'SEP',
                          'SET',
                          substr(TO_CHAR(TO_DATE(b.fec_apertura), 'MONTH'),
                                 1,
                                 3)) mes
              FROM ah_tar_debitos a, ba_per_juridicas b
             WHERE a.cod_persona = b.cod_persona
               and a.adherente = p_relacion
               and a.nro_cuenta = p_nro_cuenta
               and rownum = 1);
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
                              substr(TO_CHAR(TO_DATE(b.fec_apertura), 'MONTH'),
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
  /* Obtiene datos de la Retencion. */
   PROCEDURE pr_obt_retencion
   (
      p_fec_transaccion IN DATE,
      p_nro_cuenta      IN ge_cuentas.nro_cuenta%TYPE,
      p_cod_modulo      IN ba_modulos.cod_modulo%TYPE,
      p_cod_modalidad   IN ge_transacciones.cod_modalidad%TYPE,
      p_cod_transaccion IN ge_transacciones.cod_transaccion%TYPE,
      p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
      p_cod_retencion   IN OUT ge_retenciones.cod_retencion%TYPE,
      p_fin_retencion   IN OUT DATE
   ) IS
      v_fec_transaccion   DATE;
      v_error             VARCHAR2(200) := NULL;
      v_can_dia_retencion NUMBER(4) := 0;
   BEGIN

      v_fec_transaccion := p_fec_transaccion;
      IF p_cod_moneda IS NULL THEN
         v_error := 'Moneda no definida';
      ELSIF p_cod_retencion IS NULL THEN
         v_error := 'Retencion no definida';
      END IF;
      IF v_error IS NULL THEN
         -- busco en primer lugar sino tiene retencion personalizada la cuenta
         v_can_dia_retencion := -1; -- inicializo como sin dato
         BEGIN
            SELECT can_dia_retencion
              INTO v_can_dia_retencion
              FROM ge_ret_cuentas
             WHERE nro_cuenta = p_nro_cuenta
               AND cod_retencion = p_cod_retencion;
         EXCEPTION
            WHEN no_data_found THEN
               v_can_dia_retencion := -1;
         END;
         IF v_can_dia_retencion = -1 THEN
            -- no tiene retencion personalizada, busco la retencion general
            SELECT can_dias
              INTO v_can_dia_retencion
              FROM ge_ret_monedas
             WHERE cod_moneda = p_cod_moneda
               AND cod_retencion = p_cod_retencion;
         END IF;
         -- ya se tienen los dias de retencion, debo calcular la fecha
         IF p_fec_transaccion IS NULL THEN
            v_fec_transaccion := pag_cal.fu_obt_fec_actual(p_cod_modulo);
         END IF;
         -- obtiene la fecha habil sgte de la retencion
         p_fin_retencion := pag_cal.fu_obt_fec_fin_ret(v_fec_transaccion,
                                                       v_ofi_cta_deb,
                                                       v_can_dia_retencion);
      END IF;
      -- Verifico sino hubo errores
      IF v_error IS NOT NULL THEN
         pag_cta.g_msj_error := v_error;
         pag_cta.g_cod_error := 07;
      END IF;
      RETURN;
   END;
--Obtener código de retención
  FUNCTION lf_obt_cod_reten(p_nro_cuenta cc_cta_cajeros.nro_cuenta%TYPE)
    RETURN VARCHAR2 IS
    v_cod_reten cc_cta_cajeros.cod_retencion%TYPE := '';
  BEGIN
    SELECT cod_retencion
      INTO v_cod_reten
      FROM cc_cta_cajeros
     WHERE nro_cuenta = vp_cta_credito;
    RETURN v_cod_reten;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN v_cod_reten;
  END;
  --
   --Obtener código de retención
  FUNCTION lf_obt_cod_ret_dep_efe(p_nro_cuenta cc_cta_cajeros.nro_cuenta%TYPE)
    RETURN VARCHAR2 IS
    v_depo_ret_occount cc_cta_cajeros.cod_retencion%TYPE := '0';
  BEGIN
    SELECT val_parametro
      INTO v_depo_ret_occount
      FROM ge_cta_dat_adicionales
     WHERE nro_cuenta = vp_cta_debito
       AND parametro = 'COD_RET_DEP_EFE_TED';
    RETURN v_depo_ret_occount;
  EXCEPTION
     WHEN too_many_rows THEN
      RETURN v_depo_ret_occount;
    WHEN no_data_found THEN
      RETURN v_depo_ret_occount;
    WHEN others THEN
      RETURN v_depo_ret_occount;
  END;
  ---
  FUNCTION lf_obt_tip_persona(p_nro_cuenta in varchar2)
     RETURN VARCHAR2 IS
     v_cod_principal ba_personas.cod_persona%type;
   BEGIN
      --- Obtengo el principal.
      Select cod_persona
        into v_cod_principal
        from ge_cta_clientes
       where nro_cuenta = p_nro_cuenta
         and relacion = 'P';
      --
      If pag_gen.fu_es_per_fisica(v_cod_principal) = 'N' then
         return 'J';
      Else
         return 'F';
      End if;
    EXCEPTION
       WHEN too_many_rows THEN
        --- Obtengo el principal.
          Select cod_persona
            into v_cod_principal
            from ge_cta_clientes
           where nro_cuenta = p_nro_cuenta
             and relacion = 'P'
             and rownum = 1 ;
          --
          If pag_gen.fu_es_per_fisica(v_cod_principal) = 'N' then
             return 'J';
          Else
             return 'F';
          End if;
      WHEN no_data_found THEN
        RETURN 'F';
      WHEN others THEN
        RETURN 'F';
   end;
  ---
  FUNCTION lf_obt_tipo(p_cod_transaccion ge_transacciones.cod_transaccion%TYPE,
                       p_cod_modulo      ge_cuentas.cod_modulo%TYPE,
                       p_cod_modalidad   ge_cuentas.cod_modalidad%TYPE)
    RETURN VARCHAR2 IS
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
  ---
  FUNCTION lf_che_banco RETURN VARCHAR2 IS
   BEGIN
      BEGIN 
     --Validar si es banco otros bancos
      select 'S' 
       into v_cod_ban_chq 
       from cj_dep_chq_atm_reg u
       where u.nro_cuenta = vp_cta_debito
         and u.monto_cheque = v_importe
         and u.cod_banco in (39,46)
         and rownum = 1
         order by u.fec_insercion desc;
    EXCEPTION
      WHEN no_data_found THEN
       v_cod_ban_chq := 'N';
      WHEN others THEN
       v_cod_ban_chq := 'N';
    END;
    RETURN v_cod_ban_chq;
  END lf_che_banco;
  ---
  FUNCTION lf_exi_retencion(v_cod_retencion NUMBER) RETURN VARCHAR2 IS
    v_exi_retencion VARCHAR2(1) := 'N';
  BEGIN
   BEGIN
      SELECT 'S'
        INTO v_exi_retencion
        FROM ge_retenciones
       WHERE cod_retencion = v_cod_retencion;
       RETURN v_exi_retencion;
    EXCEPTION
      WHEN too_many_rows THEN
        RETURN 'S';
      WHEN no_data_found THEN
        RETURN v_exi_retencion;
      WHEN others THEN
        RETURN v_exi_retencion;
    END;
  END lf_exi_retencion;
  ---
   --funcion para validar moneda y parametro de Umbral
  function lf_val_lim_umbral(p_cod_moneda varchar2) return varchar2 is
    v_retorno      varchar2(1) := 'N';
    v_val_limite   ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CJ_VAL_USD_CAJA');
    Cursor c_monedas is
      select b.val_minimo cod_moneda
        from ba_cod_referencias b
       where dominio = 'COD_MON_UMBRAL'
         and activo = 'S';
  begin
    if v_val_limite = 'S' then
      --Monedas configuradas para control de umbral
      FOR reg IN c_monedas LOOP
        if reg.cod_moneda = p_cod_moneda then
          v_retorno := 'S';
        end if;
      END LOOP;
    else
      v_retorno := 'N';
    end if;

    return v_retorno;
  end lf_val_lim_umbral;
  --
 --procedimiento interno: inserta pedido de autorizacion umbral
  procedure lp_ins_pedido_umbral is
  begin
    if v_deposita = 'N' then
       insert into ge_aut_umbral(nro_cuenta,cod_persona,fecha,hora,cod_usuario,monto_loa,monto_acumulado,monto_total,estado,cod_moneda,monto_operacion,observacion)
       values (vp_cta_debito, v_cod_cliente, v_fec_valor, v_hora, user, v_mto_loa, v_mto_acumulado, v_mto_total, 'A',v_cod_moneda,v_importe,'Depósito Efe TED anulado por superar umbral.');
    else 
      insert into ge_aut_umbral(nro_cuenta,cod_persona,fecha,hora,cod_usuario,monto_loa,monto_acumulado,monto_total,estado,cod_moneda,monto_operacion,observacion)
       values (vp_cta_debito, v_cod_cliente, v_fec_valor, v_hora, user, v_mto_loa, v_mto_acumulado, v_mto_total, 'C',v_cod_moneda,v_importe,'Depósito Efe TED confirmado.');
    end if;
  exception
    when others then
      vp_cod_respuesta := '006'; -- error
      v_msj_error := 'ERROR: Al insertar umbral en TED.';
  end lp_ins_pedido_umbral;
  PROCEDURE lp_ver_horario IS
  BEGIN
    v_horario     := 'D'; -- Dia
    v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
    v_es_cta_noc  := 'N';
    v_fec_proceso := pag_cal.fu_obt_fec_actual(3);
    IF v_est_modulo = 2 THEN
      -- El modulo esta abierto
      -- Verifica la hora --
      IF (vp_hora > v_hor_limite AND
         v_fec_proceso = to_date(vp_fecha, 'ddmmyyyy')) /*OR
         v_fec_proceso < to_date(vp_fecha, 'ddmmyyyy')*/ THEN
        v_horario     := 'T'; -- Tarde
        v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,
                                                  1,
                                                  v_ofi_origen);
        v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
      END IF;
    ELSE
      v_horario     := 'N'; -- Noche
      v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,
                                                1,
                                                v_ofi_origen);
      v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
      v_es_cta_noc  := 'S'; -- Solo para que llavee la cuenta nocturna
    END IF;
    v_fec_valor := trunc(SYSDATE); -- para que sea fecha la fecha real de la transaccion --v_fec_proceso;
  END lp_ver_horario;
  ---
   PROCEDURE lp_val_mar_retencion IS
  BEGIN
     v_dep_ret_ope := fug_obt_pardinamico('CJ_RET_DEP_TED'); --S= Ret N= No Ret
     IF v_dep_ret_ope = 'S' THEN
        IF instr(fug_obt_pardinamico('CJ_TIP_PERSONA'),lf_obt_tip_persona(vp_cta_debito)) > 0 THEN --Tipo de persona F= física J= Jurídica
            v_dep_ret_cta := lf_obt_cod_ret_dep_efe(vp_cta_debito); --Obtiene código de retención
            IF to_number(v_dep_ret_cta) > 0 THEN
              IF lf_exi_retencion(to_number(v_dep_ret_cta)) = 'S' THEN --Valida que exista la retención
                IF instr(fug_obt_pardinamico('CJ_OPE_DEP_RET'),vp_operacion) > 0 THEN -- Valida que la operacion esté configurada para retener
                  v_dep_ret_mark     := 1;
                  v_cod_tra_padre    := to_number(v_cod_tra_pad_dep_ret);
                  v_cod_tra_hijo_cta := to_number(v_cod_tra_hij_dep_ret);
                  v_cod_tra_hijo_ted := to_number(v_cod_tra_hij_dep_ted_ret);
                  v_cod_retencion := to_number(v_dep_ret_cta);
                END IF;
              END IF;
          END IF;
        END IF;
      END IF;
  END lp_val_mar_retencion;
  ---
   PROCEDURE lp_obt_cargos_comision IS
     -- datos calculados
   r_gmovi            ge_movimientos%ROWTYPE;
   v_tot_cargo        ge_movimientos.monto%TYPE := 0; -- monto del cargo + impuesto
   v_cod_tra_cargo    NUMBER := 597; -- transaccion por cargo
   v_cod_tas_cargo    NUMBER;
   v_val_tas_cargo    NUMBER;
   v_val_cargo        NUMBER;
   v_cod_tra_impuesto NUMBER;
   v_cod_tas_impuesto NUMBER;
   v_val_tas_impuesto NUMBER;
   v_val_impuesto     NUMBER;
  BEGIN
    IF to_number(vp_extorno) != 99 THEN
    -- busco el monto del cargo y el impuesto antes de generar el movimiento
               prj_obt_cargo(v_ofi_cta_deb, vp_cta_debito, v_cod_moneda, v_importe,
                             v_mod_cta_deb, v_mad_cta_deb, v_cod_tra_cargo,
                             -- cargo por deposito en m/e
                             v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto,
                             v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);
   
    IF pag_cta.g_cod_error <> 0 THEN
               -- actualizacion con problemas
               vp_cod_respuesta := vr_no_aprobado;
               vp_respuesta := pag_cta.g_msj_error;
            ELSE
               -- genero la transaccion en caja
               -- totalizo el cargo + impuesto
               v_tot_cargo := nvl(v_val_cargo, 0) + nvl(v_val_impuesto, 0);
               
               IF v_val_cargo > 0 THEN
                  -- existe cargo, se genera movimiento
                  v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
                  r_gmovi.cod_usuario   := USER;
                  r_gmovi.hora          := v_hora;
                  r_gmovi.fecha         := v_fec_proceso;
                  r_gmovi.nro_secuencia := v_nro_secuencia;
                  --
                  r_gmovi.cod_modulo      := v_mod_cta_deb;
                  r_gmovi.cod_modalidad   := v_mad_cta_deb;
                  r_gmovi.cod_oficina     := v_ofi_cta_deb;
                  r_gmovi.nro_cuenta      := vp_cta_debito;
                  r_gmovi.cod_moneda      := v_cod_moneda;
                  r_gmovi.fec_valor       := v_fec_proceso;
                  r_gmovi.cod_tra_padre   := v_cod_tra_cargo;
                  r_gmovi.cod_mod_padre   := v_mod_cta_deb;
                  r_gmovi.cod_mad_padre   := v_mad_cta_deb;
                  r_gmovi.cod_transaccion := v_cod_tra_cargo;
                  r_gmovi.monto           := v_val_cargo;
                  r_gmovi.nro_documento   := v_nro_documento;
                  r_gmovi.cod_ofi_origen  := v_ofi_origen;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'Cargo por Deposito en M/E Cajero';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_tasa        := v_cod_tas_cargo;
                  r_gmovi.val_tasa        := v_val_tas_cargo;
                  r_gmovi.cod_rubro       := NULL;
                  -- inserto el registro de movimientos
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
               END IF;
               IF v_val_impuesto > 0 THEN
                  --
                  v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
                  r_gmovi.cod_usuario   := USER;
                  r_gmovi.hora          := v_hora;
                  r_gmovi.fecha         := v_fec_proceso;
                  r_gmovi.nro_secuencia := v_nro_secuencia;
                  --
                  r_gmovi.cod_modulo      := v_mod_cta_deb;
                  r_gmovi.cod_modalidad   := v_mad_cta_deb;
                  r_gmovi.cod_oficina     := v_ofi_cta_deb;
                  r_gmovi.nro_cuenta      := vp_cta_debito;
                  r_gmovi.cod_moneda      := v_cod_moneda;
                  r_gmovi.fec_valor       := v_fec_proceso;
                  r_gmovi.cod_tra_padre   := 517;
                  r_gmovi.cod_mod_padre   := v_mod_cta_deb;
                  r_gmovi.cod_mad_padre   := v_mad_cta_deb;
                  r_gmovi.cod_transaccion := 517;
                  r_gmovi.monto           :=  v_val_impuesto;
                  r_gmovi.nro_documento   := v_nro_documento;--null;
                  r_gmovi.cod_ofi_origen  := v_ofi_origen;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'IVA s/Cargo por Deposito en M/E Cajero';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_tasa        := v_cod_tas_impuesto;
                  r_gmovi.val_tasa        := v_val_tas_impuesto;
                  r_gmovi.cod_rubro       := NULL;
                  -- inserto el registro de movimientos
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
                  --
               END IF;
               v_cargos := nvl(v_tot_cargo, 0);
               IF v_tot_cargo > 0  THEN
                 IF v_es_nocturno = 'S' THEN
                    pag_cta.g_horario := 'N';
                 END IF;
                  pag_cta.pr_act_sal_cta(vp_cta_debito, v_mad_cta_deb, 'D',
                                         -- DEBITO
                                         v_fec_valor, v_hora, v_tot_cargo, 0, 0, 'N', 'N');

                  v_tot_cargo := 0;
               END IF;
               
            END IF;
        ELSE
          -- busco el monto del cargo y el impuesto antes de generar el movimiento reversado
          v_importe := v_importe * -1;
               prj_obt_cargo(v_ofi_cta_deb, vp_cta_debito, v_cod_moneda, v_importe,
                             v_mod_cta_deb, v_mad_cta_deb, v_cod_tra_cargo,
                             -- cargo por deposito en m/e
                             v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto,
                             v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);
   
          IF pag_cta.g_cod_error <> 0 THEN
               -- actualizacion con problemas
               vp_cod_respuesta := vr_no_aprobado;
               vp_respuesta := pag_cta.g_msj_error;
            ELSE
              v_importe := v_importe * -1;
              v_val_impuesto := v_val_impuesto * -1;
              v_val_cargo := v_val_cargo * -1;
               -- totalizo el cargo + impuesto
               v_tot_cargo := nvl(v_val_cargo, 0) + nvl(v_val_impuesto, 0);
               
              -- Inserto el valor del cargo
                  -- existe cargo, se genera movimiento
                IF v_val_cargo != 0 then 
                  v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
                  r_gmovi.cod_usuario   := USER;
                  r_gmovi.hora          := v_hora;
                  r_gmovi.fecha         := v_fec_proceso;
                  r_gmovi.nro_secuencia := v_nro_secuencia;
                  --
                  r_gmovi.cod_modulo      := v_mod_cta_deb;
                  r_gmovi.cod_modalidad   := v_mad_cta_deb;
                  r_gmovi.cod_oficina     := v_ofi_cta_deb;
                  r_gmovi.nro_cuenta      := vp_cta_debito;
                  r_gmovi.cod_moneda      := v_cod_moneda;
                  r_gmovi.fec_valor       := v_fec_proceso;
                  r_gmovi.cod_tra_padre   := v_cod_tra_cargo;
                  r_gmovi.cod_mod_padre   := v_mod_cta_deb;
                  r_gmovi.cod_mad_padre   := v_mad_cta_deb;
                  r_gmovi.cod_transaccion := v_cod_tra_cargo;
                  r_gmovi.monto           := v_val_cargo;
                  r_gmovi.nro_documento   := v_nro_documento;
                  r_gmovi.cod_ofi_origen  := v_ofi_origen;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'Cargo por Deposito en M/E Cajero';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_tasa        := v_cod_tas_cargo;
                  r_gmovi.val_tasa        := v_val_tas_cargo;
                  r_gmovi.cod_rubro       := NULL;
                  -- inserto el registro de movimientos
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
                  --Inserto el impuesto
                  --
                  v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
                  r_gmovi.cod_usuario   := USER;
                  r_gmovi.hora          := v_hora;
                  r_gmovi.fecha         := v_fec_proceso;
                  r_gmovi.nro_secuencia := v_nro_secuencia;
                  --
                  r_gmovi.cod_modulo      := v_mod_cta_deb;
                  r_gmovi.cod_modalidad   := v_mad_cta_deb;
                  r_gmovi.cod_oficina     := v_ofi_cta_deb;
                  r_gmovi.nro_cuenta      := vp_cta_debito;
                  r_gmovi.cod_moneda      := v_cod_moneda;
                  r_gmovi.fec_valor       := v_fec_proceso;
                  r_gmovi.cod_tra_padre   := 517;
                  r_gmovi.cod_mod_padre   := v_mod_cta_deb;
                  r_gmovi.cod_mad_padre   := v_mad_cta_deb;
                  r_gmovi.cod_transaccion := 517;
                  r_gmovi.monto           := v_val_impuesto;
                  r_gmovi.nro_documento   := v_nro_documento;
                  r_gmovi.cod_ofi_origen  := v_ofi_origen;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'IVA s/Cargo por Deposito en M/E Cajero';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_tasa        := v_cod_tas_impuesto;
                  r_gmovi.val_tasa        := v_val_tas_impuesto;
                  r_gmovi.cod_rubro       := NULL;
                  -- inserto el registro de movimientos
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
                  --
                   IF v_es_nocturno = 'S' THEN
                      pag_cta.g_horario := 'N';
                   END IF;
                  pag_cta.pr_act_sal_cta(vp_cta_debito, v_mad_cta_deb, 'D',
                                         -- DEBITO
                                         v_fec_valor, v_hora, v_tot_cargo, 0, 0, 'N', 'N');

                  v_tot_cargo := 0;
               END IF;
            END IF;    
       END IF;
  END lp_obt_cargos_comision;
  PROCEDURE lp_upd_cta_debito_04 IS
  BEGIN
    IF v_ind_ctacontable = 'N' THEN
      IF v_horario = 'D' THEN
        -- Horario normal --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          begin
            UPDATE ah_cta_vistas
               SET sal_retenido       = nvl(sal_retenido, 0) + v_importe,
                   sal_total          = nvl(sal_total, 0) + v_importe,
                   fec_ult_movimiento = v_fec_proceso,
                   hor_ult_movimiento = v_hora,
                   estado             = decode(estado,
                                               'I',
                                               'N',
                                               'A',
                                               'N',
                                               estado)
             WHERE nro_cuenta = vp_cta_debito;
            if pag_cta.G_COD_ERROR = 41 then
              --no se puede procesar
              vp_cod_respuesta := vr_mto_limite;
              v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                  vp_cod_respuesta;
              raise_application_error(-20000, v_msj_error);
            end if;
          exception
            when others then
              if pag_cta.G_COD_ERROR = 41 then
                --no se puede procesar
                vp_cod_respuesta := vr_mto_limite;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                    pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              else
                --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                    pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              end if;
          end;
        ELSIF v_mad_cta_deb = 41 THEN
          UPDATE cc_cta_corrientes
             SET sal_retenido       = nvl(sal_retenido, 0) + v_importe,
                 sal_total          = nvl(sal_total, 0) + v_importe,
                 fec_ult_movimiento = v_fec_proceso,
                 hor_ult_movimiento = v_hora,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado)
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mod_cta_deb = 4 THEN
          UPDATE cc_cta_bancarias
             SET sal_retenido       = nvl(sal_retenido, 0) + v_importe,
                 sal_total          = nvl(sal_total, 0) + v_importe,
                 fec_ult_movimiento = v_fec_proceso,
                 hor_ult_movimiento = v_hora,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado)
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      ELSIF v_horario = 'T' THEN
        -- A la Tarde --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          begin
            UPDATE ah_cta_vistas
               SET sal_retenido = nvl(sal_retenido, 0) +
                                        v_importe,
                   estado             = decode(estado,
                                               'I',
                                               'N',
                                               'A',
                                               'N',
                                               estado) --15/12/2021
             WHERE nro_cuenta = vp_cta_debito;
            if pag_cta.G_COD_ERROR = 41 then
              --no se puede procesar
              vp_cod_respuesta := vr_mto_limite;
              v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                  vp_cod_respuesta;
              raise_application_error(-20000, v_msj_error);
            end if;
          exception
            when others then
              if pag_cta.G_COD_ERROR = 41 then
                --no se puede procesar
                vp_cod_respuesta := vr_mto_limite;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                    pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              else
                --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                    pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              end if;
          end;
        ELSIF v_mad_cta_deb = 41 THEN
          UPDATE cc_cta_corrientes
             SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mod_cta_deb = 4 THEN
          UPDATE cc_cta_bancarias
             SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      ELSE
        -- A la Noche o despues del cierre --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          UPDATE ah_cta_vistas_noc
             SET mto_cre_a_confirmar = nvl(mto_cre_a_confirmar, 0) + v_importe,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mad_cta_deb = 41 THEN
          UPDATE cc_cta_corrientes_noc
             SET mto_cre_a_confirmar = nvl(mto_cre_a_confirmar, 0) + v_importe,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mod_cta_deb = 4 THEN
          UPDATE cc_cta_bancarias
             SET  sal_retenido = nvl(sal_retenido, 0) + v_importe,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      END IF;
    END IF;
  END lp_upd_cta_debito_04;
  --
  PROCEDURE lp_upd_cta_credito_04 IS
  BEGIN
    IF v_horario = 'D' THEN
      -- Horario normal --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas
           SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes
           SET sal_retenido = nvl(sal_retenido, 0) - v_importe,
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias
           SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
               sal_total          = nvl(sal_total, 0) + v_importe,
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    ELSIF v_horario = 'T' THEN
      -- A la Tarde --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas
           SET sal_retenido = nvl(sal_retenido, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes
           SET sal_retenido = nvl(sal_retenido, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias
           SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
               sal_total          = nvl(sal_total, 0) + v_importe
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    ELSE
      -- A la Noche o despues del Cierre --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas_noc
           SET sal_retenido = nvl(sal_retenido, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes_noc
           SET sal_retenido = nvl(sal_retenido, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias_noc 
           SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
               sal_total          = nvl(sal_total, 0) + v_importe
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    END IF;
  END lp_upd_cta_credito_04;
  PROCEDURE lp_upd_cta_debito_03 IS
  BEGIN
    IF v_ind_ctacontable = 'N' THEN
      IF v_horario = 'D' THEN
        -- Horario normal --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          begin
            UPDATE ah_cta_vistas
               SET sal_total          = nvl(sal_total, 0) + v_importe,
                   fec_ult_movimiento = v_fec_proceso,
                   hor_ult_movimiento = v_hora,
                   estado             = decode(estado,
                                               'I',
                                               'N',
                                               'A',
                                               'N',
                                               estado)
             WHERE nro_cuenta = vp_cta_debito;
            if pag_cta.G_COD_ERROR = 41 then
              --no se puede procesar
              vp_cod_respuesta := vr_mto_limite;
              v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                  vp_cod_respuesta;
              raise_application_error(-20000, v_msj_error);
            end if;
          exception
            when others then
              if pag_cta.G_COD_ERROR = 41 then
                --no se puede procesar
                vp_cod_respuesta := vr_mto_limite;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                    pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              else
                --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                    pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              end if;
          end;
        ELSIF v_mad_cta_deb = 41 THEN
          UPDATE cc_cta_corrientes
             SET sal_total          = nvl(sal_total, 0) + v_importe,
                 fec_ult_movimiento = v_fec_proceso,
                 hor_ult_movimiento = v_hora,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado)
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mod_cta_deb = 4 THEN
          UPDATE cc_cta_bancarias
             SET sal_total          = nvl(sal_total, 0) + v_importe,
                 fec_ult_movimiento = v_fec_proceso,
                 hor_ult_movimiento = v_hora,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado)
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      ELSIF v_horario = 'T' THEN
        -- A la Tarde --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          begin
             UPDATE ah_cta_vistas
               SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) +
                                        v_importe,
                   estado             = decode(estado,
                                               'I',
                                               'N',
                                               'A',
                                               'N',
                                               estado) --15/12/2021
             WHERE nro_cuenta = vp_cta_debito;
            if pag_cta.G_COD_ERROR = 41 then
              --no se puede procesar
              vp_cod_respuesta := vr_mto_limite;
              v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                  vp_cod_respuesta;
              raise_application_error(-20000, v_msj_error);
            end if;
          exception
            when others then
              if pag_cta.G_COD_ERROR = 41 then
                --no se puede procesar
                vp_cod_respuesta := vr_mto_limite;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                    pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              else
                --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                                    pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              end if;
          end;
        ELSIF v_mad_cta_deb = 41 THEN
           UPDATE cc_cta_corrientes
             SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mod_cta_deb = 4 THEN
           UPDATE cc_cta_bancarias
             SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      ELSE
        -- A la Noche o despues del cierre --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
           UPDATE ah_cta_vistas_noc
               SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) +
                                        v_importe,
                   estado             = decode(estado,
                                               'I',
                                               'N',
                                               'A',
                                               'N',
                                               estado) --15/12/2021
             WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mad_cta_deb = 41 THEN
            UPDATE cc_cta_corrientes_noc
             SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mod_cta_deb = 4 THEN
            UPDATE cc_cta_bancarias_noc
             SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe,
                 estado             = decode(estado,
                                             'I',
                                             'N',
                                             'A',
                                             'N',
                                             estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      END IF;
    END IF;
  END lp_upd_cta_debito_03;
  --
  PROCEDURE lp_upd_cta_credito_03 IS
  BEGIN
    IF v_horario = 'D' THEN
      -- Horario normal --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas
           SET sal_total = nvl(sal_total, 0) - v_importe,
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes
           SET sal_total = nvl(sal_total, 0) - v_importe,
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias
           SET sal_total = nvl(sal_total, 0) - v_importe,
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    ELSIF v_horario = 'T' THEN
      -- A la Tarde --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    ELSE
      -- A la Noche o despues del Cierre --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas_noc
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes_noc
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias_noc
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    END IF;
  END lp_upd_cta_credito_03;
  PROCEDURE lp_upd_cta_debito IS
  BEGIN
    IF v_ind_ctacontable = 'N' THEN
      IF v_horario = 'D' THEN
        -- Horario normal --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          UPDATE ah_cta_vistas
             SET sal_total          = nvl(sal_total, 0) - v_importe,
                 fec_ult_movimiento = v_fec_proceso,
                 hor_ult_movimiento = v_hora,
                 estado             = decode(estado, 'I', 'N', estado)
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mad_cta_deb = 41 THEN
          UPDATE cc_cta_corrientes
             SET sal_total          = nvl(sal_total, 0) - v_importe,
                 fec_ult_movimiento = v_fec_proceso,
                 hor_ult_movimiento = v_hora,
                 estado             = decode(estado, 'I', 'N', estado)
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mod_cta_deb = 4 THEN
          UPDATE cc_cta_bancarias
             SET sal_total          = nvl(sal_total, 0) - v_importe,
                 fec_ult_movimiento = v_fec_proceso,
                 hor_ult_movimiento = v_hora,
                 estado             = decode(estado, 'I', 'N', estado)
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      ELSIF v_horario = 'T' THEN
        -- A la Tarde --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          UPDATE ah_cta_vistas
             SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + v_importe
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mad_cta_deb = 41 THEN
          UPDATE cc_cta_corrientes
             SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + v_importe
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mod_cta_deb = 4 THEN
          UPDATE cc_cta_bancarias
             SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + v_importe
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      ELSE
        -- A la Noche o despues del cierre --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          UPDATE ah_cta_vistas_noc
             SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + v_importe
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mad_cta_deb = 41 THEN
          UPDATE cc_cta_corrientes_noc
             SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + v_importe
           WHERE nro_cuenta = vp_cta_debito;
        ELSIF v_mod_cta_deb = 4 THEN
          UPDATE cc_cta_bancarias_noc
             SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + v_importe
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      END IF;
    END IF;
  END lp_upd_cta_debito;
  --
  PROCEDURE lp_upd_cta_credito IS
  BEGIN
    IF v_horario = 'D' THEN
      -- Horario normal --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas
           SET sal_total = nvl(sal_total, 0) + v_importe,
               estado    = decode(estado, 'I', 'N', 'A', 'N',estado)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes
           SET sal_total = nvl(sal_total, 0) + v_importe,
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias
           SET sal_total = nvl(sal_total, 0) - v_importe,
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    ELSIF v_horario = 'T' THEN
      -- A la Tarde --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    ELSE
      -- A la Noche o despues del Cierre --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas_noc
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes_noc
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + v_importe
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias_noc
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) - v_importe
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    END IF;
  END lp_upd_cta_credito;
  --
   /*Actualización de saldo Dep Efectivo con retención*/
  PROCEDURE lp_upd_cta_reten IS
  BEGIN
    IF v_ind_ctacontable = 'N' THEN
      IF v_horario = 'D' THEN
        -- Horario normal --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          begin
            UPDATE ah_cta_vistas
               SET sal_retenido       = nvl(sal_retenido, 0) + v_importe,
                   sal_total          = nvl(sal_total, 0) + v_importe,
                   fec_ult_movimiento = v_fec_proceso,
                   hor_ult_movimiento = v_hora,
                   estado             = decode(estado,'I','N','A','N',estado)
             WHERE nro_cuenta = vp_cta_debito;
            IF SQL%NOTFOUND THEN
               --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                vp_respuesta     := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
            END IF;
            if pag_cta.G_COD_ERROR = 41 then
              --no se puede procesar
              vp_cod_respuesta := vr_mto_limite;
              v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||vp_cod_respuesta;
              raise_application_error(-20000, v_msj_error);
            end if;
          exception
            when others then
              if pag_cta.G_COD_ERROR = 41 then
                --no se puede procesar
                vp_cod_respuesta := vr_mto_limite;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              else
                --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              end if;

          end;
        ELSIF v_mad_cta_deb = 41 THEN
          UPDATE cc_cta_corrientes
             SET sal_retenido       = nvl(sal_retenido, 0) + v_importe,
                 sal_total          = nvl(sal_total, 0) + v_importe,
                 fec_ult_movimiento = v_fec_proceso,
                 hor_ult_movimiento = v_hora,
                 estado             = decode(estado,'I','N','A','N',estado)
           WHERE nro_cuenta = vp_cta_debito;
           IF SQL%NOTFOUND THEN
               --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                vp_respuesta     := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
           END IF;
        ELSIF v_mod_cta_deb = 4 THEN
          UPDATE cc_cta_bancarias
             SET sal_retenido       = nvl(sal_retenido, 0) + v_importe,
                 sal_total          = nvl(sal_total, 0) + v_importe,
                 fec_ult_movimiento = v_fec_proceso,
                 hor_ult_movimiento = v_hora,
                 estado             = decode(estado,'I','N','A','N',estado)
           WHERE nro_cuenta = vp_cta_debito;
           IF SQL%NOTFOUND THEN
               --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                vp_respuesta     := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
           END IF;
        END IF;

      ELSIF v_horario = 'T' THEN
        -- A la Tarde --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
          begin
             UPDATE ah_cta_vistas
               SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
                    sal_total          = nvl(sal_total, 0) + v_importe,
                   estado             = decode(estado,'I','N','A','N',estado) --15/12/2021
             WHERE nro_cuenta = vp_cta_debito;
             IF SQL%NOTFOUND THEN
               --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                vp_respuesta     := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
             END IF;
             if pag_cta.G_COD_ERROR = 41 then
              --no se puede procesar
              vp_cod_respuesta := vr_mto_limite;
              v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||vp_cod_respuesta;
              raise_application_error(-20000, v_msj_error);
             end if;
          exception
            when others then
              if pag_cta.G_COD_ERROR = 41 then
                --no se puede procesar
                vp_cod_respuesta := vr_mto_limite;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              else
                --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
              end if;
          end;
        ELSIF v_mad_cta_deb = 41 THEN
           UPDATE cc_cta_corrientes
             SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
                 sal_total          = nvl(sal_total, 0) + v_importe,
                 estado             = decode(estado,'I','N','A','N',estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
           IF SQL%NOTFOUND THEN
               --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                vp_respuesta     := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
           END IF;
        ELSIF v_mod_cta_deb = 4 THEN
           UPDATE cc_cta_bancarias
             SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
                 sal_total          = nvl(sal_total, 0) + v_importe,
                 estado       = decode(estado,'I','N','A','N',estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
           IF SQL%NOTFOUND THEN
               --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                vp_respuesta     := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
           END IF;
        END IF;
      ELSE
        -- A la Noche o despues del cierre --
        IF v_mad_cta_deb in (31, 38, 39, 334) THEN
           UPDATE ah_cta_vistas_noc
               SET mto_cre_a_confirmar = nvl(mto_cre_a_confirmar, 0) + v_importe,
                   estado = decode(estado,'I','N','A','N',estado) --15/12/2021
             WHERE nro_cuenta = vp_cta_debito;
           IF SQL%NOTFOUND THEN
               --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                vp_respuesta     := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
           END IF;
        ELSIF v_mad_cta_deb = 41 THEN
            UPDATE cc_cta_corrientes_noc
             SET mto_cre_a_confirmar = nvl(mto_cre_a_confirmar, 0) + v_importe,
                 estado             = decode(estado,'I','N','A','N',estado) --15/12/2021
            WHERE nro_cuenta = vp_cta_debito;
           IF SQL%NOTFOUND THEN
               --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                vp_respuesta     := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
           END IF;
        ELSIF v_mod_cta_deb = 4 THEN
            UPDATE cc_cta_bancarias
             SET sal_retenido = nvl(sal_retenido, 0) + v_importe,
                 estado             = decode(estado,'I','N','A','N',estado) --15/12/2021
           WHERE nro_cuenta = vp_cta_debito;
           IF SQL%NOTFOUND THEN
               --no se puede procesar
                vp_cod_respuesta := vr_no_aprobado;
                vp_respuesta     := pag_cta.G_MSJ_ERROR || ' ' ||pag_cta.G_COD_ERROR;
                raise_application_error(-20000, v_msj_error);
           END IF;
        END IF;
      END IF;
    END IF;
  END lp_upd_cta_reten;
  --
     /* Genera el movimiento de novedad de la cuenta */
   PROCEDURE pr_gen_nov_cuenta
   (
      p_fecha         IN DATE,
      p_hora          IN VARCHAR2,
      p_cod_modulo    IN VARCHAR2,
      p_cod_modalidad IN VARCHAR2,
      p_est_cta_ant   IN VARCHAR2,
      p_cod_usuario   IN VARCHAR2,
      p_cta_debito    IN VARCHAR2
   ) IS
      v_est_anterior    VARCHAR2(01) := NULL;
      v_est_actual      VARCHAR2(01) := NULL;
      v_fec_cam_est_ant DATE := NULL;
      v_fec_ult_mov_ant DATE := NULL;
      v_hor_ult_mov_ant VARCHAR2(8) := NULL;
      v_nro_cta         VARCHAR2(20) := NULL;
      v_insertar        VARCHAR2(1) := 'N';
   BEGIN
      v_nro_cta      := p_cta_debito;
      Begin
         select v.estado
           into v_est_actual
           from ah_cta_vistas v
          where v.nro_cuenta = p_cta_debito; 
        exception 
           when no_data_found then
            v_est_actual :=  p_est_cta_ant;
           when others then     
            v_est_actual :=  p_est_cta_ant; 
      End;  
      v_est_anterior := p_est_cta_ant;
      IF (nvl(v_est_actual, 'A') <> v_est_anterior) THEN
         -- cambiara de estado
         v_fec_cam_est_ant := g_ctas.fec_cam_estado;
         v_insertar        := 'S';
      ELSE 
         v_est_anterior    := pag_cta.fu_obt_est_cuenta;
         v_est_actual      := pag_cta.fu_obt_est_cuenta;  
         v_insertar        := 'N'; 
      END IF;
      IF nvl(g_ctas.act_ult_movimiento, 'N') = 'S' THEN
         -- cambio de fecha ultimo movimiento
         v_fec_ult_mov_ant := p_fecha;
         v_hor_ult_mov_ant := p_hora;
         v_insertar        := 'S';
      END IF;
      IF v_insertar = 'S' THEN
         -- Actualizo el registro si ya existe
         UPDATE ge_cuentas_nov
            SET est_anterior    = nvl(v_est_anterior, est_anterior),
                est_actual      = nvl(v_est_actual, est_actual),
                fec_cam_est_ant = nvl(v_fec_cam_est_ant, fec_cam_est_ant),
                fec_ult_mov_ant = nvl(v_fec_ult_mov_ant, fec_ult_mov_ant),
                hor_ult_mov_ant = nvl(v_hor_ult_mov_ant, hor_ult_mov_ant)
          WHERE cod_usuario = p_cod_usuario
            AND fecha = p_fecha
            AND hora  = p_hora
            AND nro_cuenta = v_nro_cta;
         IF SQL%NOTFOUND THEN
            INSERT INTO ge_cuentas_nov
               (fecha, hora, cod_usuario, nro_cuenta, nro_detalle, cod_modulo, cod_modalidad,
                est_anterior, est_actual, fec_cam_est_ant, fec_ult_mov_ant, hor_ult_mov_ant,
                fec_ult_cap_ant)
            VALUES
               (p_fecha, p_hora, p_cod_usuario, v_nro_cta, NULL, p_cod_modulo,
                p_cod_modalidad, v_est_anterior, v_est_actual, v_fec_cam_est_ant,
                v_fec_ult_mov_ant, v_hor_ult_mov_ant, null);

         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'PR_GEN_NOV_CUENTA ' || SQLERRM);
   END;
----   
  PROCEDURE lp_upd_caja IS
    v_existe     VARCHAR2(1) := 'N';
    v_nro_cuenta cj_movimientos.nro_cuenta%TYPE := NULL;
  BEGIN
    v_tipo := 'E';
    -------------
    IF v_clt_deb_nuestro = 'S' THEN
      v_nro_cuenta := vp_cta_debito;
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
        (fecha,
         hora,
         cod_usuario,
         nro_secuencia,
         cod_tra_padre,
         cod_mod_padre,
         cod_mad_padre,
         cod_oficina,
         cod_moneda,
         nro_caja,
         nro_documento,
         nro_cuenta,
         monto,
         tip_monto,
         tipo)
      VALUES
        (v_fec_proceso,
         v_hora,
         v_cod_usuario,
         1,
         v_cod_tra_padre,
         v_cod_modulo,
         v_cod_modalidad,
         v_ofi_origen,
         v_cod_moneda,
         v_nro_caja,
         v_nro_documento,
         v_nro_cuenta,
         v_importe,
         v_tip_monto,--'O' /* efectivo */,  FSOP-28642
         'D'); /* es debito */
    ELSE
      INSERT INTO cj_movimientos_noc
        (fecha,
         hora,
         cod_usuario,
         nro_secuencia,
         cod_tra_padre,
         cod_mod_padre,
         cod_mad_padre,
         cod_oficina,
         cod_moneda,
         nro_caja,
         nro_documento,
         nro_cuenta,
         monto,
         tip_monto,
         tipo)
      VALUES
        (v_fec_proceso,
         v_hora,
         v_cod_usuario,
         1,
         v_cod_tra_padre,
         v_cod_modulo,
         v_cod_modalidad,
         v_ofi_origen,
         v_cod_moneda,
         v_nro_caja,
         v_nro_documento,
         v_nro_cuenta,
         v_importe,
         v_tip_monto,--o /* efectivo */,  FSOP-28642
         'D');--; /* es debito */
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
         SET tot_che_otr_bco = nvl(tot_che_otr_bco, 0)+nvl(v_importe, 0) ,
             SAL_CHE_OTR_BCO = nvl(SAL_CHE_OTR_BCO, 0)+nvl(v_importe, 0),
             estado       = 1 -- abierto
       WHERE nro_caja = v_nro_caja
         AND cod_moneda = v_cod_moneda
         AND fecha = v_fec_proceso;
    EXCEPTION
      WHEN no_data_found THEN
        -- Si no existe debe insertar el control...
        INSERT INTO cj_controles
          (nro_caja,
           cod_moneda,
           fecha,
           mto_apertura,
           sal_actual,
           mto_cierre,
           tot_debitos,
           tot_creditos,
           tot_che_nue_bco,
           tot_che_otr_bco,
           det_che_nue_bco,
           det_che_otr_bco,
           INI_CHE_OTR_BCO,
           SAL_CHE_OTR_BCO,
           can_debitos,
           can_creditos,
           estado,
           cod_usu_actual)
        VALUES
          (v_nro_caja,
           v_cod_moneda,
           v_fec_proceso,
           0,
           0,--v_importe,
           0,
           0,
           0,--v_importe,
           0,--0,
           v_importe,--0,
           0,--0,
           0,--0,
           0,--0,
           v_importe,--0,
           0,
           1,
           1,
           USER);
          when others then 
            raise_application_error(-20000, 'lp_upd_caj' || SQLERRM);
            
    END;
  END lp_upd_caja;

  PROCEDURE lp_car_salida IS
  BEGIN
    vp_respuesta := vp_cod_respuesta || vp_sal_disponible ||
                    vp_sig_disponible || vp_sal_contable || vp_sig_contable ||
                    vp_transaccion || vp_tra_entidad || vp_can_extractos;
  END lp_car_salida;

  PROCEDURE lp_obt_respuesta IS
  BEGIN
    v_doceli := FUG_OBT_MENSAJE(FUG_OBT_PARDINAMICO('ATM_TEX_IMP_TICKET'));
    v_scrdta := FUG_OBT_MENSAJE(FUG_OBT_PARDINAMICO('ATM_TEX_IMP_PANTALLA'));
  
    if v_doceli is null or trim(v_doceli) = '' then
      for i in 1 .. 480 loop
        v_doceli := v_doceli || ' ';
      end loop;
    else
      -- Agregado el 12/10/2021 
      v_doceli := rpad(v_doceli, 480, ' ');
    end if;
    if v_scrdta is null or trim(v_scrdta) = '' then
      for j in 1 .. 322 loop
        v_scrdta := v_scrdta || ' ';
      end loop;
    else
      -- Agregado el 12/10/2021
      v_scrdta := rpad(v_scrdta, 322, ' ');
    end if;
  
    --se deben devolver los textos sin acentos
    if v_car_mas_iva != 0 then
      v_bncmsg := 'Por la operacion solicitada pagara un gasto de ' ||
                  TO_CHAR(v_car_mas_iva, '999G999G999D99') || ' ' ||
                  v_mon_cta_deb || '.';
    else
      v_bncmsg := ' ';
    end if;
    v_lon       := length(v_bncmsg);
    v_lon_total := 408;
    for k in v_lon + 1 .. 408 loop
      v_bncmsg := v_bncmsg || ' ';
    end loop;
  
    vp_respuesta := vp_respuesta || v_doceli || v_scrdta || v_bncmsg;
  
    IF vp_can_extractos != '000' THEN
      vp_respuesta := vp_respuesta ||
                      rpad(nvl(vp_extractos, ' '), 512, ' ');
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
    INSERT INTO it.CJ_LOG_ATM_CAJ
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
	
  function lf_obt_cta_portavalor(p_nro_caja   cj_movimientos.nro_caja%type,
                                        p_cod_moneda ba_monedas.cod_moneda%type)
    return varchar2 is
    p_cta_portavalor varchar2(10) := 0;
    v_parametro      ge_parametros.parametro%type;
	v_moneda         VARCHAR2(5);
  begin
    if p_cod_moneda = '00' then
      v_parametro := 'NRO_CTA_GS';
	  v_moneda    := 'GS';
    else
      v_parametro := 'NRO_CTA_US';
	  v_moneda    := 'USD';
    end if;

    select gp.val_parametro as nro_cta
      into p_cta_portavalor
      from (ba_cod_referencias bc join ge_entes ge on bc.val_minimo = ge.tipo)
      join ge_par_entes gp
        on gp.cod_ente = ge.cod_ente
      join cc_cta_cajeros cc
        on cc.cod_ent_portavalor = gp.cod_ente
     where bc.dominio = 'TIP_ENTE'
       and bc.val_minimo = 'CD'
       and bc.activo = 'S'
       and cc.nro_caj_externo = p_nro_caja
       and gp.parametro = v_parametro
       and cc.cod_moneda = v_moneda;
    return p_cta_portavalor;
  exception
    when no_data_found then
      return p_cta_portavalor;
  end;
  
  PROCEDURE lp_car_parametros IS
    v_indice      NUMBER(3) := 1;
    v_cod_oficina ba_oficinas.cod_oficina%type;
  
  BEGIN
    if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_DEB_COMPUESTA'), 'N') = 'S' then
      v_cod_oficina := to_char(to_number(substr(v_pedido, 1, 2)));
      vp_cta_debito := to_char(to_number(substr(v_pedido, 3, 8)));
      if v_cod_oficina <> '0' then
        vp_cta_debito := v_cod_oficina || vp_cta_debito;
      end if;
    elsif nvl(fug_obt_pardinamico('CAJ_ATM_CTA_ALFANUMERICO'), 'N') = 'S' then
      vp_cta_debito := to_char(substr(v_pedido, 1, 10));
    else
      vp_cta_debito := to_char(to_number(substr(v_pedido, 1, 10)));
    end if;
  
    v_indice      := v_indice + 10;
    vp_bco_debito := substr(v_pedido, v_indice, 3);
    v_indice      := v_indice + 3;
  
    if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_DEB_COMPUESTA'), 'N') = 'S' then
      v_cod_oficina := to_char(to_number(substr(v_pedido, v_indice, 2)));
    
      vp_cta_credito := to_char(to_number(substr(v_pedido, v_indice + 2, 8)));
    
      if v_cod_oficina <> '0' then
        vp_cta_credito := v_cod_oficina || vp_cta_credito;
      end if;
    
    else
      vp_cta_credito := to_char(to_number(substr(v_pedido, v_indice, 10)));
    end if;

    v_indice       := v_indice + 10;
    vp_bco_credito := substr(v_pedido, v_indice, 3);
    v_indice       := v_indice + 3;
    vp_operacion   := substr(v_pedido, v_indice, 2);
    v_indice       := v_indice + 2;
    vp_extorno     := substr(v_pedido, v_indice, 2);
    v_indice       := v_indice + 2;
    vp_tra_entidad := substr(v_pedido, v_indice, 15);
    v_indice       := v_indice + 15;
    vp_transaccion := substr(v_pedido, v_indice, 15);
    v_indice       := v_indice + 15;
    vp_importe     := substr(v_pedido, v_indice, 15);
    v_indice       := v_indice + 15;
    vp_importe2    := substr(v_pedido, v_indice, 15);
    v_indice       := v_indice + 15;
    vp_importe3    := substr(v_pedido, v_indice, 15);
    v_indice       := v_indice + 15;
    vp_can_cheques := substr(v_pedido, v_indice, 4);
    v_indice       := v_indice + 4;
    vp_moneda      := substr(v_pedido, v_indice, 2);
    v_indice       := v_indice + 2;
    vp_nro_atm     := substr(v_pedido, v_indice, 6);
    v_indice       := v_indice + 6;
    vp_nro_pos     := substr(v_pedido, v_indice, 2);
    v_indice       := v_indice + 2;
    vp_tra_pos     := substr(v_pedido, v_indice, 4);
    v_indice       := v_indice + 4;
    vp_tip_hora    := substr(v_pedido, v_indice, 3);
    v_indice       := v_indice + 3;
  
    if nvl(fug_obt_pardinamico('CAJ_ATM_VAL_MES_NAC'), 'N') = 'S' then
      vp_negocio     := substr(v_pedido, v_indice, 40);
      vp_car_inicial := substr(v_pedido, v_indice, 1); --varia caracter recibido en esta posicion
      v_indice       := v_indice + 40;
    
      vp_val_mes_nac := 'N';
      if substr(vp_negocio, 1, 4) = '#MC#' then
        vp_val_mes_nac := 'S';
      end if;
    
      vp_mes_nacimiento := substr(vp_negocio, 5, 11);
      vp_relacion       := substr(vp_negocio, 17, 2);
    else
      vp_negocio := substr(v_pedido, v_indice, 40);
      v_indice   := v_indice + 40;
    end if;
  
    vp_tra_extornado := substr(v_pedido, v_indice, 15);
    v_indice         := v_indice + 15;
    vp_bco_atm       := substr(v_pedido, v_indice, 3);
    v_indice         := v_indice + 3;
    vp_fecha         := substr(v_pedido, v_indice, 8);
    v_indice         := v_indice + 8;
    vp_hora          := substr(v_pedido, v_indice, 6);
    v_indice         := v_indice + 6;
  
    v_indice      := v_indice + 35;
    vp_servicio := (case
                     when trim(substr(v_pedido, v_indice, 3)) is null then
                      'ATM'
                     else
                      substr(v_pedido, v_indice, 3)
                   end);
    v_indice      := v_indice + 3;
    vp_prestacion := substr(v_pedido, v_indice, 4);
    v_indice      := v_indice + 4;
    vp_marca      := substr(v_pedido, v_indice, 3);
    v_indice      := v_indice + 3;
    vp_producto   := substr(v_pedido, v_indice, 3);
    v_indice      := v_indice + 3;
    vp_med_pago   := substr(v_pedido, v_indice, 2);
    v_indice      := v_indice + 2;
	
	-- Para transacciones de carga / descarga
	if vp_operacion in (67, 68) then
	   vp_cta_debito := lf_obt_cta_portavalor(to_number(vp_nro_atm),vp_moneda);
	end if ;
	
  END lp_car_parametros;
  PROCEDURE lp_dat_cta(p_nro_cuenta    IN OUT VARCHAR2,
                       p_cod_modulo    OUT NUMBER,
                       p_cod_modalidad OUT NUMBER,
                       p_cod_oficina   OUT NUMBER,
                       p_cod_moneda    OUT VARCHAR2) IS
  
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
              --la cuenta tiene 0 inicial si la oficina está entre el 1 y 9
              p_nro_cuenta := concat('0', p_nro_cuenta);
              SELECT cod_modulo, cod_modalidad, cod_oficina
                INTO p_cod_modulo, p_cod_modalidad, p_cod_oficina
                FROM ge_cuentas
               WHERE nro_cuenta = p_nro_cuenta;
              --asigna al parámetro la cuenta con el 0 delante
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
      v_msj_error      := 'Cuenta Inexistente(' || p_nro_cuenta || ')';
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
    v_ret                ge_movimientos.concepto%type;
    v_descripcion        cj_cajas.descripcion%type;
    v_cod_ent_financiera ge_par_entes.cod_ente%type;
  
  BEGIN
    IF to_number(vp_bco_atm) = v_cod_entidad THEN
      -- Si es banco debe verificar la cuenta corriente
      BEGIN
        SELECT b.descripcion
          INTO v_descripcion
          FROM cc_cta_cajeros a, cj_cajas b
         WHERE a.nro_caja = b.nro_caja
           and nro_caj_externo = v_nro_caja
           AND cod_moneda = v_cod_moneda;
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    END IF;
  
    IF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0) THEN
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
         WHERE (cod_banco = vp_bco_atm --Banco
               OR cod_ente = v_cod_ent_financiera) --Entidad Financiera
           AND cod_modalidad = 46 -- Modalidad de ATM'S.
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
    ELSIF to_number(vp_operacion) = 3 THEN
      v_ret := 'ATM-DEP.EFECTIVO';
    ELSIF to_number(vp_operacion) = 6 THEN
      v_ret := 'SOLICIT.EXTRACTOS';
    END IF;
    return v_ret || ' ' || v_descripcion;
  END;

  PROCEDURE lp_car_val_inicial IS
    v_cod_ent_financiera ge_par_entes.cod_ente%TYPE;
    v_mes                varchar2(3);
  
  BEGIN
    -- Verifica si la entidad es un banco o una financiera
    v_es_banco := lf_es_banco;
    -- Obtiene que entidad le corresponde para poder procesar --
    v_cod_entidad    := to_number(fug_obt_pardinamico('COD_ENT_INFONET',
                                                      NULL,
                                                      NULL,
                                                      NULL,
                                                      NULL));
    vp_cod_respuesta := vr_aprobado;
  
    v_concepto := substr(TRIM(vp_negocio), 1, 35);
  
    v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
    -- Verifica el horario.
    lp_ver_horario;
  
    BEGIN
      -- Obtiene la oficina de Casa Matriz.
      SELECT cod_ofi_matriz INTO v_ofi_origen FROM ge_par_generales;
    END;
    IF fug_obt_tip_implementacion not IN (1, 7) THEN
      IF to_number(vp_bco_credito) = v_cod_entidad THEN
        vp_cta_credito := TRIM(to_char(to_number(substr(vp_cta_credito, -7))));
      
      END IF;
      IF to_number(vp_bco_debito) = v_cod_entidad THEN
        vp_cta_debito := TRIM(to_char(to_number(substr(vp_cta_debito, -7))));
      
      END IF;
    END IF;
    v_nro_caja := NULL;
    -------- Verifica la moneda de la tarjeta...-------
    IF vp_moneda = '01' THEN
      v_cod_moneda := pag_gen.fu_obt_mon_fuerte;
    ELSE
      v_cod_moneda := pag_gen.fu_obt_mon_local;
    END IF;
    --
    v_hora := substr(vp_hora, 1, 2) || ':' || substr(vp_hora, 3, 2) || ':' ||
              substr(vp_hora, 5, 2);
    ---------------------------------------------------
    -- Al Cargar los importes
    IF nvl(v_ind_cob_comision, 'N') = 'S' THEN
      -- Dividir entre 100 el importe porque envian con 2 decimales...
      v_importe := (to_number(vp_importe) + to_number(vp_importe2) +
                   to_number(vp_importe3)) / 100;
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
    IF to_number(vp_bco_credito) = v_cod_entidad THEN
      v_clt_cre_nuestro := 'S';
    END IF;
    IF vp_bco_atm = '000' OR vp_bco_credito <> '000' THEN
      --es pos
      vp_bco_atm := vp_bco_credito;
    END IF;
    -- Verifica si el ATM es de la Entidad --
    IF to_number(vp_bco_atm) = v_cod_entidad THEN
      v_atm_nuestro := 'S';
      v_nro_caja    := to_number(vp_nro_atm);
    END IF;
    -- Si es banco...
    IF v_es_banco = 'S' THEN
      IF to_number(vp_operacion) NOT IN (40, 41, 51, 52, 54, 58) THEN
        IF to_number(vp_bco_atm) = v_cod_entidad THEN
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
              vp_bco_credito := vp_bco_atm;
              IF vp_cta_credito = '0' AND
                 to_number(vp_bco_credito) = v_cod_entidad THEN
                vp_cod_respuesta := vr_cta_inexistente;
                v_msj_error      := 'Cuenta Cajero Inexistente';
              END IF;
          END;
        END IF;
        -- verifica
        IF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0) THEN
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
             WHERE (cod_banco = vp_bco_atm --Banco
                   OR cod_ente = v_cod_ent_financiera) --Entidad Financiera
               AND cod_modalidad = 46 -- Modalidad de ATM'S.
               AND cod_moneda = v_cod_moneda;
            vp_bco_credito := vp_bco_atm;
          EXCEPTION
            WHEN no_data_found THEN
              NULL;
          END;
        ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad) AND
              to_number(vp_operacion) IN (3, 7, 31, 32) THEN
          -- Se considera mensaje al banco.
          vp_operacion := 93;
        END IF;
      ELSIF to_number(vp_operacion) IN (40) THEN
        IF vp_bco_credito = v_cod_entidad THEN
          v_clt_cre_nuestro := 'S';
        ELSE
          v_clt_cre_nuestro := 'N';
        END IF;
        IF vp_bco_debito = v_cod_entidad THEN
          v_clt_deb_nuestro := 'S';
        ELSE
          v_clt_deb_nuestro := 'N';
        END IF;
        IF to_number(vp_bco_atm) IN (v_cod_entidad) AND
           v_clt_deb_nuestro = 'N' AND v_clt_cre_nuestro = 'N' THEN
          -- El ATM es nuestro pero ninguno de los clientes es nuestro.
          -- por lo tanto se considera como un mensaje.
          vp_operacion := 93;
        ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0) AND
              v_clt_deb_nuestro = 'N' THEN
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
             WHERE (cod_banco = vp_bco_atm --Banco
                   OR cod_ente = v_cod_ent_financiera) --Entidad Financiera
               AND cod_modalidad = 46
               AND cod_moneda = v_cod_moneda;
          EXCEPTION
            WHEN no_data_found THEN
              vp_cod_respuesta := vr_cta_inexistente;
              v_msj_error      := 'Cuenta Bancaria Inexistente';
          END;
        
          --Obtiene la Cta de Crédito para transferencia a Otras Entidades Financieras 10-12-2014
        ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0) AND
              v_clt_cre_nuestro = 'N' THEN
          --
          BEGIN
            SELECT nro_cuenta, cod_oficina
              INTO vp_cta_credito, v_ofi_origen
              FROM cc_cta_bancarias
             WHERE cod_banco = to_number(vp_bco_credito)
               AND cod_modalidad = 46 -- Cuenta bancaria de credito
               AND cod_moneda = v_cod_moneda;
          EXCEPTION
            WHEN no_data_found THEN
              vp_cod_respuesta := vr_cta_inexistente;
              v_msj_error      := 'Cuenta Bancaria Inexistente';
          END;
        END IF;
      ELSIF to_number(vp_operacion) IN (41) THEN
        IF vp_bco_credito = v_cod_entidad THEN
          v_clt_cre_nuestro := 'S';
        ELSE
          v_clt_cre_nuestro := 'N';
        END IF;
        IF vp_bco_debito = v_cod_entidad THEN
          v_clt_deb_nuestro := 'S';
        ELSE
          v_clt_deb_nuestro := 'N';
        END IF;
        IF to_number(vp_bco_atm) IN (v_cod_entidad) AND
           v_clt_deb_nuestro = 'N' AND v_clt_cre_nuestro = 'N' THEN
          -- El ATM es nuestro pero ninguno de los clientes es nuestro.
          -- por lo tanto se considera como un mensaje.
          vp_operacion := 93;
        ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0) AND
              v_clt_deb_nuestro = 'N' THEN
          --es nuestro crédito
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
             WHERE (cod_banco = vp_bco_atm --Banco
                   OR cod_ente = v_cod_ent_financiera) --Entidad Financiera
               AND cod_modalidad = 46
               AND cod_moneda = v_cod_moneda;
          EXCEPTION
            WHEN no_data_found THEN
              vp_cod_respuesta := vr_cta_inexistente;
              v_msj_error      := 'Cuenta Bancaria Inexistente';
          END;
        
          --Obtiene la Cta de Crédito para transferencia a Otras Entidades Financieras 10-12-2014
        ELSIF to_number(vp_bco_atm) NOT IN (v_cod_entidad, 0) AND
              v_clt_cre_nuestro = 'N' THEN
          -- si es nuestro débito
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
             WHERE (cod_banco = vp_bco_atm --Banco
                   OR cod_ente = v_cod_ent_financiera) --Entidad Financiera
               AND cod_modalidad = 46
               AND cod_moneda = v_cod_moneda;
          EXCEPTION
            WHEN no_data_found THEN
              vp_cod_respuesta := vr_cta_inexistente;
              v_msj_error      := 'Cuenta Bancaria Inexistente';
          END;
        
        ELSIF to_number(vp_bco_atm) IN (v_cod_entidad, 0) AND
              v_clt_deb_nuestro = 'N' THEN
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
             WHERE (cod_banco = vp_bco_debito --Banco
                   OR cod_ente = v_cod_ent_financiera) --Entidad Financiera
               AND cod_modalidad = 46
               AND cod_moneda = v_cod_moneda;
          EXCEPTION
            WHEN no_data_found THEN
              vp_cod_respuesta := vr_cta_inexistente;
              v_msj_error      := 'Cuenta Bancaria Inexistente';
          END;
        ELSIF to_number(vp_bco_atm) IN (v_cod_entidad, 0) AND
              v_clt_deb_nuestro = 'S' AND v_clt_cre_nuestro = 'S' THEN
          null;
        END IF;
      END IF;
      -- Si es nuestro ATM o nuestro POST...
      IF to_number(vp_bco_atm) IN (v_cod_entidad, 0) THEN
        -- Si la Cuenta de credito no es del Banco.
        IF to_number(vp_bco_credito) NOT IN (v_cod_entidad, 0) and
           to_number(vp_operacion) NOT IN (41) THEN
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
             WHERE (cod_banco = vp_bco_atm --Banco
                   OR cod_ente = v_cod_ent_financiera) --Entidad Financiera
               AND cod_modalidad = 46 -- Modalidad de ATM'S.
               AND cod_moneda = v_cod_moneda;
          EXCEPTION
            WHEN no_data_found THEN
              vp_cod_respuesta := vr_cta_inexistente;
              v_msj_error      := 'Cuenta Bancaria Inexistente';
          END;
        END IF;
        -- Si la Cuenta de debito no es del Banco.
        IF to_number(vp_bco_debito) NOT IN (v_cod_entidad, 0) AND
           to_number(vp_operacion) NOT IN (41) THEN
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
             WHERE (cod_banco = vp_bco_debito --Banco
                   OR cod_ente = v_cod_ent_financiera) --Entidad Financiera
               AND cod_modalidad = 46
               AND cod_moneda = v_cod_moneda;
          EXCEPTION
            WHEN no_data_found THEN
              vp_cod_respuesta := vr_cta_inexistente;
              v_msj_error      := 'Cuenta Bancaria Inexistente';
          END;
        
        END IF;
      END IF;
    END IF;
  
    --verifica la cuenta de débito si se toma el primer cero de la cadena
    if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_ALFANUMERICO'), 'N') = 'S' then
      --vp_cta_debito
      pag_cta.pr_obt_cuenta(vp_cta_debito);
      g_cod_error := pag_cta.g_cod_error;
      IF g_cod_error = 12 THEN
        vp_cta_debito := to_number(vp_cta_debito);
        pag_cta.pr_obt_cuenta(vp_cta_debito);
        g_cod_error := pag_cta.g_cod_error;
        IF g_cod_error = 12 THEN
          vp_cod_respuesta := vr_cta_inexistente;
          v_msj_error      := 'Cuenta Bancaria Inexistente';
        END IF;
      end if;
    end if;
  
    -- Verifica de vuelta si es nuestro cliente...
    IF vp_bco_credito = v_cod_entidad THEN
      v_clt_cre_nuestro := 'S';
    ELSE
      v_clt_cre_nuestro := 'N';
    END IF;
    IF vp_bco_debito = v_cod_entidad THEN
      v_clt_deb_nuestro := 'S';
    ELSE
      v_clt_deb_nuestro := 'N';
    END IF;
  
    --verifica si supera el importe maximo de transferencias por dia
   /* IF vp_operacion IN (41, 5, 3) THEN
      IF vp_bco_debito = v_cod_entidad THEN
        v_retorno := fuj_ctr_mto_tra_atm(vp_cta_debito, v_importe);
        if nvl(v_retorno, 'N') = 'N' then
          vp_cod_respuesta := vr_mto_limite;
        end if;
      end if;
    end if;*/--comentado Lou
  
    IF vp_cod_respuesta = vr_aprobado then
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
          INTO v_ind_ctacontable,
               v_cod_tra_contable,
               v_mod_contable,
               v_mad_contable,
               v_cod_rubro
          FROM cc_cta_ficticias
         WHERE nro_cuenta = vp_cta_debito;
        vp_cta_debito := NULL;
      EXCEPTION
        WHEN no_data_found THEN
          v_ind_ctacontable := 'N';
      END;
    
      IF vp_servicio = 'ATM' then
        IF to_number(vp_bco_debito) = v_cod_entidad THEN
          IF vp_cta_debito IS NOT NULL AND vp_cta_debito != '0' THEN
            if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_DEB_COMPUESTA'), 'N') = 'S' then
              vp_cta_debito := to_char(to_number(vp_cta_debito));
            end if;
          
            if nvl(fug_obt_pardinamico('CAJ_ATM_VAL_MES_NAC'), 'N') = 'S' and
               nvl(vp_val_mes_nac, 'N') = 'S' then
              v_mes := lf_obt_mes_nac(vp_cta_debito, vp_relacion);
              --lp_reg_operacion('ANTES VAL '||vp_mes_nacimiento, v_mes, '', v_fec_inicio);
              if instr(vp_mes_nacimiento, v_mes) > 0 then
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
  
    IF vp_cod_respuesta = vr_aprobado then
      -- Llavea las cuentas
      -- Verifica si la cuenta de debito es de la Entidad --
      IF v_ind_ctacontable = 'N' THEN
        IF to_number(vp_bco_debito) = v_cod_entidad THEN
          v_clt_deb_nuestro := 'S';
        END IF;
      
        IF vp_cta_debito IS NOT NULL AND vp_cta_debito != '0' THEN
          if nvl(fug_obt_pardinamico('CAJ_ATM_CTA_DEB_COMPUESTA'), 'N') = 'S' then
            IF v_clt_deb_nuestro = 'S' THEN
              vp_cta_debito := to_char(to_number(vp_cta_debito));
            END IF;
          end if;
        
          lp_dat_cta(vp_cta_debito,
                     v_mod_cta_deb,
                     v_mad_cta_deb,
                     v_ofi_cta_deb,
                     v_mon_cta_deb);
        
          IF vp_cod_respuesta = vr_aprobado AND
             to_number(vp_operacion) NOT IN (2, 52, 93, 6, 3) THEN
            IF pag_cta.fu_llavear_cuenta(v_mad_cta_deb,
                                         vp_cta_debito,
                                         v_es_cta_noc) = 'N' THEN
              vp_cod_respuesta := vr_reintente;
              v_msj_error      := 'No se pudo llavear la Cuenta Débito';
            END IF;
          END IF;
        END IF;
      
      END IF;
      IF vp_cta_credito IS NOT NULL AND vp_cta_credito != '0' THEN
        IF to_number(vp_bco_credito) = v_cod_entidad THEN
          v_clt_cre_nuestro := 'S';
        END IF;
      
        lp_dat_cta(vp_cta_credito,
                   v_mod_cta_cre,
                   v_mad_cta_cre,
                   v_ofi_cta_cre,
                   v_mon_cta_cre);
        IF vp_cod_respuesta = vr_aprobado AND
           to_number(vp_operacion) NOT IN (2, 52, 93, 6) THEN
          IF pag_cta.fu_llavear_cuenta(v_mad_cta_cre,
                                       vp_cta_credito,
                                       v_es_cta_noc) = 'N' THEN
            vp_cod_respuesta := vr_reintente;
            v_msj_error      := 'No se pudo llavear la Cuenta Crédito';
          END IF;
        END IF;
      END IF;
    end if;
  
    if nvl(fug_obt_pardinamico('CAJ_ATM_VAL_MES_NAC'), 'N') = 'S' and
       nvl(vp_val_mes_nac, 'N') = 'S' then
      v_concepto := case
                      when vp_servicio = 'ATM' THEN
                       case
                         when substr(vp_negocio, 1, 1) = '#' then
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
  PROCEDURE lp_ver_ope_consulta IS
    -- Consulta de Saldo --
    v_sal_disponible ah_cta_vistas.sal_total%TYPE;
    v_sal_contable   ah_cta_vistas.sal_total%TYPE;
  BEGIN
    IF v_clt_deb_nuestro = 'S' THEN
      vp_cod_respuesta := vr_aprobado;
      v_sal_disponible := it.fug_obt_sal_disp_atm(vp_cta_debito);
      v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0);
      lp_dat_cta(vp_cta_debito,
                 v_mod_cta_deb,
                 v_mad_cta_deb,
                 v_ofi_cta_deb,
                 v_mon_cta_deb);
      -- Carga la respuesta --
      vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))),
                                15,
                                '0');
      IF v_sal_disponible < 0 THEN
        vp_sig_disponible := '-';
      END IF;
      vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))),
                              15,
                              '0');
      IF v_sal_contable < 0 THEN
        vp_sig_contable := '-';
      END IF;
    ELSE
      vp_cod_respuesta  := vr_aprobado;
      vp_sal_disponible := lpad('0', 15, '0');
      vp_sal_contable   := lpad('0', 15, '0');
    END IF;
  END lp_ver_ope_consulta;
  --
  PROCEDURE lp_ver_ope_depositos IS
    -- Depósito de Efectivo --
    v_man_mto_min_cta NUMBER(18, 2);
    v_nvo_estado      ah_cta_vistas.estado%TYPE;
    v_procesa         varchar2(1);
  BEGIN
   lp_val_mar_retencion;--Se valida si la cuenta posee indicador de retención de saldo.
    --
     IF v_dep_ret_mark = 0 THEN
      IF to_number(vp_operacion) = 64 THEN
         -- Pago de servicios - (Depósito de dinero)
         v_cod_tra_padre  := v_cod_tra_pad_dep;
         v_cod_tra_hijo_cta  := v_cod_tra_hij_dep;
         v_cod_tra_hijo_ted  := v_cod_tra_hij_dep_ted;
       ELSIF to_number(vp_operacion) = 68 THEN --GDR-242
			v_cod_tra_padre    := v_cod_tra_pad_tcd; --1125 -- codigo de transaccion PADRE.Carga Descarga portavalores TED
			v_cod_tra_hijo_cta := v_cod_tra_hij_trc; --3692 -- codigo de transaccion Hijo para deposito en efectivo.Carga portavalores TED
			v_cod_tra_hijo_ted := v_cod_tra_hij_dep_ted; --503 -- codigo de cta TED Extraccion en efectivo.Carga portavalores TED

       ELSIF to_number(vp_operacion) = 73 THEN
      -- Otras Entidades - (Depósito de dinero)
        v_cod_tra_padre    := v_cod_tra_pad_dep_oen; -- codigo de transaccion PADRE para deposito en efectivo de OTRAS ENTIDADES cuenta cliente
        v_cod_tra_hijo_cta := v_cod_tra_hij_dep_oen; -- codigo de transaccion para deposito en efectivo de OTRAS ENTIDADES cuenta CLIENTE
        v_cod_tra_hijo_ted := v_cod_tra_hij_dep_oen_ted; -- codigo de transaccion hijo para deposito en efectivo de OTRAS ENTIDADES cuenta TED    
      ELSE
          -- Depósito de dinero en efectivo TED
         v_cod_tra_padre    := to_number(fug_obt_pardinamico('COD_TRA_PADRE_DEP_EFE_TED'));
         v_cod_tra_hijo_cta := to_number(fug_obt_pardinamico('COD_TRA_HIJO_DEP_EFE_TED'));
         v_cod_tra_hijo_ted := to_number(fug_obt_pardinamico('COD_TRA_CTA_TED_DEP_EFE_TED'));
      END IF;
     END IF;
    -- Hace las verificaciones si es clte de debito es nuestro....
    IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
      vp_cod_respuesta := vr_aprobado;
      -- Obtiene los datos principales de la cuenta
      lp_dat_cta(vp_cta_debito,
                 v_mod_cta_deb,
                 v_mad_cta_deb,
                 v_ofi_cta_deb,
                 v_mon_cta_deb);
      pag_cta.pr_obt_cuenta(vp_cta_debito);
      v_man_mto_min_cta := fug_obt_pardinamico('AHO_MTO_MIN_CUENTA',
                                               v_mod_cta_deb,
                                               v_mad_cta_deb,
                                               v_mon_cta_deb);
    
      --validacion de operacion
      begin
        pag_cta.pr_ver_operacion(vp_cta_debito,
                                 v_cod_tra_padre,
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 'C',
                                 pag_cta.g_ctas.cod_moneda,
                                 v_importe,
                                 pag_cta.g_ctas.cod_oficina,
                                 -- out
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 v_nvo_estado,
                                 v_sal_disponible,
                                 v_procesa,
                                 v_cod_tra_hijo_cta);
      
      exception
        when others then
          vp_cod_respuesta := vr_no_aprobado;
          v_msj_error      := 'Error al verificar Cuenta - Operacion ' ||
                              pag_cta.G_COD_ERROR || ' ' ||
                              pag_cta.G_MSJ_ERROR;
      end;
      if v_procesa = 'N' then
        if pag_cta.G_COD_ERROR = 41 then
          --no se puede procesar
          vp_cod_respuesta := vr_mto_limite;
          v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                              pag_cta.G_COD_ERROR;
        else
          --no se puede procesar
          vp_cod_respuesta := vr_no_aprobado;
          v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                              pag_cta.G_COD_ERROR;
        end if;
      end if;
      -- 
      -- Debe verificar el monto de la operacion
      IF v_mon_cta_deb != v_cod_moneda THEN
        -- Se responde que la cuenta no existe...
        vp_cod_respuesta := vr_cta_inexistente;
        v_msj_error      := 'Cuenta Débito Inexistente. Moneda no corresponde a la cuenta.';
      END IF;
      -- Debe verificar si supera el límite de depósito configurado.
         --Validar código de operación --Excluir depósitos de portavalor
         IF instr(nvl(v_cod_ope_ted_umb,0),to_number(vp_operacion)) = 0 THEN
          IF instr(fug_obt_pardinamico('CC_CTA_SERVICIOS'), vp_cta_debito) = 0 THEN
             IF fug_obt_pardinamico('CJ_VAL_USD_TED') = 'S' THEN
              --Validar limite efectivo (umbral)
              if nvl(v_importe,0) > 0 and
                 lf_val_lim_umbral(v_cod_moneda) = 'S' then
                 --obtener datos loa/umbral
                     it.prg_obt_val_deposito(vp_cta_debito,v_cod_moneda, v_importe,v_mto_loa,v_mto_acumulado,v_mto_total,v_deposita);--S: supera el monto N: accede al depósito
                  if v_deposita = 'N' then
                    --genera pedido de autorizacion
                   lp_ins_pedido_umbral;
                   -- Se responde monto límite del umbral.
                    vp_cod_respuesta := vr_mto_limite; --61
                    v_msj_error      := 'Monto supera el límite establecido en el umbral configurado.'||v_mto_loa;
                  end if;
              end if;
          END IF;
         END IF;
        END IF;
      -- Debe verificar monto minimo a depositar
      IF v_importe < v_man_mto_min_cta THEN
        -- Se responde que la cuenta no existe...
        vp_cod_respuesta := vr_mto_invalido;
        v_msj_error      := 'Monto inválido, menor al configurado';
      END IF;
      IF vp_cod_respuesta = vr_aprobado THEN
        IF v_mad_cta_deb NOT IN (31, 41, 42, 46, 38, 39, 334,43,46) AND
           v_ind_ctacontable = 'N' THEN
          -- Ahorro a la Vista/ Cta. Corrientes
          vp_cod_respuesta := vr_cta_inex_ahorro;
          v_msj_error      := 'Tipo de Cuenta Débito Inválido. Modalidad: ' ||
                              v_mad_cta_deb;
        END IF;
      END IF;

      /*v_cargos         := nvl(v_val_cargo, 0) + nvl(v_val_impuesto, 0);
      v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) +
                          (nvl(v_importe, 0) + nvl(v_cargos, 0));
      v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0) +
                          (nvl(v_importe, 0) + nvl(v_cargos, 0));*/
      v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) + nvl(v_importe, 0);
      v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0) + nvl(v_importe, 0);

      IF v_mad_cta_deb IN (42, 46) OR v_ind_ctacontable = 'S' THEN
        v_sal_disponible := 0;
        v_sal_contable   := 0;
      END IF;
      IF vp_cod_respuesta <> vr_aprobado THEN
        -- extraccion rechazada, debe mostrar el saldo sin el debito
        v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0);
        v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0);
      END IF;
     

    END IF;
    -- Hace las verificaciones si el clte de credito es nuestro....
    IF nvl(to_number(vp_cta_credito), 0) != 0 AND
       vp_cod_respuesta = vr_aprobado THEN
      -- Obtiene los datos de la cuenta de debito...
      IF vp_cta_debito IS NOT NULL THEN
        lp_dat_cta(vp_cta_debito,
                   v_mod_cta_deb,
                   v_mad_cta_deb,
                   v_ofi_cta_deb,
                   v_mon_cta_deb);
        pag_cta.pr_obt_cuenta(vp_cta_debito);
        g_cod_error := pag_cta.g_cod_error;
      ELSE
        v_mon_cta_deb := v_cod_moneda;
        v_mod_cta_deb := v_mod_cta_deb;
        v_mad_cta_deb := v_mad_cta_deb;
        v_ofi_cta_deb := v_ofi_origen;
      END IF;
      IF v_mon_cta_deb != v_cod_moneda AND vp_cod_respuesta = vr_aprobado THEN
        -- Se responde que la cuenta no existe...
        vp_cod_respuesta := vr_cta_inexistente;
        v_msj_error      := 'Moneda de la Cuenta Debito distinto a la Moneda de la Transaccion';
      END IF;
      v_est_cuenta := pag_cta.fu_obt_est_cuenta;
      IF (v_est_cuenta NOT IN ('N', 'S', 'I', 'D', 'A') OR
         v_mad_cta_deb NOT IN (31, 41, 42, 46, 48, 38, 39, 334,43)) AND
         vp_cod_respuesta = vr_aprobado THEN
        -- No es normal o con bloqueo de saldo
        vp_cod_respuesta := vr_cta_bloqueada; -- Transaccion no aprobada
        v_msj_error      := 'Estado o Tipo de Cuenta Debito Inválido. Estado: ' ||
                            v_est_cuenta || ' Modalidad: ' || v_mad_cta_deb;
      END IF;
    END IF;
  END lp_ver_ope_depositos;
  --
  --
  PROCEDURE lp_ver_ope_cheques IS
    -- Depósito de cheque --
    v_sal_disponible  ah_cta_vistas.sal_total%TYPE;
    v_sal_contable    ah_cta_vistas.sal_total%TYPE;
    v_man_mto_min_cta NUMBER(18, 2);
    v_nvo_estado      ah_cta_vistas.estado%TYPE;
    v_procesa         varchar2(1);
  BEGIN
    -- Hace las verificaciones si es clte de debito es nuestro....
    IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
      vp_cod_respuesta := vr_aprobado;
      -- Obtiene los datos principales de la cuenta
      lp_dat_cta(vp_cta_debito,
                 v_mod_cta_deb,
                 v_mad_cta_deb,
                 v_ofi_cta_deb,
                 v_mon_cta_deb);
      pag_cta.pr_obt_cuenta(vp_cta_debito);
      v_man_mto_min_cta := fug_obt_pardinamico('AHO_MTO_MIN_CUENTA',
                                               v_mod_cta_deb,
                                               v_mad_cta_deb,
                                               v_mon_cta_deb);
    
      --validacion de operacion
      begin
        pag_cta.pr_ver_operacion(vp_cta_debito,
                                 393,
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 'C',
                                 pag_cta.g_ctas.cod_moneda,
                                 v_importe,
                                 pag_cta.g_ctas.cod_oficina,
                                 -- out
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 v_nvo_estado,
                                 v_sal_disponible,
                                 v_procesa,
                                 613);
      
      exception
        when others then
          vp_cod_respuesta := vr_no_aprobado;
          v_msj_error      := 'Error al verificar Cuenta - Operacion ' ||
                              pag_cta.G_COD_ERROR || ' ' ||
                              pag_cta.G_MSJ_ERROR;
      end;
      if v_procesa = 'N' then
        if pag_cta.G_COD_ERROR = 41 then
          --no se puede procesar
          vp_cod_respuesta := vr_mto_limite;
          v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                              pag_cta.G_COD_ERROR;
        else
          --no se puede procesar
          vp_cod_respuesta := vr_no_aprobado;
          v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                              pag_cta.G_COD_ERROR;
        end if;
      end if;
      -- 
      -- Debe verificar el monto de la operacion
      IF v_mon_cta_deb != v_cod_moneda THEN
        -- Se responde que la cuenta no existe...
        vp_cod_respuesta := vr_cta_inexistente;
        v_msj_error      := 'Cuenta Débito Inexistente. Moneda no corresponde a la cuenta.';
      END IF;
      -- Debe verificar monto minimo a depositar
      IF v_importe < v_man_mto_min_cta THEN
        -- Se responde que la cuenta no existe...
        vp_cod_respuesta := vr_mto_invalido;
        v_msj_error      := 'Monto inválido, menor al configurado';
      END IF;
      IF vp_cod_respuesta = vr_aprobado THEN
        IF v_mad_cta_deb NOT IN (31, 41, 42, 46, 38, 39, 334) AND
           v_ind_ctacontable = 'N' THEN
          -- Ahorro a la Vista/ Cta. Corrientes
          vp_cod_respuesta := vr_cta_inex_ahorro;
          v_msj_error      := 'Tipo de Cuenta Débito Inválido. Modalidad: ' ||
                              v_mad_cta_deb;
        END IF;
      END IF;

      
      v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0);
      v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0) + nvl(v_importe, 0);

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
      vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))),
                                15,
                                '0');
      IF v_sal_disponible < 0 THEN
        vp_sig_disponible := '-';
      END IF;
      vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))),
                              15,
                              '0');
      IF v_sal_contable < 0 THEN
        vp_sig_contable := '-';
      END IF;
    
    END IF;
    -- Hace las verificaciones si el clte de credito es nuestro....
    IF nvl(to_number(vp_cta_credito), 0) != 0 AND
       vp_cod_respuesta = vr_aprobado THEN
      -- Obtiene los datos de la cuenta de debito...
      IF vp_cta_debito IS NOT NULL THEN
        lp_dat_cta(vp_cta_debito,
                   v_mod_cta_deb,
                   v_mad_cta_deb,
                   v_ofi_cta_deb,
                   v_mon_cta_deb);
        pag_cta.pr_obt_cuenta(vp_cta_debito);
        g_cod_error := pag_cta.g_cod_error;
      ELSE
        v_mon_cta_deb := v_cod_moneda;
        v_mod_cta_deb := v_mod_cta_deb;
        v_mad_cta_deb := v_mad_cta_deb;
        v_ofi_cta_deb := v_ofi_origen;
      END IF;
      IF v_mon_cta_deb != v_cod_moneda AND vp_cod_respuesta = vr_aprobado THEN
        -- Se responde que la cuenta no existe...
        vp_cod_respuesta := vr_cta_inexistente;
        v_msj_error      := 'Moneda de la Cuenta Debito distinto a la Moneda de la Transaccion';
      END IF;
      v_est_cuenta := pag_cta.fu_obt_est_cuenta;
      IF (v_est_cuenta NOT IN ('N', 'S', 'I', 'D', 'A') OR
         v_mad_cta_deb NOT IN (31, 41, 42, 46, 48, 38, 39, 334)) AND
         vp_cod_respuesta = vr_aprobado THEN
        -- No es normal o con bloqueo de saldo
        vp_cod_respuesta := vr_cta_bloqueada; -- Transaccion no aprobada
        v_msj_error      := 'Estado o Tipo de Cuenta Debito Inválido. Estado: ' ||
                            v_est_cuenta || ' Modalidad: ' || v_mad_cta_deb;
      END IF;
    END IF;
  END lp_ver_ope_cheques;
  --
  PROCEDURE lp_ver_ope_extracciones IS
    -- Extraccion de Efectivo --
    v_sal_disponible  ah_cta_vistas.sal_total%TYPE;
    v_sal_contable    ah_cta_vistas.sal_total%TYPE;
    v_mto_acuerdo     cc_lin_sobregiros.monto%TYPE := 0;
    v_man_mto_min_cta NUMBER(18, 2);
    v_nvo_estado      ah_cta_vistas.estado%TYPE;
    v_procesa         varchar2(1);
  BEGIN
    -- Hace las verificaciones si es clte de debito es nuestro....
    IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
      vp_cod_respuesta := vr_aprobado;
      -- Obtiene los datos principales de la cuenta
      lp_dat_cta(vp_cta_debito,
                 v_mod_cta_deb,
                 v_mad_cta_deb,
                 v_ofi_cta_deb,
                 v_mon_cta_deb);
      pag_cta.pr_obt_cuenta(vp_cta_debito);
      v_man_mto_min_cta := fug_obt_pardinamico('AHO_MTO_MIN_CUENTA',
                                               v_mod_cta_deb,
                                               v_mad_cta_deb,
                                               v_mon_cta_deb);
    
      -- Debe verificar el monto de la operacion
      IF v_mon_cta_deb != v_cod_moneda THEN
        -- Se responde que la cuenta no existe...
        vp_cod_respuesta := vr_cta_inexistente;
        v_msj_error      := 'Cuenta Débito Inexistente';
      END IF;
      IF vp_cod_respuesta = vr_aprobado THEN
        IF v_mad_cta_deb NOT IN (31, 41, 42, 46, 38, 39, 334,43,46) AND
           v_ind_ctacontable = 'N' THEN
          -- Ahorro a la Vista/ Cta. Corrientes
          vp_cod_respuesta := vr_cta_inex_ahorro;
          v_msj_error      := 'Tipo de Cuenta Débito Inválido. Modalidad: ' ||
                              v_mad_cta_deb;
        END IF;
      END IF;
    IF to_number(vp_operacion) = 66 THEN 
        v_cod_tra_padre    := v_cod_tra_pad_vuelto; -- codigo de transaccion PADRE para extraccion en efectivo por VUELTO  cuenta cliente
        v_cod_tra_hijo_cta := v_cod_tra_hij_vuelto; -- codigo de transaccion para extraccion en efectivo por VUELTO   cuenta CLIENTE
        v_cod_tra_hijo_ted := v_cod_tra_hij_vuelto_ted; -- codigo de transaccion hijo para extraccion en efectivo por VUELTO  cuenta TED
    ELSIF to_number(vp_operacion) = 63 THEN 
        v_cod_tra_padre    := v_cod_tra_pad_rec_wu; -- codigo de transaccion PADRE para extraccion en efectivo por Recepcion WU cuenta cliente
        v_cod_tra_hijo_cta := v_cod_tra_hij_rec_wu; -- codigo de transaccion para extraccion en efectivo por Recepcion WU  cuenta CLIENTE
        v_cod_tra_hijo_ted := v_cod_tra_hij_rec_wu_ted; -- codigo de transaccion hijo para extraccion en efectivo por Recepcion WU cuenta TED
    ELSIF to_number(vp_operacion) = 67 THEN --GDR-242
         v_cod_tra_padre    := v_cod_tra_pad_tcd; -- codigo de transaccion PADRE para extraccion en efectivo.Descarga portavalores TED
         v_cod_tra_hijo_cta := v_cod_tra_hij_trd; -- codigo de transaccion Hijo para extraccion en efectivo.Descarga portavalores TED
         v_cod_tra_hijo_ted := v_cod_tra_trd_ted; -- codigo de cta TED Extraccion  en efectivo.Descarga portavalores TED 
    ELSIF to_number(vp_operacion) = 75 THEN
        v_cod_tra_padre    := v_cod_tra_pad_oen; -- codigo de transaccion PADRE para extraccion en efectivo de OTRAS ENTIDADES cuenta cliente
        v_cod_tra_hijo_cta := v_cod_tra_hij_oen; -- codigo de transaccion para extraccion en efectivo de OTRAS ENTIDADES cuenta CLIENTE
        v_cod_tra_hijo_ted := v_cod_tra_hij_oen_ted; -- codigo de transaccion hijo para extraccion en efectivo de OTRAS ENTIDADES cuenta TED
  ELSIF to_number(vp_operacion) = 85 THEN
        v_cod_tra_padre    := v_cod_tra_pad_dep; -- codigo de transaccion PADRE DE PAGOS DE SERVICIOS
        v_cod_tra_hijo_cta := v_cod_tra_hij_ext_ser; -- codigo de transaccion para extraccion en efectivo POR SERVICIOS cuenta CLIENTE
        v_cod_tra_hijo_ted := v_cod_tra_hij_ext_ser_ted; -- codigo de transaccion hijo para extraccion en efectivo POR SERVICIOS cuenta TED
  ELSIF to_number(vp_operacion) = 15 THEN
         v_cod_tra_padre    := v_cod_tra_pad_tet;--1230 -- codigo de transaccion PADRE para extraccion en efectivo.Tarjetas de debito
         v_cod_tra_hijo_cta := v_cod_tra_hij_etd;--3870 -- codigo de transaccion Hijo para extraccion en efectivo.Tarjetas de debito
         v_cod_tra_hijo_ted := v_cod_tra_tet_ted;-- 602 -- codigo de cta TED Extraccion  en efectivo.Tarjetas de debito
  ELSIF to_number(vp_operacion) = 25 THEN
         v_cod_tra_padre    := v_cod_tra_pad_tet;--1230-- codigo de transaccion PADRE para extraccion en efectivo.Tarjetas de credito
         v_cod_tra_hijo_cta := v_cod_tra_hij_etc;--3871 -- codigo de transaccion Hijo para extraccion en efectivo.Tarjetas de credito
         v_cod_tra_hijo_ted := v_cod_tra_tet_ted;-- 602 -- codigo de cta TED Extraccion  en efectivo.Tarjetas de credito
    ELSE
        v_cod_tra_padre    := 482;  -- codigo de transaccion PADRE para extraccion en efectivo cuenta cliente
        v_cod_tra_hijo_cta := 678;  -- codigo de transaccion hijo para extraccion en efectivo cuenta cliente
        v_cod_tra_hijo_ted := 602;  -- codigo de transaccion para extraccion en efectivo cuenta TED
    END IF;
      --validacion de operacion
      begin
        pag_cta.pr_ver_operacion(vp_cta_debito,
                                 v_cod_tra_padre,
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 'D',
                                 pag_cta.g_ctas.cod_moneda,
                                 v_importe,
                                 pag_cta.g_ctas.cod_oficina,
                                 -- out
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 v_nvo_estado,
                                 v_sal_disponible,
                                 v_procesa,
                                 v_cod_tra_hijo_cta);
      exception
        when others then
          vp_cod_respuesta := vr_no_aprobado;
          v_msj_error      := 'Error al verificar Cuenta - Operacion ' ||
                              pag_cta.G_MSJ_ERROR;
      end;
      if v_procesa = 'N' then
        if pag_cta.G_COD_ERROR = 31 then
          --no se puede procesar
          vp_cod_respuesta := vr_sal_insuficiente;
          v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                              pag_cta.G_COD_ERROR;
        elsif pag_cta.G_COD_ERROR = 25 then
         --no se puede procesar
          vp_cod_respuesta := vr_sal_insuficiente;
          v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                              pag_cta.G_COD_ERROR;
        else
          --no se puede procesar
          vp_cod_respuesta := vr_no_aprobado;
          v_msj_error      := pag_cta.G_MSJ_ERROR || ' ' ||
                              pag_cta.G_COD_ERROR;
        end if;
      end if;
      -- 
      v_cargos         := nvl(v_val_cargo, 0) + nvl(v_val_impuesto, 0);
      v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) -
                          (nvl(v_importe, 0) + nvl(v_cargos, 0));
      v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0) -
                          (nvl(v_importe, 0) + nvl(v_cargos, 0));
      IF v_sal_disponible < 0 AND vp_cod_respuesta = vr_aprobado AND
         v_mad_cta_deb NOT IN (42, 46) AND v_ind_ctacontable = 'N' THEN
        IF v_mad_cta_deb = 41 THEN
          IF fug_obt_pardinamico('CC_TED_SOBREGIRO') = 'S' THEN
            -- Si es Cuenta Corriente debe verificar si no tiene acuerdo de Sobregiro.
            -- Debe buscar el monto del acuerdo para verificar nuevamente
            v_mto_acuerdo := pag_cta.fu_obt_lin_sobregiro(vp_cta_debito,v_fec_proceso);
          ELSE
             v_mto_acuerdo := 0;
          END IF;
          IF nvl(v_mto_acuerdo, 0) + nvl(v_sal_disponible, 0) < 0 THEN
            -- Sigue siendo insuficiente su acuerdo...
            vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
            v_msj_error      := 'Cuenta con Saldo Insuficiente';
          ELSE
            -- Sino mantiene aprobado.
            vp_cod_respuesta := vr_aprobado;
          
          END IF;
        ELSIF v_mod_cta_deb = 4 AND v_mad_cta_deb = 43 AND instr(fug_obt_pardinamico('CC_CTA_SERVICIOS'), vp_cta_debito) > 0 THEN
          -- Cuentas bancarias para PAGO DE SERVICIOS, WU, VUELTO 
          v_sal_disponible := 0;
          v_sal_contable   := 0;
          vp_cod_respuesta := vr_aprobado;
        ELSIF v_mod_cta_deb = 4 AND v_mad_cta_deb = 46 THEN
          -- Cuentas bancarias para TRANSACCIONES DE CARGA DESCARGA - PORTAVALORES
		  
			BEGIN
				SELECT GP.VAL_PARAMETRO 
					INTO v_cta_portavalor
					FROM ge_entes GE INNER JOIN ge_par_entes GP ON GE.Cod_Ente = gp.cod_ente
					WHERE ge.tipo = 'CD'
					AND GP.VAL_PARAMETRO =  vp_cta_debito;
		  
			EXCEPTION
				WHEN no_data_found THEN
					-- Sigue siendo insuficiente su acuerdo...
					vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
					v_msj_error      := 'Cuenta con Saldo Insuficiente';
			END; 
			v_sal_disponible := 0;
			v_sal_contable   := 0;
			vp_cod_respuesta := vr_aprobado;
        ELSE
          -- Si no es Cta Corriente debe responder Saldo Insuficiente...
          vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
          v_msj_error      := 'Cuenta con Saldo Insuficiente';
        END IF;
      ELSIF v_mad_cta_deb in (31, 38, 39, 334) THEN
        v_exo_mto_minimo := fug_obt_paradicional(vp_cta_debito,
                                                 'EXO_MTO_MINIMO');
        IF v_sal_disponible < v_man_mto_min_cta OR v_sal_disponible < 0 THEN
          /*IF (pag_cta.g_ctas.cod_seg_cliente <> v_cod_seg_funcionario AND
             NVL(V_EXO_MTO_MINIMO, 'N') <> 'S') THEN
            -- Si es Cta. Ahorro y no es funcionario debe de mantener un monto minimo en su cta....
            vp_cod_respuesta := vr_sal_insuficiente;
            v_msj_error      := 'Cuenta con Saldo Insuficiente';
          END IF;*/
          null;
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
      vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))),
                                15,
                                '0');
      IF v_sal_disponible < 0 THEN
        vp_sig_disponible := '-';
      END IF;
      vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))),
                              15,
                              '0');
      IF v_sal_contable < 0 THEN
        vp_sig_contable := '-';
      END IF;
    
    END IF;
    -- Hace las verificaciones si el clte de credito es nuestro....
    IF nvl(to_number(vp_cta_credito), 0) != 0 AND
       vp_cod_respuesta = vr_aprobado THEN
      -- Obtiene los datos de la cuenta de credito...
      IF vp_cta_credito IS NOT NULL THEN
        lp_dat_cta(vp_cta_credito,
                   v_mod_cta_cre,
                   v_mad_cta_cre,
                   v_ofi_cta_cre,
                   v_mon_cta_cre);
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
        vp_cod_respuesta := vr_cta_inex_ahorro;
        v_msj_error      := 'Moneda de la Cuenta Crédito distinto a la Moneda de la Transacción';
      END IF;
      v_est_cta_cre := pag_cta.fu_obt_est_cuenta;
      IF (v_est_cta_cre NOT IN ('N', 'S', 'I') OR
         v_mad_cta_cre NOT IN (31, 41, 42, 46, 48, 38, 39, 334)) AND
         vp_cod_respuesta = vr_aprobado THEN
        -- No es normal o con bloqueo de saldo
        vp_cod_respuesta := vr_cta_bloqueada; -- Transaccion no aprobada
        v_msj_error      := 'Estado o Tipo de Cuenta Crédito Inválido. Estado: ' ||
                            v_est_cta_cre || ' Modalidad: ' ||
                            v_mad_cta_cre;
      END IF;
    END IF;
  END lp_ver_ope_extracciones;
  --
  PROCEDURE lp_ver_ope_reversa IS
    v_sal_disponible ah_cta_vistas.sal_total%TYPE;
    v_sal_contable   ah_cta_vistas.sal_total%TYPE;
  BEGIN
    -- Un extorno no se puede desaprobar...
    vp_cod_respuesta := vr_aprobado; -- Aprobado
    -- Cambia el signo del importe...
    v_importe := v_importe * -1;
  
    IF v_clt_deb_nuestro = 'S' THEN
      -- Obtiene los datos principales de la cuenta
      lp_dat_cta(vp_cta_debito,
                 v_mod_cta_deb,
                 v_mad_cta_deb,
                 v_ofi_cta_deb,
                 v_mon_cta_deb);
    
      v_sal_disponible := nvl(pag_cta.fu_sal_disponible, 0) -
                          nvl(v_importe, 0);
      v_sal_contable   := nvl(pag_cta.g_ctas.sal_actual, 0) -
                          nvl(v_importe, 0);
    
      vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))),
                                15,
                                '0');
      IF v_sal_disponible < 0 THEN
        vp_sig_disponible := '-';
      END IF;
      vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))),
                              15,
                              '0');
      IF v_sal_contable < 0 THEN
        vp_sig_contable := '-';
      END IF;
    ELSE
      vp_sal_disponible := lpad('0', 15, '0');
      vp_sal_contable   := lpad('0', 15, '0');
    END IF;
    IF nvl(to_number(vp_cta_credito), 0) != 0 THEN
      lp_dat_cta(vp_cta_credito,
                 v_mod_cta_cre,
                 v_mad_cta_cre,
                 v_ofi_cta_cre,
                 v_mon_cta_cre);
    END IF;
  END lp_ver_ope_reversa;
  ------------------
  --- Procesos... --
  ------------------
  --
  PROCEDURE lp_pro_ope_consulta IS
    -- Consulta de Saldo --
  BEGIN
    v_cod_tra_padre := 389;
    IF v_clt_deb_nuestro = 'S' THEN
      -- Carga los parametros de movimientos de Debito
      r_gmovi.cod_modulo    := v_mod_cta_deb;
      r_gmovi.cod_modalidad := v_mad_cta_deb;
      r_gmovi.cod_oficina   := v_ofi_cta_deb;
      r_gmovi.nro_cuenta    := vp_cta_debito;
      r_gmovi.cod_moneda    := v_cod_moneda;
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
  END lp_pro_ope_consulta;
  --
  --
   PROCEDURE lp_pro_ope_depositos IS
    -- Depósito en efectivo --
  BEGIN
    IF to_number(vp_extorno)= 99 THEN
     IF to_number(vp_operacion) = 64 THEN
          -- Pago de servicios - (Depósito de dinero)
          v_cod_tra_padre  := v_cod_tra_pad_dep;
          v_cod_tra_hijo_cta  := v_cod_tra_hij_dep;
          v_cod_tra_hijo_ted  := v_cod_tra_hij_dep_ted;
        ELSIF to_number(vp_operacion) = 73 THEN
      -- Otras Entidades (Depósito de dinero)
        v_cod_tra_padre    := v_cod_tra_pad_dep_oen; -- codigo de transaccion PADRE para deposito en efectivo de OTRAS ENTIDADES cuenta cliente
        v_cod_tra_hijo_cta := v_cod_tra_hij_dep_oen; -- codigo de transaccion para deposito en efectivo de OTRAS ENTIDADES cuenta CLIENTE
        v_cod_tra_hijo_ted := v_cod_tra_hij_dep_oen_ted; -- codigo de transaccion hijo para deposito en efectivo de OTRAS ENTIDADES cuenta TED
       ELSE
          v_cod_tra_padre    := to_number(fug_obt_pardinamico('COD_TRA_PADRE_DEP_EFE_TED'));
          v_cod_tra_hijo_cta := to_number(fug_obt_pardinamico('COD_TRA_HIJO_DEP_EFE_TED'));
          v_cod_tra_hijo_ted := to_number(fug_obt_pardinamico('COD_TRA_CTA_TED_DEP_EFE_TED'));
       END IF;
     END IF;
      IF v_dep_ret_mark = 1 AND v_cod_retencion != 0 THEn
      -- Recupera fecha de retencion
        pr_obt_retencion(v_fec_proceso, vp_cta_debito, v_mod_cta_deb,
                 v_mad_cta_deb, v_cod_tra_hijo_cta, v_cod_moneda,
                 v_cod_retencion, v_fec_fin_retencion);
        r_gmovi.cod_retencion := v_cod_retencion;
        r_gmovi.fec_fin_retencion := v_fec_fin_retencion;
      ELSE
        r_gmovi.cod_retencion := null;
        r_gmovi.fec_fin_retencion := null;
      END IF;
      IF to_number(vp_extorno) = 99 and v_dep_ret_mark = 1 THEN
        r_gmovi.reversado      := 'S';
      ELSE
        r_gmovi.reversado      := 'N';
      END IF;
    v_est_cta_ant := pag_cta.fu_obt_est_cuenta;
    IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
      -- Carga los parametros de movimientos de Debito/Credito
      r_gmovi.cod_modulo    := v_mod_cta_deb;
      r_gmovi.cod_modalidad := v_mad_cta_deb;
      r_gmovi.cod_oficina   := v_ofi_cta_deb;
      r_gmovi.nro_cuenta    := vp_cta_debito;  
      r_gmovi.cod_moneda    := v_cod_moneda;
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
        r_gmovi.cod_transaccion := v_cod_tra_hijo_cta;
        IF lf_exi_banco(vp_bco_atm) = 'B' THEN
          r_gmovi.cod_banco := vp_bco_atm;
        ELSE
          r_gmovi.nro_documento2 := vp_bco_atm;
        END IF;
      END IF;
      r_gmovi.monto          := v_importe;
      r_gmovi.nro_documento  := v_nro_documento;
      r_gmovi.nro_documento3 := v_nro_documento3;
    
      r_gmovi.cod_tasa       := NULL;
      r_gmovi.val_tasa       := NULL;
      r_gmovi.cotizacion     := NULL;
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
        r_gmovi.concepto        := 'Cargo por Deposito';
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
          r_gmovi.concepto        := 'IVA s/Cargo por Deposito';
          r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
          r_gmovi.cod_transaccion := v_cod_tra_impuesto;
          pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        END IF;
          v_importe := v_importe + nvl(v_cargos, 0);
          lp_upd_cta_debito_03;
        IF v_est_cuenta = 'I' or v_est_cuenta = 'A' THEN
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
        IF v_dep_ret_mark = 1 AND v_cod_retencion != 0 THEN
           lp_upd_cta_reten;
        ELSE
           lp_upd_cta_debito_03;
        END IF;
        IF v_est_cuenta = 'I' or v_est_cuenta = 'A' THEN
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
      /*lp_env_notificacion(vp_cta_debito,
                          v_importe,
                          v_nro_documento,
                          to_number(vp_operacion),
                          v_hora);*/
    END IF;
    IF v_es_banco = 'S' AND to_number(vp_cta_credito) <> 0 THEN
      -- Carga los parametros de movimientos de Credito
      v_nro_secuencia       := v_nro_secuencia + 1;
      r_gmovi.cod_modulo    := v_mod_cta_cre;
      r_gmovi.cod_modalidad := v_mad_cta_cre;
      r_gmovi.cod_oficina   := v_ofi_cta_cre;
      r_gmovi.nro_cuenta    := vp_cta_credito; 
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.cod_usuario   := v_cod_usuario;
      r_gmovi.hora          := v_hora;
      r_gmovi.fecha         := v_fec_proceso;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      --
      r_gmovi.fec_valor     := v_fec_valor;
      r_gmovi.cod_tra_padre := v_cod_tra_padre;
      r_gmovi.cod_mod_padre := v_cod_modulo;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.cod_retencion := null;
      r_gmovi.fec_fin_retencion := null;
      IF v_cod_rub_caja IS NOT NULL THEN
        r_gmovi.cod_transaccion := v_cod_tra_hijo_ted;
        r_gmovi.tip_mov_rubro   := 'D';
        r_gmovi.cod_rubro       := v_cod_rub_caja;
      ELSE
        r_gmovi.cod_transaccion := v_cod_tra_hijo_ted;
      END IF;
      IF lf_exi_banco(vp_bco_atm) = 'B' THEN
        r_gmovi.cod_banco := vp_bco_atm;
      ELSE
        r_gmovi.nro_documento2 := vp_bco_atm;
      END IF;
      r_gmovi.monto          := v_importe;
      r_gmovi.nro_documento  := v_nro_documento;
      r_gmovi.nro_documento3 := v_nro_documento3;
    
      r_gmovi.cod_tasa       := NULL;
      r_gmovi.val_tasa       := NULL;
      r_gmovi.cotizacion     := NULL;
      r_gmovi.cod_ofi_origen := v_ofi_origen;
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.concepto       := v_concepto;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
    
      if v_mod_cta_cre = 4 then
         if fug_obt_tip_modalidad(v_mod_cta_cre, v_mad_cta_cre) = 'A' then
            v_tip_transaccion := lf_obt_tipo(r_gmovi.cod_transaccion,
                                             v_mod_cta_cre,
                                             v_mad_cta_cre);
            if v_tip_transaccion = 'C' then
              v_importe := v_importe * (-1);
            end if;
         end if; 
      end if;
      lp_upd_cta_credito_03;
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
    pr_gen_nov_cuenta(v_fec_proceso,v_hora,v_mod_cta_deb,v_mad_cta_deb,v_est_cta_ant,r_gmovi.cod_usuario,vp_cta_debito);
  END;
  --
  FUNCTION fu_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type) return VARCHAR2 is
    v_hora ge_movimientos.hora%type;
    v_nro_sec number;
    v_can_user number;
    v_nro_user number;
    v_user ba_usuarios.cod_usuario%type;
  BEGIN
    BEGIN
      SELECT COUNT(*)
        INTO v_can_user
        FROM ba_cod_referencias
       WHERE dominio = 'USU_MOV_SERVICIO'
         AND abreviatura = p_tip_user;
      EXCEPTION
        WHEN OTHERS THEN
         v_can_user := 0;
    END;
    
     v_nro_sec := fue_obt_sig_secuencia('S_SER_APICAJERO');
     v_nro_user:= mod(v_nro_sec,v_can_user);
     
     if v_nro_user >= v_can_user then
       v_nro_sec:=0;
     end if;
     
     v_user := FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO',v_nro_user,p_tip_user);
                       
    return v_user;
  EXCEPTION
    WHEN OTHERS THEN
        return (USER);
  END;
  --
  PROCEDURE lp_pro_ope_cheques IS
    -- Depósito de cheque --
    v_cod_transaccion  ge_transacciones.cod_transaccion%type;
    v_hor_actual      varchar2(08):=to_char(SYSDATE,'HH24:MI'); --FSOP-28642
    v_hor_cie_cheques varchar2(08) := fue_obt_val_max_refcodes('HOR_COR_CAMARA','T');
    v_usu_mov         ba_usuarios.cod_usuario%type;
    v_hor_mov         ge_movimientos.hora%type;
  BEGIN
    v_cod_retencion := 1;-- lf_obt_cod_reten(vp_cta_credito);
     
    IF to_number(vp_operacion) = 4 THEN
      v_cod_tra_padre := 395;--: Nuevo código utilizado para CAJ. Ant ATM: 352;
    END IF;
    --FSOP-28642
   IF v_cod_moneda =pag_gen.FU_OBT_MON_LOCAL  THEN             
       if v_horario = 'D' and v_hor_actual > v_hor_cie_cheques then
           --se graba ya como cheques 48 hs de retencion
           v_cod_transaccion := 632;
           v_tip_monto       := 'S';
           --ingresa luego del horario de cierre de ted (graba como nocturno)
           v_horario     := 'N'; -- Noche
           v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,1,v_ofi_origen);
           v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
           v_es_cta_noc  := 'S'; -- Solo para que llavee la cuenta nocturna
       else
           v_cod_transaccion := 615;
           v_tip_monto       := 'T';
       end if;     
   ELSE
        v_cod_transaccion := 615;
        v_tip_monto       := 'T';  
        IF v_horario = 'D' and v_hor_actual > v_hor_cie_cheques THEN
           -- se graba ya como cheques 48 hs de retencion
           v_cod_transaccion := 632;
           v_tip_monto       := 'S';
           --ingresa luego del horario de cierre de ted (graba como nocturno)
           v_horario     := 'N'; -- Noche
           v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,1,v_ofi_origen);
           v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
           v_es_cta_noc  := 'S'; -- Solo para que llavee la cuenta nocturna
       END IF;
   END IF;  
              
    v_est_cta_ant := pag_cta.fu_obt_est_cuenta;
    ----
    v_usu_mov := fu_obt_mov_user('APICAJERO');
    v_hor_mov := fug_ini_hora;
    v_hor_mov := fug_obt_hor_disponible(v_fec_proceso,
                                        v_hor_mov,
                                        v_usu_mov,
                                        v_es_nocturno);
    ----
    IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
      -- Carga los parametros de movimientos de Debito/Credito
      -- Recupera fecha de retencion
       --FSOP-28642
        pag_cta.pr_obt_retencion(v_fec_proceso,
                                 vp_cta_debito,
                                 v_mod_cta_deb,
                                 v_mad_cta_deb,
                                 v_cod_transaccion,
                                 v_cod_moneda,
                                 v_cod_retencion,
                                 v_fec_fin_retencion);
                                       
      /*pr_obt_retencion(v_fec_proceso, vp_cta_debito, v_mod_cta_deb,
                       v_mad_cta_deb, 612, v_cod_moneda,
                       v_cod_retencion, v_fec_fin_retencion);*/
                       
      r_gmovi.cod_modulo    := v_mod_cta_deb;
      r_gmovi.cod_modalidad := v_mad_cta_deb;
      r_gmovi.cod_oficina   := v_ofi_cta_deb;
      r_gmovi.nro_cuenta    := vp_cta_debito;  
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.cod_usuario   := v_usu_mov; --v_cod_usuario;
      r_gmovi.hora          := v_hor_mov;--v_hora;
      r_gmovi.fecha         := v_fec_proceso;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      r_gmovi.nro_caja      := v_nro_caja;
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
        r_gmovi.cod_transaccion := v_cod_transaccion; --Nuevo cód transacción hijo
        r_gmovi.cod_retencion := v_cod_retencion;
        r_gmovi.fec_fin_retencion:= v_fec_fin_retencion;
        IF lf_exi_banco(vp_bco_atm) = 'B' THEN
          r_gmovi.cod_banco := vp_bco_atm;
        ELSE
          r_gmovi.nro_documento2 := vp_bco_atm;
        END IF;
      END IF;
      r_gmovi.monto          := v_importe;
      r_gmovi.nro_documento  := v_nro_documento;
      r_gmovi.nro_documento3 := v_nro_documento3;
    
      r_gmovi.cod_tasa       := NULL;
      r_gmovi.val_tasa       := NULL;
      r_gmovi.cotizacion     := NULL;
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
        r_gmovi.concepto        := 'Cargo por Deposito';
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
          r_gmovi.concepto        := 'IVA s/Cargo por Deposito';
          r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
          r_gmovi.cod_transaccion := v_cod_tra_impuesto;
          pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        END IF;
        v_importe := v_importe + nvl(v_cargos, 0);
        lp_upd_cta_debito_04;
        IF v_est_cuenta = 'I' or v_est_cuenta = 'A' THEN
          -- Debo cambiar el estado de la cuenta
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.cod_retencion   := null;
          r_gmovi.fec_fin_retencion:= null;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.monto           := NULL;
          r_gmovi.est_cuenta      := 'N';
          r_gmovi.cod_tra_padre   := 425;
          r_gmovi.cod_transaccion := 425;
          pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        END IF;
        v_importe := v_importe - nvl(v_cargos, 0); -- para el credito debe ser solo por el monto extraido
      null;
      ELSE
        lp_upd_cta_debito_04;
        IF v_est_cuenta = 'I' or v_est_cuenta = 'A' THEN
          -- Debo cambiar el estado de la cuenta
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.cod_retencion   := null;
          r_gmovi.fec_fin_retencion:= null;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.monto           := NULL;
          r_gmovi.est_cuenta      := 'N';
          r_gmovi.cod_tra_padre   := 425;
          r_gmovi.cod_transaccion := 425;
          pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        END IF;
      END IF;
     /* lp_env_notificacion(vp_cta_debito,
                          v_importe,
                          v_nro_documento,
                          to_number(vp_operacion),
                          v_hora);*/
    END IF;
    IF v_es_banco = 'S' AND to_number(vp_cta_credito) <> 0 THEN
      -- Carga los parametros de movimientos de Credito
      v_nro_secuencia       := v_nro_secuencia + 1;
      r_gmovi.cod_modulo    := v_mod_cta_cre;
      r_gmovi.cod_modalidad := v_mad_cta_cre;
      r_gmovi.cod_oficina   := v_ofi_cta_cre;
      r_gmovi.nro_cuenta    := vp_cta_credito; 
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.cod_usuario   := v_usu_mov;--v_cod_usuario;
      r_gmovi.hora          := v_hor_mov;--v_hora;
      r_gmovi.fecha         := v_fec_proceso;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      --
      r_gmovi.fec_valor     := v_fec_valor;
      r_gmovi.cod_tra_padre := v_cod_tra_padre;
      r_gmovi.cod_mod_padre := v_cod_modulo;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.cod_retencion := null;
      r_gmovi.fec_fin_retencion:= null;
      r_gmovi.tip_mov_rubro   := null;
      r_gmovi.cod_rubro       := null;
      IF v_cod_retencion =  1 then 
          r_gmovi.cod_transaccion := 504;
      ELSE 
          r_gmovi.cod_transaccion := 9731; -- Código nuevo 
      END IF;
      IF lf_exi_banco(vp_bco_atm) = 'B' THEN
        r_gmovi.cod_banco := vp_bco_atm;
      ELSE
        r_gmovi.nro_documento2 := vp_bco_atm;
      END IF;
      r_gmovi.monto          := v_importe;
      r_gmovi.nro_documento  := v_nro_documento;
      r_gmovi.nro_documento3 := v_nro_documento3;
    
      r_gmovi.cod_tasa       := NULL;
      r_gmovi.val_tasa       := NULL;
      r_gmovi.cotizacion     := NULL;
      r_gmovi.cod_ofi_origen := v_ofi_origen;
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.concepto       := v_concepto;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
    
      if v_mod_cta_cre = 4 then
        if fug_obt_tip_modalidad(v_mod_cta_cre, v_mad_cta_cre) = 'A' then
          v_tip_transaccion := lf_obt_tipo(r_gmovi.cod_transaccion,
                                           v_mod_cta_cre,
                                           v_mad_cta_cre);
          if v_tip_transaccion = 'C' then
            v_importe := v_importe * (-1);
          end if;
        end if;
      end if;
    
      lp_upd_cta_credito_04;
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
    lp_upd_caja;
    pr_gen_nov_cuenta(v_fec_proceso, v_hor_mov /*v_hora*/,v_mod_cta_deb,v_mad_cta_deb,v_est_cta_ant,r_gmovi.cod_usuario,vp_cta_debito);
  END;
  --
  PROCEDURE lp_pro_ope_extracciones IS
    -- Extraccion de Efectivo --
  BEGIN
   IF to_number(vp_extorno)= 99 THEN
      IF to_number(vp_operacion) = 66 THEN 
         v_cod_tra_padre    := v_cod_tra_pad_vuelto; -- codigo de transaccion PADRE para extraccion en efectivo por VUELTO  cuenta cliente
         v_cod_tra_hijo_cta := v_cod_tra_hij_vuelto; -- codigo de transaccion para extraccion en efectivo por VUELTO   cuenta CLIENTE
         v_cod_tra_hijo_ted := v_cod_tra_hij_vuelto_ted; -- codigo de transaccion hijo para extraccion en efectivo por VUELTO  cuenta TED
      ELSIF to_number(vp_operacion) = 63 THEN 
         v_cod_tra_padre    := v_cod_tra_pad_rec_wu; -- codigo de transaccion PADRE para extraccion en efectivo por Recepcion WU cuenta cliente
         v_cod_tra_hijo_cta := v_cod_tra_hij_rec_wu; -- codigo de transaccion para extraccion en efectivo por Recepcion WU  cuenta CLIENTE
         v_cod_tra_hijo_ted := v_cod_tra_hij_rec_wu_ted; -- codigo de transaccion hijo para extraccion en efectivo por Recepcion WU cuenta TED
    ELSIF to_number(vp_operacion) = 15 THEN
         v_cod_tra_padre    := v_cod_tra_pad_tet;--1230 -- codigo de transaccion PADRE para extraccion en efectivo.Tarjetas de debito
         v_cod_tra_hijo_cta := v_cod_tra_hij_etd;--3870 -- codigo de transaccion Hijo para extraccion en efectivo.Tarjetas de debito
         v_cod_tra_hijo_ted := v_cod_tra_tet_ted;-- 602 -- codigo de cta TED Extraccion  en efectivo.Tarjetas de debito
      ELSIF to_number(vp_operacion) = 25 THEN
         v_cod_tra_padre    := v_cod_tra_pad_tet;--1230-- codigo de transaccion PADRE para extraccion en efectivo.Tarjetas de credito
         v_cod_tra_hijo_cta := v_cod_tra_hij_etc;--3871 -- codigo de transaccion Hijo para extraccion en efectivo.Tarjetas de credito
         v_cod_tra_hijo_ted := v_cod_tra_tet_ted;-- 602 -- codigo de cta TED Extraccion  en efectivo.Tarjetas de credito

      ELSIF to_number(vp_operacion) = 27 THEN
          v_cod_tra_padre := 990;
      ELSIF to_number(vp_operacion) = 5 THEN
          v_cod_tra_padre    := 482;  -- codigo de transaccion PADRE para extraccion en efectivo cuenta cliente
          v_cod_tra_hijo_cta := 678;  -- codigo de transaccion hijo para extraccion en efectivo cuenta cliente
          v_cod_tra_hijo_ted := 602;  -- codigo de transaccion para extraccion en efectivo cuenta TED
   ELSIF to_number(vp_operacion) = 85 THEN
        v_cod_tra_padre    := v_cod_tra_pad_dep; -- codigo de transaccion PADRE DE PAGOS DE SERVICIOS
        v_cod_tra_hijo_cta := v_cod_tra_hij_ext_ser; -- codigo de transaccion para extraccion en efectivo POR SERVICIOS cuenta CLIENTE
        v_cod_tra_hijo_ted := v_cod_tra_hij_ext_ser_ted; -- codigo de transaccion hijo para extraccion en efectivo POR SERVICIOS cuenta TED
      ELSIF to_number(vp_operacion) = 75 THEN
         v_cod_tra_padre    := v_cod_tra_pad_oen; -- codigo de transaccion PADRE para extraccion en efectivo OTRAS ENTIDADES
         v_cod_tra_hijo_cta := v_cod_tra_hij_oen; -- codigo de transaccion para extraccion en efectivo OTRAS ENTIDADES
         v_cod_tra_hijo_ted := v_cod_tra_hij_oen_ted; -- codigo de transaccion hijo para extraccion en efectivo por OTRAS ENTIDADES
      END IF;
    END IF;
    IF nvl(to_number(vp_cta_debito), 0) != 0 THEN
      -- Carga los parametros de movimientos de Debito
      r_gmovi.cod_modulo    := v_mod_cta_deb;
      r_gmovi.cod_modalidad := v_mad_cta_deb;
      r_gmovi.cod_oficina   := v_ofi_cta_deb;
      r_gmovi.nro_cuenta    := vp_cta_debito;
      r_gmovi.cod_moneda    := v_cod_moneda;
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
        r_gmovi.cod_transaccion := v_cod_tra_hijo_cta;
        IF lf_exi_banco(vp_bco_atm) = 'B' THEN
          r_gmovi.cod_banco := vp_bco_atm;
        ELSE
          r_gmovi.nro_documento2 := vp_bco_atm;
        END IF;
      END IF;
      r_gmovi.monto          := v_importe;
      r_gmovi.nro_documento  := v_nro_documento;
      r_gmovi.nro_documento3 := v_nro_documento3;
    
      r_gmovi.cod_tasa       := NULL;
      r_gmovi.val_tasa       := NULL;
      r_gmovi.cotizacion     := NULL;
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
        lp_upd_cta_debito;
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
        lp_upd_cta_debito;
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
     /* lp_env_notificacion(vp_cta_debito,
                          v_importe,
                          v_nro_documento,
                          to_number(vp_operacion),
                          v_hora);*/
    END IF;
    IF v_es_banco = 'S' AND to_number(vp_cta_credito) <> 0 THEN
      -- Carga los parametros de movimientos de Credito
      v_nro_secuencia       := v_nro_secuencia + 1;
      r_gmovi.cod_modulo    := v_mod_cta_cre;
      r_gmovi.cod_modalidad := v_mad_cta_cre;
      r_gmovi.cod_oficina   := v_ofi_cta_cre;
      r_gmovi.nro_cuenta    := vp_cta_credito;
      r_gmovi.cod_moneda    := v_cod_moneda;
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
        r_gmovi.cod_transaccion := v_cod_tra_hijo_ted;
        r_gmovi.tip_mov_rubro   := 'C';
        r_gmovi.cod_rubro       := v_cod_rub_caja;
      ELSE
        r_gmovi.cod_transaccion := v_cod_tra_hijo_ted;
      END IF;
      IF lf_exi_banco(vp_bco_atm) = 'B' THEN
        r_gmovi.cod_banco := vp_bco_atm;
      ELSE
        r_gmovi.nro_documento2 := vp_bco_atm;
      END IF;
      r_gmovi.monto          := v_importe;
      r_gmovi.nro_documento  := v_nro_documento;
      r_gmovi.nro_documento3 := v_nro_documento3;
    
      r_gmovi.cod_tasa       := NULL;
      r_gmovi.val_tasa       := NULL;
      r_gmovi.cotizacion     := NULL;
      r_gmovi.cod_ofi_origen := v_ofi_origen;
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.concepto       := v_concepto;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
    
      if v_mod_cta_cre = 4 then
          v_tip_transaccion := lf_obt_tipo(r_gmovi.cod_transaccion,
                                           v_mod_cta_cre,
                                           v_mad_cta_cre);
          if v_tip_transaccion = 'C' then
            v_importe := v_importe * (-1);
          end if;
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
  END lp_pro_ope_extracciones;
  --
  PROCEDURE lp_pro_ope_reversa IS
    v_exi_movi     VARCHAR2(1) := 'N';
    v_fec_anterior ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_ant_hab(v_fec_proceso,
                                                                           NULL,
                                                                           1);
    v_hora_oper    varchar2(9);
  
  BEGIN
    -- Un extor2no no se puede desaprobar...
    -- Se busca el siguiente segundo para no tener problemas...
    v_hora_oper := substr(vp_hora, 1, 2) || ':' || substr(vp_hora, 3, 2) || ':' ||
                   substr(vp_hora, 5, 2);
    v_hora      := pag_gen.fu_obt_sig_segundo(v_hora);
  
    vp_cod_respuesta := vr_aprobado; -- Aprobado
    BEGIN
      SELECT DISTINCT 'S'
        INTO v_exi_movi
        FROM ge_movimientos a
       WHERE a.nro_documento = v_nro_documento
        AND a.cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep, v_cod_tra_pad_oen,v_cod_tra_pad_dep_oen)
         AND (fup_exi_gru_transac(v_gru_reversiones,
                                  a.cod_tra_padre,
                                  a.cod_mod_padre,
                                  a.cod_mad_padre) = 'S')
         AND NOT EXISTS (SELECT DISTINCT 'S'
                FROM ge_movimientos
               WHERE nro_documento = a.nro_documento
                 AND cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep,v_cod_tra_pad_oen, v_cod_tra_pad_dep_oen)
                 AND monto < 0
                 AND (fup_exi_gru_transac(v_gru_reversiones,
                                          cod_tra_padre,
                                          cod_mod_padre,
                                          cod_mad_padre) = 'S'))
         AND NOT EXISTS
       (SELECT DISTINCT 'S'
                FROM ge_movimientos_noc
               WHERE nro_documento = a.nro_documento
               AND cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep,v_cod_tra_pad_oen, v_cod_tra_pad_dep_oen)
                 AND monto < 0
                 AND (fup_exi_gru_transac(v_gru_reversiones,
                                          cod_tra_padre,
                                          cod_mod_padre,
                                          cod_mad_padre) = 'S'));
    
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_exi_movi
            FROM ge_movimientos_noc a
           WHERE a.nro_documento = v_nro_documento
            AND a.cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep,v_cod_tra_pad_oen, v_cod_tra_pad_dep_oen)
             AND (fup_exi_gru_transac(v_gru_reversiones,
                                      a.cod_tra_padre,
                                      a.cod_mod_padre,
                                      a.cod_mad_padre) = 'S')
             AND NOT EXISTS (SELECT DISTINCT 'S'
                    FROM ge_movimientos_noc
                   WHERE nro_documento = a.nro_documento
                    AND a.cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep,v_cod_tra_pad_oen, v_cod_tra_pad_dep_oen)
                     AND monto < 0
                     AND (fup_exi_gru_transac(v_gru_reversiones,
                                              cod_tra_padre,
                                              cod_mod_padre,
                                              cod_mad_padre) = 'S'))
             AND NOT EXISTS
           (SELECT DISTINCT 'S'
                    FROM ge_movimientos
                   WHERE nro_documento = a.nro_documento
                    AND a.cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep,v_cod_tra_pad_oen, v_cod_tra_pad_dep_oen)
                     AND monto < 0
                     AND (fup_exi_gru_transac(v_gru_reversiones,
                                              cod_tra_padre,
                                              cod_mod_padre,
                                              cod_mad_padre) = 'S'));
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              SELECT DISTINCT 'S'
                INTO v_exi_movi
                FROM gv_movimientos a
               WHERE a.nro_documento = v_nro_documento
                AND a.cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep,v_cod_tra_pad_oen, v_cod_tra_pad_dep_oen)
                 AND a.fecha BETWEEN v_fec_anterior AND v_fec_proceso
                 AND (fup_exi_gru_transac(v_gru_reversiones,
                                          a.cod_tra_padre,
                                          a.cod_mod_padre,
                                          a.cod_mad_padre) = 'S')
                 AND NOT EXISTS
               (SELECT DISTINCT 'S'
                        FROM ge_movimientos_noc
                       WHERE nro_documento = a.nro_documento
                        AND cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep,v_cod_tra_pad_oen, v_cod_tra_pad_dep_oen)
                         AND monto < 0
                         AND (fup_exi_gru_transac(v_gru_reversiones,
                                                  cod_tra_padre,
                                                  cod_mod_padre,
                                                  cod_mad_padre) = 'S'))
                 AND NOT EXISTS
               (SELECT DISTINCT 'S'
                        FROM ge_movimientos
                       WHERE nro_documento = a.nro_documento
                        AND cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep,v_cod_tra_pad_oen, v_cod_tra_pad_dep_oen)
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
                          AND cod_tra_padre IN(393,482,395,v_cod_tra_pad_rec_wu,v_cod_tra_pad_tet,v_cod_tra_pad_vuelto,v_cod_tra_pad_dep,v_cod_tra_pad_oen, v_cod_tra_pad_dep_oen)
                         AND fecha BETWEEN v_fec_anterior AND v_fec_proceso
                         AND (fup_exi_gru_transac(v_gru_reversiones,
                                                  cod_tra_padre,
                                                  cod_mod_padre,
                                                  cod_mad_padre) = 'S'));
            EXCEPTION
              WHEN no_data_found THEN
                v_exi_movi       := 'N';
                vp_cod_respuesta := vr_rev_no_encontrada;
                v_msj_error      := 'No se encuentra movimiento a reversar';
            END;
        END;
        lp_car_salida;
    END;
    IF to_number(vp_operacion) = 04 AND v_exi_movi = 'S' THEN
      lp_pro_ope_cheques; --Reversa de Depósito en cheque
    ELSIF to_number(vp_operacion) IN (5,66, 63,75,15,25,85) AND v_exi_movi = 'S' THEN
      lp_pro_ope_extracciones; --Reversa de Extraccion / extraccion por vuelto / extraccion por recepcion / extracciones TC debito / Extracciones TC Credito / Extr. de saldo pago de servicios
    ELSIF to_number(vp_operacion) IN (3,64,73) AND v_exi_movi = 'S' THEN
      --Verifica la moneda-------
      IF vp_moneda = '01' THEN
        lp_pro_ope_depositos; --Reversa del deposito 
        lp_obt_cargos_comision; --Reversa de las comisiones del deposito en moneda dólares
      ELSE
        lp_val_mar_retencion;--Se valida si la cuenta posee indicador de retención de saldo.
        IF v_dep_ret_mark = 0 THEN
         IF to_number(vp_operacion) = 64 THEN
            -- Pago de servicios - (Depósito de dinero)
            v_cod_tra_padre     := v_cod_tra_pad_dep;
            v_cod_tra_hijo_cta  := v_cod_tra_hij_dep;
            v_cod_tra_hijo_ted  := v_cod_tra_hij_dep_ted;
         ELSE
            -- Codigo de transaccion para depositos normales
           v_cod_tra_padre    := to_number(fug_obt_pardinamico('COD_TRA_PADRE_DEP_EFE_TED'));
           v_cod_tra_hijo_cta := to_number(fug_obt_pardinamico('COD_TRA_HIJO_DEP_EFE_TED'));
           v_cod_tra_hijo_ted := to_number(fug_obt_pardinamico('COD_TRA_CTA_TED_DEP_EFE_TED'));
         END IF;
        END IF;
        lp_pro_ope_depositos; --Reversa del deposito (03) / deposito efectivo como pago de servicios (64) / depoósito de cuentas con retencion (70)
        END IF;
    --
    END IF;
  END lp_pro_ope_reversa;

  PROCEDURE lp_obt_dat_tra_atm(p_cod_tra_padre       IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
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
  END lp_obt_dat_tra_atm;
  --Comision
 
  FUNCTION lf_ver_cta_cnb RETURN VARCHAR2 IS
    v_cta_cnb  VARCHAR2(10);
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
    vp_cod_respuesta  := vr_aprobado;
    vp_can_extractos  := '000';
    vp_sig_disponible := '+';
    vp_sig_contable   := '+';
    vp_sal_disponible := lpad('0', 15, '0');
    vp_sal_contable   := lpad('0', 15, '0');
    lp_car_salida;
    lp_obt_respuesta;
  ELSE
    -- no es CNB realiza la autorizacion de siempre
  
    -- Carga los valores iniciales
    lp_car_val_inicial;
    ---
    IF nvl(to_number(vp_cta_debito), 0) != 0 AND
       vp_cod_respuesta = vr_aprobado THEN
      -- Debo verificar si existe la cuenta
      IF v_ind_ctacontable = 'N' THEN
        pag_cta.pr_obt_cuenta(vp_cta_debito);
      ELSE
        pag_cta.g_ctas.sal_disponible := 0;
        pag_cta.g_ctas.sal_actual     := 0;
      END IF;
      lp_dat_cta(vp_cta_debito,
                 v_mod_cta_deb,
                 v_mad_cta_deb,
                 v_ofi_cta_deb,
                 v_mon_cta_deb);
      g_cod_error := pag_cta.g_cod_error;
      IF g_cod_error = 12 THEN
        -- Cuenta inexistente
        vp_cod_respuesta := vr_cta_inexistente; -- Tarjeta desconocida
        v_msj_error      := 'Cuenta Débito Inexistente';
      END IF;
    END IF;
    IF vp_cod_respuesta = vr_aprobado THEN
      -- Verifica el estado de la cuenta
      v_est_cuenta := pag_cta.fu_obt_est_cuenta;
     IF v_est_cuenta = 'A' and vp_operacion = 5 then
         vp_cod_respuesta := vr_cta_inex_ahorro; -- Transaccion no aprobada
         v_msj_error      := 'Estado de la Cuenta Débito Abierta. Estado: ' || v_est_cuenta;
         
     ELSE
      IF v_est_cuenta NOT IN ('N', 'I', 'A') THEN
        IF v_est_cuenta in ('T','D','B') AND vp_operacion = 5 THEN
            vp_cod_respuesta := vr_cta_bloqueada; -- Transaccion no aprobada
            v_msj_error      := 'Estado de la Cuenta Débito Bloqueado. Estado: ' || v_est_cuenta;
        END IF;
        IF v_est_cuenta in ('T','B') AND vp_operacion IN(3) THEN
            vp_cod_respuesta := vr_cta_bloqueada; -- Transaccion no aprobada
            v_msj_error      := 'Estado de la Cuenta Débito Bloqueado. Estado: ' || v_est_cuenta;
        END IF;
      ELSE
        --Verifica si es una cta. combinada
        IF v_cta_com = 'S' THEN
          vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
        END IF;
      END IF;
    END IF;
   END IF;
    IF vp_operacion IN (41) AND nvl(to_number(vp_cta_credito), 0) != 0 AND
       vp_cod_respuesta = vr_aprobado THEN
      -- Debo verificar si existe la cuenta
      IF v_ind_ctacontable = 'N' THEN
        pag_cta.pr_obt_cuenta(vp_cta_credito);
      ELSE
        pag_cta.g_ctas.sal_disponible := 0;
        pag_cta.g_ctas.sal_actual     := 0;
      END IF;
      lp_dat_cta(vp_cta_credito,
                 v_mod_cta_cre,
                 v_mad_cta_cre,
                 v_ofi_cta_cre,
                 v_mon_cta_cre);
      g_cod_error := pag_cta.g_cod_error;
      IF g_cod_error = 12 THEN
        -- Cuenta inexistente
        vp_cod_respuesta := vr_cta_inexistente; -- Tarjeta desconocida
        v_msj_error      := 'Cuenta Crédito Inexistente';
      END IF;
    
      IF vp_cod_respuesta = vr_aprobado THEN
        -- Verifica el estado de la cuenta
        v_est_cuenta := pag_cta.fu_obt_est_cuenta;
        IF v_est_cuenta NOT IN ('N', 'S', 'I', 'D', 'A') THEN
          -- No es normal o con bloqueo de saldo
          -- Estado Inactivo tambien debe permitir.
          vp_cod_respuesta := vr_cta_bloqueada; -- Transaccion no aprobada
          v_msj_error      := 'Estado de la Cuenta Crédito Inválido. Estado: ' ||
                              v_est_cuenta;
        ELSE
          --Verifica si es una cta. combinada
          IF v_cta_com = 'S' THEN
            vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
          END IF;
        END IF;
      END IF;
    END IF;
  
    IF vp_cod_respuesta = vr_aprobado THEN
      IF to_number(vp_extorno) != 99 THEN
        IF to_number(vp_operacion) IN (2, 52, 93) THEN
          -- Consulta de Saldo
          lp_ver_ope_consulta;
        ELSIF to_number(vp_operacion) IN (3,64,68,73) THEN
          -- Depósito EFECTIVO/ deposito efectivo como pago de servicios
          lp_ver_ope_depositos;
        ELSIF to_number(vp_operacion) = 4 THEN
          if lf_che_banco = 'N' then 
            -- Deposito Cheque
               vp_cod_respuesta := vr_aprobado; -- Transaccion aprobada por Cheques otros bancos sin generación de movimientos
            else
               vp_cod_respuesta := vr_aprobado; -- Transaccion aprobada por Cheques propios sin generación de movimientos
            end if;
        ELSIF to_number(vp_operacion) IN (5,63,66,67,75,85,15,25) THEN
           -- Extraccion efectivo (05) / extraccion por vuelto en efectivo (66)/Extraccion por recepción de WU(63) / Descarga TED / / extracciones TC debito / Extracciones TC Credito / Extr. de saldo pago de servicios
          lp_ver_ope_extracciones;
        ELSIF v_clt_deb_nuestro = 'S' THEN
          vp_cod_respuesta := vr_ope_invalida;
        END IF;
      ELSE
        -- Reversion
        lp_ver_ope_reversa;
      END IF;
    
    END IF;
    -- Verifica el estado del modulo por si se este haciendo el cierre
    v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
    IF v_est_modulo IN (1, 6) THEN
      -- Se esta corriendo el proceso de cierre
      vp_cod_respuesta := vr_en_cierre; -- En cierre
    END IF;
    -- Carga los datos de salida
    -- lp_car_salida;
    --Validar codigo de operacion
    IF instr(v_cod_ope_ted,to_number(vp_operacion)) = 0 THEN
      vp_cod_respuesta := vr_ope_invalida; -- Transaccion no aprobada
      v_msj_error      := 'Código de operación inválida';
    END IF;
    -- Si la respuesta fue aprobado, Debe procesar la transaccion --
    IF vp_cod_respuesta = vr_aprobado THEN
      IF to_number(vp_extorno) != 99 THEN
        IF to_number(vp_operacion) IN (2, 52, 93) THEN
          -- Consulta de Saldo
          lp_pro_ope_consulta;
        ELSIF to_number(vp_operacion) IN (3,64,68,73) THEN
          -- Depósito EFECTIVO (03) / Deposito efectivo como pago de servicios (64)
          lp_pro_ope_depositos;
        ELSIF to_number(vp_operacion) IN (5,63,66,67,75,85,15,25) THEN
          -- Extraccion efectivo (05) / extraccion por vuelto en efectivo (66)/Extraccion por recepción de WU(63) / Descarga TED / / extracciones TC debito / Extracciones TC Credito / Extr. de saldo pago de servicios
          lp_pro_ope_extracciones;
        ELSIF to_number(vp_operacion) = 4 THEN
          if lf_che_banco = 'N' then 
             --Depósito de cheques
               vp_cod_respuesta := vr_aprobado; -- Transaccion aprobada por Cheques otros bancos sin generación de movimientos
            else
               vp_cod_respuesta := vr_aprobado; -- Transaccion aprobada por Cheques propios sin generación de movimientos
            end if;
        END IF;   
    IF to_number(vp_operacion) = 3 THEN 
      -- Se verifican los cargos de comision por Deposito / USD
      lp_obt_cargos_comision; --Comisión por operación con moneda extranjera
      v_sal_disponible  := nvl(v_sal_disponible, 0) - nvl(v_cargos, 0);
      v_sal_contable  := nvl(v_sal_contable, 0) - nvl(v_cargos, 0);
      -- Carga la respuesta --
      vp_sal_disponible := lpad(TRIM(to_char(abs(v_sal_disponible * 100))), 15,'0');
      IF v_sal_disponible < 0 THEN
        vp_sig_disponible := '-';
      END IF;
      vp_sal_contable := lpad(TRIM(to_char(abs(v_sal_contable * 100))),15,'0');
      IF v_sal_contable < 0 THEN
        vp_sig_contable := '-';
      END IF;
    END IF;
      ELSE
        lp_pro_ope_reversa;
      END IF;
    END IF;
    -- Carga los datos de salida
    lp_car_salida;
    lp_obt_respuesta;
  END IF;
  --
  lp_reg_operacion(substr(v_pedido, 1, 4000),
                   substr(vp_respuesta, 1, 4000),
                   substr(v_msj_error, 1, 4000),
                   v_fec_inicio,
                   vp_extorno,
                   v_fec_valor,
                   v_nro_documento,
                   vp_cta_debito,
                   v_hora,
                   vp_bco_debito,
                   vp_cta_credito,
                   vp_bco_credito,
                   vp_operacion,
                   v_importe,
                   vp_moneda,
                   vp_nro_atm,
                   vp_nro_pos,
                   vp_tra_pos,
                   vp_tip_hora,
                   vp_negocio,
                   vp_tra_extornado,
                   vp_bco_atm,
                   vp_servicio,
                   vp_prestacion,
                   vp_marca,
                   vp_producto,
                   vp_med_pago);
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
    lp_reg_operacion(substr(v_pedido, 1, 4000),
                     substr(vp_respuesta, 1, 4000),
                     substr(v_msj_error, 1, 4000),
                     v_fec_inicio);
    RETURN vp_respuesta;
END;
/
