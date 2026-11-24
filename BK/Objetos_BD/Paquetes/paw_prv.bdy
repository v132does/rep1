CREATE OR REPLACE PACKAGE BODY IT.paw_prv IS

  --Indica el estado enviado
  EST_ENVIADO_NOTIFICACION CONSTANT VARCHAR2(1) := 'E';
  V_COD_CANAL                CONSTANT VARCHAR2(3) := '993';
  v_tip_mensaje        VARCHAR2(10); -- guarda el tipo IAC
  v_can_aut_requeridas NUMBER(5) := 0; -- cantidad de firmas requeridas

  --en el original era publica
  v_cod_mon_local VARCHAR2(3) := pag_gen.FU_OBT_MON_LOCAL;
  -- para controlar si viene de fu_autorizarOperacion

FUNCTION fu_obtCodigoRetorno(p_mensaje IN VARCHAR2, p_respuesta OUT VARCHAR2) RETURN VARCHAR2 IS
  v_mensaje VARCHAR(150);
BEGIN
  v_mensaje   := upper(TRIM(p_mensaje));
  p_respuesta := 'R42';
  CASE
    WHEN v_mensaje = 'MODALIDAD CTA DEBITO NO CORRESPONDE' THEN
      RETURN 'CMODDEBNOV';
    WHEN v_mensaje = 'ESTADO DE CTA DEBITO INVALIDO' THEN
      RETURN 'CESTDEBINV';
    WHEN v_mensaje = 'HORARIO SIPAP CERRADO, NO SE PUEDE PROCESAR ARCHIVO MIXTO' THEN
      RETURN 'CNARCSIPAP';
    WHEN v_mensaje = 'NO EXISTE CUENTA PARA EL CREDITO' THEN
      RETURN 'CNOCTACRED';
    WHEN v_mensaje = 'MODALIDAD DE LA CUENTA INVALIDO' THEN
      RETURN 'CMODCTACRE';
    WHEN v_mensaje = 'ESTADO INVALIDO' THEN
      RETURN 'CESTCTACRE';
    WHEN v_mensaje = 'ESTADO DE LA CUENTA INVALIDO' THEN
      RETURN 'CESTCTAINV';
    WHEN v_mensaje = 'MONEDA CTA CREDITO INVALIDA' THEN
      RETURN 'CMONCREINV';
    WHEN v_mensaje = 'MONEDA NO CORRESPONDE A LA CTA CREDITO' THEN
      RETURN 'CMONCTACRE';
    WHEN v_mensaje = 'CUENTA CREDITO PERTENECE AL ENTE' THEN
      RETURN 'CCTACREPRO';
    WHEN v_mensaje = 'FORMA DE PAGO INVALIDA' THEN
      RETURN 'CFORPAGINV';
    WHEN v_mensaje = 'BENEFICIARIO NO EXISTE P/CHEQUE GERENCIA' THEN
      RETURN 'CBENCHEGER';
    WHEN v_mensaje = 'NO EXISTE CUENTA PARA EL CREDITO' THEN
      RETURN 'CCTACRENOE';
    WHEN v_mensaje = 'DIRECCION DE CORREO INVALIDO' THEN
      RETURN 'CDIRCORINV';
    WHEN v_mensaje = 'CREDITO INTERBANCARIO INHABILITADO' THEN
      RETURN 'CNOSIPAPHA';
    WHEN v_mensaje = 'MONEDA CREDITO NO ESPECIFICADA' THEN
      RETURN 'CSINMONCRE';
    WHEN v_mensaje = 'PRIORIDAD INVALIDA, ACH SOLO PARA GS' THEN
      RETURN 'CPRIINVACH';
    WHEN v_mensaje = 'MONTO MAXIMO PARA ACH EXCEDIDO' THEN
      RETURN 'CMONMAXACH';
    WHEN v_mensaje = 'FECHA INVALIDA PARA OPERACION DE CAMBIO' THEN
      RETURN 'CFECOPECAM';
    WHEN v_mensaje = 'HORA INVALIDA PARA OPERACION DE CAMBIO' THEN
      RETURN 'CHOROPECAM';
    WHEN v_mensaje = 'MONEDA DE CREDITO INVALIDA' THEN
      RETURN 'CMONCREINV';
    WHEN v_mensaje = 'NO EXISTE CUENTA INTERBANCARIA' THEN
      RETURN 'CEXICTABAN';
    WHEN v_mensaje = 'TIPO DOC. DEL BENEF. NO PUEDE SER NULO' THEN
      RETURN 'CTIPDOCNUL';
    WHEN v_mensaje = 'DOCUMENTO DEL BENEF. NO PUEDE SER NULO' THEN
      RETURN 'CNRODOCNUL';
    WHEN v_mensaje LIKE 'FECHA DE PAGO ES MAYOR A%DIAS' THEN
      RETURN 'CFECMAY180';
    WHEN v_mensaje = 'ENTIDAD INEXISTENTE O INHABILITADA' THEN
      RETURN 'CFECENTINE';
    WHEN v_mensaje = 'TIPO DOC. DEL BENEF. INVALIDO' THEN
      RETURN 'CTIPDOCINV';
    WHEN v_mensaje = 'PRIORIDAD ACH NO PERMITIDA PARA BCP' THEN
      RETURN 'CPRIACGBCP';
    WHEN v_mensaje = 'NO EXISTE BENEFICIARIO PARA EL CREDITO' THEN
      RETURN 'CNOEBENCRE';
    WHEN v_mensaje = 'NO EXISTE BENEF. PARA EL CREDITO SIPAP' THEN
      RETURN 'CNOEBENSIP';
    WHEN v_mensaje = 'NO TIENE ORDEN PAGO' THEN
      RETURN 'CNOORDPAGO';
    WHEN v_mensaje = 'NO TIENE NRO. FACTURA' THEN
      RETURN 'CNOTNROFAC';
    WHEN v_mensaje = 'NO TIENE MONTO A PAGAR' THEN
      RETURN 'CNOTMANPAG';
    WHEN v_mensaje = 'MONTO INVALIDO' THEN
      RETURN 'CMONTINVAL';
    WHEN v_mensaje = 'MONEDA NO ADMITE DECIMAL' THEN
      RETURN 'CMONNOADEC';
    WHEN v_mensaje = 'MONEDA NO CORESPONDE A LA CTA. DE DEBITO' THEN
      RETURN 'CMONCTADEB';
    WHEN v_mensaje = 'NO TIENE NRO.DE ORDEN EN FACTURAS' THEN
      RETURN 'CNOTORDFAC';
    WHEN v_mensaje = 'NO TIENE NRO.FACTURA EN EL DETALLE' THEN
      RETURN 'CNOTFACDET';
    WHEN v_mensaje = 'NO TIENE MONTO LA FACTURA' THEN
      RETURN 'CNOTMONFAC';
    WHEN v_mensaje = 'NO COINCIDE MONTO DE ORDEN CON FACTURAS' THEN
      RETURN 'CNOCMONFEC';
    WHEN v_mensaje = 'ORDEN YA INGRESADA ANTERIORMENTE' THEN
      RETURN 'CNORDREPET';
    WHEN v_mensaje = 'REGISTRO YA INGRESADO ANTERIORMENTE' THEN
      RETURN 'CREGINGREA';
    WHEN v_mensaje LIKE 'EL TOTAL DE CABECERA:%NO COINCIDE CON EL TOTAL DEL DETALLE:%' THEN
      p_respuesta := 'R22';
      RETURN 'CTOT999CAB';
    WHEN v_mensaje = 'LOS TOTALES POR ORDEN NO COINCIDEN' THEN
      RETURN 'CTOTORDCON';
    WHEN v_mensaje = 'EXISTEN FACTURAS CON IMPORTES NEGATIVOS.' THEN
      p_respuesta := 'R22';
      RETURN 'CEXIFACNEG';
    WHEN v_mensaje = 'LOS DATOS DE DETALLE YA ESTAN EN EL SISTEMA. VERIFIQUE' THEN
      RETURN 'CDATDETEXI';
  END CASE;
  RETURN NULL;
