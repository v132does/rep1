CREATE OR REPLACE PROCEDURE IT.prg_gen_mov_noc_spi(p_monto                 IN ge_movimientos.monto%TYPE,
                                                   p_nro_cta_deb           IN ge_movimientos.nro_cuenta%TYPE,
                                                   p_nro_cta_cre           IN ge_movimientos.nro_cuenta%TYPE,
                                                   p_cod_moneda            IN ge_movimientos.cod_moneda%TYPE,
                                                   p_cod_swift             IN ge_snp_transferencias.cod_msj_swift%TYPE,
                                                   p_cod_tip_operacion     IN ge_snp_transferencias.cod_tip_operacion %TYPE,
                                                   p_cod_sub_tip_operacion IN ge_snp_transferencias.cod_sub_tip_operacion%TYPE,
                                                   p_nro_referencia        IN ge_snp_transferencias.nro_referencia%TYPE,
                                                   p_nro_ref_externa       IN ge_snp_transferencias.nro_ref_externa%TYPE,
                                                   p_referencia            IN ge_movimientos.referencia%TYPE,
                                                   p_ind_transaccion       IN varchar2,
                                                   p_ind_reverso           IN varchar2,
                                                   p_fecha                 IN ge_movimientos.fecha%TYPE,
                                                   p_hora                  IN ge_movimientos.hora%TYPE,
                                                   p_cod_usuario           IN ge_movimientos.cod_usuario%TYPE,
                                                   p_cod_usu_reversion     IN ge_movimientos.cod_usu_reversion%TYPE DEFAULT USER,
                                                   p_hor_reversion         IN ge_movimientos.hor_reversion%TYPE,
                                                   p_cod_respuesta         OUT number,
                                                   p_nom_respuesta         OUT varchar2,
                                                   p_nro_ref_original      IN varchar2 default null,
                                                   p_par_cargo             IN varchar2 default null,
                                                   p_consumidor            IN varchar2 default null,
                                                   p_cod_tra_pad_debito    IN NUMBER DEFAULT NULl,
                                                   p_cod_tra_pad_credito   IN NUMBER DEFAULT NULL,
                                                   p_cod_mod_pad_debito    IN NUMBER DEFAULT NULL,
                                                   p_cod_mod_pad_credito   IN NUMBER DEFAULT NULL,
                                                   p_cod_mad_pad_debito    IN NUMBER DEFAULT NULL,
                                                   p_cod_mad_pad_credito   IN NUMBER DEFAULT NULL,
                                                   p_cod_tra_debito        IN NUMBER DEFAULT NULL,
                                                   p_cod_tra_credito       IN NUMBER DEFAULT NULL  ) IS

  v_hor_limite  VARCHAR2(8) := '999999';
  v_est_modulo  ba_modulos.estado%TYPE;
  v_est_cuenta  ge_cuentas.estado%TYPE;
  v_est_cta_cre ge_cuentas.estado%TYPE;
  -- Variables de la Cuenta
  v_mod_cta_deb     ge_movimientos.cod_modulo%TYPE;
  v_mad_cta_deb     ge_movimientos.cod_modalidad%TYPE;
  v_mon_cta_deb     ge_movimientos.cod_moneda%TYPE;
  v_ofi_cta_deb     ge_movimientos.cod_oficina%TYPE;
  v_mod_cta_cre     ge_movimientos.cod_modulo%TYPE;
  v_mad_cta_cre     ge_movimientos.cod_modalidad%TYPE;
  v_mon_cta_cre     ge_movimientos.cod_moneda%TYPE;
  v_ofi_cta_cre     ge_movimientos.cod_oficina%TYPE;
  v_ind_ctacontable VARCHAR2(1) := 'N';
  v_mod_contable    ge_movimientos.cod_modulo%TYPE;
  v_mad_contable    ge_movimientos.cod_modalidad%TYPE;
  v_cta_com         ah_cta_vistas.cta_combinada%TYPE; --Indicador si es cta. combinada
  v_cod_cliente     ge_cta_clientes.cod_persona%TYPE;
  --- Variables del movimiento...
  v_fec_proceso     ge_movimientos.fecha%TYPE;
  v_fec_valor       ge_movimientos.fecha%TYPE;
  v_cod_moneda      ba_monedas.cod_moneda%TYPE := p_cod_moneda;
  v_acu_sobregiro   cc_cta_corrientes.acu_sobregiro%TYPE;
  v_importe         ge_movimientos.monto%TYPE := p_monto;
  v_ofi_origen      cj_movimientos.cod_oficina%TYPE;
  v_hora            cj_movimientos.hora%TYPE := fug_obt_mov_hora;
  v_nro_documento   ge_movimientos.nro_documento%TYPE := p_nro_referencia;
  v_nro_documento2  ge_movimientos.nro_documento2%TYPE;
  v_referencia      ge_movimientos.referencia%type := p_referencia;
  v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE := 0;
  v_concepto        ge_movimientos.concepto%TYPE := p_nro_ref_externa;
  v_cod_modulo      ge_movimientos.cod_modulo%TYPE := 4;
  v_cod_modalidad   ge_movimientos.cod_modalidad%TYPE := 455;
  v_cod_usuario     ge_movimientos.cod_usuario%TYPE := upper(USER);
  v_msj_error       varchar2(4000) := 'OK';
  v_cod_tra_padre   ge_movimientos.cod_tra_padre%type := pas_snp.fu_obt_cod_tra_padre; -- cod. transaccion padre
  v_cod_tra_pad_deb ge_movimientos.cod_tra_padre%type := pas_snp.fu_obt_cod_tra_padre; -- cod. transaccion padre
  v_cod_tra_pad_cre ge_movimientos.cod_tra_padre%type := pas_snp.fu_obt_cod_tra_padre; -- cod. transaccion padre
  v_cod_modulo_deb      ge_movimientos.cod_modulo%TYPE := 4;
  v_cod_modulo_cre      ge_movimientos.cod_modulo%TYPE := 4;
  v_cod_modalidad_deb   ge_movimientos.cod_modalidad%TYPE := 455;
  v_cod_modalidad_cre   ge_movimientos.cod_modalidad%TYPE := 455;
  v_cod_tra_credito ge_movimientos.cod_transaccion%type; -- cod. transaccion hijo credito
  v_cod_tra_debito  ge_movimientos.cod_transaccion%type := 503; -- cod. transaccion hijo debito
  v_mod_padre       ge_movimientos.Cod_Mod_Padre%type;
  v_mad_padre       ge_movimientos.Cod_Mad_Padre%type;
  v_tra_debito      ge_movimientos.Cod_Transaccion%type;
  v_mto_cargo         ge_movimientos.monto%type    := 0;
  v_val_tas_cargo     ge_movimientos.val_tasa%type := NULL;
  v_cod_tasa          ba_cod_referencias.abreviatura%type;
  v_cod_tas_impuesto  ge_tasas.cod_tasa%type       := NULL;
  v_val_tas_impuesto  ge_movimientos.val_tasa%type := NULL;
  v_mto_impuesto      ge_movimientos.monto%type    := 0;
  v_tra_impuesto      ba_cod_referencias.abreviatura%type;
  v_tra_cargo         ba_cod_referencias.abreviatura%type;
  v_des_error         varchar2(4000);
  ex_comision         exception;
  --
  -- Posibles Respuestas --
  vr_aprobado         NUMBER(10) := 0;
  vr_no_aprobado      NUMBER(10) := 5;
  vr_cta_inexistente  NUMBER(10) := 14;
  vr_ope_invalida     NUMBER(10) := 12;
  vr_sal_insuficiente NUMBER(10) := 51;
  vr_otr_error        NUMBER(10) := 99;
  vr_en_cierre        NUMBER(10) := 91;
  vr_reintente        NUMBER(10) := 19;
  g_cod_error         pag_cta.g_cod_error%TYPE;
  g_lugar    varchar2(250);
  -- Variables para manejar los parametros --
  vp_cta_debito  VARCHAR2(35) := p_nro_cta_deb;
  vp_cta_credito VARCHAR2(35) := p_nro_cta_cre;
  vp_operacion   VARCHAR2(2);
  vp_importe     VARCHAR2(15);
  vp_fecha       VARCHAR2(8);
  vp_hora        VARCHAR2(6);

  -- De salida...
  vp_cod_respuesta  NUMBER(10) := 0;
  vp_sal_disponible VARCHAR2(15);
  vp_respuesta      VARCHAR2(2000);

  v_horario         VARCHAR2(1) := 'D'; -- (D) Dia, (T) Tarde, (N) Nocturno
  v_es_nocturno     VARCHAR2(1) := 'N';
  v_es_cta_noc      VARCHAR2(1) := 'N';
  r_gmovi           ge_movimientos%ROWTYPE;
  v_gru_reversiones GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('NULL');
  rg_mensaje        pas_snp.rg_msj;
  rg_msj_transferencia pas_snp.rg_msj;
  v_user           cj_cajas.cod_usuario%TYPE:=user;
  CURSOR cur_gmono IS
    SELECT fecha,
           hora,
           cod_usuario,
           nro_secuencia,
           fec_valor,
           monto,
           nro_cuenta,
           cod_moneda,
           cod_oficina,
           cod_error,
           cod_retencion,
           fec_fin_retencion,
           est_cuenta,
           estado,
           cod_causa,
           cod_banco,
           cod_ofi_origen,
           concepto,
           cod_tasa,
           val_tasa,
           cod_rubro,
           cod_ref_cambio,
           reversado,
           cod_usu_reversion,
           hor_reversion,
           emi_aviso,
           cod_tra_padre,
           cod_mod_padre,
           cod_mad_padre,
           cod_transaccion,
           cod_modulo,
           cod_modalidad,
           mto_equ_local,
           nro_caja,
           cotizacion,
           cod_bco_central,
           nro_documento,
           nro_documento2,
           nro_documento3,
           nro_documento4,
           protegido,
           cod_autorizacion,
           cod_usu_autorizador,
           usu_insercion,
           fec_insercion,
           usu_modificacion,
           fec_modificacion,
           tip_mov_rubro,
           cod_tip_ope_cambio,
           referencia,
           cod_persona,
           cod_sit_contable,
           nro_conciliacion
      FROM ge_movimientos_noc
     WHERE fecha = p_fecha
       AND hora = p_hora
       AND cod_usuario = p_cod_usuario
       AND reversado = 'N'
       AND nro_cuenta in (vp_cta_debito,vp_cta_credito)
     ORDER BY nro_secuencia DESC;
  /*Recupera el valor del cargo*/
 PROCEDURE lp_obt_cargo( p_cod_ofi_cta       in     ge_cuentas.cod_oficina%type,
                         p_nro_cuenta        in     ge_cuentas.nro_cuenta%type,
                         p_cod_moneda        in     ge_cuentas.cod_moneda%type,
                         p_val_transaccion   in     ge_movimientos.monto%type,
                         p_cod_modulo        in     ge_cuentas.cod_modulo%type,
                         p_cod_modalidad     in     ge_cuentas.cod_modalidad%type,
                         p_tas_personalizada in     ge_cuentas.tas_personalizada%type,
                         p_cod_tra_cargo     in     ge_movimientos.cod_transaccion%type,
                         p_cod_tas_cargo     in out ge_movimientos.cod_tasa%type,
                         p_val_tas_cargo     out    ge_movimientos.val_tasa%type,
                         p_val_cargo         out    ge_movimientos.val_tasa%type)
   IS
      v_val_transaccion ge_movimientos.monto%type := p_val_transaccion;
      v_fec_vigencia    ge_tas_fechas.fec_vigencia%type;
      v_tip_valor       ge_tasas.tip_valor%type;
      v_tipo            ge_tasas.tipo%type;
      v_redondeo        number(1);
   BEGIN
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', p_cod_modulo, p_cod_modalidad, p_cod_moneda);
       -- busco el valor de la tasa
       pag_gen.pr_obt_val_tasa( p_cod_modulo,
                                p_cod_modalidad,
                                p_cod_ofi_cta,
                                p_nro_cuenta,
                                p_cod_moneda,
                                v_val_transaccion,
                                nvl(p_tas_personalizada,'N'),
                                p_cod_tas_cargo,
                                p_cod_tra_cargo,
                                v_fec_proceso,
                                p_val_tas_cargo,
                                v_fec_vigencia,
                                v_tip_valor,
                                v_tipo);
          if v_tip_valor = 'V' then
             -- si es un valor, se toma directamente
             p_val_cargo := round( nvl(p_val_tas_cargo,0), v_redondeo );
          else
             -- es un porcentaje
             p_val_cargo := round( nvl( v_val_transaccion, 0 ) * nvl( p_val_tas_cargo, 0 ) / 100, v_redondeo );
             --verificar si el monto a cobrar esta limitado x el minimo y maximo de la tasa
             p_val_cargo := pag_gen.fu_obt_val_final(p_val_cargo);
          end if;

          if p_val_cargo < 0 then
             v_des_error := 'Error en LP_OBT_CARGO: Monto del Impuesto más alto que el Monto del Cargo';
          end if;

   EXCEPTION
      when others then
            v_des_error := 'Error en LP_OBT_CARGO: '|| sqlerrm;
   END lp_obt_cargo;
  /* Crea los movimientos para insertarlos en GE_MOVIMIENTOS. */
  PROCEDURE lp_ins_movimientos(rp_gmovi            IN ge_movimientos%ROWTYPE,
                               p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
                               p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
                               p_es_nocturno       IN VARCHAR2 := 'X');

  ---------- Definicion de procesos y funciones locales

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
  PROCEDURE lp_ins_movimientos(rp_gmovi            IN ge_movimientos%ROWTYPE,
                               p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
                               p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
                               p_es_nocturno       IN VARCHAR2 := 'X') IS

    r_gmovi           ge_movimientos%ROWTYPE;
    v_est_anterior    VARCHAR2(1) := NULL;
    v_est_actual      VARCHAR2(1) := NULL;
    v_fec_cam_est_ant DATE := NULL;
    v_fec_ult_mov_ant DATE := NULL;
    v_hor_ult_mov_ant VARCHAR2(8) := NULL;
    v_fec_ult_cap_ant DATE := NULL;
    -- DATOS DE LA REVERSION DE LA CUENTA
    v_afecta             VARCHAR2(1) := 'N';
    v_afe_sal_total      NUMBER := 0;
    v_afe_sal_retenido   NUMBER := 0;
    v_afe_sal_bloqueado  NUMBER := 0;
    v_act_ult_movimiento VARCHAR2(1) := 'N';
    v_tip_movimiento     VARCHAR2(1);
    r_docu               md_cta_documentos%ROWTYPE;

    --variables para reversar servicios: cobro y remisin
    v_remision      VARCHAR2(1) := NULL;
    v_pri_vez       VARCHAR2(1) := 'S';
    v_proveedor     ge_entes.cod_ente%TYPE;
    v_fec_proceso   DATE;
    v_tipo          ge_entes.tipo%TYPE;
    v_nro_cuo_cci   NUMBER(4);
    v_nro_sol_cci   pr_solicitudes.nro_solicitud%TYPE;
    v_nro_cta_cci   pr_cta_prestamos.nro_cuenta%TYPE;
    v_est_solicitud pr_solicitudes.estado%TYPE;
    v_redondeo      NUMBER(2);
    v_est_cuo_cobro pr_cuotas.estado%TYPE;
    -- variables para reversar operaciones vencidas
    r_vcven            ov_cta_vencidas%ROWTYPE;
    v_con_garantia_ven NUMBER(5) := 0;
    v_nro_recibo       ge_pag_proveedores.nro_recibo%TYPE;
    v_cod_error        NUMBER := 0;
    v_fec_actual       ge_calendarios.fec_actual%TYPE;
    v_concepto         ge_movimientos.concepto%type:='RV'||p_nro_ref_externa;
    /* obtiene datos de la transaccion */
    PROCEDURE pr_obt_tip_transaccion(p_cod_transaccion IN ge_transacciones.cod_transaccion%TYPE,
                                     p_cod_modulo      IN ge_transacciones.cod_modulo%TYPE,
                                     p_cod_modalidad   IN ge_transacciones.cod_modalidad%TYPE,
                                     p_tipo            OUT VARCHAR2,
                                     p_afecta          OUT VARCHAR2) IS
    BEGIN
      SELECT tipo, afecta
        INTO p_tipo, p_afecta
        FROM ge_transacciones
       WHERE cod_modulo = p_cod_modulo
         AND cod_modalidad = p_cod_modalidad
         AND cod_transaccion = p_cod_transaccion;
    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20004,
                                'Transaccion inexistente ' ||
                                to_char(nvl(p_cod_modulo, 0)) || '-' ||
                                to_char(nvl(p_cod_modalidad, 0)) || '-' ||
                                to_char(p_cod_transaccion));
      WHEN OTHERS THEN
        raise_application_error(-20005, SQLERRM);
    END;
  BEGIN
