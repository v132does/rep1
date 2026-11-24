CREATE OR REPLACE PROCEDURE IT.prg_pro_mov_transferencia
/* Proceso que genera los movimientos de transferencias enviadas , actualizacion de saldos
  generacion de movimientos nocturnos */

(p_mto_debito      IN  ge_snp_transferencias.monto%type, --monto
 p_nro_cta_debito  IN ge_snp_transferencias.nro_cta_solicitante%type, --cuenta debito
 p_cod_mon_debito  IN ge_snp_transferencias.Cod_Moneda%type, --moneda debito
 p_cod_mon_Credito IN ge_snp_transferencias.Cod_Moneda%type, --moneda credito
 p_numeroContrato  IN NUMBER,
 p_cotizacion      IN NUMBER,
 p_ind_spi         IN VARCHAR2, --indica si es SPI
 P_ind_int         IN VARCHAR2, --indica si es interno o transferencias entre cuentas
 p_cod_msj_swift   IN ge_snp_transferencias.cod_msj_swift%type, --codigo mensaje
 p_nro_referencia  IN ge_snp_transferencias.Nro_Referencia%type,
 P_cod_swift       IN ge_snp_transferencias.cod_swi_pte_beneficiario%type,
 P_consumidor      IN VARCHAR2, --indica cual es el consumidor de la API
 p_cod_tra_pad_debito    IN NUMBER DEFAULT NULl,
 p_cod_tra_pad_credito   IN NUMBER DEFAULT NULL,
 p_cod_mod_pad_debito    IN NUMBER DEFAULT NULL,
 p_cod_mod_pad_credito   IN NUMBER DEFAULT NULL,
 p_cod_mad_pad_debito    IN NUMBER DEFAULT NULL,
 p_cod_mad_pad_credito   IN NUMBER DEFAULT NULL,
 p_cod_tra_debito        IN NUMBER DEFAULT NULL,
 p_cod_tra_credito       IN NUMBER DEFAULT NULL,
 p_salida          OUT typ_tra_movimiento) --Descripcion de la respuesta

 IS
  v_retorno          typ_tra_movimiento := typ_tra_movimiento;
  v_es_mov_noc     varchar2(1) := 'N';
  v_cod_respuesta  number(10);
  v_desc_respuesta varchar2(4000);
  v_cod_error      varchar2(10);
  rg_msj_transferencia  pas_snp.rg_msj;
  v_usu_mov             ba_usuarios.cod_usuario%type;
  v_hor_mov             ge_snp_transferencias.hora%type;
  v_nro_secuencia       number(3) := 0;
  v_cta_pte_solicitante varchar2(20); -- Nro de Cuenta Interbancaria
  v_cod_mod_padre       number(4); -- Modulo Padre
  v_cod_mad_padre       number(4); -- Modalidad Padre
  v_cod_tra_credito     ge_movimientos.cod_transaccion%type := 196; -- cod. transaccion hijo credito
  v_cod_tra_debito      ge_movimientos.cod_transaccion%type := 503; -- cod. transaccion hijo debito
  v_cod_tra_pad_cre     ge_movimientos.cod_tra_padre%type := pas_snp.fu_obt_cod_tra_padre; -- cod. transaccion padre
  v_cod_mod_pad_cre     number(4); -- Modulo Padre
  v_cod_mad_pad_cre     number(4); -- Modalidad Padre
  v_cod_mon_debito      ge_cuentas.cod_moneda%type; -- moneda de la cuenta
  v_cod_mon_local       varchar2(3) := pag_gen.fu_obt_mon_local;
  v_cod_mon_credito     ge_snp_transferencias.cod_moneda%type; -- moneda de la transferencia
  v_mto_equ_local       number(18) := null;
  v_mto_credito         ge_movimientos.monto%type; -- Monto de la transferencia
  v_nro_contrato        number(7); -- Nro de Contrato de Cambio
  v_cot_debito          ge_movimientos.monto%type := null;
  v_cot_credito         number(18, 4) := null;
  v_cotizacion          ge_movimientos.monto%type := null;
  v_mto_debito          ge_movimientos.monto%type;
  v_fec_actual          date := pag_cal.fu_obt_fec_actual(9);
  v_fec_valor           DATE := v_fec_actual;
  v_mto_contrato        ge_movimientos.monto%type; -- Monto de Contrato de Cambio
  v_nro_cta_debito      varchar2(16);
  v_nro_cta_credito     varchar2(20); -- cuenta de credito
  v_cod_per_solicitante ge_snp_transferencias.cod_per_solicitante%type;
  MSG_OK CONSTANT       VARCHAR2(30) :='OP_APROBADA';
  retError             typ_mensajeRespuesta := typ_mensajeRespuesta;
  v_mensajeCaja        typ_mensajeCaja;
  v_can_aut_requeridas NUMBER(5) := 0; -- cantidad de firmas requeridas
  v_cod_tra_padre      ge_movimientos.cod_tra_padre%type := pas_snp.fu_obt_cod_tra_padre; -- cod. transaccion padre
  v_cod_mod_debito     number(4); -- Modulo de la cuenta
  v_cod_mad_debito     number(4); -- Modalidad de la cuenta
  v_cod_ofi_debito     number(4); -- oficina de la cuenta
  v_cta_for_debito     varchar2(17); -- cuenta formateada
  v_nom_cta_debito     varchar2(100);
  v_nro_referencia     ge_snp_transferencias.nro_referencia%type;
  v_concepto_mov       ge_movimientos.concepto%type;
  v_mod_estado         ba_modulos.estado%TYPE;
  v_tip_movimiento     varchar2(1); -- D:Débito; C: Crédito
  v_cod_swift          ge_snp_transferencias.cod_swi_pte_beneficiario%type;
  v_horario            VARCHAR2(1) := 'D'; -- Dia normal
  v_es_cta_noc         VARCHAR2(1) := 'N'; -- Graba S/N ctas noctunas
  v_cod_canal          varchar2(3):='999';
  v_est_caja       cj_cajas.estado%TYPE;
  v_tip_caja       cj_cajas.tipo%TYPE;
  v_cod_ofi_origen cj_cajas.cod_oficina%TYPE;
  v_cod_usuario    cj_cajas.cod_usuario%TYPE;
  v_ult_cierre     cj_cajas.fec_hor_cierre%TYPE;
  v_user           cj_cajas.cod_usuario%TYPE:=user;
  v_sesion             bw_aut_sesiones.cod_sesion%type;
  v_nro_doc_solicitante   ge_snp_transferencias.nro_doc_solicitante%type;
  c_tra_cta_cre_deb_igual CONSTANT VARCHAR2(3) := 200;
  c_tra_err_conversion    CONSTANT VARCHAR2(3) := 203;
  c_tra_mto_invalido      CONSTANT VARCHAR2(3) := 204;
  c_tra_cta_cre_error     CONSTANT VARCHAR2(3) := 212;
  c_tra_cta_deb_error     CONSTANT VARCHAR2(3) := 213;
  c_cod_cta_invalida      CONSTANT VARCHAR2(3) := '114';
  c_cod_cta_doc_invalido   CONSTANT VARCHAR2(3) := '327';
  c_cod_cta_lim_permitio   CONSTANT VARCHAR2(3) := '328';
  c_cod_cta_inv_combinada CONSTANT VARCHAR2(3) := '252';
  c_cod_sin_autorizacion  CONSTANT VARCHAR2(3) := '108';
  c_cod_lim_excedido      CONSTANT VARCHAR2(3) := '136';
  c_cont_cambio_invalido  CONSTANT VARCHAR2(3) := '162';
  c_cod_mto_invalido      CONSTANT VARCHAR2(3) := '121';
  c_cod_tra_prohibida     CONSTANT VARCHAR2(3) := '110';
  c_cod_mov_ya_ingresado  CONSTANT VARCHAR2(3) := '134';
  c_cod_cta_duplicada     CONSTANT VARCHAR2(3) := '102';
  c_con_cambio         constant varchar2(04) := '162';
  sal_per_sin_aut         CONSTANT VARCHAR2(15):= 'SAL_PER_SIN_AUT';
  msg_cod_cta_conjunta    CONSTANT VARCHAR2(15) := 'CTA_CONJUNTA';
  c_mov_ingresado     CONSTANT VARCHAR2(25) := 'G_COD_MOV_DUPLI';
  c_op_error              CONSTANT VARCHAR2(15) := 'OP_ERROR';
  c_pro_cierre          CONSTANT VARCHAR2(15):= '330';
  c_fec_transf          CONSTANT VARCHAR2(15):= '329';
  c_con_moneda         constant varchar2(04) := '203';
  c_tra_invalida       constant varchar2(04) := '109';
  c_con_invalida       constant varchar2(04) := '274';
  c_sal_insufiente     constant varchar2(04) := '105';
  c_sis_cierre         constant varchar2(04) := '106';
  c_cod_operacion      constant varchar2(03) := '036';
  c_err_credito        constant varchar2(03) := '212';
  c_err_debito         constant varchar2(03) := '213';
  c_act_transf         constant varchar2(03) := '331';
  c_err_incosis         constant varchar2(03) := '332';
  BITACORA_ERROR   CONSTANT VARCHAR2(3) := 'ERR';
  BITACORA_ENTRADA CONSTANT VARCHAR2(3) := 'ENT';
  BITACORA_SALIDA  CONSTANT VARCHAR2(3) := 'SAL';
  PRE_MON_LOC_INVALIDA CONSTANT VARCHAR2(15) := 'PRE_MON_LOC_INV';
  c_paympvu            CONSTANT VARCHAR2(20) := 'PAYMENT_SUPPLIERS'; --TCE-806
  c_exp_web            constant varchar2(20) := 'CORPS_WEB'; --Falta definir la tarea
  c_exp_app            constant varchar2(20) := 'CORPS_APP'; --Falta definir la tarea
  e_error_controlado exception; --TCE-591

  PROCEDURE pr_insertarBitacora(p_codigoPersona IN VARCHAR2 DEFAULT NULL,
                                 p_codigoCanal   IN VARCHAR2 DEFAULT NULL,
                                 p_codSesion     IN VARCHAR2 DEFAULT NULL,
                                 p_tipoMensaje   IN VARCHAR2 DEFAULT NULL,
                                 p_codigoEmpresa IN VARCHAR2 DEFAULT NULL,
                                 p_datos         IN VARCHAR2 DEFAULT NULL,
                                 p_tipo                IN VARCHAR2 DEFAULT NULL,
                                 p_numeroTelefono      IN VARCHAR2 DEFAULT NULL,
                                 p_codigoError         IN VARCHAR2 DEFAULT NULL,
                                 p_observacion         IN VARCHAR2 DEFAULT NULL,
                                 p_codigoMotivo        IN VARCHAR2 DEFAULT NULL,
                                 p_numeroCuentaDebito  IN VARCHAR2 DEFAULT NULL,
                                 p_numeroCuentaCredito IN VARCHAR2 DEFAULT NULL,
                                 p_monto               IN NUMBER DEFAULT NULL,
                                 p_codigoMoneda        IN VARCHAR2 DEFAULT NULL,
                                 p_dato2               IN CLOB DEFAULT NULL
                                 ) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO bw_bitacoras
         (COD_PERSONA, COD_CANAL, COD_SESION, COD_TIP_MENSAJE, COD_PER_VINCULADA,
         DATO, TIPO, DATO2)
      VALUES
         (p_codigoPersona, p_codigoCanal, p_codSesion, p_tipoMensaje, p_codigoEmpresa,
         SUBSTR(p_datos, 1, 4000), p_tipo, p_dato2);

      IF p_tipo = BITACORA_ERROR and p_observacion is not null THEN
         insert into bw_log_incidencias
           (nro_telefono, cod_error, usu_insercion, fec_insercion, observacion,
            nro_caja, cod_tip_mensaje, cod_persona, nro_cta_debito,
            nro_cta_credito, monto, cod_moneda, cod_motivo)
         values
           (p_numeroTelefono,p_codigoError,user,sysdate, p_observacion,
            p_codigoCanal, p_tipoMensaje, p_codigoPersona, p_numeroCuentaDebito,
            p_numeroCuentaCredito, p_monto, p_codigoMoneda, p_codigoMotivo);
      END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         --NULL;
         raise_application_error(-20000,'aca' || ' - ' ||sqlerrm);
   END;
  --- controla horario
  FUNCTION lp_ver_horario(p_horario        OUT VARCHAR2,
                          p_es_mov_noc     OUT VARCHAR2,
                          p_es_cta_noc     OUT VARCHAR2,
                          p_ult_cierre     IN DATE,
                          p_cod_ofi_origen IN VARCHAR2,
                          p_fec_actual     OUT DATE,
                          p_fec_cie_caja   IN DATE,
                          p_fec_valor      OUT DATE)
    RETURN typ_MensajeRespuesta IS

    c_msg_sis_cierre constant varchar2(15) := '106';
    v_est_modulo ba_modulos.estado%TYPE;
    v_retorno    typ_MensajeRespuesta := typ_MensajeRespuesta;
  BEGIN

    p_horario    := 'D'; -- Dia normal
    p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
    p_es_cta_noc := 'N';
    if nvl(p_ind_spi, 'N') != 'S' then
      p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(9);
      v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(9);
    elsif nvl(p_ind_spi, 'N') = 'S' then
      p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
      v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);
    end if;
    IF v_est_modulo = 2 THEN
      -- El modulo esta abierto

      -- Verifica la hora --
      IF nvl(p_ind_spi, 'N') != 'S' then
        IF SYSDATE > p_ult_cierre AND trunc(p_ult_cierre) = p_fec_actual THEN
          p_horario    := 'T'; -- Tarde
          p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1,
                                                   1,
                                                   p_cod_ofi_origen);
          p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
        END IF;
      END IF;
    ELSE

      p_horario    := 'N';
      p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'S';
      p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1,
                                               1,
                                               p_cod_ofi_origen);
    END IF;
    pag_cta.g_horario := p_horario;
    p_fec_valor       := trunc(sysdate);
    v_mod_estado      := v_est_modulo;
    RETURN v_retorno;
  END;
  -- conversion de moneda
  PROCEDURE lp_con_mon_a_moneda(p_cod_mon_original IN ba_monedas.cod_moneda%TYPE,
                                p_cod_mon_destino  IN ba_monedas.cod_moneda%TYPE,
                                p_mto_mon_original IN NUMBER,
                                p_mto_mon_destino  OUT NUMBER,
                                p_cot_mon_original IN OUT NUMBER,
                                p_cot_mon_destino  IN OUT NUMBER,
                                p_interbancaria    IN VARCHAR2 DEFAULT NULL) IS
    v_lugar varchar2(100);
  begin
    if p_cot_mon_original <= 0 then
      p_cot_mon_original := null;
    end if;
    if p_cot_mon_destino <= 0 then
      p_cot_mon_destino := null;
    end if;
    v_lugar := 'obtener moneda base';
    if p_cod_mon_original = p_cod_mon_destino then
      p_mto_mon_destino := p_mto_mon_original;
      if p_cod_mon_original <> v_cod_mon_local then
        p_cot_mon_destino  := nvl(p_cot_mon_original,
                                  pag_gen.fu_obt_cotizacion(p_cod_mon_original));
        p_cot_mon_original := p_cot_mon_destino;
      else
        p_cot_mon_destino  := 1;
        p_cot_mon_original := 1;
      end if;
    else
      if nvl(p_interbancaria, 'N') = 'N' then
        if p_cod_mon_original <> v_cod_mon_local and
           p_cod_mon_destino = v_cod_mon_local then
          --convertir moneda original a base o destino
          p_cot_mon_original := nvl(p_cot_mon_original,
                                    fuw_obt_cotizacion(p_cod_mon_original,
                                                       'C' /*COMPRA*/,
                                                       v_fec_actual));
          p_cot_mon_destino  := 1;
          p_mto_mon_destino  := round(p_mto_mon_original *
                                      p_cot_mon_original,
                                      0);
        elsif p_cod_mon_original = v_cod_mon_local and
              p_cod_mon_destino <> v_cod_mon_local then
          -- pasar moneda original a moneda base
          p_cot_mon_original := 1;
          p_cot_mon_destino  := nvl(p_cot_mon_destino,
                                    fuw_obt_cotizacion(p_cod_mon_destino,
                                                       'V' /*VENTA */,
                                                       v_fec_actual));
          p_mto_mon_destino  := round(p_mto_mon_original /
                                      p_cot_mon_destino,
                                      2);
        elsif p_cod_mon_original <> v_cod_mon_local and
              p_cod_mon_destino <> v_cod_mon_local then
          p_cot_mon_original := nvl(p_cot_mon_original,
                                    fuw_obt_cotizacion(p_cod_mon_original,
                                                       'C' /*COMPRA*/,
                                                       v_fec_actual));
          p_mto_mon_destino  := p_mto_mon_original * p_cot_mon_original;
          p_cot_mon_destino  := nvl(p_cot_mon_destino,
                                    fuw_obt_cotizacion(p_cod_mon_destino,
                                                       'V' /*VENTA */,
                                                       v_fec_actual));
          p_mto_mon_destino  := round(p_mto_mon_destino / p_cot_mon_destino,
                                      2);
        end if;
      else
        if p_cod_mon_original <> v_cod_mon_local and
           p_cod_mon_destino = v_cod_mon_local then
          --convertir moneda original a base o destino
          p_cot_mon_original := nvl(p_cot_mon_original,
                                    fuw_obt_cotizacion(p_cod_mon_original,
                                                       'V' /*VENTA*/,
                                                       v_fec_actual));
          p_cot_mon_destino  := 1;
          p_mto_mon_destino  := round(p_mto_mon_original *
                                      p_cot_mon_original,
                                      0);
        elsif p_cod_mon_original = v_cod_mon_local and
              p_cod_mon_destino <> v_cod_mon_local then
          -- pasar moneda original a moneda base
          p_cot_mon_original := 1;
          p_cot_mon_destino  := nvl(p_cot_mon_destino,
                                    fuw_obt_cotizacion(p_cod_mon_destino,
                                                       'C' /*COMPRA*/,
                                                       v_fec_actual));
          p_mto_mon_destino  := round(p_mto_mon_original /
                                      p_cot_mon_destino,
                                      2);
        elsif p_cod_mon_original <> v_cod_mon_local and
              p_cod_mon_destino <> v_cod_mon_local then
          p_cot_mon_original := nvl(p_cot_mon_original,
                                    fuw_obt_cotizacion(p_cod_mon_original,
                                                       'V' /*VENTA*/,
                                                       v_fec_actual));
          p_mto_mon_destino  := p_mto_mon_original * p_cot_mon_original;
          p_cot_mon_destino  := nvl(p_cot_mon_destino,
                                    fuw_obt_cotizacion(p_cod_mon_destino,
                                                       'C' /*COMPRA*/,
                                                       v_fec_actual));
          p_mto_mon_destino  := round(p_mto_mon_destino / p_cot_mon_destino,
                                      2);
        end if;
      end if;
    end if;
  exception
    when others then
      raise_application_error(-20000, v_lugar || ' - ' || sqlerrm);
  end;
  -- validacion de contrato de cambio
  procedure lp_val_con_cambio(p_operacion       in varchar2, -- V/C (Valida, Confirma)
                              p_nro_contrato    in number,
                              p_cod_mon_debito  in varchar2 default null,
                              p_cod_mon_credito in varchar2 default null,
                              p_nro_cta_debito  in varchar2 default null,
                              p_nro_cta_credito in varchar2 default null,
                              p_cotizacion      in number default 0,
                              p_importe         in number default 0,
                              p_cod_mensaje     out varchar2) is

    v_tipo              varchar2(1);
    v_cont_mon_compra   lc_con_cambios.cod_mon_compra%TYPE;
    v_cont_cotiz_compra lc_con_cambios.Cot_Compra%TYPE;
    v_cont_mon_venta    lc_con_cambios.cod_mon_venta%TYPE;
    v_cont_cotiz_venta  lc_con_cambios.Cot_venta%TYPE;
    v_paridad           lc_con_cambios.paridad%TYPE;
    v_mto_compra        lc_con_cambios.mto_compra%TYPE;
    v_mto_venta         lc_con_cambios.mto_venta%Type;
    v_cta_debito        lc_con_cambios.nro_cta_debito%Type;
    v_cta_credito       lc_con_cambios.nro_cta_credito%Type;
    v_fec_actual        ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_fec_servidor      date := trunc(sysdate);
    c_con_cam_invalido constant varchar2(3) := '162';
    c_con_mto_invalido constant varchar2(3) := '180';
    c_con_cta_deb_inv  constant varchar2(3) := '182';
    c_con_cta_cre_inv  constant varchar2(3) := '183';
    c_cot_con_cam_inv  constant varchar2(3) := '163';

  begin
    p_cod_mensaje := MSG_OK;
    if p_nro_contrato > 0 then
      if p_operacion = 'V' then
        if p_cod_mon_debito <> v_cod_mon_local and
           p_cod_mon_credito <> v_cod_mon_local then
          v_tipo := 'A'; -- arbitraje
        elsif p_cod_mon_credito = v_cod_mon_local and
              p_cod_mon_debito <> v_cod_mon_local then
          v_tipo := 'C'; -- compra
        else
          v_tipo := 'V'; -- venta
        end if;
        begin
          select cod_mon_compra,
                 cot_compra,
                 cod_mon_venta,
                 cot_venta,
                 paridad,
                 nvl(mto_compra, 0),
                 nvl(mto_venta, 0),
                 nro_cta_debito,
                 nro_cta_credito
            into v_cont_mon_compra,
                 v_cont_cotiz_compra,
                 v_cont_mon_venta,
                 v_cont_cotiz_venta,
                 v_paridad,
                 v_mto_compra,
                 v_mto_venta,
                 v_cta_debito,
                 v_cta_credito
            from lc_con_cambios
           where nro_contrato = p_nro_contrato
             and estado = 'P'
             and tipo = v_tipo
             and trunc(fec_insercion) = v_fec_servidor;
        exception
          when others then
            p_cod_mensaje := c_con_cam_invalido;
        end;
        if p_cod_mensaje = MSG_OK then
          if (v_mto_compra != p_importe and v_mto_venta != p_importe) then
            p_cod_mensaje := c_con_mto_invalido;
          elsif v_cta_debito != p_nro_cta_debito then
            p_cod_mensaje := c_con_cta_deb_inv;
          elsif v_cta_credito != p_nro_cta_credito and
                p_nro_cta_credito is not null and
                nvl(v_cta_credito, 0) != 0 then
            p_cod_mensaje := c_con_cta_cre_inv;
          end if;
        end if;
        --valido la cotizacion recibida Vs. la cotizacion del contrato
        if (v_tipo = 'A' and p_cotizacion != v_paridad) OR
           (v_tipo = 'V' and p_cotizacion != v_cont_cotiz_venta) OR
           (v_tipo = 'C' and p_cotizacion != v_cont_cotiz_compra) then
          p_cod_mensaje := c_cot_con_cam_inv;
        end if;
      else
        update lc_con_cambios
           set estado = 'C'
         where nro_contrato = p_nro_contrato;
      end if;
    end if;
  end;
  FUNCTION lf_val_cta_debito(p_nro_cta_debito  IN VARCHAR2,
                             p_cod_tra_padre   IN NUMBER,
                             p_monto           IN NUMBER,
                             p_cod_mon_debito  OUT VARCHAR2,
                             p_cod_mod_debito  OUT NUMBER,
                             p_cod_mad_debito  OUT NUMBER,
                             p_cod_ofi_debito  OUT NUMBER,
                             p_cta_for_debito  OUT VARCHAR2,
                             p_nom_cta_debito  OUT VARCHAR2,
                             p_cod_modulo      IN ge_modalidades.cod_modulo%TYPE DEFAULT NULL,
                             p_cod_modalidad   IN ge_modalidades.cod_modalidad%TYPE DEFAULT NULL,
                             p_nro_cta_credito IN VARCHAR2 default null,
                             p_consumidor_ori  IN VARCHAR default null --TCE-806 - Se agrego un parametro mas para validar el consumidor
                             )
    RETURN typ_mensajeRespuesta IS
    MSG_COD_CTA_INVALIDA    CONSTANT VARCHAR2(15) := 'COD_CTA_INVALID';
    MSG_COD_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := 'COD_CTA_INEXIST';
    MSG_COD_TRA_PROHIBIDA   CONSTANT VARCHAR2(15) := 'COD_TRA_PROHIB';
    MSG_COD_SAL_INSUF       CONSTANT VARCHAR2(15) := 'COD_SAL_INSUF';
    MSG_COD_CTA_DUPLICADA   CONSTANT VARCHAR2(15) := 'COD_CTA_DUPLIC';
    MSG_COD_CTA_CONJUNTA    CONSTANT VARCHAR2(15) := 'CTA_CONJUNTA';

    v_est_cta_debito VARCHAR2(1);
    v_nvo_estado     VARCHAR2(1) := NULL; -- cambio de estado de cuenta
    v_procesa        VARCHAR2(1) := 'N';
    v_sal_disponible NUMBER(18, 2);
    v_retorno        typ_mensajeRespuesta := typ_mensajeRespuesta;
    -- verifico cuenta de debito
  BEGIN
    PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK,
                              v_retorno.nombreRespuesta,
                              v_retorno.descripcionRespuesta,
                              v_retorno.error);

    SELECT a.cod_moneda,
           a.estado,
           cod_modalidad,
           cod_modulo,
           cod_oficina,
           fug_cta_formateada(cod_modulo,
                              cod_modalidad,
                              cod_oficina,
                              nro_cuenta,
                              cod_moneda) cta_formateada,
           denominacion
      INTO p_cod_mon_debito,
           v_est_cta_debito,
           p_cod_mad_debito,
           p_cod_mod_debito,
           p_cod_ofi_debito,
           p_cta_for_debito,
           p_nom_cta_debito
      FROM ge_cuentas a
     WHERE a.nro_cuenta = p_nro_cta_debito; -- contiene el nro de cuenta
    -- debito
    pag_cta.PR_OBT_CUENTA(p_nro_cta_debito);
    v_est_cta_debito := pag_cta.FU_OBT_EST_CUENTA;
    IF p_cod_mad_debito NOT IN (31, 41, 334) THEN
      PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
      -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
    ELSIF v_est_cta_debito NOT IN ('P', 'I', 'N', 'S') THEN
      PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
      -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
    ELSIF pag_cta.fu_ver_tra_prohibida(p_nro_cta_debito,
                                       p_cod_tra_padre,
                                       nvl(p_cod_modulo, 9),
                                       nvl(p_cod_modalidad, 91)) = 'S' THEN
      PAW_UTI.pr_mensajeUsuario(MSG_COD_TRA_PROHIBIDA,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
      -- v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
    ELSIF paw_bas.fu_es_conjunta(p_nro_cta_debito, v_can_aut_requeridas) = 'S'
      and nvl(p_consumidor_ori, 'DFL') not in (c_paympvu, c_exp_web, c_exp_app) THEN --TCE-806 - Se agrego una condicion mas para validar por consumidor
      PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_CONJUNTA,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
      -- v_cod_respuesta := paw_bce.v_cod_tra_invalida;
    ELSIF p_cod_mad_debito = 41 and p_nro_cta_credito is not null Then
      --> No es nulo cuando es transferencia entre cuentas Propias o a Terceros
      --SDPARDEBAU-2-MB: Se envia la Cta. de Credito para validar el saldo de ambas cuentas. Si ambos son negativos (Sin Tener en cuenta la LS) detener el proceso.
      If FUC_OBT_SAL_SIN_SOBREGIRO(p_nro_cta_debito) <= 0 and
         FUC_OBT_SAL_SIN_SOBREGIRO(p_nro_cta_credito) <= 0 Then
        -- El destino sera Fondeado con el sobregiro del origen. No se debe permitir
        PAW_UTI.pr_mensajeUsuario(MSG_COD_SAL_INSUF,
                                  v_retorno.nombreRespuesta,
                                  v_retorno.descripcionRespuesta,
                                  v_retorno.error);
      ElsIf FUC_OBT_SAL_SIN_SOBREGIRO(p_nro_cta_debito) > 0 and
            (FUC_OBT_SAL_SIN_SOBREGIRO(p_nro_cta_debito) - p_monto) < 0 then
        -- El destino sera Fondeado con un sobregiro del origen a raiz de la operacion actual. No se debe permitir
        PAW_UTI.pr_mensajeUsuario(MSG_COD_SAL_INSUF,
                                  v_retorno.nombreRespuesta,
                                  v_retorno.descripcionRespuesta,
                                  v_retorno.error);
      End If;
    ELSE
      pag_cta.pr_ver_operacion(p_nro_cta_debito,
                               p_cod_tra_padre,
                               nvl(p_cod_modulo, 9),
                               nvl(p_cod_modalidad, 91),
                               'D',
                               p_cod_mon_debito,
                               p_monto,
                               61 /*p_mensajeCaja.codigoOficinaOrigen*/ /* v_cod_ofi_origen */,
                               p_cod_mod_debito,
                               p_cod_mad_debito,
                               v_nvo_estado,
                               v_sal_disponible,
                               v_procesa,
                               503);
      IF v_procesa = 'N' THEN
        -- no se puede debitar
        IF instr(upper(pag_cta.G_MSJ_ERROR), 'INSUFIC') > 0 THEN
          -- saldo insuficiente
          PAW_UTI.pr_mensajeUsuario(MSG_COD_SAL_INSUF,
                                    v_retorno.nombreRespuesta,
                                    v_retorno.descripcionRespuesta,
                                    v_retorno.error);
          -- v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
        ELSE
          PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA,
                                    v_retorno.nombreRespuesta,
                                    v_retorno.descripcionRespuesta,
                                    v_retorno.error);
          -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
        END IF;
      END IF;
    END IF;

    RETURN v_retorno;
  EXCEPTION
    WHEN no_data_found THEN
      PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INEXISTENTE,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
      RETURN v_retorno;
    WHEN too_many_rows THEN
      PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_DUPLICADA,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
      RETURN v_retorno;
    WHEN OTHERS THEN
      PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
      RETURN v_retorno;
  END;
  --mensaje al usuario
  PROCEDURE pr_mensajeUsuario(mensaje            IN VARCHAR2,
                               nombreMensaje      OUT VARCHAR2,
                               descripcionMensaje OUT VARCHAR2,
                               error              OUT VARCHAR2) IS
      v_error VARCHAR2(1) /*:= 'S'*/;
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
BEGIN
  --JCBM 20-08-2024
  pre_cam_for_numerico('.,');
  if P_ind_int = 'N' then
    --prg_cre_savepoint('MOV'); --TCE-591
    /*Seccion de transferencias a otros bancos.*/
      pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                       v_retorno.error);
      v_retorno.ind_nocturno:='N';
      v_cod_mon_debito  := FUG_OBT_MON_CTA(p_nro_cta_debito);
      v_cod_mon_credito := paw_bel.depurarAlfanumerico(p_cod_mon_Credito, 3);
      --JCBM 20-08-2024
      v_mto_credito     := paw_bel.depurarNumerico(p_mto_debito, 18,'S');
      v_nro_contrato    := paw_bel.depurarNumerico(p_numeroContrato, 7);
      v_cotizacion      := paw_bel.depurarNumerico(p_cotizacion, 18);

      v_nro_cta_debito  := p_nro_cta_debito;
            --TRFS-1112
       /* Validacion de moneda local con decimales */
       --TRFS-1377 solo misma moneda y local, valida el monto en decimales
       IF v_cod_mon_credito = v_cod_mon_local and  paw_bel.depurarNumerico(p_mto_debito,18) <> v_mto_credito THEN
         pr_mensajeUsuario(PRE_MON_LOC_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_insertarBitacora(it.fug_obt_cli_principal(p_nro_cta_debito), v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - La moneda local no soporta decimales: '  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);
      else
        begin
       pas_snp.pr_obt_mensaje(p_nro_referencia, 'N');

      if pas_snp.fu_obt_cod_error = 0 then
        rg_msj_transferencia := pas_snp.fu_obt_reg_transferencias;
        v_nro_referencia     := rg_msj_transferencia.nro_referencia;
        v_sesion           := paw_bel.depurarAlfanumerico('P'||rg_msj_transferencia.cod_per_solicitante,32);
        v_cod_per_solicitante := it.fug_obt_cli_principal(p_nro_cta_debito);--obtiene codigo de persona del cliente principal
        v_nro_doc_solicitante := fue_obt_nro_doc_persona(rg_msj_transferencia.cod_per_solicitante) ;
      else
        null;
      end if;
    --controla modulos en transicion
    if pae_cnf.fu_obt_est_modulo(3) IN (1, 6) then
      pr_mensajeUsuario(c_sis_cierre, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - Modulo en estado 1 o 6:'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

    else
      -- Verifica el monto de la Operacion
      if nvl(v_mto_credito, 0) < 1 then
        pr_mensajeUsuario(c_cod_mto_invalido, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

      end if;
      if  v_retorno.error='N' then
      -- moneda diferentes sin contrato de cambio
      if v_cod_mon_credito <> v_cod_mon_debito then
        -- Verifica que no pueda realizar cambio de monedas en fecha distinta a la fecha actual
        /*if v_fec_operacion <> v_fec_actual then
           \*paw_bel.pr_mensajeUsuario(c_fec_inv_cam_moneda, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           paw_bel.pr_insertarBitacora(userInfo.codigoPersona, v_cod_canal, v_sesion, c_cod_operacion, userInfo.codigoEmpresa, 'fuw_transferenciaSipap -' || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
           return v_retorno;*\
           null;
        end if ;*/
        if nvl(v_nro_contrato, 0) > 0 then
          -- se asigna v_cotizacion a las dos variables al correr el proceso lp_con_mon_a_moneda, una de las
          -- variables obtendrá su valor correcto (1) dependiendo de las monedas de credito y debito
          if v_cod_mon_credito <> v_cod_mon_local and
             v_cod_mon_debito <> v_cod_mon_local and
             v_cod_mon_credito <> v_cod_mon_debito then
            begin
              -- En Arbitraje siempre la cotizacion compra pertenece a la Cta. Debito
              select c.cot_compra, c.cot_venta
                into v_cot_debito, v_cot_credito
                from lc_con_cambios c
               where c.nro_contrato = v_nro_contrato;
            exception
              when others then
               pr_mensajeUsuario(c_con_cambio, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

            end;
          else
            v_cot_credito := v_cotizacion;
            v_cot_debito  := v_cotizacion;
          end if;
        elsif v_cod_mon_credito <> v_cod_mon_local and
              v_cod_mon_debito <> v_cod_mon_local then
          -- es arbitraje y no tiene contrato de cambios
          pr_mensajeUsuario(c_con_cambio, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
          pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

        end if;
        -- Se realiza la conversion de moneda
        Begin
          lp_con_mon_a_moneda(v_cod_mon_credito,
                              v_cod_mon_debito,
                              v_mto_credito,
                              v_mto_debito,
                              v_cot_credito,
                              v_cot_debito,
                              'S');
        Exception
          When OTHERS then
            pr_mensajeUsuario(c_con_moneda, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

        End;
        -- Agrega el monto de cambio para verificar el Contrato
        if v_cod_mon_credito = v_cod_mon_local and
           v_cod_mon_debito <> v_cod_mon_local then
          v_mto_contrato := v_mto_debito;
        else
          v_mto_contrato := v_mto_credito;
        end if;
        -- valido el contrato de cambio, ojo con las variables.
        if nvl(v_nro_contrato, 0) > 0 then
          lp_val_con_cambio('V',
                            v_nro_contrato,
                            v_cod_mon_debito,
                            v_cod_mon_credito,
                            v_nro_cta_debito,
                            v_cta_pte_solicitante,
                            v_cotizacion,
                            v_mto_contrato,
                            v_cod_error);
          if v_cod_error != MSG_OK then
             pr_mensajeUsuario(v_cod_error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
             pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -' || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

            null;
          end if;
        end if;
        if v_cod_mon_debito <> v_cod_mon_local and
           v_cod_mon_credito = v_cod_mon_local then
          v_cotizacion := v_cot_debito;
        elsif v_cod_mon_debito = v_cod_mon_local and
              v_cod_mon_credito <> v_cod_mon_local then
          v_cotizacion := v_cot_credito;
        end if;
      else
        -- Valida Contrato si es moneda igual
        if nvl(v_nro_contrato, 0) > 0 or nvl(v_cotizacion, 1) > 1 then
           pr_mensajeUsuario(c_con_cambio, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -' || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

          null;
        end if;
        -- Se iguala el monto por que la Moneda Credito y Debito es igual
        v_mto_debito := v_mto_credito;
      end if;
      end if;
       if  v_retorno.error='N' then
      -- Valida la cuenta debito si puede realizar la operacion
      retError := lf_val_cta_debito(v_nro_cta_debito,
                                    v_cod_tra_padre,
                                    v_mto_debito,
                                    v_cod_mon_debito,
                                    v_cod_mod_debito,
                                    v_cod_mad_debito,
                                    v_cod_ofi_debito,
                                    v_cta_for_debito,
                                    v_nom_cta_debito,
                                    null,
                                    null,
                                    null,
                                    p_consumidor); --TCE-806

      if retError.error = 'S' then

        v_retorno.error                := retError.error;
        v_retorno.nombreRespuesta      := retError.nombreRespuesta;
        v_retorno.descripcionRespuesta := retError.descripcionRespuesta;
        pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - Valida la cuenta debito -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

     else

      if rg_msj_transferencia.cod_msj_swift =
         fug_obt_pardinamico('COD_SPI_PCD') and nvl(p_ind_spi, 'N') = 'S' then

        v_concepto_mov := rg_msj_transferencia.nro_ref_externa;
      else
        v_concepto_mov := pas_snp.fu_obt_mov_concepto('M',
                                                      'H',
                                                      rg_msj_transferencia.nro_referencia);
      end if;
      v_cod_swift   := paw_bel.depurarAlfanumerico(P_cod_swift, 15);
     --recupera datos de caja
     begin
       select estado, tipo, cod_oficina, cod_usuario, fec_hor_cierre
         into v_est_caja,
              v_tip_caja,
              v_cod_ofi_origen,
              v_cod_usuario,
              v_ult_cierre
         from cj_cajas
        where nro_caja = v_cod_canal;
     exception
       when others then
         null;
     end;
      --controla estado de modulos
      --controla horario cierre
      reterror := lp_ver_horario(v_horario,
                                 v_es_mov_noc,
                                 v_es_cta_noc,
                                 v_mensajeCaja.fechaUltimoCierre,
                                 v_cod_ofi_origen,
                                 v_fec_actual,
                                 v_ult_cierre,
                                 v_fec_valor);

      IF reterror.error = 'S' THEN
        v_retorno.error                := retError.error;
        v_retorno.nombreRespuesta      := retError.nombreRespuesta;
        v_retorno.descripcionRespuesta :=  retError.descripcionRespuesta;
        pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - lp_ver_horario -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

      END IF;
        v_cta_pte_solicitante := pas_snp.fu_obt_cta_bancaria(rg_msj_transferencia.nro_cta_pte_solicitante,
                                                             'C');
      --Graba en mov nocturno para transferencias SPI
      if rg_msj_transferencia.fecha is null and rg_msj_transferencia.hora is null and rg_msj_transferencia.cod_usuario is null then
      if v_es_mov_noc = 'S' and
         p_cod_msj_swift = fug_obt_pardinamico('COD_SPI_PCD') and
         nvl(p_ind_spi, 'N') = 'S'  then

        prg_gen_mov_noc_spi(v_mto_credito,
                            p_nro_cta_debito,
                            v_cta_pte_solicitante,
                            p_cod_mon_debito,
                            rg_msj_transferencia.cod_msj_swift,
                            rg_msj_transferencia.cod_tip_operacion,
                            rg_msj_transferencia.cod_sub_tip_operacion,
                            rg_msj_transferencia.nro_referencia,
                            rg_msj_transferencia.nro_ref_externa,
                            P_cod_swift,
                            'E',
                            'N',
                            null,
                            null,
                            null,
                            null,
                            null,
                            v_cod_respuesta,
                            v_desc_respuesta,
                            null,
                            null,
                            p_consumidor);
                            v_retorno.ind_nocturno:='S';

        IF v_cod_respuesta = 91 then
           pr_mensajeUsuario(c_sis_cierre, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - prg_gen_mov_noc_spi -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

        elsif v_cod_respuesta != 0 THEN
              pr_mensajeUsuario(c_pro_cierre, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
             pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - prg_gen_mov_noc_spi -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

        END IF;
        if  v_cod_respuesta = 0 then--TRFS-1304
             v_retorno.numeroDocumento:=rg_msj_transferencia.nro_referencia;

        end if;
      elsif nvl(v_es_mov_noc, 'N') = 'N' then
        --valida fecha valor y fecha ingreso
      if rg_msj_transferencia.fec_valor is null or rg_msj_transferencia.fec_ingreso is null then
        pr_mensajeUsuario(c_fec_transf, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - '  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);

      end if;
        -- Genera el Movimiento y envia el mensaje a BCP si la fecha es actual y esta activo
        if rg_msj_transferencia.fec_valor =
           rg_msj_transferencia.fec_ingreso and
           (pas_snp.fu_obt_fec_ult_operacion =
           rg_msj_transferencia.fec_valor and nvl(p_ind_spi, 'N') <> 'S') or
           (p_ind_spi = 'S' and
           rg_msj_transferencia.fec_valor = trunc(sysdate)) then
         /* if pas_snp.fu_obt_est_horario(rg_msj_transferencia.cod_msj_swift,
                                        rg_msj_transferencia.cod_tip_operacion,
                                        rg_msj_transferencia.cod_sub_tip_operacion) = 'A' then*/
            --Si el horario está VIGENTE en BCP

            -- se retornará la transaccion a ser utilizada para la generacion del movimiento.
            pas_snp.pr_obt_par_mensajes(rg_msj_transferencia.cod_msj_swift, -- Tipo MT
                                        rg_msj_transferencia.cod_tip_operacion, -- Tipo de Operacion
                                        rg_msj_transferencia.cod_sub_tip_operacion, -- Sub-Tipo de Operacion
                                        'E', -- Transferencia Enviada
                                        v_cod_mod_padre,
                                        v_cod_mad_padre,
                                        v_cod_tra_credito);
            if v_cod_mon_debito <> v_cod_mon_local then
              if v_cod_mon_credito = v_cod_mon_local then
                v_mto_equ_local := v_mto_credito;
              else
                v_mto_equ_local := null;
              end if;
            end if;
            --TCE-220
          --Asigna valores
          v_cod_tra_padre:=nvl(p_cod_tra_pad_debito,v_cod_tra_padre);
          v_cod_mod_padre:=nvl(p_cod_mod_pad_debito,v_cod_mod_padre);
          v_cod_mad_padre:=nvl(p_cod_mad_pad_debito,v_cod_mad_padre);
          v_cod_tra_pad_cre:=nvl(p_cod_tra_pad_credito,v_cod_tra_padre);
          v_cod_mod_pad_cre:=nvl(p_cod_mod_pad_credito,v_cod_mod_padre);
          v_cod_mad_pad_cre:=nvl(p_cod_mad_pad_credito,v_cod_mad_padre);
          v_cod_tra_debito:=nvl(p_cod_tra_debito,v_cod_tra_debito);
          v_cod_tra_credito:=nvl(p_cod_tra_credito,v_cod_tra_credito);
            --Obtiene usuario en base al consumidor recibido
            v_user:=FUE_OBT_VAL_MAX_REFERENCIA('CONSUMIDORES_API',p_consumidor);
            pag_cta.pr_set_cod_rubro(NULL, NULL);
            -- Setea el Nro. Documento2 para levantar el programa asociado a la mensajería a partir del movimiento generado
            pag_cta.pr_set_nro_documento2(rg_msj_transferencia.cod_msj_swift ||
                                          rg_msj_transferencia.cod_tip_operacion ||
                                          rg_msj_transferencia.cod_sub_tip_operacion);
           if v_user='PAYMPV' then
             prs_tra_obt_usu_hor_mov_pym(v_user,
                                        v_usu_mov,
                                        v_hor_mov);
           else
           prs_tra_obt_usu_hor_mov_env(v_user,
                                        v_usu_mov,
                                        v_hor_mov);
           end if;
            pag_cta.pr_set_variables(v_usu_mov,
                                     v_fec_actual,
                                     v_cod_tra_padre,
                                     'N',
                                     'N',
                                     v_nro_secuencia);

            IF pae_cnf.fu_obt_est_modulo(3) IN (1, 6) then
               pr_mensajeUsuario(c_sis_cierre, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - Modulo en estado 1 o 6:'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);
               raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
            end if;
            -- Registrar movimientos de Débito al CLIENTE
            pag_cta.g_horario := 'D';
            pag_cta.pr_set_referencia(null);--ojo
            pag_cta.pr_act_operacion(v_nro_cta_debito, -- Nro.Cta.
                                     v_hor_mov, -- Hora
                                     'D', -- Tip.Mov.
                                     v_cod_mon_debito, -- Cod.Mon.
                                     v_mto_debito, -- Monto
                                     v_cod_tra_padre, -- Trx.Padre
                                     v_cod_tra_debito, -- Trx.Hija
                                     v_nro_referencia, -- Nro.Doc.
                                     v_cot_debito, -- Cotizacion
                                     v_cod_ofi_debito, -- Ofic.Orig.
                                     v_cod_mod_padre, -- Mod.Pad.Cliente
                                     v_cod_mad_padre, -- Mad.Pad.Cliente
                                     NULL, -- Cod.Tasa
                                     NULL, -- Val.Tasa
                                     v_concepto_mov, -- Concepto
                                     'S', -- Emit.Aviso
                                     v_nro_secuencia,
                                     v_fec_actual,
                                     null, -- Cod_Banco
                                     null, -- Cod_Causa
                                     v_mto_equ_local);
            if pag_cta.fu_obt_cod_error = 0 then

              if v_mod_estado != pae_cnf.fu_obt_est_modulo(3) then

                pr_mensajeUsuario(c_op_error , v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - control cambio estado mod'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);
                raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
                --return;
              end if;
             if  v_retorno.error='N' then
              if v_cod_mon_credito <> v_cod_mon_local then
                if v_cod_mon_debito = v_cod_mon_local then
                  v_mto_equ_local := v_mto_debito;
                else
                  v_mto_equ_local := null;
                end if;
              end if;
              v_tip_movimiento := pas_snp.fu_obt_tip_mov_transaccion(v_cod_mod_padre,
                                                                     v_cod_mad_padre,
                                                                     v_cod_tra_credito);

              if nvl(pas_snp.fu_obt_cod_error, 1) <> 0 then
                pr_mensajeUsuario(c_tra_invalida, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -' || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), bitacora_error );
                raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
              else
                pag_cta.pr_set_variables(v_usu_mov,
                                         v_fec_actual,
                                         v_cod_tra_pad_cre,
                                         'N',
                                         'N',
                                         v_nro_secuencia);
                --
                -- Setea el Tipo de Movimiento del Rubro para SNP
                pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(v_cta_pte_solicitante),
                                         v_tip_movimiento);
                -- Setea la Referencia del Movimiento para SNP
                pag_cta.pr_set_referencia(v_cod_swift);
                -- Registrar movimientos a la Cta. Interbancaria
                pag_cta.pr_act_operacion(v_cta_pte_solicitante, -- Nro.Cta.
                                         v_hor_mov, -- Hora
                                         v_tip_movimiento, -- Tip.Mov.Cta.Corresponsal
                                         v_cod_mon_credito, -- Cod.Mon.
                                         v_mto_credito, -- Monto
                                         v_cod_tra_pad_cre, -- Trx.Padre
                                         v_cod_tra_credito, -- Trx.Hija
                                         v_nro_referencia, -- Nro.Doc.
                                         v_cot_credito, -- Cotizacion
                                         v_cod_ofi_debito, -- Ofic.Orig.
                                         v_cod_mod_pad_cre, -- Mod.Pad.Cliente
                                         v_cod_mad_pad_cre, -- Mad.Pad.Cliente
                                         NULL, -- Cod.Tasa
                                         NULL, -- Val.Tasa
                                         v_concepto_mov,
                                         'S', -- Emit.Aviso
                                         v_nro_secuencia,
                                         v_fec_actual,
                                         null, -- Cod_Banco
                                         null, -- Cod_Causa
                                         v_mto_equ_local);
                if pag_cta.fu_obt_cod_error = 0 then
                  --Para las transferencias que corresponden a SNP se debe cargar este campo. No así para la generacion de cargos.
                  pag_cta.pr_set_nro_documento2(null);
                  pas_snp.pr_gen_mov_cargo(rg_msj_transferencia,
                                           v_nro_cta_debito,
                                           v_cta_pte_solicitante,
                                           v_mto_credito,
                                           v_hor_mov,
                                           v_nro_secuencia);
                  if pag_cta.fu_obt_cod_error <> 0 then
                    pr_mensajeUsuario(c_err_credito, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                    pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);
                    raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
                  else
                    begin
                      --registro el movimiento
                      --guarda el nro de referencia en bw_movimientos en dato2
                      paw_con.pr_reg_operacion(v_nro_cta_debito,
                                               v_cod_mon_debito,
                                               v_mto_debito,
                                               null,
                                               null,
                                               'Entidad_Destino',
                                               v_cod_swift,
                                               'Nro. Referencia',
                                               rg_msj_transferencia.nro_referencia,
                                               rg_msj_transferencia.observacion,
                                               null,
                                               'C',
                                               rg_msj_transferencia.cod_per_solicitante,
                                               c_cod_operacion,
                                               rg_msj_transferencia.nro_referencia,
                                               999,
                                               v_sesion,
                                               rg_msj_transferencia.cod_per_solicitante);
                      exception
                         when others then
                            pr_mensajeUsuario(c_act_transf, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                            pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - Modulo en estado 1 o 6:'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,sqlerrm), bitacora_error);
                            raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
                    end;
                     if  v_retorno.error='N' then
                        v_retorno.numeroDocumento:=rg_msj_transferencia.nro_referencia;
                        BEGIN
                           -- Actualiza la Transferencia
                           update ge_snp_transferencias gt
                              set gt.fecha       = v_fec_actual,
                                  gt.hora        = v_hor_mov,
                                  gt.cod_usuario = v_usu_mov
                            where gt.nro_referencia = rg_msj_transferencia.nro_referencia
                              and gt.cod_msj_swift = rg_msj_transferencia.cod_msj_swift;
                           if sql%notfound then
                             pr_mensajeUsuario(c_act_transf, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                             pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - Modulo en estado 1 o 6:'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);
                             raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
                             --return;
                           end if;
                        END;
                    end if;
                  end if;
                else
                    pr_mensajeUsuario(c_err_credito, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                    pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - Modulo en estado 1 o 6:'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);
                    raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
                    --return;
                end if;
              end if;
              end if;
            else
              if pag_cta.fu_obt_cod_error = 31 then
                pr_mensajeUsuario(c_sal_insufiente, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - Modulo en estado 1 o 6:'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);
                raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
              else
                pr_mensajeUsuario(c_err_debito, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - Modulo en estado 1 o 6:'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);
                raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
              end if;
            end if;
          --end if;
        end if;
      end if;
      else
         pr_mensajeUsuario(c_mov_ingresado, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia - Modulo en estado 1 o 6:'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,null), bitacora_error);
         raise e_error_controlado; --prg_rol_savepoint('MOV'); --TCE-591
     end if;
     end if;
    end if;
    end if;
        end;
    end if;
  end if;
  v_retorno.cotizacion:=v_cotizacion;--TRFS-1343
  p_salida:=v_retorno;
EXCEPTION
  when e_error_controlado then
      pr_mensajeUsuario(c_op_error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,sqlerrm), bitacora_error);
      rollback; --prg_rol_savepoint('MOV'); --TCE-591
      p_salida:=v_retorno;
  WHEN others then
      pr_mensajeUsuario(c_op_error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      pr_insertarBitacora(rg_msj_transferencia.cod_per_solicitante, v_cod_canal, null, c_cod_operacion, null, 'prg_pro_mov_transferencia -'  || paw_bel.fu_generarBitacora(v_retorno.error,v_retorno.nombrerespuesta, v_retorno.descripcionRespuesta,sqlerrm), bitacora_error);
      rollback; --prg_rol_savepoint('MOV'); --TCE-591
      p_salida:=v_retorno;

END;
/