END; --fin fu_obtCodigoRetorno
  
  FUNCTION lf_val_caja(p_sesion IN typ_validarSesion) RETURN typ_mensajeCaja IS
    MSG_CAJ_PROHIBIDA     CONSTANT VARCHAR2(15) := 'CAJ_PROHIBIDA';
    MSG_EST_CAJ_INVALIDA  CONSTANT VARCHAR2(15) := 'EST_CAJ_INVALID';
    MSG_CAJ_NO_ENCONTRADA CONSTANT VARCHAR2(15) := 'CAJ_NO_ENCONTRA';
    -- Verifico la situacion del numero de caja
    v_est_caja       cj_cajas.estado%TYPE;
    v_tip_caja       cj_cajas.tipo%TYPE;
    v_cod_ofi_origen cj_cajas.cod_oficina%TYPE;
    v_cod_usuario    cj_cajas.cod_usuario%TYPE;
    v_ult_cierre     cj_cajas.fec_hor_cierre%TYPE;
    v_retorno        typ_mensajeCaja;
  BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                              v_retorno.error);
    SELECT estado, tipo, cod_oficina, cod_usuario, fec_hor_cierre
    INTO v_est_caja, v_tip_caja, v_cod_ofi_origen, v_cod_usuario, v_ult_cierre
    FROM cj_cajas
    WHERE nro_caja = to_number(p_sesion.codigoCanal);
    IF v_tip_caja NOT IN ('C', 'I', 'S') THEN
      -- tipo de caja no permitido
      -- paw_bce.v_cod_respuesta := '-20';
      paw_uti.pr_mensajeUsuario(MSG_CAJ_PROHIBIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
    END IF;
    IF v_est_caja <> 'A' THEN
      -- paw_bce.v_cod_respuesta := '-20';
      paw_uti.pr_mensajeUsuario(MSG_EST_CAJ_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
    END IF;
    v_retorno.estadoCaja          := v_est_caja;
    v_retorno.tipoCaja            := v_tip_caja;
    v_retorno.codigoOficinaOrigen := v_cod_ofi_origen;
    v_retorno.codigoUsuario       := v_cod_usuario;
    v_retorno.fechaUltimoCierre   := v_ult_cierre;
    RETURN v_retorno;
  EXCEPTION
    WHEN no_data_found THEN
      -- paw_bce.v_cod_respuesta := '-20'; -- con error
      paw_uti.pr_mensajeUsuario(MSG_CAJ_NO_ENCONTRADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
      RETURN v_retorno;
  END;
 /*
  Verifica que la cuenta pertenezca ala persona
 */
 FUNCTION lf_val_cta_origen(p_nro_cuenta IN VARCHAR2, p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
   v_sino VARCHAR(1) := 'N';
 BEGIN
   SELECT 'S'
   INTO v_sino
   FROM ge_cta_clientes
   WHERE nro_cuenta = p_nro_cuenta
   AND cod_persona = p_cod_persona
   AND rownum = 1;
   RETURN v_sino;
 EXCEPTION
   WHEN OTHERS THEN
     v_sino := 'N';
     RETURN v_sino;
 END; --fin lf_val_cta_origen

  FUNCTION lf_obt_bco_snp(p_codigo IN NUMBER) RETURN VARCHAR2 IS
    v_retorno gv_snp_participantes.participante%TYPE := NULL;
  BEGIN
    IF nvl(p_codigo, 0) = 0 THEN
      v_retorno := 'BBVA';
    ELSE
      BEGIN
        SELECT a.participante INTO v_retorno FROM gv_snp_participantes a WHERE a.cod_banco = p_codigo;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          SELECT b.participante INTO v_retorno FROM gv_snp_participantes b WHERE b.cod_ente = p_codigo;
      END;
      v_retorno := initCap(v_retorno);
    END IF;
    RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  PROCEDURE pr_con_mon_a_moneda(p_cod_mon_original IN ba_monedas.cod_moneda%TYPE,
                                p_cod_mon_destino IN ba_monedas.cod_moneda%TYPE, p_mto_mon_original IN NUMBER,
                                p_mto_mon_destino OUT NUMBER, p_cot_mon_original IN OUT NUMBER,
                                p_cot_mon_destino IN OUT NUMBER, p_interbancaria IN VARCHAR2 DEFAULT NULL) IS
    v_lugar VARCHAR2(100);
    -- obtener cotizacion para operaciones via banca electronica
    FUNCTION lf_obt_cotizacion(p_cod_moneda IN ba_monedas.cod_moneda%TYPE, p_tipo IN VARCHAR2
                                -- C-COMPRA o V-VENTA
                               ) RETURN NUMBER IS
      v_fec_actual DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
      v_cotizacion ge_cotizaciones.val_conversion%TYPE;
    BEGIN
      SELECT decode(p_tipo, 'C', val_com_electronica, 'V', val_ven_electronica, NULL)
      INTO v_cotizacion
      FROM ge_cotizaciones a
      WHERE fecha = (SELECT MAX(fecha)
                     FROM ge_cotizaciones
                     WHERE cod_moneda = a.cod_moneda
                     AND fecha <= v_fec_actual)
      AND cod_moneda = p_cod_moneda;
      RETURN v_cotizacion;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
      WHEN OTHERS THEN
        RETURN NULL;
    END;
    -- fin fu_obt_cotizacion
  BEGIN
    v_lugar := 'obtener moneda base';
    IF p_cod_mon_original = p_cod_mon_destino THEN
      p_mto_mon_destino := p_mto_mon_original;
      IF p_cod_mon_original <> v_cod_mon_local THEN
        p_cot_mon_destino  := nvl(p_cot_mon_original, pag_gen.fu_obt_cotizacion(p_cod_mon_original));
        p_cot_mon_original := p_cot_mon_destino;
      ELSE
        p_cot_mon_destino  := 1;
        p_cot_mon_original := 1;
      END IF;
    ELSE
      IF nvl(p_interbancaria, 'N') = 'N' THEN
        IF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino = v_cod_mon_local THEN
          --convertir moneda original a base o destino
          p_cot_mon_original := nvl(p_cot_mon_original, lf_obt_cotizacion(p_cod_mon_original, 'C' /*COMPRA*/));
          p_cot_mon_destino  := 1;
          p_mto_mon_destino  := round(p_mto_mon_original * p_cot_mon_original, 0);
        ELSIF p_cod_mon_original = v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
          -- pasar moneda original a moneda base
          p_cot_mon_original := 1;
          p_cot_mon_destino  := nvl(p_cot_mon_destino, lf_obt_cotizacion(p_cod_mon_destino, 'V' /*VENTA */));
          p_mto_mon_destino  := round(p_mto_mon_original / p_cot_mon_destino, 2);
        ELSIF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
          p_cot_mon_original := nvl(p_cot_mon_original, lf_obt_cotizacion(p_cod_mon_original, 'C' /*COMPRA*/));
          p_mto_mon_destino  := p_mto_mon_original * p_cot_mon_original;
          p_cot_mon_destino  := nvl(p_cot_mon_destino, lf_obt_cotizacion(p_cod_mon_destino, 'V' /*VENTA */));
          p_mto_mon_destino  := round(p_mto_mon_destino / p_cot_mon_destino, 2);
        END IF;
      ELSE
        --SNP
        IF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino = v_cod_mon_local THEN
          --convertir moneda original a base o destino
          p_cot_mon_original := nvl(p_cot_mon_original, paw_bce.fu_obt_cotizacion(p_cod_mon_original, 'V' /*VENTA*/));
          p_cot_mon_destino  := 1;
          p_mto_mon_destino  := round(p_mto_mon_original * p_cot_mon_original, 0);
        ELSIF p_cod_mon_original = v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
          -- pasar moneda original a moneda base
          p_cot_mon_original := 1;
          p_cot_mon_destino  := nvl(p_cot_mon_destino, paw_bce.fu_obt_cotizacion(p_cod_mon_destino, 'C' /*COMPRA*/));
          p_mto_mon_destino  := round(p_mto_mon_original / p_cot_mon_destino, 2);
        ELSIF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
          p_cot_mon_original := nvl(p_cot_mon_original, paw_bce.fu_obt_cotizacion(p_cod_mon_original, 'V' /*VENTA*/));
          p_mto_mon_destino  := p_mto_mon_original * p_cot_mon_original;
          p_cot_mon_destino  := nvl(p_cot_mon_destino, paw_bce.fu_obt_cotizacion(p_cod_mon_destino, 'C' /*COMPRA*/));
          p_mto_mon_destino  := round(p_mto_mon_destino / p_cot_mon_destino, 2);
        END IF;
        --SNP
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, v_lugar || ' - ' || SQLERRM);
  END;

  FUNCTION lf_val_cta_debito(p_nro_cta_debito IN VARCHAR2,
                             p_cod_tra_padre IN NUMBER,
                             p_monto IN NUMBER,
                             p_cod_mon_debito OUT VARCHAR2,
                             p_cod_mod_debito OUT NUMBER,
                             p_cod_mad_debito OUT NUMBER,
                             p_cod_ofi_debito OUT NUMBER,
                             p_cta_for_debito OUT VARCHAR2,
                             p_nom_cta_debito OUT VARCHAR2,
                             p_cod_modulo IN ge_modalidades.cod_modulo%TYPE DEFAULT NULL,
                             p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE DEFAULT NULL)
    RETURN typ_mensajeRespuesta IS
    MSG_COD_CTA_INVALIDA    CONSTANT VARCHAR2(15) := 'COD_CTA_INVALID';
    MSG_COD_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := 'COD_CTA_INEXIST';
    MSG_COD_TRA_PROHIBIDA   CONSTANT VARCHAR2(15) := 'COD_TRA_PROHIB';
    MSG_COD_SAL_INSUF       CONSTANT VARCHAR2(15) := 'COD_SAL_INSUF';
    MSG_COD_CTA_DUPLICADA   CONSTANT VARCHAR2(15) := 'COD_CTA_DUPLIC';

    v_est_cta_debito VARCHAR2(1);
    v_nvo_estado     VARCHAR2(1) := NULL; -- cambio de estado de cuenta
    v_procesa        VARCHAR2(1) := 'N';
    v_sal_disponible NUMBER(18, 2);
    v_can_conjunta   NUMBER(7);
    v_retorno        typ_mensajeRespuesta := typ_mensajeRespuesta;
    v_cod_ofi_origen ba_oficinas.cod_oficina%type := fug_obt_ofi_usuario(user);
    -- verifico cuenta de debito
  BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

    SELECT a.cod_moneda, a.estado, cod_modalidad, cod_modulo, cod_oficina,
           fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda) cta_formateada,
           denominacion
    INTO p_cod_mon_debito, v_est_cta_debito, p_cod_mad_debito, p_cod_mod_debito, p_cod_ofi_debito, p_cta_for_debito,
         p_nom_cta_debito
    FROM ge_cuentas a
    WHERE a.nro_cuenta = p_nro_cta_debito; -- contiene el nro de cuenta
    -- debito
    pag_cta.PR_OBT_CUENTA(p_nro_cta_debito);
    v_est_cta_debito := pag_cta.FU_OBT_EST_CUENTA;
    IF p_cod_mad_debito NOT IN (31, 41) THEN
      paw_uti.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
      -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
    ELSIF v_est_cta_debito NOT IN ('P', 'I', 'N', 'S') THEN
      paw_uti.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
      -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
    ELSIF pag_cta.fu_ver_tra_prohibida(p_nro_cta_debito, p_cod_tra_padre, 9, 91) = 'S' THEN
      paw_uti.pr_mensajeUsuario(MSG_COD_TRA_PROHIBIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
    ELSE
      pag_cta.pr_ver_operacion(p_nro_cta_debito, p_cod_tra_padre, nvl(p_cod_modulo, 9), nvl(p_cod_modalidad, 91), 'D',
                               p_cod_mon_debito, p_monto, v_cod_ofi_origen,
                               p_cod_mod_debito, p_cod_mad_debito, v_nvo_estado, v_sal_disponible, v_procesa, 503);
      IF v_procesa = 'N' THEN
        -- no se puede debitar
        IF instr(upper(pag_cta.G_MSJ_ERROR), 'INSUFIC') > 0 THEN
          -- saldo insuficiente
          paw_uti.pr_mensajeUsuario(MSG_COD_SAL_INSUF, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                    v_retorno.error);
          -- v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
        ELSE
          paw_uti.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                    v_retorno.error);
          -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
        END IF;
      END IF;
    END IF;
    -- agregado para permitir a cuentas indistintas de personas fisicas grabar sin autorizacion
    IF v_retorno.error = 'N' THEN
      -- veo si la cuenta no es conjunta
      SELECT COUNT(*)
      INTO v_can_conjunta
      FROM ge_cta_clientes
      WHERE nro_cuenta = p_nro_cta_debito
      AND relacion = 'Y'
      AND rownum = 1;
      IF nvl(v_can_conjunta, 0) = 0 THEN
        -- veo si es persona fisica no debe requerir autorizacion
        v_can_aut_requeridas := 0; -- no tiene autorizacion pendiente cuando es la persona fisica
      END IF;
    END IF;

    RETURN v_retorno;
  EXCEPTION
    WHEN no_data_found THEN
      paw_uti.pr_mensajeUsuario(MSG_COD_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
      RETURN v_retorno;
    WHEN too_many_rows THEN
      paw_uti.pr_mensajeUsuario(MSG_COD_CTA_DUPLICADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
      RETURN v_retorno;
    WHEN OTHERS THEN
      paw_uti.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
      RETURN v_retorno;
  END; --lf_val_cta_debito

  PROCEDURE pr_ins_notificaciones(p_cod_ente IN NUMBER, p_cod_operacion IN NUMBER, p_cod_persona IN VARCHAR2,
                                  p_tipo IN VARCHAR2, p_est_notificacion IN VARCHAR2, p_campo1 IN VARCHAR2 DEFAULT NULL,
                                  p_valor1 IN VARCHAR2 DEFAULT NULL, p_campo2 IN VARCHAR2 DEFAULT NULL,
                                  p_valor2 IN VARCHAR2 DEFAULT NULL, p_campo3 IN VARCHAR2 DEFAULT NULL,
                                  p_valor3 IN VARCHAR2 DEFAULT NULL, p_campo4 IN VARCHAR2 DEFAULT NULL,
                                  p_valor4 IN VARCHAR2 DEFAULT NULL) IS
    v_fecha         DATE := pag_cal.fu_obt_fec_actual(1);
    v_hora          VARCHAR2(8) := to_char(SYSDATE, 'hh24:mi:ss');
    v_nro_secuencia NUMBER;
  BEGIN
    BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    END;

    v_nro_secuencia := paw_prv.fu_obt_secuencia(v_fecha, p_cod_ente);

    INSERT INTO ge_not_hub_global
      (fecha, hora, nro_secuencia, cod_ente, cod_operacion, cod_persona, tipo, est_notificacion, fec_envio, campo1,
       valor1, campo2, valor2, campo3, valor3, campo4, valor4)
    VALUES
      (v_fecha, v_hora, v_nro_secuencia, p_cod_ente, p_cod_operacion, p_cod_persona, p_tipo, p_est_notificacion, NULL,
       p_campo1, p_valor1, p_campo2, p_valor2, p_campo3, p_valor3, p_campo4, p_valor4);
  END; --pr_ins_notificaciones

  FUNCTION fu_ver_prv_hubglobal(p_cod_ente IN NUMBER) RETURN BOOLEAN IS
  BEGIN
    IF nvl(fug_obt_parentes(p_cod_ente, 'HAB_PRV_HUB_GLOBAL'), 'N') = 'S' THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END; --fin fu_ver_prv_hubglobal

  FUNCTION fu_obt_secuencia(p_fecha DATE, p_cod_ente NUMBER) RETURN NUMBER IS
    v_nro_secuencia NUMBER(3);
  BEGIN
    SELECT MAX(a.nro_secuencia)
    INTO v_nro_secuencia
    FROM ge_not_hub_global a
    WHERE a.fecha = p_fecha
    AND a.cod_ente = p_cod_ente
    GROUP BY trunc(a.fecha), a.cod_ente;
    RETURN nvl(v_nro_secuencia, 0) + 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 1;
    WHEN OTHERS THEN
      RETURN 1;
  END; --fu_obt_secuencia
  
  -- Verificación de Movimientos pendientes BBVA y SIPAP
  PROCEDURE pr_ver_pag_global IS
  v_fec_actual date := pag_cal.fu_obt_fec_actual(1);
  v_act_cab    varchar2(1) := 'N';
  v_estado     varchar2(3) := 'R41';
  cursor c_cab is
    select *
      from ge_pag_pro_hub_glo_cab a
     where a.estado = 'R31' for update;
  CURSOR c_pag(p_nro_archivo number, p_cod_ente number, p_nom_agrupado varchar2) IS
    select d.*, b.rowid as nroreg
      from ge_pag_proveedores a,
           ge_pag_pro_hub_global b,
           ge_snp_transferencias d
     where trunc(a.fec_insercion) <= v_fec_actual
       and a.estado = 'N'
       and b.nro_archivo = p_nro_archivo
       and b.cod_ente = p_cod_ente
       and b.hub_nom_agrupado = p_nom_agrupado
       and b.cod_ente = a.cod_ente
       and b.cod_moneda = a.cod_moneda
       and b.nro_archivo = a.nro_archivo
       and b.nro_factura = a.nro_factura
       and b.nro_orden = a.nro_orden
       and b.for_pago = 'I'
       and b.estado = 'C'
       and d.nro_referencia = a.nro_referencia
       and d.estado = 'A';
   cursor c_pagf(p_nro_archivo number, p_cod_ente number, p_nom_agrupado varchar2) IS
     select a.*, b.rowid as nroregf
       from ge_pag_proveedores a, 
            ge_pag_pro_hub_global b
      where trunc(a.fec_insercion) <= v_fec_actual
        and a.cod_ente = b.cod_ente
        and a.nro_archivo = b.nro_archivo
        and a.nro_orden = b.nro_orden
        and a.nro_factura = b.nro_factura
        and b.nro_archivo = p_nro_archivo
        and b.cod_ente = p_cod_ente
        and b.hub_nom_agrupado = p_nom_agrupado
        and b.cod_respuesta = 'R31'
        and b.for_pago = 'C'
        and b.estado = 'C';
  BEGIN
    Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
    for k in c_cab loop
      for x in c_pag(k.nro_archivo,k.ente,k.nom_agrupado) loop
        if x.situacion = 'L' then
          update ge_pag_pro_hub_global g
             set g.estado = 'N',
                 g.cod_respuesta = v_estado
           where g.rowid = x.nroreg;
          if v_act_cab = 'N' then
            v_act_cab := 'S';
          end if;
        end if;
      end loop;
      if v_act_cab = 'S' then
        update ge_pag_pro_hub_glo_cab a
           set a.estado = v_estado
         where current of c_cab;
      end if;
      for m in c_pagf(k.nro_archivo,k.ente,k.nom_agrupado) loop
        if m.estado = 'N' then
          update ge_pag_pro_hub_global g
             set g.estado = 'N',
                 g.cod_respuesta = v_estado
           where g.rowid = m.nroregf;
          if v_act_cab = 'N' then
            v_act_cab := 'S';
          end if;
        elsif m.estado = 'A' then
          v_estado := 'R42';
          update ge_pag_pro_hub_global g
             set g.estado = 'E',
                 g.cod_respuesta = v_estado,
                 g.msj_respuesta = 'OPERROR',
                 g.des_respuesta = 'Ocurrió un error en verificación Posterior.'
           where g.rowid = m.nroregf;
           prg_ins_log_errores('paw_prv.pr_ver_pag_global','m.estado = A',
                               'p_nro_archivo',k.nro_archivo,'p_cod_ente',k.ente,'p_nom_agrupado',k.nom_agrupado);
          if v_act_cab = 'N' then
            v_act_cab := 'S';
          end if;  
        end if;
      end loop;
      if v_act_cab = 'S' then
        update ge_pag_pro_hub_glo_cab a
           set a.estado = v_estado
         where current of c_cab;
      end if;
    end loop;
  END;

  PROCEDURE pr_pro_archivo(p_nro_archivo IN NUMBER,
                           p_cod_ente    IN NUMBER,
                           p_nom_agrupado IN VARCHAR2,
                           p_error       OUT VARCHAR2) IS
    CURSOR c_dat IS
      select *
        from ge_pag_pro_hub_global a
       WHERE a.nro_archivo = p_nro_archivo
         and a.cod_ente = p_cod_ente
         and a.hub_nom_agrupado = p_nom_agrupado
         and a.cod_respuesta is null
         and a.estado = 'I'
         FOR UPDATE;

    v_fec_actual     date := pag_cal.fu_obt_fec_actual(1);
    v_cod_persona    ba_personas.cod_persona%TYPE;
    v_cod_ente       ge_entes.cod_ente%type := p_cod_ente;
    v_val_cta_deb    VARCHAR2(1) := 'N';
    v_cod_mon_debito ge_cuentas.Cod_Moneda%type;
    v_cot_credito    ge_movimientos.cotizacion%TYPE;
    v_cot_debito     ge_movimientos.cotizacion%TYPE;
    v_tot_debito     ge_movimientos.monto%TYPE := 0;
    v_mto_debito     ge_movimientos.monto%TYPE := 0;
    v_fec_pago       date;
    v_error          varchar2(1000);
    v_can_ordenes    number := 0;
    v_est_periodo    ge_snp_horarios.estado%TYPE;
    v_fec_snp_hor    ge_snp_horarios.fecha%TYPE;
    v_hora_fin       ge_snp_horarios.hor_fin%TYPE;
    v_hora_pro       ge_snp_horarios.hor_fin%TYPE;
    v_cantidad       NUMBER;
    v_cam_fecha      BOOLEAN;
    v_nro_archivo    NUMBER;
    v_nro_documento  NUMBER;
    v_cod_operacion  VARCHAR2(3) := '075';
    v_tip_pago       VARCHAR2(1) := 'P';
    v_des_pendiente  bw_mov_pendientes.descripcion%TYPE;
    v_err_pago       VARCHAR2(2) := '00';
    v_des_ente       ge_entes.descripcion%TYPE;
    v_mto_total      NUMBER;
    v_cta_debito     VARCHAR2(100);
    v_tra_pad_proveedor ge_movimientos.cod_tra_padre%TYPE := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_PPROV');
    v_cod_tra_padre     ge_movimientos.cod_tra_padre%TYPE;
    v_cod_modulo        ge_cuentas.cod_modulo%type;
    v_cod_modalidad     ge_cuentas.cod_modalidad%type;
    v_msj_respuesta     typ_MensajeRespuesta := typ_MensajeRespuesta;
    v_cod_oficina       ge_movimientos.cod_oficina%TYPE;
    v_cta_for_debito    VARCHAR2(17);
    v_nom_cta_debito    VARCHAR2(100);
    v_retorno           typ_pagoProveedores := typ_pagoProveedores();
    v_ind_sipap         varchar2(1) := 'N';
    v_reg_cab           varchar2(1) := 'S';
    v_men_respuesta     varchar2(100);
    v_dir_correo        ba_personas.dir_correo%TYPE;
    v_estado            varchar2(3);
    v_fec_pag_habil     date;

    procedure lp_act_pag_cab(p_nom_mensaje varchar2, p_respuesta varchar2)
    is
    begin
      update ge_pag_pro_hub_glo_cab a
         set a.nom_mensaje = nvl(substr(replace(p_nom_mensaje,'_'),-10),(replace(p_nom_mensaje,'_'))),
             a.estado = p_respuesta
       where a.nro_archivo = p_nro_archivo
         and a.ente = p_cod_ente
         and a.nom_agrupado = p_nom_agrupado;
    end;
    --
    procedure lp_act_pag_det(p_nom_mensaje varchar2, p_respuesta varchar2, p_estado varchar2)
    is
    v_nom_respuesta bw_men_respuesta.nombre%type;
    v_des_mensaje   bw_men_respuesta.des_mensaje%type;
    v_error         bw_men_respuesta.error%type;
    begin
      paw_uti.pr_mensajeUsuario(p_nom_mensaje, v_nom_respuesta, v_des_mensaje, v_error);
      v_nom_respuesta := nvl(substr(replace(v_nom_respuesta,'_'),-10),(replace(v_nom_respuesta,'_')));

      update ge_pag_pro_hub_global a
         set a.msj_respuesta = v_nom_respuesta,
             a.des_respuesta = v_des_mensaje,
             a.cod_respuesta = p_respuesta,
             a.estado        = p_estado
       where a.nro_archivo = p_nro_archivo
         and a.cod_ente = p_cod_ente
         and a.hub_nom_agrupado = p_nom_agrupado;
    end;
    
    function lf_ver_errores return varchar2 is
      v_cod_respuesta varchar2(3);
    begin
      select a.hub_iso_err_codigo
        into v_cod_respuesta
        from ge_pag_pro_hub_global a
       where a.cod_ente = p_cod_ente
         and a.nro_archivo = p_nro_archivo
         and a.hub_nom_agrupado = p_nom_agrupado
         and a.estado = 'E'
         and rownum = 1;
         return v_cod_respuesta;
        EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
    end;
    
    /* Obtiene la hora fin snp de un periodo */
    function lf_obt_hor_fin_snp(p_cod_periodo in ge_snp_horarios.cod_periodo%type) return varchar2 is
       v_retorno ge_snp_horarios.hor_fin%TYPE;
    begin
       select h.hor_fin
         into v_retorno
         from ge_snp_horarios h
        where h.cod_periodo = p_cod_periodo;
       return v_retorno;
    exception
       when others then
          return null;
    end lf_obt_hor_fin_snp;
      

  BEGIN
    Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
    p_error := 'N';
    v_nro_archivo := p_nro_archivo;
    -- Actualizar la cabecera si hay errores.
    v_estado := lf_ver_errores;
    if v_estado is not null then
      begin
        update ge_pag_pro_hub_glo_cab a
           set a.estado = v_estado
         where a.nro_archivo = p_nro_archivo
           and a.ente = p_cod_ente
           and a.nom_agrupado = p_nom_agrupado
           and a.estado = 'R11';
      end;
      p_error := 'S';
      goto fin;
    end if;
    -- obtener datos de cabecera
    begin
      select a.mon_total, a.nro_cuenta, trunc(a.fec_pago)
        into v_mto_total, v_cta_debito, v_fec_pago
        from ge_pag_pro_hub_glo_cab a
       where a.nro_archivo = p_nro_archivo
         and a.ente = p_cod_ente
         and a.nom_agrupado = p_nom_agrupado
         and a.estado = 'R11';
    exception
      when no_data_found then
        v_reg_cab := 'N';
    end;
    if v_reg_cab = 'N' then
      goto fin;
    end if;
    --
    v_fec_pag_habil := pag_cal.fu_obt_fec_habil(v_fec_pago, 1,1);
    IF v_fec_pago < v_fec_actual 
      and v_fec_pag_habil < v_fec_actual THEN
      p_error := 'S';
      v_men_respuesta := 'FEC_PAGO_INVAL';
      lp_act_pag_cab(v_men_respuesta,'R23');
      lp_act_pag_det(v_men_respuesta,'R23','E');
      prg_ins_log_errores('paw_prv.pr_pro_archivo','Fecha de pago hábil menor a fecha actual.',
                          'p_nro_archivo',p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
      goto fin;
    END IF;
    --
    v_cod_tra_padre := v_tra_pad_proveedor; -- transacción padre para pago a proveedores
    v_des_pendiente := 'Proveedores';
--Cuando no se encuentra el ente
    IF p_cod_ente < 0 THEN
      p_error := 'S';
      v_men_respuesta := 'PRO_OBT_CTA_DEB';
      lp_act_pag_cab(v_men_respuesta,'R23');
      lp_act_pag_det(v_men_respuesta,'R23','E');
      prg_ins_log_errores('paw_prv.pr_pro_archivo','Ente menor a 0.','p_nro_archivo',p_nro_archivo,
                          'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
      goto fin;
    END IF;

    BEGIN
      SELECT a.cod_persona
        INTO v_cod_persona
        FROM ge_cta_clientes a
       where a.nro_cuenta = v_cta_debito
         AND a.relacion = 'P';
    END;
    BEGIN
      select a.cod_moneda
        into v_cod_mon_debito
        from ge_cuentas a
       where a.nro_cuenta = v_cta_debito;
    end;
    begin
      select a.descripcion
        into v_des_ente
        FROM ge_entes a
       WHERE a.cod_ente = p_cod_ente;
    END;
    -- Servicio habilitado
    IF fu_ver_prv_hubglobal(v_cod_ente) THEN
      -- Validar cta corresponde al cliente
      BEGIN
        SELECT DISTINCT 'S'
          INTO v_val_cta_deb
          FROM ge_par_entes a
         WHERE a.cod_ente = v_cod_ente
           AND a.parametro LIKE 'CTA_DEB_PPROV%'
           and a.val_parametro = v_cta_debito;
      EXCEPTION
        WHEN no_data_found THEN
          v_val_cta_deb := 'N';
        WHEN OTHERS THEN
          v_val_cta_deb := 'N';
      END;
      IF v_val_cta_deb = 'N' THEN
        p_error := 'S';
        v_men_respuesta := 'CTANOCORRESPOND';
        lp_act_pag_cab(v_men_respuesta,'R23');
        lp_act_pag_det(v_men_respuesta,'R23','E');
        prg_ins_log_errores('paw_prv.pr_pro_archivo','Cuenta no corresponde.','p_nro_archivo',
                            p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
        goto fin;
      END IF;
    ELSE
      p_error := 'S';
      v_men_respuesta := 'SAL_ERR_DAT_ENT';
      -- Insertar error por no estar con el servicio activo.
      lp_act_pag_cab(v_men_respuesta,'R23');
      lp_act_pag_det(v_men_respuesta,'R23','E');
      prg_ins_log_errores('paw_prv.pr_pro_archivo','Servicio no activado para el ente','p_nro_archivo',
                           p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
      goto fin;
    END IF;
    -- Limpiar TMP
    pag_prv.PR_ELI_PROV_TMP(v_cod_ente, SYSDATE, v_nro_archivo);
    pag_prv.PR_ELI_FAC_TMP(v_cod_ente, SYSDATE, v_nro_archivo);
    
    for k in c_dat loop
      v_can_ordenes := nvl(v_can_ordenes,0) + 1;
      if k.for_pago = 'I' and v_ind_sipap = 'N' then
        v_ind_sipap := 'S';
      end if;
      IF k.monto > 0 THEN
        IF k.cod_moneda = v_cod_mon_debito THEN
          v_tot_debito := v_tot_debito + k.monto;
        ELSE
          v_mto_debito := 0;
          IF k.nro_con_cambio IS NOT NULL THEN
            pag_prv.pr_val_nro_contrato(k.nro_con_cambio,
                                        v_cod_persona,
                                        k.monto,
                                        v_cod_mon_debito, -- moneda debito
                                        k.cod_moneda, -- moneda credito
                                        'S',
                                        k.cod_proceso,
                                        k.concepto,
                                        v_mto_debito);
          ELSE
            BEGIN
              pr_con_mon_a_moneda(K.cod_moneda,
                                  v_cod_mon_debito,
                                  K.monto,
                                  v_mto_debito,
                                  v_cot_credito,
                                  v_cot_debito,
                                  'S');
            EXCEPTION
              WHEN OTHERS THEN
                p_error := 'S';
                v_men_respuesta := 'ERRCONVERS';
                update ge_pag_pro_hub_global a
                   set a.estado = 'E',
                       a.des_respuesta = v_men_respuesta, -- 'TRA_ERR_CONVERS' = ERRCONVERS
                       a.cod_respuesta = 'R42'
                 where current of c_dat;
                lp_act_pag_cab(v_men_respuesta,'R42');
                prg_ins_log_errores('paw_prv.pr_pro_archivo','Contrato de cambio.','p_nro_archivo',
                            p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
                goto fin;
            END;
          END IF;
          IF nvl(v_mto_debito, 0) > 0 THEN
            v_tot_debito := v_tot_debito + v_mto_debito;
          END IF;
        END IF;
      END IF;
      BEGIN
        INSERT INTO ge_pag_proveedores_tmp
          (nro_orden,
           nro_factura,
           tip_comprobante,
           for_pago,
           nro_cheque,
           nro_cta_credito,
           fec_ingreso,
           fec_pago,
           monto,
           nro_recibo,
           beneficiario,
           concepto,
           estado,
           cod_usu_operador,
           cod_ente,
           cod_proceso,
           cod_moneda,
           tip_carga,
           cod_mon_recibido,
           ref_facturas,
           referencia,
           mon_tot_recibo,
           ret_fac_proveedor,
           des_fac_proveedor,
           ret_facturas,
           des_sucursal,
           tipo,
           nro_cta_debito,
           nro_secuencia,
           nro_archivo,
           cod_tip_doc_beneficiario,
           nro_doc_beneficiario,
           nro_cta_beneficiario,
           ent_bca_beneficiario,
           ind_valor,
           dir_beneficiario,
           tip_factura,
           nro_con_cambio,
           ben_dir_correo,
           nro_ord_archivo)
        VALUES
          (k.nro_orden,
           k.nro_factura,
           k.tip_comprobante,
           k.for_pago,
           k.nro_cheque,
           k.nro_cta_credito,
           k.fec_ingreso,
           k.fec_pago,
           k.monto,
           k.nro_recibo,
           k.beneficiario,
           k.concepto,
           'C',
           k.cod_usu_operador,
           k.cod_ente,
           k.cod_proceso,
           k.cod_moneda,
           k.tip_carga,
           k.cod_mon_recibido,
           k.ref_facturas,
           k.referencia,
           k.mon_tot_recibo,
           k.ret_fac_proveedor,
           k.des_fac_proveedor,
           k.ret_facturas,
           k.des_sucursal,
           k.tipo,
           k.nro_cta_debito,
           k.nro_secuencia,
           k.nro_archivo,
           k.cod_tip_doc_beneficiario,
           k.nro_doc_beneficiario,
           k.nro_cta_beneficiario,
           k.ent_bca_beneficiario,
           k.ind_valor,
           k.dir_beneficiario,
           k.tip_factura,
           k.nro_con_cambio,
           k.ben_dir_correo,
           k.nro_ord_archivo
           );
      EXCEPTION
        WHEN OTHERS THEN
          p_error := 'S';
          v_men_respuesta := 'ROERRDATOS';
          update ge_pag_pro_hub_global a
             set a.estado = 'E',
                 a.msj_respuesta = v_men_respuesta, --'PRO_ERR_DATOS'
                 a.cod_respuesta = 'R42'
           where current of c_dat;
           lp_act_pag_cab(v_men_respuesta,'R42');
           prg_ins_log_errores('paw_prv.pr_pro_archivo','Exception de insert en ge_pag_proveedores_tmp.',
                               'p_nro_archivo',p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
           goto fin;
          --raise_application_error(-20000, 'Error: ' || sqlerrm);
      END;
    END LOOP;
    IF v_can_ordenes = 0 THEN
      lp_act_pag_cab('PRO_ERR_DAT_INV', 'R42');
      lp_act_pag_det('PRO_ERR_DAT_INV','R42','E');
      prg_ins_log_errores('paw_prv.pr_pro_archivo','v_can_ordenes = 0. No ingresó al cursor c_dat.',
                               'p_nro_archivo',p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
      goto fin;
    END IF;

    IF nvl(p_error,'N') <> 'S' THEN
      v_msj_respuesta := lf_val_cta_debito(v_cta_debito, v_cod_tra_padre, v_tot_debito,
                                           v_cod_mon_debito, v_cod_modulo, v_cod_modalidad,
                                           v_cod_oficina, v_cta_for_debito, v_nom_cta_debito);

      v_men_respuesta := v_msj_respuesta.nombreRespuesta;
      
      IF v_men_respuesta = 'COD_CTA_INVALID' then
        v_men_respuesta  := 'C_EST_CTA_INV';
      ELSIF v_men_respuesta = 'COD_CTA_INEXIST' then
        v_men_respuesta  := 'PRO_CTA_DEB_INE';
      ELSIF v_men_respuesta = 'COD_TRA_PROHIB' then
        v_men_respuesta  := 'G_CODTRAPROHIB';
      ELSIF v_men_respuesta = 'COD_CTA_DUPLIC' then
        v_men_respuesta  := 'PRO_CTA_DEB_DUP';
      END IF;
      
      -- solo debe tener en cuenta el saldo si la fecha de pago es al dia
      IF v_msj_respuesta.nombreRespuesta = 'COD_SAL_INSUF' THEN
        IF v_fec_pago <> v_fec_actual THEN
          v_msj_respuesta.error := 'N';
          v_men_respuesta := 'OP_APROBADA';
        ELSE
          v_msj_respuesta.error := 'S';
          p_error := 'S';
          lp_act_pag_cab(v_men_respuesta,'R24');
          lp_act_pag_det(v_men_respuesta,'R24','E');
          prg_ins_log_errores('paw_prv.pr_pro_archivo','Saldo Insusficiente para la fecha de pago actual',
                              'p_nro_archivo',p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
          goto fin;
        END IF;
      END IF;

      IF v_msj_respuesta.error = 'S' THEN
        -- para poder corregir los decimales en los detalles
        p_error := 'S';
        IF instr(pag_cta.G_MSJ_ERROR, 'Decimales no permitidos') > 0 THEN
          v_men_respuesta := 'CMONNOADEC';
          lp_act_pag_cab(v_men_respuesta,'R42');          
          begin
            update ge_pag_pro_hub_global a
               set a.msj_respuesta = v_men_respuesta,
                   a.des_respuesta = 'MONEDA NO ADMITE DECIMAL',
                   a.cod_respuesta = 'R42',
                   a.estado        = 'E'
             where a.nro_archivo = p_nro_archivo
               and a.cod_ente = p_cod_ente
               and a.hub_nom_agrupado = p_nom_agrupado;
          end;
          prg_ins_log_errores('paw_prv.pr_pro_archivo','La moneda no permite Decimales.','p_nro_archivo',
                               p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
        ELSE
          v_retorno.error                := v_msj_respuesta.error;
          v_retorno.nombreRespuesta      := v_msj_respuesta.nombreRespuesta;
          v_retorno.descripcionRespuesta := v_msj_respuesta.descripcionRespuesta;
          lp_act_pag_cab(v_men_respuesta,'R42');
          lp_act_pag_det(v_men_respuesta,'R42','E');
          prg_ins_log_errores('paw_prv.pr_pro_archivo','Error en validación lf_val_cta_debito.','p_nro_archivo',
                               p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
        END IF;
        goto fin;
      END IF;

    --
      pag_prv.PR_VER_DAT_TMP(v_cod_ente,
                             v_fec_pago,
                             NULL,
                             v_error,
                             'N',
                             NULL,
                             v_cta_debito,
                             p_nro_archivo);
      prg_ins_log_errores('paw_prv.pr_pro_archivo', 'Luego de llamar a pag_prv.PR_VER_DAT_TMP (N), v_error = '||nvl(v_error,'null'),
                          'p_nro_archivo',p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
      IF v_error IS NOT NULL THEN
        p_error := 'S';
        IF instr(v_error, 'Horario SIPAP Cerrado') > 0 THEN
          lp_act_pag_cab('PRO_ERR_SIPAP', 'R42');
          lp_act_pag_det('PRO_ERR_SIPAP', 'R42','E');
          goto fin;
        ELSIF instr(v_error, 'Errores en la verificacion de datos') > 0 THEN
          declare
          v_mensaje varchar2(40);
          v_cod_respuesta varchar2(3);
          CURSOR c_ptmp IS
            select *
              from ge_pag_proveedores_tmp a
             where trunc(a.fec_insercion) = v_fec_actual
               and a.usu_insercion = user
               and a.cod_ente = v_cod_ente
               and a.nro_archivo = p_nro_archivo
               and a.cod_proceso > 0;
          BEGIN
            for k in c_ptmp loop
              v_mensaje := nvl(fu_obtCodigoRetorno(k.concepto, v_cod_respuesta),'OPERROR');
              update ge_pag_pro_hub_global a
                 set a.msj_respuesta = v_mensaje,
                     a.des_respuesta = k.concepto,
                     a.cod_respuesta = nvl(v_cod_respuesta,'R42'),
                     a.estado = 'E'
               where a.hub_nom_agrupado = p_nom_agrupado
                 and a.cod_ente = k.cod_ente
                 and a.nro_archivo = k.nro_archivo
                 and a.nro_orden = k.nro_orden
                 and a.for_pago = k.for_pago;
            end loop;
            lp_act_pag_cab('PRO_ERR_DAT_INV', 'R42');
            prg_ins_log_errores('paw_prv.pr_pro_archivo','pag_prv detectó error de verif. datos ','p_nro_archivo',
                               p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
            goto fin;
          END;
        ELSE
          v_men_respuesta := 'OP_ERROR';
          lp_act_pag_cab(v_men_respuesta,'R42');          
          begin
            update ge_pag_pro_hub_global a
               set a.msj_respuesta = v_men_respuesta,
                   a.des_respuesta = v_error,
                   a.cod_respuesta = 'R42',
                   a.estado        = 'E'
             where a.nro_archivo = p_nro_archivo
               and a.cod_ente = p_cod_ente
               and a.hub_nom_agrupado = p_nom_agrupado;
          end;
          prg_ins_log_errores('paw_prv.pr_pro_archivo','Error en respuseta pag_prv.PR_VER_DAT_TMP (N) v_error = '||v_error,'p_nro_archivo',
                               p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
        END IF;
      END IF;
      --
      IF v_ind_sipap = 'S' and trunc(v_fec_pago) = v_fec_actual THEN
        v_est_periodo := pas_snp.fu_obt_est_horario('103', '001', '002');
        IF v_est_periodo <> 'A' THEN
          -- hora sipap cerrada
          v_fec_snp_hor := pag_prv.fu_obt_fec_snp(1);
          -- si llego hasta aca es porque el lote no es mixto
          IF v_fec_snp_hor = v_fec_pago THEN
            -- si se cambia la fecha hay que ver si hay monedas distintas
            v_cantidad := pag_prv.fu_obt_can_ope_cambio(v_cod_ente,
                                                        v_fec_pago,
                                                        v_cod_mon_debito,
                                                        p_nro_archivo,
                                                        'S');
            IF v_cantidad > 0 THEN
              p_error := 'S';
              lp_act_pag_cab('PRO_ERR_SIPAP', 'R42');
              lp_act_pag_det('PRO_ERR_SIPAP', 'R42', 'E');
              prg_ins_log_errores('paw_prv.pr_pro_archivo','cantidad > 0 por pag_prv.fu_obt_can_ope_cambio, v_cantidad = '||v_cantidad,'p_nro_archivo',
                               p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
              goto fin;
            ELSE
              v_hora_fin := lf_obt_hor_fin_snp(1);
              v_hora_pro := to_char(sysdate,'HH24MM');
              if to_number(v_hora_pro) >= to_number(v_hora_fin) then
                -- se cambia fecha de pago por hora cerrada, solo pagos SIPAP si llego hasta aca
                v_cam_fecha := pag_prv.fu_cam_fec_pago(v_cod_ente,
                                                       v_fec_pago,
                                                       v_nro_archivo,
                                                       'S');
                lp_act_pag_cab(null, 'R31');
                lp_act_pag_det(v_men_respuesta,'R31','C');
                prg_ins_log_errores('paw_prv.pr_pro_archivo','Cambio a fec. siguiente por v_hora_pro = '||v_hora_pro||' v_hora_fin = '||v_hora_fin,'p_nro_archivo',
                                    p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
                goto fin;
              end if;
            END IF;
          END IF;
        END IF;
      END IF;
    END IF;
    --
    IF p_error = 'S' THEN
      lp_act_pag_det('OP_ERROR','R42','E');
      lp_act_pag_cab('OP_ERROR','R42');
      prg_ins_log_errores('paw_prv.pr_pro_archivo','p_error = S. Luego de pag_prv.pr_ver_dat_tmp, v_error = '||v_error,'p_nro_archivo',
                               p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);      
      goto fin;
    END IF;
    --
    SELECT s_nro_documento.NEXTVAL INTO v_nro_documento FROM dual;

    IF v_can_aut_requeridas > 0 THEN
       --- inserto el movimiento pendiente de autorización

       INSERT INTO bw_mov_pendientes
          (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda, descripcion, monto, cantidad, etiqueta, dato, etiqueta2, dato2, estado, can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, referencia, tip_pago)
       VALUES
          (v_nro_documento, v_cod_persona, SYSDATE, v_cod_operacion, v_cta_debito, v_cod_mon_debito, v_des_pendiente, v_tot_debito, v_can_ordenes, 'Ente', p_cod_ente, 'Fechas de Pago', to_char(v_fec_pag_habil, 'dd/mm/yyyy'), 'P', v_can_aut_requeridas, v_can_aut_requeridas, v_cod_persona, v_nro_archivo, v_tip_pago);
    ELSE

      INSERT INTO bw_mov_pendientes
        (nro_documento, cod_per_principal, fec_hora, cod_tip_mensaje, nro_cuenta, cod_moneda, descripcion, monto, cantidad, etiqueta, dato, etiqueta2, dato2, estado, can_aut_requeridas, can_aut_faltantes, cod_per_ingreso, referencia, tip_pago)
      VALUES
        (v_nro_documento, v_cod_persona, SYSDATE, v_cod_operacion, v_cta_debito, v_cod_mon_debito, v_des_pendiente, v_tot_debito, v_can_ordenes, 'Ente', v_cod_ente, 'Fechas de Pago', to_char(v_fec_pag_habil, 'dd/mm/yyyy'), 'C', 0, 0, v_cod_persona, v_nro_archivo, v_tip_pago);

      pag_prv.PR_VER_DAT_TMP(v_cod_ente,
                             v_fec_pago,
                             NULL,
                             v_error,
                             'S',
                             v_nro_documento,
                             v_cta_debito,
                             v_nro_archivo);
      prg_ins_log_errores('paw_prv.pr_pro_archivo', 'Luego de llamar a pag_prv.PR_VER_DAT_TMP (S), v_error = '||nvl(v_error,'null'),
                          'p_nro_archivo',p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
      IF v_error IS NOT NULL THEN
        p_error := 'S';
        lp_act_pag_cab('PRO_ERR_VER_PAG', 'R42');
        lp_act_pag_det('PRO_ERR_VER_PAG', 'R42', 'E');
        prg_ins_log_errores('paw_prv.pr_pro_archivo','p_error = s luego de pag_prv.pr_ver_dat_tmp s','p_nro_archivo',
                               p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
        goto fin;
      ELSE
        BEGIN
          v_dir_correo := fug_obt_dir_mail_per(v_cod_persona);
        EXCEPTION
          WHEN OTHERS THEN
            v_dir_correo := fug_obt_pardinamico('CAM_MAR_PAG_NOM');--'pagosnominas@bbva.com.py';
        END;
        if v_ind_sipap != 'S' then
          IF v_fec_pag_habil = v_fec_actual THEN
            pag_prv.PR_PRO_PAGO(v_cod_ente, v_nro_documento, v_err_pago);
            IF v_err_pago <> '00' THEN
              p_error := 'S';
              lp_act_pag_cab('PRO_ERR_PRO_PAG', 'R42');
              lp_act_pag_det('PRO_ERR_PRO_PAG', 'R42', 'E');
              prg_ins_log_errores('paw_prv.pr_pro_archivo','v_err_pago <> 00 luego de pag_prv.pr_pro_pago','p_nro_archivo',
                                   p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
              goto fin;
            ELSE
              lp_act_pag_cab(null, 'R41');
              lp_act_pag_det(v_msj_respuesta.nombreRespuesta,'R41','N');
              it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                           v_dir_correo,
                           'Pago a Proveedores en Linea GH',
                           'Pago a Proveedores ingresado por Global Hub ' ||
                           chr(10) || chr(10) || 'Codigo  : ' || v_cod_ente ||
                           chr(10) || 'Empresa : ' || v_des_ente || chr(10) ||
                           'Monto   : ' ||
                           to_char(v_tot_debito, '999G999G999G999D99') || ' ' ||
                           v_cod_mon_debito || chr(10) || 'Cantidad: ' ||
                           to_char(v_can_ordenes) || chr(10) ||
                           'Fecha de Pago: ' || to_char(v_fec_pago) || chr(10) ||
                           chr(10) || 'Atentamente. ');
            END IF;
          ELSE
            lp_act_pag_cab(null, 'R31');
            lp_act_pag_det(v_men_respuesta,'R31','C');
            it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                         v_dir_correo,
                         'Pago a Proveedores Fecha Futura GH',
                         'Pago a Proveedores ingresado por Global Hub ' ||
                         chr(10) || chr(10) || 'Codigo  : ' || v_cod_ente ||
                         chr(10) || 'Empresa : ' || v_des_ente || chr(10) ||
                         'Monto   : ' ||
                         to_char(v_tot_debito, '999G999G999G999D99') || ' ' ||
                         v_cod_mon_debito || chr(10) || 'Cantidad: ' ||
                         to_char(v_can_ordenes) || chr(10) || 'Fecha de Pago: ' ||
                         to_char(v_fec_pago) || chr(10) || chr(10) ||
                         'Atentamente. ');
          END IF;
        end if;
        -- sipap
        IF v_ind_sipap = 'S' THEN
          pag_prv.pr_pro_pag_snp(v_cod_ente, user, v_err_pago, v_fec_pago, v_nro_archivo);
          IF v_err_pago IS NOT NULL THEN
            p_error := 'S';
            lp_act_pag_cab('PRO_ERR_VER_PAG', 'R42');
            lp_act_pag_det('PRO_ERR_VER_PAG', 'R42', 'E');
            prg_ins_log_errores('paw_prv.pr_pro_archivo','v_err_pago no nulo luego de pag_prv.pr_pro_pag_snp','p_nro_archivo',
                                   p_nro_archivo,'p_cod_ente',p_cod_ente,'p_nom_agrupado',p_nom_agrupado);
            goto fin;
          ELSE
              BEGIN
                UPDATE ge_pag_pro_hub_global a
                   SET a.estado = 'C',
                       a.des_respuesta = NULL
                 WHERE a.nro_archivo = p_nro_archivo
                   and a.cod_ente = p_cod_ente
                   and a.hub_nom_agrupado = p_nom_agrupado
                   and a.cod_respuesta is null
                   and a.estado = 'I';
               END;
            lp_act_pag_cab(null, 'R31');
            lp_act_pag_det(v_men_respuesta,'R31','C');
            IF v_fec_pago = v_fec_actual THEN
              it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                           v_dir_correo,
                           'Pago a Proveedores en Linea GH',
                           'Pago a Proveedores ingresado por Global Hub ' ||
                           chr(10) || chr(10) || 'Codigo  : ' || v_cod_ente ||
                           chr(10) || 'Empresa : ' || v_des_ente || chr(10) ||
                           'Monto   : ' ||
                           to_char(v_tot_debito, '999G999G999G999D99') || chr(10) ||
                           'Cantidad: ' || to_char(v_can_ordenes) || chr(10) ||
                           'Fecha de Pago: ' || to_char(v_fec_pago, 'dd/mm/yyyy')
                           || chr(10) || chr(10) || 'Atentamente. ');
            END IF;
            --
            -- llamar a funcion que verifica estado de transferenica.
            paw_prv.pr_ver_pag_global;
            --
          END IF;
        END IF;
      END IF;
   END IF;
   <<FIN>>
   null;
  END pr_pro_archivo;
  ----

  FUNCTION fu_obtenerEnte(p_nro_cuenta IN VARCHAR) RETURN NUMBER IS
    v_res TYP_RESGLOBALHUBPRV := TYP_RESGLOBALHUBPRV;
  BEGIN
    v_res := fu_obt_cod_ente_globalhub(p_nro_cuenta);
    RETURN v_res.codigoEnte;
  END;

function fu_obtenerCodPersona(p_CodEnte in number) return varchar2 is
  v_cod_persona varchar2(12);
begin
  select cod_persona
    into v_cod_persona
    from ge_entes
   where cod_ente = p_CodEnte;
   return v_cod_persona;
end;
  FUNCTION fu_obt_cod_ente_globalhub(p_nro_cuenta IN VARCHAR) RETURN TYP_RESGLOBALHUBPRV IS
    v_retorno TYP_RESGLOBALHUBPRV := TYP_RESGLOBALHUBPRV;
    PRO_CTA_DEB_INEXISTENTE CONSTANT VARCHAR2(15) := 'PRO_CTA_DEB_INE';
  BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                              v_retorno.error);
    BEGIN
      SELECT e.cod_ente
      INTO v_retorno.codigoEnte
      FROM ge_par_entes e
      WHERE e.val_parametro = p_nro_cuenta
      AND e.cod_ente IN (SELECT cod_ente
                        FROM ge_par_entes
                        WHERE parametro = 'HAB_PRV_HUB_GLOBAL'
                        AND val_parametro = 'S'
                        AND cod_ente = e.cod_ente);
    EXCEPTION
      WHEN OTHERS THEN
        paw_uti.pr_mensajeUsuario(PRO_CTA_DEB_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                  v_retorno.error);
    END;
    RETURN v_retorno;
  END;

  FUNCTION fu_obt_glo_hub_nro_archivo(p_cod_ente IN VARCHAR2) RETURN NUMBER IS
    v_nro_archivo NUMBER := 0;
  BEGIN
    BEGIN

      SELECT nvl(MAX(nro_archivo), 1)+1
      INTO v_nro_archivo
      FROM (SELECT p.nro_archivo
             FROM ge_pag_proveedores_tmp p
             WHERE p.cod_ente = p_cod_ente
             AND trunc(p.fec_insercion) = trunc(SYSDATE)
             UNION
             SELECT p.nro_archivo
             FROM ge_pag_proveedores p
             WHERE p.cod_ente = p_cod_ente
             AND trunc(p.fec_insercion) = trunc(SYSDATE)
             UNION
             SELECT nro_archivo
             FROM ge_pag_pro_hub_glo_cab
             WHERE ente = p_cod_ente
             );
    EXCEPTION
      WHEN OTHERS THEN
        v_nro_archivo := 1;
    END;
    RETURN v_nro_archivo;
  END;

  
  FUNCTION lf_obt_cod_moneda(p_cod_moneda IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF (p_cod_moneda = 'PYG') THEN
      RETURN 'GS';
    ELSE
      RETURN paw_uti.depurarAlfanumerico(p_cod_moneda, 3);
    END IF;
  END;

  FUNCTION lf_val_cta_moneda(p_nro_cuenta IN VARCHAR2, p_moneda IN VARCHAR2) RETURN TYP_RESGLOBALHUBPRV IS
    v_retorno TYP_RESGLOBALHUBPRV := TYP_RESGLOBALHUBPRV;
    v_moneda  VARCHAR2(3);
    MON_DEB_INVALID CONSTANT VARCHAR2(15) := 'MON_DEB_INVALID';
    PRO_CTA_DEB_INE CONSTANT VARCHAR2(15) := 'PRO_CTA_DEB_INE';
  BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                              v_retorno.error);
    BEGIN
      v_moneda := lf_obt_cod_moneda(p_moneda);
      IF (v_moneda <> fug_obt_mon_cta(p_nro_cuenta)) THEN
        paw_uti.pr_mensajeUsuario(MON_DEB_INVALID, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                  v_retorno.error);
        RETURN v_retorno;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        paw_uti.pr_mensajeUsuario(PRO_CTA_DEB_INE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                  v_retorno.error);
    END;
    v_retorno.codigomoneda := v_moneda;
    RETURN v_retorno;
  END;

  FUNCTION lf_val_pago_sipap(p_pago IN typ_globalhubPrvPago)
    RETURN typ_globalhubPrvPago IS
     v_ret          typ_globalhubPrvPago;
  BEGIN
    v_ret         := p_pago;
    v_ret.ERROR   := 'N';
    IF (p_pago.NRO_DOC_BENEFICIARIO IS NULL OR length(p_pago.NRO_DOC_BENEFICIARIO) < 4) THEN
      v_ret.ERROR         := 'S';
      v_ret.ESTADO        := 'E';
      v_ret.MSJ_RESPUESTA :='OAUTDOCINE';
      v_ret.ISO_COD_ERROR := 'R23';
      v_ret.ISO_DES_ERROR := 'Number of referred document invalid';
      RETURN v_ret;
    END IF;
    RETURN p_pago;
  END;

  FUNCTION lf_val_pago_bbva(p_pago IN typ_globalhubPrvPago, p_nro_cuenta IN VARCHAR2, p_moneda IN VARCHAR)
    RETURN typ_globalhubPrvPago IS
    v_ret          typ_globalhubPrvPago;
    v_aux          TYP_RESGLOBALHUBPRV;
  BEGIN
    v_ret         := p_pago;
    v_ret.ERROR   := 'N';

    --Verifica qye sea la misma moneda la cuenta y el pago
    v_aux := lf_val_cta_moneda(v_ret.NRO_CTA_CREDITO, p_moneda);
    IF (v_aux.error = 'S') THEN
      v_ret.ERROR         := 'S';
      v_ret.ESTADO        := 'E';
      v_ret.MSJ_RESPUESTA :='CNOCTACRED';
      v_ret.ISO_COD_ERROR := 'R42';
      v_ret.ISO_DES_ERROR := 'The currency of credit account is invalid or missing';
      RETURN v_ret;
    END IF;

    RETURN v_ret;
  END;

  FUNCTION lf_val_generales(p_pago IN typ_globalhubPrvPago, v_moneda IN VARCHAR2) RETURN typ_globalhubPrvPago IS
    v_ret typ_globalhubPrvPago;
  BEGIN
    v_ret       := p_pago;
    v_ret.ERROR := 'N';
    IF (p_pago.MONTO IS NULL OR p_pago.MONTO <= 0) THEN
      v_ret.ERROR         := 'S';
      v_ret.ESTADO        := 'E';
      v_ret.ISO_COD_ERROR := 'R23';
      v_ret.MSJ_RESPUESTA := 'LMTOTOTINV';
      v_ret.ISO_DES_ERROR := 'The amount is invalid or missing';
      RETURN v_ret;
    END IF;


    v_ret.COD_MONEDA := lf_obt_cod_moneda(p_pago.COD_MONEDA);
    IF (v_ret.COD_MONEDA <> v_moneda) THEN
      v_ret.ERROR         := 'S';
      v_ret.ESTADO        := 'E';
      v_ret.ISO_COD_ERROR := 'R23';
      v_ret.MSJ_RESPUESTA:='OMONPAGINV';
      v_ret.ISO_DES_ERROR := 'The currency of account is invalid or missing';
      RETURN v_ret;
    END IF;

    IF (v_ret.FOR_PAGO NOT IN ('I', 'C')) THEN
      v_ret.ISO_COD_ERROR := 'R23';
      v_ret.ESTADO        := 'E';
      v_ret.MSJ_RESPUESTA := 'GDATOINV';
      v_ret.ISO_DES_ERROR := 'Incorrect payment method';
      v_ret.ERROR         := 'S';
    END IF;

    RETURN v_ret;
  END;
  
  FUNCTION lf_ins_pago(p_linea           IN typ_globalhubPrvPago,
                       p_nro_cuenta      IN VARCHAR2,
                       p_moneda          IN VARCHAR,
                       p_ente            IN NUMBER,
                       p_nro_archivo     IN NUMBER,
                       p_fecha           IN DATE,
                       p_hub_agrupado    IN VARCHAR2,
                       p_hub_nom_archivo IN VARCHAR2)
    RETURN typ_globalhubPrvPago IS
    p_pago       typ_globalhubPrvPago := typ_globalhubPrvPago;
    v_nro_cuenta varchar2(16);
    v_retorno    TYP_RESGLOBALHUBPRV := TYP_RESGLOBALHUBPRV;
  BEGIN
    p_pago       := p_linea;
    v_nro_cuenta := paw_uti.depurarNumerico(p_nro_cuenta, 18);
    v_retorno    := fu_obt_cod_ente_globalhub(v_nro_cuenta);
    IF (v_retorno.error = 'S') THEN
      p_pago.ERROR         := v_retorno.error;
      p_pago.ISO_COD_ERROR := 'R23';
      p_pago.MSJ_RESPUESTA := 'CTAINVALID';
      p_pago.ISO_DES_ERROR := 'Closed account number';
    END IF;
    v_retorno := lf_val_cta_moneda(p_nro_cuenta, p_moneda);
    IF (v_retorno.error = 'S') THEN
      p_pago.ERROR         := 'S';
      p_pago.ISO_COD_ERROR := 'R42';
      p_pago.MSJ_RESPUESTA := 'CMONCTACRE';
      p_pago.ISO_DES_ERROR := 'The currency of debit account is invalid or missing';
    END IF;
    --si ya se detecto se trata de insertar igual para mantener el historico
    if (p_linea.ERROR is null or p_linea.ERROR = 'N') then
      p_pago := lf_val_generales(p_linea, p_moneda);
      IF (p_pago.ERROR = 'N') THEN
        IF (upper(p_linea.FOR_PAGO) = 'I') THEN
          p_pago := lf_val_pago_sipap(p_linea);
        ELSIF (upper(p_linea.FOR_PAGO) = 'C') THEN
          p_pago := lf_val_pago_bbva(p_linea, p_nro_cuenta, p_moneda);
        END IF;
      END IF;
    else
      p_pago.ESTADO := 'E';
    end if;
    INSERT INTO ge_pag_pro_hub_global
      (NRO_ORDEN,
       NRO_FACTURA,
       TIP_COMPROBANTE,
       FOR_PAGO,
       NRO_CHEQUE,
       NRO_CTA_CREDITO,
       FEC_INGRESO,
       FEC_PAGO,
       MONTO,
       NRO_RECIBO,
       BENEFICIARIO,
       CONCEPTO,
       ESTADO,
       COD_USU_OPERADOR,
       COD_ENTE,
       COD_PROCESO,
       COD_MONEDA,
       TIP_CARGA,
       COD_MON_RECIBIDO,
       REF_FACTURAS,
       REFERENCIA,
       MON_TOT_RECIBO,
       RET_FAC_PROVEEDOR,
       DES_FAC_PROVEEDOR,
       RET_FACTURAS,
       DES_SUCURSAL,
       TIPO,
       NRO_CTA_DEBITO,
       NRO_SECUENCIA,
       NRO_ARCHIVO,
       COD_TIP_DOC_BENEFICIARIO,
       NRO_DOC_BENEFICIARIO,
       NRO_CTA_BENEFICIARIO,
       ENT_BCA_BENEFICIARIO,
       IND_VALOR,
       DIR_BENEFICIARIO,
       TIP_FACTURA,
       NRO_CON_CAMBIO,
       BEN_DIR_CORREO,
       NRO_ORD_ARCHIVO,
       COD_ONE_BANK,
       TIP_ACREDITAMIENTO,
       TIP_TRANSFERENCIA,
       HUB_AGRUPADO,
       HUB_NOM_FICHERO,
       HUB_ISO_ERR_CODIGO,
       HUB_ISO_ERR_MENSAJE,
       HUB_NOM_AGRUPADO,
       MSJ_RESPUESTA)
    VALUES
      (p_pago.NRO_ORDEN,
       p_pago.NRO_FACTURA,
       p_pago.TIP_COMPROBANTE,
       p_pago.FOR_PAGO,
       NULL,
       p_pago.NRO_CTA_CREDITO,
       trunc(SYSDATE),
       p_fecha,
       p_pago.monto,
       p_pago.NRO_RECIBO,
       upper(p_pago.BENEFICIARIO),
       p_pago.CONCEPTO,
       p_pago.ESTADO,
       USER,
       p_ente,
       p_pago.COD_PROCESO,
       p_moneda,
       p_pago.TIP_CARGA,
       NULL,
       p_pago.REF_FACTURAS,
       p_pago.REFERENCIA,
       p_pago.MON_TOT_RECIBO,
       p_pago.RET_FAC_PROVEEDOR,
       p_pago.DES_FAC_PROVEEDOR,
       p_pago.RET_FACTURAS,
       p_pago.DES_SUCURSAL,
       p_pago.TIPO,
       p_nro_cuenta,
       p_pago.NRO_SECUENCIA,
       p_nro_archivo,
       p_pago.COD_TIP_DOC_BENEFICIARIO,
       p_pago.NRO_DOC_BENEFICIARIO,
       p_pago.NRO_CTA_BENEFICIARIO,
       p_pago.ENT_BCA_BENEFICIARIO,
       p_pago.IND_VALOR,
       p_pago.DIR_BENEFICIARIO,
       p_pago.TIP_FACTURA,
       p_pago.nro_con_cambio,
       p_pago.BEN_DIR_CORREO,
       p_nro_archivo,
       p_pago.COD_ONE_BANK,
       p_pago.TIP_ACREDITAMIENTO,
       p_pago.TIP_TRANSFERENCIA,
       p_hub_agrupado,
       p_hub_nom_archivo,
       p_pago.ISO_COD_ERROR,
       p_pago.ISO_DES_ERROR,
       p_pago.NOM_AGRUPADO,
       p_pago.MSJ_RESPUESTA);
    RETURN p_pago;
  END;

  PROCEDURE pr_act_estado(p_estado IN VARCHAR, p_tipo IN VARCHAR2) IS
    v_fecUltimoEnvio DATE;
    FUNCTION lf_ult_envio RETURN DATE IS
      v_fecUltimoEnvio DATE;
    BEGIN
      BEGIN
        --la fecha de envio de la ultima novidad con exito sino hoy menos 3 dias
        SELECT MAX(fec_envio)
        INTO v_fecUltimoEnvio
        FROM ge_not_hub_global h
        WHERE h.est_notificacion = EST_ENVIADO_NOTIFICACION;
      EXCEPTION
        WHEN OTHERS THEN
          v_fecUltimoEnvio := SYSDATE - 3;
      END;
      RETURN v_fecUltimoEnvio;
    END;
  BEGIN
    v_fecUltimoEnvio := nvl(lf_ult_envio, SYSDATE - 3);
    IF (p_estado = 'T') THEN
      UPDATE ge_not_hub_global
      SET est_notificacion = p_estado, fec_envio = SYSDATE
      WHERE fec_insercion > v_fecUltimoEnvio
      AND tipo = p_tipo
      AND est_notificacion <> EST_ENVIADO_NOTIFICACION;
    ELSE
      UPDATE ge_not_hub_global
      SET est_notificacion = p_estado
      WHERE fec_insercion > v_fecUltimoEnvio
      AND tipo = p_tipo
      AND est_notificacion <> EST_ENVIADO_NOTIFICACION;
    END IF;
  END;

  FUNCTION fu_ins_pag_pro_tmp(p_cod_ente IN NUMBER, p_nro_archivo IN NUMBER) RETURN NUMBER IS
    v_retorno         NUMBER := 0;
    v_reg_con_errores NUMBER := 0;
    CURSOR c_pagos IS
      SELECT *
      FROM ge_pag_pro_hub_global p
      WHERE p.cod_ente = p_cod_ente
      AND p.nro_archivo = p_nro_archivo
      AND TRUNC(p.fec_insercion) = TRUNC(SYSDATE);
  BEGIN
    FOR reg IN c_pagos LOOP
      BEGIN
        INSERT INTO GE_PAG_PROVEEDORES_TMP
          (NRO_ORDEN, NRO_FACTURA, TIP_COMPROBANTE, FOR_PAGO, NRO_CHEQUE, NRO_CTA_CREDITO, FEC_INGRESO, FEC_PAGO, MONTO,
           NRO_RECIBO, BENEFICIARIO, CONCEPTO, ESTADO, COD_USU_OPERADOR, COD_ENTE, COD_PROCESO, COD_MONEDA, TIP_CARGA,
           COD_MON_RECIBIDO, REF_FACTURAS, REFERENCIA, MON_TOT_RECIBO, RET_FAC_PROVEEDOR, DES_FAC_PROVEEDOR,
           RET_FACTURAS, DES_SUCURSAL, TIPO, NRO_CTA_DEBITO, NRO_SECUENCIA, NRO_ARCHIVO, COD_TIP_DOC_BENEFICIARIO,
           NRO_DOC_BENEFICIARIO, NRO_CTA_BENEFICIARIO, ENT_BCA_BENEFICIARIO, IND_VALOR, DIR_BENEFICIARIO, TIP_FACTURA,
           NRO_CON_CAMBIO, BEN_DIR_CORREO, NRO_ORD_ARCHIVO)
        VALUES
          (reg.NRO_ORDEN, reg.NRO_FACTURA, reg.TIP_COMPROBANTE, reg.FOR_PAGO, reg.NRO_CHEQUE, reg.NRO_CTA_CREDITO,
           reg.FEC_INGRESO, reg.FEC_PAGO, reg.MONTO, reg.NRO_RECIBO, reg.BENEFICIARIO, reg.CONCEPTO, reg.ESTADO,
           reg.COD_USU_OPERADOR, reg.COD_ENTE, reg.COD_PROCESO, reg.COD_MONEDA, reg.TIP_CARGA, reg.COD_MON_RECIBIDO,
           reg.REF_FACTURAS, reg.REFERENCIA, reg.MON_TOT_RECIBO, reg.RET_FAC_PROVEEDOR, reg.DES_FAC_PROVEEDOR,
           reg.RET_FACTURAS, reg.DES_SUCURSAL, reg.TIPO, reg.NRO_CTA_DEBITO, reg.NRO_SECUENCIA, reg.NRO_ARCHIVO,
           reg.COD_TIP_DOC_BENEFICIARIO, reg.NRO_DOC_BENEFICIARIO, reg.NRO_CTA_BENEFICIARIO, reg.ENT_BCA_BENEFICIARIO,
           reg.IND_VALOR, reg.DIR_BENEFICIARIO, reg.TIP_FACTURA, reg.NRO_CON_CAMBIO, reg.BEN_DIR_CORREO,
           reg.NRO_ORD_ARCHIVO);
        v_retorno := v_retorno + 1;
      EXCEPTION
        WHEN OTHERS THEN
          v_reg_con_errores := v_reg_con_errores + 1;        
      END;
    END LOOP;
  
    IF v_reg_con_errores > 0 THEN
      RETURN - 2; -- Con errores al insertar
    ELSE
      RETURN v_retorno;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RETURN - 1; -- No se inserta ningun dato
  END;

FUNCTION fu_insertarLineaPago(NRO_ORDEN IN NUMBER, NRO_FACTURA IN VARCHAR2, TIP_COMPROBANTE IN VARCHAR2,
                              FOR_PAGO IN VARCHAR2, NRO_CHEQUE IN NUMBER, NRO_CTA_CREDITO IN VARCHAR2,
                              FEC_INGRESO IN DATE, FEC_PAGO IN DATE, MONTO IN NUMBER, NRO_RECIBO IN NUMBER,
                              BENEFICIARIO IN VARCHAR2, CONCEPTO IN VARCHAR2, ESTADO IN VARCHAR2, COD_ENTE IN NUMBER,
                              COD_PROCESO IN NUMBER, COD_MONEDA IN VARCHAR2, TIP_CARGA IN VARCHAR2,
                              COD_MON_RECIBIDO IN VARCHAR2, REF_FACTURAS IN VARCHAR2, REFERENCIA IN VARCHAR2,
                              MON_TOT_RECIBO IN NUMBER, RET_FAC_PROVEEDOR IN NUMBER, DES_FAC_PROVEEDOR IN NUMBER,
                              RET_FACTURAS IN NUMBER, DES_SUCURSAL IN VARCHAR2, TIPO IN VARCHAR2,
                              NRO_CTA_DEBITO IN VARCHAR2, NRO_SECUENCIA IN NUMBER, NRO_ARCHIVO IN NUMBER,
                              COD_TIP_DOC_BENEFICIARIO IN NUMBER, NRO_DOC_BENEFICIARIO IN VARCHAR2,
                              NRO_CTA_BENEFICIARIO IN VARCHAR2, ENT_BCA_BENEFICIARIO IN NUMBER, IND_VALOR IN VARCHAR2,
                              DIR_BENEFICIARIO IN VARCHAR2, TIP_FACTURA IN NUMBER, NRO_CON_CAMBIO IN NUMBER,
                              BEN_DIR_CORREO IN VARCHAR2, NRO_ORD_ARCHIVO IN NUMBER, COD_ONE_BANK IN VARCHAR2,
                              TIP_ACREDITAMIENTO IN VARCHAR2, TIP_TRANSFERENCIA IN VARCHAR2, MSJ_RESPUESTA IN VARCHAR2,
                              DES_RESPUESTA IN VARCHAR2, ERROR IN VARCHAR2, ISO_COD_ERROR IN VARCHAR2,
                              ISO_DES_ERROR IN VARCHAR2, p_nro_cuenta IN VARCHAR2, p_moneda IN VARCHAR, p_ente IN NUMBER,
                              p_nro_archivo IN NUMBER, p_fecha IN DATE, p_hub_agrupado IN VARCHAR2,
                              p_hub_ref_local IN VARCHAR2, p_hub_nom_archivo IN VARCHAR2, p_hub_nom_agrupado IN VARCHAR2)
  RETURN NUMBER IS
  v_pago           typ_globalhubPrvPago := typ_globalhubPrvPago;
  v_res            typ_globalhubPrvPago := typ_globalhubPrvPago;
  v_moneda         VARCHAR2(3);
  v_monedaDebito   VARCHAR2(3);
  v_nro_con_cambio NUMBER(5) := NRO_CON_CAMBIO;
BEGIN
  v_moneda                        := lf_obt_cod_moneda(COD_MONEDA);
  v_pago.NRO_ORDEN                := NRO_ORDEN;
  v_pago.NRO_FACTURA              := NRO_FACTURA;
  v_pago.TIP_COMPROBANTE          := TIP_COMPROBANTE;
  v_pago.FOR_PAGO                 := FOR_PAGO;
  v_pago.NRO_CHEQUE               := NRO_CHEQUE;
  v_pago.NRO_CTA_CREDITO          := NRO_CTA_CREDITO;
  v_pago.FEC_INGRESO              := FEC_INGRESO;
  v_pago.FEC_PAGO                 := FEC_PAGO;
  v_pago.MONTO                    := MONTO;
  v_pago.NRO_RECIBO               := NRO_RECIBO;
  v_pago.BENEFICIARIO             := BENEFICIARIO;
  v_pago.CONCEPTO                 := CONCEPTO;
  v_pago.ESTADO                   := ESTADO;
  v_pago.COD_ENTE                 := COD_ENTE;
  v_pago.COD_PROCESO              := COD_PROCESO;
  v_pago.COD_MONEDA               := v_moneda;
  v_pago.TIP_CARGA                := TIP_CARGA;
  v_pago.COD_MON_RECIBIDO         := COD_MON_RECIBIDO;
  v_pago.REF_FACTURAS             := REF_FACTURAS;
  v_pago.REFERENCIA               := REFERENCIA;
  v_pago.MON_TOT_RECIBO           := MON_TOT_RECIBO;
  v_pago.RET_FAC_PROVEEDOR        := RET_FAC_PROVEEDOR;
  v_pago.DES_FAC_PROVEEDOR        := DES_FAC_PROVEEDOR;
  v_pago.RET_FACTURAS             := RET_FACTURAS;
  v_pago.DES_SUCURSAL             := DES_SUCURSAL;
  v_pago.TIPO                     := TIPO;
  v_pago.NRO_CTA_DEBITO           := NRO_CTA_DEBITO;
  v_pago.NRO_SECUENCIA            := NRO_SECUENCIA;
  v_pago.NRO_ARCHIVO              := NRO_ARCHIVO;
  v_pago.COD_TIP_DOC_BENEFICIARIO := COD_TIP_DOC_BENEFICIARIO;
  v_pago.NRO_DOC_BENEFICIARIO     := NRO_DOC_BENEFICIARIO;
  v_pago.NRO_CTA_BENEFICIARIO     := NRO_CTA_BENEFICIARIO;
  v_pago.ENT_BCA_BENEFICIARIO     := ENT_BCA_BENEFICIARIO;
  v_pago.IND_VALOR                := IND_VALOR;
  v_pago.DIR_BENEFICIARIO         := DIR_BENEFICIARIO;
  v_pago.TIP_FACTURA              := TIP_FACTURA;
  IF (v_nro_con_cambio = 0) THEN
    v_nro_con_cambio := NULL;
  END IF;
  v_pago.NRO_CON_CAMBIO     := v_nro_con_cambio;
  v_pago.BEN_DIR_CORREO     := BEN_DIR_CORREO;
  v_pago.NRO_ORD_ARCHIVO    := NRO_ORD_ARCHIVO;
  v_pago.COD_ONE_BANK       := COD_ONE_BANK;
  v_pago.TIP_ACREDITAMIENTO := TIP_ACREDITAMIENTO;
  v_pago.TIP_TRANSFERENCIA  := TIP_TRANSFERENCIA;
  v_pago.MSJ_RESPUESTA      := MSJ_RESPUESTA;
  v_pago.DES_RESPUESTA      := DES_RESPUESTA;
  v_pago.ERROR              := ERROR;
  v_pago.ISO_COD_ERROR      := ISO_COD_ERROR;
  v_pago.ISO_DES_ERROR      := ISO_DES_ERROR;
  v_pago.NOM_AGRUPADO       := p_hub_nom_agrupado;
  v_monedaDebito            := lf_obt_cod_moneda(p_moneda);
  v_res                     := lf_ins_pago(v_pago, p_nro_cuenta, v_monedaDebito, p_ente, p_nro_archivo, p_fecha,
                                           p_hub_agrupado, p_hub_nom_archivo);

  IF (v_res.ERROR = 'S') THEN
    PAW_BEL.pr_insertarBitacora(v_pago.COD_ENTE, V_COD_CANAL, v_pago.NOM_AGRUPADO, 'ERR', v_pago.NRO_ARCHIVO,
                                v_pago.COD_ENTE, 'v_error:' || v_res.DES_RESPUESTA);
    RETURN 1;
  END IF;
  RETURN 0;

END; --fin fu_insertarLineaPago


FUNCTION fu_insertarCabecera(p_nro_archivo IN NUMBER, p_ente IN NUMBER, p_can_pagos IN NUMBER, p_mon_total IN NUMBER,
                             p_nro_cuenta IN VARCHAR2, p_fec_pago IN DATE, p_archivo IN CLOB, p_nom_agrupado IN VARCHAR2)
  RETURN NUMBER IS
  v_nro_archivo NUMBER(4);
BEGIN
  IF (v_nro_archivo = 0) THEN
    v_nro_archivo := fu_obt_glo_hub_nro_archivo(p_ente);
  ELSE
    v_nro_archivo := p_nro_archivo;
  END IF;
  INSERT INTO ge_pag_pro_hub_glo_cab
    (nro_archivo, ente, can_pagos, mon_total, nro_cuenta, fec_pago, archivo, nom_agrupado)
  VALUES
    (v_nro_archivo, p_ente, p_can_pagos, p_mon_total, p_nro_cuenta, p_fec_pago, p_archivo, p_nom_agrupado);
  RETURN v_nro_archivo;
END; --fin fu_insertarCabecera

FUNCTION fu_realizarPagosArchivo(p_nom_agrupado IN VARCHAR2) RETURN NUMBER IS
  CURSOR lotes IS
    SELECT t.nro_archivo, t.ente, t.can_pagos, t.mon_total, t.nro_cuenta, t.fec_pago,t.nom_agrupado
    FROM ge_pag_pro_hub_glo_cab t
    WHERE t.nom_agrupado = p_nom_agrupado;
  v_error VARCHAR2(200);
  v_ret   NUMBER := 0;
BEGIN
  FOR lote IN lotes LOOP
      PAW_BEL.pr_insertarBitacora(lote.ente,V_COD_CANAL,lote.nom_agrupado,'ENT',lote.nro_archivo,lote.ente,'v_error:'||v_error);
      pr_pro_archivo(lote.nro_archivo, lote.ente,lote.nom_agrupado, v_error);
      if(not v_error is null) then
             v_ret := v_ret - 1;
         PAW_BEL.pr_insertarBitacora(lote.ente,V_COD_CANAL,lote.nom_agrupado,'ERR',lote.nro_archivo,lote.ente,'v_error:'||v_error);
      end if;
    v_ret := v_ret + 1;
  END LOOP;
  RETURN v_ret;
END; --fin fu_realizarPagosArchivo
BEGIN
  pre_cam_for_numerico('.,');
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 9;
END paw_prv;
/