--    v_fec_actual := pag_cal.fu_obt_fec_actual(v_cod_modulo);
v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,
                                                1,
                                                v_ofi_origen);
    -- Traspaso los datos del registro leido en el nuevo
    r_gmovi := rp_gmovi;
    r_gmovi.fecha             := nvl(v_fec_actual, rp_gmovi.fecha);
    r_gmovi.fec_valor         := rp_gmovi.fec_valor;
    r_gmovi.hora              := p_hor_reversion;
    r_gmovi.hor_reversion     := rp_gmovi.hora;
    r_gmovi.cod_usuario       := p_cod_usu_reversion;
    r_gmovi.monto             := rp_gmovi.monto * -1;
    r_gmovi.reversado         := 'S';
    r_gmovi.cod_usu_reversion := rp_gmovi.cod_usuario;
    r_gmovi.mto_equ_local     := rp_gmovi.mto_equ_local * -1;
    r_gmovi.concepto          := substr(v_concepto, 1, 100);
    IF r_gmovi.fecha <> r_gmovi.fec_valor THEN
      IF r_gmovi.cod_rubro IS NOT NULL THEN
        DECLARE
          v_rub cb_rubros.cod_rubro%TYPE := NULL;
        BEGIN
          BEGIN
            SELECT cod_rub_reversion
              INTO v_rub
              FROM cb_rub_reversiones
             WHERE cod_rubro = r_gmovi.cod_rubro;
          EXCEPTION
            WHEN OTHERS THEN
              v_rub := NULL;
          END;
          IF v_rub IS NOT NULL THEN
            r_gmovi.cod_rubro := v_rub;
          END IF;
        END;
      END IF;
    END IF;
    pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);

  END lp_ins_movimientos;
  PROCEDURE lp_ver_horario IS
  BEGIN
    v_horario     := 'D'; -- Dia
    v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
    v_es_cta_noc  := 'N';
    v_fec_proceso := pag_cal.fu_obt_fec_actual(3);
    v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
    IF v_est_modulo = 2 THEN
      -- El modulo esta abierto
        v_es_nocturno := 'N';
        v_horario     := 'D';
        v_es_cta_noc  := 'N';
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
          UPDATE cc_cta_bancarias
             SET mto_deb_pendientes = nvl(mto_deb_pendientes, 0) + v_importe
           WHERE nro_cuenta = vp_cta_debito;
        END IF;
      END IF;
    END IF;
  END lp_upd_cta_debito;
  --
  PROCEDURE lp_upd_cta_credito(p_mto_oper in number default null) IS
  BEGIN
    IF v_horario = 'D' THEN
      -- Horario normal --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas
           SET sal_total = nvl(sal_total, 0) + nvl(p_mto_oper,v_importe),
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes
           SET sal_total = nvl(sal_total, 0) + nvl(p_mto_oper,v_importe),
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias
           SET sal_total = nvl(sal_total, 0) + nvl(p_mto_oper,v_importe),
               estado    = decode(estado, 'I', 'N', estado)
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    ELSE
      -- A la Noche o despues del Cierre --
      IF v_mad_cta_cre in (31, 38, 39, 334) THEN
        UPDATE ah_cta_vistas_noc
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + nvl(p_mto_oper,v_importe)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mad_cta_cre = 41 THEN
        UPDATE cc_cta_corrientes_noc
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + nvl(p_mto_oper,v_importe)
         WHERE nro_cuenta = vp_cta_credito;
      ELSIF v_mod_cta_cre = 4 THEN
        UPDATE cc_cta_bancarias
           SET mto_cre_pendientes = nvl(mto_cre_pendientes, 0) + nvl(p_mto_oper,v_importe)
         WHERE nro_cuenta = vp_cta_credito;
      END IF;
    END IF;
  END lp_upd_cta_credito;

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
            --ojo ver otras entidades
            BEGIN
              --la cuenta tiene 0 inicial si la oficina est entre el 1 y 9
              p_nro_cuenta := concat('0', p_nro_cuenta);
              SELECT cod_modulo, cod_modalidad, cod_oficina
                INTO p_cod_modulo, p_cod_modalidad, p_cod_oficina
                FROM ge_cuentas
               WHERE nro_cuenta = p_nro_cuenta;
              --asigna al parmetro la cuenta con el 0 delante
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
      IF p_cod_modalidad IN (31,38,39,334) THEN
        --ojo ver otras modalidades para otras entidades
        SELECT nvl(cta_combinada, 'N'), cod_moneda, 'N'
          INTO v_cta_com, p_cod_moneda, v_acu_sobregiro
          FROM ah_cta_vistas
         WHERE nro_cuenta = p_nro_cuenta;
      ELSIF p_cod_modalidad = 41 THEN
        SELECT cod_moneda, acu_sobregiro
          INTO p_cod_moneda, v_acu_sobregiro
          FROM cc_cta_corrientes
         WHERE nro_cuenta = p_nro_cuenta;
      END IF;
    END IF;
  EXCEPTION
    WHEN no_data_found THEN
      vp_cod_respuesta := vr_cta_inexistente;
      v_msj_error      := 'Cuenta Inexistente(' || p_nro_cuenta || ')';
  END lp_dat_cta;

  PROCEDURE lp_pro_env_transferencia IS
    -- Envio de transferencia --
  v_procesa boolean:=false;
  BEGIN
    if p_consumidor is not null then 
       --Obtiene usuario en base al consumidor recibido
            v_user:=FUE_OBT_VAL_MAX_REFERENCIA('CONSUMIDORES_API',p_consumidor);
            --TTCE-101
            if v_user='PAYMPV' then
             prs_tra_obt_usu_hor_mov_pym(v_user,
                                        v_cod_usuario,
                                        v_hora);
           else
           prs_tra_obt_usu_hor_mov_env(v_user,
                                        v_cod_usuario,
                                        v_hora);
           end if; 
    else 
  --DA-10340
     prs_snp_obt_usu_hor_mov_env('HBANKF',
                                 v_cod_usuario,
                                 v_hora);
    end if; 
    if nvl(p_ind_reverso, 'N') = 'S' then
      FOR c1 IN cur_gmono LOOP
        lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'S');
        v_procesa:=true;
      END LOOP;

     IF v_procesa THEN     
           FOR c1 IN cur_gmono LOOP       
      UPDATE ge_movimientos_noc
         SET reversado         = 'S',
             cod_usu_reversion = p_cod_usu_reversion,
             hor_reversion     = p_hor_reversion
               WHERE fecha = c1.fecha
                 AND hora = c1.hora
                 AND cod_usuario = c1.cod_usuario
                 AND nro_secuencia= c1.nro_secuencia
         AND reversado = 'N';
            END LOOP;
      -- Cambia el signo del importe...
      v_importe := v_importe * -1;

      lp_upd_cta_debito;
      lp_upd_cta_credito;
      END IF;      
    else
      v_ofi_origen     := fug_obt_ofi_usuario(v_cod_usuario);
      v_nro_documento2 := p_cod_swift || p_cod_tip_operacion ||
                          p_cod_sub_tip_operacion;
      --SPI 2
      if p_cod_swift=fug_obt_pardinamico( 'COD_SPI_DEV') then
         v_concepto:='Dev.'||' '||p_nro_ref_original;
      end if;
      IF nvl(to_number(p_nro_cta_deb), 0) != 0 THEN
        if rg_msj_transferencia.ref_oid ='PPV' then
           v_cod_tra_debito := 7503;
         end if;
         --TCE-247
         
         v_cod_tra_debito:=nvl(p_cod_tra_debito,v_cod_tra_debito);
         v_cod_tra_pad_deb:=nvl(p_cod_tra_pad_debito,v_cod_tra_padre);
         v_cod_modulo_deb:=nvl(p_cod_mod_pad_debito,v_cod_modulo);
         v_cod_modalidad_deb:=nvl(p_cod_mad_pad_debito,v_cod_modalidad);
        -- Carga los parametros de movimientos de Debito
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.cod_modulo      := v_mod_cta_deb;
        r_gmovi.cod_modalidad   := v_mad_cta_deb;
        r_gmovi.cod_oficina     := v_ofi_cta_deb;
        r_gmovi.nro_cuenta      := vp_cta_debito;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fec_proceso;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.fec_valor       := v_fec_valor;
        r_gmovi.cod_tra_padre   := v_cod_tra_pad_deb;
        r_gmovi.cod_mod_padre   := v_cod_modulo_deb;
        r_gmovi.cod_mad_padre   := v_cod_modalidad_deb;
        r_gmovi.cod_transaccion := v_cod_tra_debito;
        r_gmovi.monto           := v_importe;
        r_gmovi.nro_documento   := v_nro_documento;
        r_gmovi.nro_documento2  := v_nro_documento2;
        r_gmovi.cod_tasa        := NULL;
        r_gmovi.val_tasa        := NULL;
        r_gmovi.cotizacion      := NULL;
        r_gmovi.cod_ofi_origen  := v_ofi_origen;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.concepto        := v_concepto;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        lp_upd_cta_debito;
      END IF;
      IF to_number(p_nro_cta_cre) <> 0 THEN
        PAS_SNP.pr_obt_par_mensajes(p_cod_swift,
                                    p_cod_tip_operacion,
                                    p_cod_sub_tip_operacion,
                                    'E',
                                    v_cod_modulo,
                                    v_cod_modalidad,
                                    v_cod_tra_credito);
        if rg_msj_transferencia.ref_oid ='PPV' then
           v_cod_tra_credito := 7196;
         end if;
         --TCE-247
         
         v_cod_tra_credito:=nvl(p_cod_tra_credito,v_cod_tra_credito);
         v_cod_tra_pad_cre:=nvl(p_cod_tra_pad_credito,v_cod_tra_padre);
         v_cod_modulo_cre:=nvl(p_cod_mod_pad_credito,v_cod_modulo);
         v_cod_modalidad_cre:=nvl(p_cod_mad_pad_credito,v_cod_modalidad);
        -- Carga los parametros de movimientos de Credito
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.cod_modulo      := v_mod_cta_cre;
        r_gmovi.cod_modalidad   := v_mad_cta_cre;
        r_gmovi.cod_oficina     := v_ofi_cta_cre;
        r_gmovi.nro_cuenta      := vp_cta_credito;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fec_proceso;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.nro_documento2  := v_nro_documento2;
        r_gmovi.fec_valor       := v_fec_valor;
        r_gmovi.cod_tra_padre   := v_cod_tra_pad_cre;
        r_gmovi.cod_mod_padre   := v_cod_modulo_cre;
        r_gmovi.cod_mad_padre   := v_cod_modalidad_cre;
        r_gmovi.cod_rubro       := pac_che.fu_obt_rub_cta_ban(vp_cta_credito);
        r_gmovi.tip_mov_rubro   := 'C';
        r_gmovi.cod_transaccion := v_cod_tra_credito;
        r_gmovi.monto           := v_importe;
        r_gmovi.nro_documento   := v_nro_documento;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_tasa        := NULL;
        r_gmovi.val_tasa        := NULL;
        r_gmovi.cotizacion      := NULL;
        r_gmovi.cod_ofi_origen  := v_ofi_origen;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.concepto        := v_concepto;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        lp_upd_cta_credito;
      END IF;
    end if;
  END lp_pro_env_transferencia;
  PROCEDURE lp_pro_rec_transferencia IS
    -- transferencia Recibida--
  BEGIN
    prs_snp_obt_usu_hor_movimiento(user,'N',v_cod_usuario,v_hora);
    if nvl(p_ind_reverso, 'N') = 'S' then
      lp_upd_cta_debito;
      lp_upd_cta_credito;
    else
      v_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);
      v_nro_documento2 := p_cod_swift || p_cod_tip_operacion ||
                          p_cod_sub_tip_operacion;
      --SPI 2
      if p_cod_swift=fug_obt_pardinamico( 'COD_SPI_DEV') then
         v_concepto:='Dev.'||' '||p_nro_ref_original;
      end if;
      IF nvl(to_number(p_nro_cta_deb), 0) != 0 THEN
        --cuenta interbancaria
        pas_snp.pr_obt_par_mensajes(p_cod_swift,
                                    p_cod_tip_operacion,
                                    p_cod_sub_tip_operacion,
                                    'R',
                                    v_mod_padre,
                                    v_mad_padre,
                                    v_tra_debito);
        -- Carga los parametros de movimientos de Debito
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.cod_modulo      := v_mod_cta_deb;
        r_gmovi.cod_modalidad   := v_mad_cta_deb;
        r_gmovi.cod_oficina     := v_ofi_cta_deb;
        r_gmovi.nro_cuenta      := vp_cta_debito;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fec_proceso;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.nro_documento2  := v_nro_documento2;
        r_gmovi.fec_valor       := v_fec_valor;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_mod_padre   := v_mod_padre;
        r_gmovi.cod_mad_padre   := v_mad_padre;
        r_gmovi.cod_rubro       := pac_che.fu_obt_rub_cta_ban(p_nro_cta_deb);
        r_gmovi.tip_mov_rubro   := 'D';
        r_gmovi.cod_transaccion := v_tra_debito;
        r_gmovi.monto           := v_importe;
        r_gmovi.nro_documento   := v_nro_documento;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_tasa        := NULL;
        r_gmovi.val_tasa        := NULL;
        r_gmovi.cotizacion      := NULL;
        r_gmovi.cod_ofi_origen  := v_ofi_origen;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.concepto        := v_concepto;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        lp_upd_cta_debito;
      END IF;
      IF to_number(p_nro_cta_cre) <> 0 THEN
        --cliente
        -- Carga los parametros de movimientos de Credito

        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.cod_modulo      := v_mod_cta_cre;
        r_gmovi.cod_modalidad   := v_mad_cta_cre;
        r_gmovi.cod_oficina     := v_ofi_cta_cre;
        r_gmovi.nro_cuenta      := vp_cta_credito;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fec_proceso;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.fec_valor       := v_fec_valor;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.cod_transaccion := 602;
        r_gmovi.monto           := v_importe;
        r_gmovi.referencia      := NULL;
        r_gmovi.nro_documento   := v_nro_documento;
        r_gmovi.nro_documento2  := v_nro_documento2;
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.cod_tasa        := NULL;
        r_gmovi.val_tasa        := NULL;
        r_gmovi.cotizacion      := NULL;
        r_gmovi.tip_mov_rubro   := NULL;
        r_gmovi.cod_ofi_origen  := v_ofi_origen;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.concepto        := v_concepto;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        lp_upd_cta_credito;
      END IF;
      --SPI 2 Cobro de cargos
      if p_par_cargo is not null then
        --obtener datos de la tasa y monto
        begin
             v_cod_tasa      :=fue_obt_des_refcodes(p_par_cargo,'COD_TASA');
             v_tra_cargo     :=fue_obt_des_refcodes(p_par_cargo,'TRA_CARGO');
             v_tra_impuesto  :=fue_obt_des_refcodes(p_par_cargo,'TRA_IVA');

             g_lugar:='Obtener importe del cargo';
             lp_obt_cargo(pag_cta.g_ctas.cod_oficina,
                          vp_cta_credito,
                          pag_cta.g_ctas.cod_moneda,
                          v_importe,
                          pag_cta.g_ctas.cod_modulo,
                          pag_cta.g_ctas.cod_modalidad,
                          nvl(pag_cta.g_ctas.tas_personalizada,'N'),
                          v_tra_cargo,
                          v_cod_tasa,
                          v_val_tas_cargo,
                          v_mto_cargo);

             if v_des_error is null then
               if v_mto_cargo > 0 then
                  -- Se obtiene el IVA por el total del CARGO.
                  g_lugar:='Obtener impuesto del cargo';
                  lp_obt_cargo(pag_cta.g_ctas.cod_oficina,
                               vp_cta_credito,
                               pag_cta.g_ctas.cod_moneda,
                               v_mto_cargo,
                               pag_cta.g_ctas.cod_modulo,
                               pag_cta.g_ctas.cod_modalidad,
                               nvl(pag_cta.g_ctas.tas_personalizada,'N'),
                               v_tra_impuesto,
                               v_cod_tas_impuesto,
                               v_val_tas_impuesto,
                               v_mto_impuesto);

                   if v_des_error is not null then
                      raise ex_comision;
                   end if;
               end if;
             else
                 raise ex_comision;
             end if;
              r_gmovi.cod_modulo      := v_mod_cta_cre;
              r_gmovi.cod_modalidad   := v_mad_cta_cre;
              r_gmovi.cod_oficina     := v_ofi_cta_cre;
              r_gmovi.nro_cuenta      := vp_cta_credito;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hora;
              r_gmovi.fecha           := v_fec_proceso;
              r_gmovi.cod_tra_padre   := v_cod_tra_padre;
              r_gmovi.cod_mod_padre   := v_mod_padre;
              r_gmovi.cod_mad_padre   := v_mad_padre;
              r_gmovi.cod_rubro       := null;
              r_gmovi.fec_valor       := v_fec_valor;
              r_gmovi.tip_mov_rubro   := 'D';
              r_gmovi.nro_documento2  := v_nro_documento2;
              r_gmovi.nro_documento   := v_nro_documento;
              r_gmovi.referencia      := v_cod_tasa;
              r_gmovi.cotizacion      := NULL;
              r_gmovi.cod_ofi_origen  := v_ofi_origen;
              r_gmovi.emi_aviso       := 'S';
              r_gmovi.concepto        := 'Comision de Transferencia - BCP';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              begin
                 prg_cre_savepoint('comision');
                 --movimiento para la gravada
                 if v_mto_cargo > 0 then
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.cod_transaccion := v_tra_cargo;
                    r_gmovi.monto           := v_mto_cargo;
                    r_gmovi.cod_tasa        := v_cod_tasa;
                    r_gmovi.val_tasa        := v_val_tas_cargo;
                    g_lugar:='Insertar movimiento p/ cargo';
                    pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                 end if;
                 --movimiento para el IVA
                 if v_mto_impuesto > 0 then
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.cod_transaccion := v_tra_impuesto;
                    r_gmovi.monto           := v_mto_impuesto;
                    r_gmovi.cod_tasa        := v_cod_tas_impuesto;
                    r_gmovi.val_tasa        := v_val_tas_impuesto;
                    g_lugar:='Insertar movimiento p/ impuesto';
                    pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                 end if;
                 --debito a la cuenta gravada + iva
                 lp_upd_cta_credito((v_mto_cargo+v_mto_impuesto)*-1);
              exception
                  when others then
                    --si produce alguna excepción sólo deshace los cambios relacionados al cobro de cargo
                    prg_rol_savepoint('comision');
                    v_des_error :=sqlerrm;
                    raise ex_comision;
              end;
        exception
          when ex_comision then
            pas_snp.pr_reg_operacion( 'Error al generar comision, Referencia transferencia: '||p_nro_referencia, 'Error al procesar prg_gen_mov_spi,Referencia:  '||p_nro_referencia|| '|' ||g_lugar|| '|' ||vr_otr_error|| '|' ||v_des_error );
        end;
      end if;
      --cobrar comision
      --HA-2576 --DA-7849
      v_est_cta_cre := pag_cta.fu_obt_est_cuenta;
      IF v_est_cta_cre in ('A') THEN
          -- Debo cambiar el estado de la cuenta
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.monto           := NULL;
          r_gmovi.est_cuenta      := 'N';
          r_gmovi.cod_tra_padre   := 303;
          r_gmovi.cod_transaccion := 425;
          pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
       END IF;
    end if;
  END lp_pro_rec_transferencia;
