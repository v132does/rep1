CREATE OR REPLACE PACKAGE BODY IT.PAA_CDI IS

  v_cta_tamano         NUMBER(3) := 18;
  v_can_aut_requeridas NUMBER(5) := 0; -- cantidad de firmas requeridas
  v_fec_actual         DATE := pag_cal.fu_obt_fec_actual(3);

  PROCEDURE lp_ver_horario(p_cod_ofi_origen  ba_oficinas.cod_oficina%type,
                           p_modulo          in ba_modulos.cod_modulo%type,
                           p_horario         out varchar2,
                           p_es_mov_nocturno out varchar2,
                           p_es_cta_nocturno out varchar2,
                           p_fec_actual      out date,
                           p_fec_valor       out date,
                           p_cod_error       out number,
                           p_respuesta       out varchar2) is
  
    v_est_modulo ba_modulos.estado%type;
  begin
    p_cod_error       := 0;
    p_horario         := 'D'; -- dia normal
    p_es_mov_nocturno := 'N'; -- para grabar en las tablas nocturnas
    p_es_cta_nocturno := 'N';
    p_fec_actual      := pag_cal.fu_obt_fec_actual(p_modulo);
    v_est_modulo      := pae_cnf.fu_obt_est_modulo(p_modulo);
  
    if fug_obt_pardinamico('ACT_NOCTURNO') = 'N' then
      p_cod_error := '1070';
      p_respuesta := 'Modulo en proceso de cierre';
    elsif v_est_modulo in (1, 6) then
      p_cod_error := '1070';
      p_respuesta := 'Modulo en proceso de cierre';
    elsif v_est_modulo = 2 then
      p_horario         := 'D'; -- dia normal
      p_es_mov_nocturno := 'N'; -- para grabar en las tablas nocturnas
      p_es_cta_nocturno := 'N';
      p_fec_actual      := pag_cal.fu_obt_fec_actual(p_modulo);
    else
      p_horario := 'N'; -- noche
      if v_est_modulo <> 1 then
        p_fec_actual := pag_cal.fu_obt_fec_habil(p_fec_actual + 1,
                                                 1,
                                                 p_cod_ofi_origen);
      end if;
      p_es_mov_nocturno := 'S'; -- para grabar en las tablas nocturnas
      p_es_cta_nocturno := 'S'; -- solo para que llavee la cuenta nocturna
    end if;
    pag_cta.g_horario := p_horario;
    p_fec_valor       := trunc(sysdate);
    v_mod_estado      := v_est_modulo;
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 99;
      p_respuesta := 'Ocurrio un error en la verificacion de horario';
      prg_ins_log_programas('paa_cdi.lp_ver_horario',
                            substr(DBMS_UTILITY.format_error_backtrace || ' ' ||
                                   DBMS_UTILITY.format_error_stack,
                                   1,
                                   4000),
                            null,
                            null);
    
  END lp_ver_horario;

  FUNCTION lf_ver_alfanumerico(p_string  IN VARCHAR2,
                               maxLength IN NUMBER,
                               p_espacio IN CHAR DEFAULT 'N') RETURN VARCHAR2 IS
  BEGIN
    IF p_espacio = 'N' THEN
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:]])', ''),
                    1,
                    maxLength);
    ELSE
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string),
                                   '([^[:alnum:][:space:]])',
                                   ''),
                    1,
                    maxLength);
    END IF;
  END;
  FUNCTION lf_ver_texto(p_string    IN VARCHAR2,
                        maxLength   IN NUMBER,
                        p_documento IN VARCHAR2 DEFAULT 'N') RETURN VARCHAR2 IS
  BEGIN
    IF p_documento = 'N' THEN
      --texto
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string),
                                   '([^0-9A-Za-z ,./_-])',
                                   ''),
                    1,
                    maxLength);
    ELSE
      --documento
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^0-9A-Za-z-])', ''),
                    1,
                    maxLength);
    END IF;
  END;

  --valida cta debito
  PROCEDURE lp_val_cta_debito(p_nro_cta_debito     IN VARCHAR2,
                              p_cod_tra_padre      IN NUMBER,
                              p_mto_operacion      IN NUMBER,
                              p_cod_mon_debito     OUT VARCHAR2,
                              p_cod_mod_debito     OUT NUMBER,
                              p_cod_mad_debito     OUT NUMBER,
                              p_cod_ofi_debito     OUT NUMBER,
                              p_cta_for_debito     OUT VARCHAR2,
                              p_nom_cta_debito     OUT VARCHAR2,
                              p_cod_modulo         IN ge_modalidades.cod_modulo%TYPE DEFAULT NULL,
                              p_cod_modalidad      IN ge_modalidades.cod_modalidad%TYPE DEFAULT NULL,
                              p_nro_cta_credito    IN VARCHAR2 default null,
                              p_cod_tra_pad_debito IN NUMBER,
                              p_cod_error          OUT NUMBER,
                              p_respuesta          OUT VARCHAR2) IS
  
    v_est_cta_debito VARCHAR2(1);
    v_nvo_estado     VARCHAR2(1) := NULL; -- cambio de estado de cuenta
    v_procesa        VARCHAR2(1) := 'N';
    v_sal_disponible NUMBER(18, 2);
    v_can_conjunta   NUMBER(7);
    v_cod_ofi_origen ba_oficinas.cod_oficina%type;
    -- verifico cuenta de debito
  BEGIN
  
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
      p_cod_error := 16;
      p_respuesta := 'Codigo de modalidad de cuenta invalida';
    ELSIF v_est_cta_debito NOT IN ('P', 'I', 'N', 'S') THEN
      p_cod_error := 17;
      p_respuesta := 'Estado de cuenta invalida';
    ELSIF pag_cta.fu_ver_tra_prohibida(p_nro_cta_debito,
                                       p_cod_tra_padre,
                                       nvl(p_cod_modulo, 3),
                                       nvl(p_cod_modalidad, 31)) = 'S' THEN
      p_cod_error := 18;
      p_respuesta := 'Estado de cuenta invalida';
    ELSIF paw_bas.fu_es_conjunta(p_nro_cta_debito, v_can_aut_requeridas) = 'S' THEN
      p_cod_error := 19;
      p_respuesta := 'La cuenta es conjunta';
    ELSIF p_cod_mad_debito = 41 and p_nro_cta_credito IS NOT NULL THEN
      IF FUC_OBT_SAL_SIN_SOBREGIRO(p_nro_cta_debito) <= 0 and
         FUC_OBT_SAL_SIN_SOBREGIRO(p_nro_cta_credito) <= 0 THEN
        p_cod_error := 20;
        p_respuesta := 'Saldo insuficiente';
      ELSIF FUC_OBT_SAL_SIN_SOBREGIRO(p_nro_cta_debito) > 0 and
            (FUC_OBT_SAL_SIN_SOBREGIRO(p_nro_cta_debito) - p_mto_operacion) < 0 THEN
        p_cod_error := 21;
        p_respuesta := 'Saldo insuficiente';
      END IF;
    ELSE
      pag_cta.pr_ver_operacion(p_nro_cta_debito,
                               p_cod_tra_padre,
                               nvl(p_cod_modulo, 3),
                               nvl(p_cod_modalidad, 31),
                               'D',
                               p_cod_mon_debito,
                               p_mto_operacion,
                               v_cod_ofi_origen,
                               p_cod_mod_debito,
                               p_cod_mad_debito,
                               v_nvo_estado,
                               v_sal_disponible,
                               v_procesa,
                               p_cod_tra_pad_debito);
      IF v_procesa = 'N' THEN
        -- no se puede debitar
        IF instr(upper(pag_cta.G_MSJ_ERROR), 'INSUFIC') > 0 THEN
          -- saldo insuficiente
          p_cod_error := 22;
          p_respuesta := 'Saldo insuficiente';
        ELSE
          p_cod_error := 23;
          p_respuesta := 'Codigo de cuenta invalida';
        END IF;
      END IF;
    END IF;
    -- agregado para permitir a cuentas indistintas de personas fisicas grabar sin autorizacion
    IF nvl(p_cod_error, 0) = 0 THEN
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
  
  EXCEPTION
    WHEN no_data_found THEN
      p_cod_error := 24;
      p_respuesta := 'Cuenta de debito no encontrada';
    WHEN too_many_rows THEN
      p_cod_error := 25;
      p_respuesta := 'Cuenta de debito duplicada';
    WHEN OTHERS THEN
      p_cod_error := 26;
      p_respuesta := 'Cuenta de debito invalida';
  END;
  -- Fin Validar Cuenta Debito

  --Funcion que controla la Cuenta Origen corresponda a la persona 
  FUNCTION lf_val_cta_origen(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS
    v_existe VARCHAR(1) := 'N';
  BEGIN
    SELECT 'S'
      INTO v_existe
      FROM ge_cta_clientes
     WHERE nro_cuenta = p_nro_cuenta
       AND rownum = 1;
    RETURN v_existe;
  EXCEPTION
    WHEN OTHERS THEN
      v_existe := 'N';
      RETURN v_existe;
    
  END;
  -- Final de Controla la Cuenta Origen

  -- transaccion entre cuentas internas
  PROCEDURE pr_gen_tra_interna(p_nro_cta_debito      IN VARCHAR2, --numero cuenta debito
                               p_nro_cta_credito     IN VARCHAR2, --numero cuenta credito
                               p_cod_tra_pad_debito  IN NUMBER, --codigo transacción padre debito 
                               p_cod_tra_pad_credito IN NUMBER, --codigo transacción padre credito 
                               p_mto_operacion       IN NUMBER, --monto de la operacion
                               p_cod_tra_debito      IN NUMBER, --codigo transaccion debito
                               p_cod_tra_credito     IN NUMBER, --codigo transaccion credito
                               p_nro_documento       IN NUMBER, --numero de documento u operacion que recibe
                               p_deb_concepto        IN VARCHAR2, --concepto debito
                               p_cre_concepto        IN VARCHAR2, --concepto credito
                               p_cod_error           OUT NUMBER,
                               p_respuesta           OUT VARCHAR2,
                               p_nro_sec_debito      OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE,
                               p_nro_sec_credito     OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE) IS
  
    -- definicion de variables
    v_nro_cta_debito      VARCHAR2(16);
    v_monto               NUMBER(18, 2); -- monto a acreditar
    v_nro_cta_credito     VARCHAR2(17); -- cuenta de credito
    v_cta_for_debito      VARCHAR2(17); -- cuenta formateada
    v_cod_mon_debito      VARCHAR2(3); -- moneda de la cuenta
    v_cod_mod_debito      NUMBER(4); -- modulo de la cuenta
    v_cod_mad_debito      NUMBER(4); -- modalidad de la cuenta
    v_cod_ofi_debito      NUMBER(4); -- oficina de la cuenta
    v_nom_cta_debito      VARCHAR2(100);
    v_cod_mon_credito     VARCHAR2(3); -- moneda de la cuenta
    v_cta_for_credito     VARCHAR2(17); -- cuenta formateada
    v_est_cta_credito     VARCHAR2(1); -- estado de la cuenta
    v_cod_mod_credito     NUMBER(4); -- modulo de la cuenta
    v_cod_mad_credito     NUMBER(4); -- modalidad de la cuenta
    v_cod_ofi_credito     NUMBER(4); -- oficina de la cuenta
    v_nvo_est_credito     VARCHAR2(1) := NULL; -- cambio de estado de cuenta
    v_sal_dis_credito     NUMBER(18, 2);
    v_mto_credito         NUMBER(18, 2);
    v_nom_cta_credito     VARCHAR2(100);
    v_mto_equ_local       NUMBER(18) := NULL;
    v_cod_tra_pad_debito  NUMBER(4) := p_cod_tra_pad_debito; --cod. transaccion padre 
    v_cod_tra_pad_credito NUMBER(4) := p_cod_tra_pad_credito; --cod. transaccion padre 
    v_cod_tra_deb         NUMBER(4) := p_cod_tra_debito; --cod. transaccion 
    v_cod_tra_cre         NUMBER(4) := p_cod_tra_credito; --cod. transaccion 
    v_procesa             VARCHAR2(1) := 'N'; -- indica si se puede o no procesar
    v_deb_concepto        VARCHAR2(100);
    v_cre_concepto        VARCHAR2(100);
    v_fec_valor           DATE := pag_cal.fu_obt_fec_actual(3); -- fecha de hoy
    v_hor_actual          VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
    v_nro_operacion       NUMBER(10) := p_nro_documento; -- nro unico de operacion 
    v_horario             VARCHAR2(1);
    v_es_mov_nocturno     VARCHAR2(1);
    v_es_cta_nocturno     VARCHAR2(1);
    v_fec_actual          DATE;
    v_cod_ofi_origen      ba_oficinas.cod_oficina%type := fug_obt_ofi_usuario(user);
    v_respuesta           varchar(4000);
    v_det_error           ge_log_errores.det_error%type;
    v_nro_sec_debito      NUMBER(3);
    v_nro_sec_credito     NUMBER(3);
    v_usu_movimiento      ba_usuarios.cod_usuario%type;
  
  BEGIN
    -- definición de variables
    p_cod_error := 0;
    -- inicializo la secuencia
    v_nro_sec_debito  := 0;
    v_nro_sec_credito := 0;
    v_nro_cta_debito  := lf_ver_alfanumerico(p_nro_cta_debito, v_cta_tamano);
    v_nro_cta_credito := lf_ver_alfanumerico(p_nro_cta_credito,
                                             v_cta_tamano);
    v_monto           := nvl(p_mto_operacion, 0); -- monto a acreditar
    v_mto_credito     := v_monto;
    
    IF p_deb_concepto IS NOT NULL THEN
      v_deb_concepto := lf_ver_texto(p_deb_concepto, 35);
    END IF;
  
    IF p_cre_concepto IS NOT NULL THEN
      v_cre_concepto := lf_ver_texto(p_cre_concepto, 35);
    END IF;
  
    --  busco los datos de la cuentas
    IF nvl(p_cod_error, 0) = 0 THEN
      -- verifico cuenta de debito
      IF v_nro_cta_debito = v_nro_cta_credito THEN
        p_cod_error := 1;
        p_respuesta := 'Las cuentas de debito y credito son iguales';
      ELSE
      
        lp_val_cta_debito(v_nro_cta_debito,
                          v_cod_tra_pad_debito,
                          v_monto,
                          v_cod_mon_debito,
                          v_cod_mod_debito,
                          v_cod_mad_debito,
                          v_cod_ofi_debito,
                          v_cta_for_debito,
                          v_nom_cta_debito,
                          null,
                          null,
                          v_nro_cta_credito,
                          v_cod_tra_pad_debito,
                          p_cod_error,
                          p_respuesta);
      
        IF nvl(p_cod_error, 0) != 0 THEN
          p_cod_error := p_cod_error;
          p_respuesta := p_respuesta || ' -lf_val_cta_debito';
        END IF;
      
        IF nvl(p_cod_error, 0) = 0 THEN
          IF lf_val_cta_origen(v_nro_cta_debito) = 'N' THEN
            p_cod_error := 3;
            p_respuesta := 'La cuenta debito ' || v_nro_cta_debito ||
                           'no corresponde a un cliente';
          END IF;
        END IF;
      
        IF nvl(p_cod_error, 0) = 0 THEN
          IF lf_val_cta_origen(v_nro_cta_credito) = 'N' THEN
            p_cod_error := 4;
            p_respuesta := 'La cuenta credito ' || v_nro_cta_credito ||
                           'no corresponde a un cliente';
          END IF;
        END IF;
      END IF;
    
      IF nvl(p_cod_error, 0) = 0 THEN
        -- cuenta credito 
        BEGIN
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
            INTO v_cod_mon_credito,
                 v_est_cta_credito,
                 v_cod_mad_credito,
                 v_cod_mod_credito,
                 v_cod_ofi_credito,
                 v_cta_for_credito,
                 v_nom_cta_credito
            FROM ge_cuentas a
           WHERE a.nro_cuenta = v_nro_cta_credito;
          -- credito
          IF nvl(p_cod_error, 0) = 0 THEN
            IF v_mto_credito <= 0 THEN
              p_cod_error := 5;
              p_respuesta := 'El monto credito es invalido';
            ELSIF v_cod_mad_credito NOT IN (31, 41, 334) THEN
              p_cod_error := 6;
              p_respuesta := 'La modalidad de la cuenta de credito es invalida';
            ELSIF v_est_cta_credito NOT IN ('A', 'I', 'N', 'S') THEN
              --ABIERTA/INACTIVA/NORMAL/BLOQUEO SALDO
              p_cod_error := 7;
              p_respuesta := 'El estado de la cuenta de credito es invalida';
            ELSIF pag_cta.fu_ver_tra_prohibida(v_nro_cta_credito,
                                               v_cod_tra_pad_credito,
                                               v_cod_mod_credito,
                                               v_cod_mad_credito) = 'S' THEN
              p_cod_error := 8;
              p_respuesta := 'Transaccion prohibida para la cuenta de credito';
            ELSE
              pag_cta.pr_ver_operacion(v_nro_cta_credito,
                                       v_cod_tra_pad_credito,
                                       v_cod_mod_credito,
                                       v_cod_mad_credito,
                                       'C',
                                       v_cod_mon_credito,
                                       v_mto_credito,
                                       v_cod_ofi_credito,
                                       v_cod_mod_credito,
                                       v_cod_mad_credito,
                                       v_nvo_est_credito,
                                       v_sal_dis_credito,
                                       v_procesa,
                                       v_cod_tra_cre);
              IF v_procesa = 'N' THEN
                p_cod_error := 9;
                p_respuesta := 'No se puede operar con la cuenta de credito';
              END IF;
            END IF;
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
            p_cod_error := 10;
            p_respuesta := 'Cuenta de credito no encontrada';
          WHEN too_many_rows THEN
            p_cod_error := 11;
            p_respuesta := 'Cuenta de credito duplicada';
          WHEN OTHERS THEN
            p_cod_error := 12;
            p_respuesta := 'La cuenta de credito es invalida';
        END;
      
        IF nvl(p_cod_error, 0) = 0 THEN
          -- seteo las variables
          v_nro_sec_debito  := 0;
          v_nro_sec_credito := 0;
          pr_obt_usu_hor_tra_interna(user,v_usu_movimiento,v_hor_actual);
          pag_cta.PR_SET_VARIABLES(v_usu_movimiento,
                                   v_fec_valor,
                                   v_cod_tra_pad_debito,
                                   'N',
                                   'N',
                                   v_nro_sec_debito,
                                   NULL,
                                   v_cod_ofi_origen,
                                   v_cod_mod_debito,
                                   v_cod_mad_debito);
          -- esta la cuenta en condiciones, verifico el horario
          lp_ver_horario(v_cod_ofi_debito,
                         v_cod_mod_debito,
                         v_horario,
                         v_es_mov_nocturno,
                         v_es_cta_nocturno,
                         v_fec_actual,
                         v_fec_valor,
                         p_cod_error,
                         p_respuesta);
        
          if nvl(p_cod_error, 0) != '0' then
            p_cod_error := 13;
            p_respuesta := v_respuesta || '-lp_ver_horario';
          end if;
          -- actualizo la cuenta de debito
          -- Se busca una hora disponible
          /*v_hor_actual := fug_obt_hor_disponible(v_fec_actual,
                                                 v_hor_actual,
                                                 user,
                                                 v_es_mov_nocturno);*/
          pag_cta.PR_ACT_OPERACION(v_nro_cta_debito,
                                   v_hor_actual,
                                   'D',
                                   v_cod_mon_debito,
                                   v_monto,
                                   v_cod_tra_pad_debito,
                                   v_cod_tra_deb,
                                   v_nro_operacion,
                                   null,
                                   v_cod_ofi_debito,
                                   v_cod_mod_debito,
                                   v_cod_mad_debito,
                                   NULL,
                                   NULL,
                                   v_deb_concepto,
                                   'N',
                                   v_nro_sec_debito,
                                   v_fec_valor,
                                   NULL,
                                   NULL,
                                   v_mto_equ_local);
          p_nro_sec_debito := v_nro_sec_debito;
          IF pag_cta.g_cod_error != 0 THEN
            p_cod_error := pag_cta.g_cod_error;
            p_respuesta := pag_cta.G_MSJ_ERROR;
            return;
          END IF;
          IF nvl(pag_cta.g_cod_error, 0) = 0 THEN
            v_nro_sec_credito := v_nro_sec_debito;
            pag_cta.PR_SET_VARIABLES(v_usu_movimiento,
                                   v_fec_valor,
                                   v_cod_tra_pad_credito,
                                   'N',
                                   'N',
                                   v_nro_sec_credito,
                                   NULL,
                                   v_cod_ofi_origen,
                                   v_cod_mod_credito,
                                   v_cod_mad_credito);
            pag_cta.PR_ACT_OPERACION(v_nro_cta_credito,
                                     v_hor_actual,
                                     'C',
                                     v_cod_mon_credito,
                                     v_mto_credito,
                                     v_cod_tra_pad_credito,
                                     v_cod_tra_cre,
                                     v_nro_operacion,
                                     null,
                                     v_cod_ofi_credito,
                                     v_cod_mod_credito,
                                     v_cod_mad_credito,
                                     NULL,
                                     NULL,
                                     v_cre_concepto,
                                     'N',
                                     v_nro_sec_credito,
                                     v_fec_valor,
                                     NULL,
                                     NULL,
                                     v_mto_equ_local);
            p_nro_sec_credito := v_nro_sec_credito;
            -- hubo error en el credito
            IF pag_cta.g_cod_error != 0 THEN
              p_cod_error := pag_cta.g_cod_error;
              p_respuesta := pag_cta.G_MSJ_ERROR;
              return;
            END IF;
          ELSE
            -- hubo error en el debito
            p_cod_error := 15;
            p_respuesta := 'Ocurrio un error en el proceso de dedito';
          END IF;
        END IF;
      END IF;
    END IF;
    if nvl(p_cod_error, 0) != '0' then
      v_det_error := p_cod_error || '-' || p_respuesta ||
                     ', p_nro_cta_deb: ' || p_nro_cta_debito ||
                     ', p_nro_cta_cre: ' || p_nro_cta_credito ||
                     ', p_nro_operacion: ' || p_nro_documento;
      prg_ins_log_programas('paa_cdi.pr_gen_tra_interna',
                            v_det_error,
                            p_nro_documento,
                            nvl(p_nro_cta_debito, p_nro_cta_credito));
    end if;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 999;
      p_respuesta := sqlerrm;
      v_det_error := p_cod_error || '-' || p_respuesta ||
                     ', p_nro_cta_deb: ' || p_nro_cta_debito ||
                     ', p_nro_cta_cre: ' || p_nro_cta_credito ||
                     ', p_nro_operacion: ' || p_nro_documento;
      prg_ins_log_programas('paa_cdi.pr_gen_tra_interna',
                            v_det_error,
                            p_nro_documento,
                            nvl(p_nro_cta_debito, p_nro_cta_credito));
  END;
  -- fin validacion o confirmacion de transaccion entre cuentas

  /*procedimiento que retorna usuario para evitar error de pk en ge_movimientos*/
  procedure pr_obt_usu_hor_tra_interna(p_usuario in varchar2,
                                       p_usu_mov out varchar2,
                                       p_hor_mov out varchar2) is
    v_tip_movimiento   ba_cod_referencias.val_maximo%type;
    v_val_minimo       ge_par_dinamicos.val_parametro%type;
    v_val_maximo       ge_par_dinamicos.val_parametro%type;
    v_par_minimo       ge_parametros.parametro%type;
    v_par_maximo       ge_parametros.parametro%type;
    v_can_registro     number(5) := 0;
    v_secuencia        varchar2(100);
  
  begin
  
    v_tip_movimiento := 'MVMTS';
    --se obtiene el nombre de los parametros de la cant. minima y maxima
    v_par_minimo := v_tip_movimiento || '_CAN_MIN_USU';
    v_par_maximo := v_tip_movimiento || '_CAN_MAX_USU';
    --se obtiene el valor minimo y maximo para la generacion de usuarios y secuencias
    v_val_minimo := nvl(fug_obt_pardinamico(v_par_minimo), 1);
    v_val_maximo := nvl(fug_obt_pardinamico(v_par_maximo), 9);
  
    ---se obtiene el usuario
    p_usu_mov := v_tip_movimiento ||
                 round(dbms_random.value(v_val_minimo, v_val_maximo));
    --se valida si el usuario esta registrado en ba_usuarios
    select count(*)
      into v_can_registro
      from ba_usuarios us
     where us.cod_usuario = p_usu_mov;
  
    if v_can_registro = 0 then
      p_usu_mov := p_usuario;
      p_hor_mov := to_char(sysdate, 'HH24:MI:SS');
      return;
    end if;
    --se obtiene la secuencia para generar la hora del movimiento
    v_secuencia := 'S_HOR_MOV_'|| p_usu_mov;
    --se obtiene la hora en base a la secuencia
    p_hor_mov := fuw_obt_mov_hora(v_secuencia);
  exception
    when others then
      p_usu_mov := p_usuario;
      p_hor_mov := to_char(sysdate, 'HH24:MI:SS');
  end pr_obt_usu_hor_tra_interna;

--inicializacion del paquete
BEGIN
  pre_cam_for_numerico('.,');
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 3;
END PAA_CDI;
/