BEGIN
  BEGIN
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 4;
  END;
  g_lugar:='Verifica horario';
  lp_ver_horario;
  g_lugar:='Verifica estado del modulo';
  -- Verifica el estado del modulo de ahorro por si se este haciendo el cierre
  IF v_est_modulo IN (1, 6) THEN
        vp_cod_respuesta := vr_en_cierre; -- En cierre
        v_msj_error      :='Modulo en estado 1 0 6';
  END IF;
  g_lugar:='Verifica horario';
  lp_ver_horario;
  pas_snp.pr_obt_mensaje(p_nro_referencia,'N');
  rg_msj_transferencia := pas_snp.fu_obt_reg_transferencias;
  if p_ind_transaccion = 'E' THEN
    IF nvl(to_number(vp_cta_debito), 0) != 0 AND
       vp_cod_respuesta = vr_aprobado THEN
              g_lugar:='Obtiene cuenta debito';
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
        vp_cod_respuesta := vr_cta_inexistente;
        v_msj_error      := 'Cuenta Debito Inexistente';
         pas_snp.pr_reg_operacion( p_cod_swift , g_lugar|| '|' || g_cod_error|| '|' ||'Error'|| '|' ||'Error' );
      END IF;
    END IF;
    IF vp_cta_credito IS NOT NULL AND vp_cta_credito != '0' THEN
     g_lugar:='Obtiene cuenta Credito';
      lp_dat_cta(vp_cta_credito,
                 v_mod_cta_cre,
                 v_mad_cta_cre,
                 v_ofi_cta_cre,
                 v_mon_cta_cre);
      IF vp_cod_respuesta = vr_aprobado AND
         to_number(vp_operacion) NOT IN (2, 52, 93, 6) THEN
         NULL;
            /*g_lugar:='LLavea Credito';
        IF pag_cta.fu_llavear_cuenta(v_mad_cta_cre,
                                     vp_cta_credito,
                                     v_es_cta_noc) = 'N' THEN
          vp_cod_respuesta := vr_reintente;
          v_msj_error      := 'No se pudo llavear la Cuenta Crdito';
           pas_snp.pr_reg_operacion( p_cod_swift , g_lugar|| '|' || g_cod_error|| '|' ||'Error'|| '|' ||'Error' );
        END IF;*/
      END IF;
    END IF;
  END IF;
  if p_ind_transaccion = 'R'   THEN
    IF nvl(to_number(vp_cta_credito), 0) != 0 AND
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
        vp_cod_respuesta := vr_cta_inexistente;
        v_msj_error      := 'Cuenta Debito Inexistente';
      END IF;
    END IF;
    IF vp_cta_debito IS NOT NULL AND vp_cta_debito != '0' THEN

      lp_dat_cta(vp_cta_debito,
                 v_mod_cta_deb,
                 v_mad_cta_deb,
                 v_ofi_cta_deb,
                 v_mon_cta_deb);
      IF vp_cod_respuesta = vr_aprobado AND
         to_number(vp_operacion) NOT IN (2, 52, 93, 6) THEN
         NULL;
        /*IF pag_cta.fu_llavear_cuenta(v_mad_cta_cre,
                                     vp_cta_debito,
                                     v_es_cta_noc) = 'N' THEN
          vp_cod_respuesta := vr_reintente;
          v_msj_error      := 'No se pudo llavear la Cuenta Crdito';
        END IF;*/
      END IF;
    END IF;
  END IF;
  IF vp_cod_respuesta = vr_aprobado THEN
    -- Verifica el estado de la cuenta
    v_est_cuenta := pag_cta.fu_obt_est_cuenta;
    IF v_est_cuenta IN ('C', 'P', 'X', 'T') THEN
      -- No es normal o con bloqueo de saldo
      -- Estado Inactivo tambien debe permitir.
      vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
      v_msj_error      := 'Estado de la Cuenta Debito Invalido. Estado: ' ||
                          v_est_cuenta;
    ELSE
      --Verifica si es una cta. combinada
      IF v_cta_com = 'S' THEN
        vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
      END IF;
    END IF;
  END IF;
  IF vp_operacion IN (41) AND   nvl(to_number(vp_cta_credito), 0) != 0 AND
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
      v_msj_error      := 'Cuenta Credito Inexistente';
    END IF;

    IF vp_cod_respuesta = vr_aprobado THEN
      -- Verifica el estado de la cuenta
      v_est_cuenta := pag_cta.fu_obt_est_cuenta;
      IF v_est_cuenta  IN ('C', 'P', 'X', 'T') THEN
        -- No es normal o con bloqueo de saldo
        -- Estado Inactivo tambien debe permitir.
        vp_cod_respuesta := vr_no_aprobado; -- Transaccion no aprobada
        v_msj_error      := 'Estado de la Cuenta Credito Invalido. Estado: ' ||
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
     -- Verifica el estado del modulo de ahorro
      v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
      IF v_est_modulo IN (1, 6) THEN
        vp_cod_respuesta := vr_en_cierre; -- En cierre
        v_msj_error      :='Modulo en estado 1 0 6';
      END IF;
      IF vp_cod_respuesta = vr_aprobado THEN
          lp_ver_horario;
          IF p_ind_transaccion = 'E' THEN
            -- Envio de transferencia
            lp_pro_env_transferencia;
          ELSIF p_ind_transaccion = 'R' THEN
            -- Transferencia Recibida
            lp_pro_rec_transferencia;
            pas_snp.pr_obt_mensaje(p_nro_referencia,'N'); --DA-7828
            if pas_snp.fu_obt_cod_error=0 then
               rg_mensaje := pas_snp.fu_obt_reg_transferencias;
               it.prg_gen_aler_tra_rrhh(rg_mensaje,'S');
            end if;
          END IF;
       END IF;
  END IF;

  IF vp_cod_respuesta = 0 and p_ind_transaccion = 'E' and
     p_ind_reverso = 'N' THEN
    update ge_snp_transferencias
       set fec_valor   = v_fec_valor,
           fecha       = v_fec_proceso,
           hora        = v_hora,
           cod_usuario = v_cod_usuario,
           estado      = 'U'
     where nro_referencia = p_nro_referencia;
  end if;
  IF vp_cod_respuesta = 0 and p_ind_transaccion = 'R' and
     p_ind_reverso = 'N' THEN
    update ge_snp_transferencias
       set fec_valor   = v_fec_valor,
           fecha       = v_fec_proceso,
           hora        = v_hora,
           cod_usuario = v_cod_usuario
     where nro_referencia = p_nro_referencia;
   
    update ge_snp_transferencias
       set estado = 'A', situacion = 'L'
     where nro_referencia = p_nro_referencia;
  end if;
  if vp_cod_respuesta !=vr_aprobado then

    pas_snp.pr_reg_operacion( 'Error en prg_gen_mov_noc_spi, Referencia transferencia: '||p_nro_referencia, 'Error al procesar prg_gen_mov_spi,Referencia:  '||p_nro_referencia|| '|' ||vp_cod_respuesta|| '|' ||v_msj_error );
  end if;
  p_cod_respuesta := vp_cod_respuesta;
  p_nom_respuesta := v_msj_error;
exception
when others then
    v_msj_error := sqlerrm;
   -- rollback;
    vp_cod_respuesta := vr_otr_error;
    pas_snp.pr_reg_operacion( 'Error en prg_gen_mov_noc_spi, Referencia transferencia: '||p_nro_referencia, 'Error al procesar prg_gen_mov_spi,Referencia:  '||p_nro_referencia|| '|' ||vp_cod_respuesta|| '|' ||v_msj_error );
    --variables de salida
    p_cod_respuesta := vp_cod_respuesta;
    p_nom_respuesta := 'Error al procesar prg_gen_mov_spi' || v_msj_error;

END;
/
