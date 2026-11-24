CREATE OR REPLACE PACKAGE BODY IT.PAG_BAT IS

FUNCTION fu_act_sal_bat_estado(p_cod_proveedor IN bw_pag_servicios.cod_proveedor%TYPE)
  RETURN VARCHAR2 IS
  v_existe    VARCHAR2(1);
BEGIN
  BEGIN
    SELECT 'S'
    INTO v_existe
    FROM dual
    WHERE p_cod_proveedor IN
          (SELECT regexp_substr(fug_obt_pardinamico('GE_ACT_SAL_BAT_PROV'), '(.*?)(,|$)', 1, LEVEL,
                                 NULL, 1) AS item
           FROM (SELECT fug_obt_pardinamico('GE_ACT_SAL_BAT_PROV') FROM dual)
           CONNECT BY LEVEL <= regexp_count(fug_obt_pardinamico('GE_ACT_SAL_BAT_PROV'), ',') + 1);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END;
  RETURN 'S';
END;

  PROCEDURE fu_ins_log_mov_cre_batch(mensaje IN GE_BAT_MOV_LOG.log%TYPE) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    BEGIN
      INSERT INTO GE_BAT_MOV_LOG (LOG) VALUES (substr(mensaje, 0, 3000));
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END;

  PROCEDURE pr_act_operacion(p_nro_cuenta IN ge_movimientos.nro_cuenta%TYPE,
                             p_fecha IN ge_movimientos.fecha%TYPE,
                             p_hora IN ge_movimientos.hora%TYPE, p_tip_movimiento IN VARCHAR2,
                             p_cod_moneda IN ge_movimientos.cod_moneda%TYPE,
                             p_monto IN ge_movimientos.monto%TYPE,
                             p_cod_tra_padre IN ge_movimientos.cod_tra_padre%TYPE,
                             p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
                             p_nro_documento IN ge_movimientos.nro_documento%TYPE,
                             p_cotizacion IN ge_movimientos.cotizacion%TYPE,
                             p_cod_ofi_origen IN ge_movimientos.cod_ofi_origen%TYPE,
                             p_cod_mod_padre IN ge_movimientos.cod_mod_padre%TYPE,
                             p_cod_mad_padre IN ge_movimientos.cod_mad_padre%TYPE,
                             p_cod_tasa IN ge_movimientos.cod_tasa%TYPE,
                             p_val_tasa IN ge_movimientos.val_tasa%TYPE,
                             p_concepto IN ge_movimientos.concepto%TYPE,
                             p_emi_aviso IN ge_movimientos.emi_aviso%TYPE,
                             p_nro_secuencia IN OUT ge_movimientos.nro_secuencia%TYPE,
                             p_fec_valor IN ge_movimientos.fec_valor%TYPE,
                             p_cod_banco IN NUMBER DEFAULT NULL, p_cod_causa IN NUMBER DEFAULT NULL,
                             p_mto_equ_local IN ge_movimientos.mto_equ_local%TYPE DEFAULT NULL,
                             p_estado IN VARCHAR2 DEFAULT 'N') IS
    g_movs ge_movimientos%ROWTYPE;
    v_nocturno VARCHAR2(1); -- DDSI-212 -- 2017/12
    /* Inserta datos en la Tabla GE_MOVIMIENTOS */
    PROCEDURE PR_INS_BW_MOV_CRE_BATCH(RP_GMOVI IN GE_MOVIMIENTOS%ROWTYPE,
                                      p_tip_movimiento IN VARCHAR2) IS
      v_error VARCHAR2(30);
    BEGIN
    
      INSERT INTO GE_BAT_MOVIMIENTOS
        (cod_usuario, hora, nro_secuencia, cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
         cod_moneda, cod_tra_padre, cod_transaccion, fecha, nro_documento, monto, cod_mod_padre,
         cod_mad_padre, EST_PRO_BATCH, TIP_OPERACION)
      VALUES
        (rp_gmovi.cod_usuario, rp_gmovi.hora, rp_gmovi.nro_secuencia, rp_gmovi.cod_modulo,
         rp_gmovi.cod_modalidad, rp_gmovi.cod_oficina, rp_gmovi.nro_cuenta, rp_gmovi.cod_moneda,
         rp_gmovi.cod_tra_padre, rp_gmovi.cod_transaccion, rp_gmovi.fecha, rp_gmovi.nro_documento,
         rp_gmovi.monto, rp_gmovi.cod_mod_padre, rp_gmovi.cod_mad_padre, 'N', p_tip_movimiento);
    EXCEPTION
      WHEN OTHERS THEN
        fu_ins_log_mov_cre_batch('insertar en ' || v_error || ' usuario ' ||
                                 substr(lower(USER), 1, 6) || ' hora ' || rp_gmovi.hora ||
                                 ' secuencia ' || to_char(rp_gmovi.nro_secuencia) || ' cuenta ' ||
                                 rp_gmovi.nro_cuenta || ' moneda ' || rp_gmovi.cod_moneda ||
                                 ' trhijo ' || to_char(rp_gmovi.cod_transaccion) || ' fecha  ' ||
                                 to_char(rp_gmovi.fecha) || ' importe ' || to_char(rp_gmovi.monto) ||
                                 ' cotizacion ' || to_char(rp_gmovi.cotizacion) || ' ' || SQLERRM);
        raise_application_error(-20000,
                                'insertar en ' || v_error || ' usuario ' ||
                                 substr(lower(USER), 1, 6) || ' hora ' || rp_gmovi.hora ||
                                 ' secuencia ' || to_char(rp_gmovi.nro_secuencia) || ' cuenta ' ||
                                 rp_gmovi.nro_cuenta || ' moneda ' || rp_gmovi.cod_moneda ||
                                 ' trhijo ' || to_char(rp_gmovi.cod_transaccion) || ' fecha  ' ||
                                 to_char(rp_gmovi.fecha) || ' importe ' || to_char(rp_gmovi.monto) ||
                                 ' cotizacion ' || to_char(rp_gmovi.cotizacion) || ' ' || SQLERRM);
    END;
  
  BEGIN
    g_movs.cod_usuario   := nvl(g_movs.cod_usuario, USER);
    g_movs.nro_secuencia := p_nro_secuencia;
    g_movs.hora          := p_hora;
    g_movs.fecha         := p_fecha;
    g_movs.fec_valor     := p_fec_valor;
    g_movs.nro_cuenta    := p_nro_cuenta;
    -- transaccion padre
    g_movs.cod_tra_padre := p_cod_tra_padre;
    g_movs.cod_mod_padre := p_cod_mod_padre;
    g_movs.cod_mad_padre := p_cod_mad_padre;
    -- transaccion hijo
    g_movs.cod_transaccion := p_cod_transaccion;
  
    g_movs.concepto := p_concepto;
    --    g_movs.tip_movimiento  := p_tip_movimiento;
    g_movs.cod_moneda     := p_cod_moneda;
    g_movs.monto          := p_monto;
    g_movs.nro_documento  := p_nro_documento;
    g_movs.cotizacion     := p_cotizacion;
    g_movs.cod_ofi_origen := p_cod_ofi_origen;
    g_movs.emi_aviso      := p_emi_aviso;
    g_movs.cod_tasa       := p_cod_tasa;
    g_movs.val_tasa       := p_val_tasa;
    g_movs.cod_banco      := p_cod_banco;
    g_movs.cod_causa      := p_cod_causa;
    g_movs.mto_equ_local  := p_mto_equ_local;
    g_movs.estado         := p_estado;
    g_movs.reversado      := 'N';
  
    SELECT cod_modulo, cod_modalidad, cod_oficina
    INTO g_movs.cod_modulo, g_movs.cod_modalidad, g_movs.cod_oficina
    FROM ge_cuentas
    WHERE nro_cuenta = p_nro_cuenta;
  
    IF (p_tip_movimiento <> 'C') THEN
      raise_application_error(-20000, 'Solo Creditos son permitidos');
    END IF;

    BEGIN
      -- DDSI-212 -- 2017/12
      IF nvl(pag_cta.g_horario, 'D') IN ('D', 'T') then
         v_nocturno := 'N';
      ELSE
         v_nocturno := 'S';
      END IF;
      --inserta el movimiento en la cuenta pero no actualiza el saldo
      pag_gen.PR_INS_GE_MOVIMIENTO(g_movs, v_nocturno);  -- DDSI-212 -- 2017/12
      --guarda para actualizar el saldo
      pr_ins_bw_mov_cre_batch(g_movs, p_tip_movimiento);
    EXCEPTION
      WHEN OTHERS THEN
        fu_ins_log_mov_cre_batch(SQLERRM);
    END;
  END;

  --reversa un pago de servicios
  PROCEDURE pr_rev_operacion(p_fecha IN ge_movimientos.fecha%TYPE,
                             p_hora IN ge_movimientos.hora%TYPE,
                             p_cod_usuario IN ge_movimientos.cod_usuario%TYPE,
                             p_cod_mod_padre IN ge_movimientos.cod_mod_padre%TYPE,
                             p_cod_mad_padre IN ge_movimientos.cod_mad_padre%TYPE,
                             p_cod_tra_padre IN ge_movimientos.cod_tra_padre%TYPE,
                             p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE DEFAULT USER,
                             p_hor_reversion IN ge_movimientos.hor_reversion%TYPE DEFAULT to_char(SYSDATE,'HH24:MI:SS'),
                             p_es_nocturno IN VARCHAR2 DEFAULT 'N',
                             p_concepto IN VARCHAR2 DEFAULT NULL,
                             p_nro_documento IN ge_movimientos.nro_documento%TYPE DEFAULT NULL,
                             p_mov_orden IN VARCHAR2 DEFAULT NULL,
                             p_monto IN bw_pag_servicios.mto_transaccion%TYPE,
                             p_ws_cod_servicio IN bw_pag_servicios.cod_ws_servicios%TYPE,
                             p_cod_transaccion IN bw_pag_servicios.nro_transaccion%TYPE,
                             p_nro_boleta IN ge_set_pagos.nro_boleta%TYPE) IS
    v_nro_cuenta      ge_movimientos.nro_cuenta%TYPE;                         
    v_nro_cta_deb     bw_pag_servicios.nro_transaccion%TYPE;                     
    v_hor_reversion   ge_movimientos.hora%TYPE;
    v_fecha           bw_pag_servicios.fecha%type;
    v_ins_reversion     VARCHAR2(1) := 'N';
    v_can_intentos      NUMBER := 0;
    v_men_respuesta     VARCHAR2(4000);
    v_temp              TIMESTAMP;
    C_CANT_INT_REV      NUMBER(1) := 3; -- Cantidad de Intentos para reversion
    --variables p/ el envío de mail.
    v_para       VARCHAR2(2000);
    v_asunto     VARCHAR2(2000);
    v_mensaje    VARCHAR2(2000) := null;
    v_dir_correo VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--NVL(fug_obt_dir_correo,'bbvanet@bbva.com');  
    v_res        NUMBER;  
    
    BEGIN
      BEGIN
         SELECT DISTINCT m.nro_cuenta
           INTO v_nro_cuenta
      FROM ge_movimientos m
      WHERE m.cod_tra_padre = p_cod_tra_padre
      AND m.fecha = p_fecha
      AND m.hora = p_hora
      AND m.cod_usuario = p_cod_usuario
      AND m.reversado = 'N'
            AND EXISTS (SELECT 1
                   FROM bw_pag_servicios p
                  WHERE p.fecha = m.fecha
                    AND p.hora = m.hora
                    AND p.nro_cuenta = m.nro_cuenta);
      EXCEPTION
         WHEN OTHERS THEN
            v_nro_cuenta := '';
      END;
     BEGIN
        select a.nro_cuenta, a.fecha
          into v_nro_cta_deb, v_fecha
          from bw_pag_servicios a
         where a.nro_transaccion = p_cod_transaccion
           and a.cod_ws_servicios = p_ws_cod_servicio
           and a.reversado = 'N';
      EXCEPTION
         WHEN OTHERS THEN
            v_nro_cta_deb := NULL;
      END;
  
    fu_ins_log_mov_cre_batch('Reversa p_fecha:' || p_fecha || ', p_hora:' || p_hora ||
                             ', p_cod_usuario:' || p_cod_usuario || ', p_cod_mod_padre:' ||
                             p_cod_mod_padre || ', p_cod_mad_padre:' || p_cod_mad_padre ||
                             ', p_cod_mad_padre:' || p_cod_mad_padre || ', p_cod_tra_padre:' ||
                               p_cod_tra_padre || ', p_cod_usu_reversion' || p_cod_usu_reversion
                               || ', v_nro_cuenta ' || v_nro_cuenta
                               || ', v_nro_cta_deb ' || v_nro_cta_deb
                               || ', p_ws_cod_servicio ' || p_ws_cod_servicio
                               || ', p_cod_transaccion ' || p_cod_transaccion
                               || ', p_nro_boleta ' || p_nro_boleta);
     v_hor_reversion := p_hor_reversion;
        v_hor_reversion := fug_obt_hor_disponible(p_fecha,v_hor_reversion,p_cod_usu_reversion,'N'); 
        v_ins_reversion := 'N';
        v_can_intentos  := 0;
        WHILE v_ins_reversion = 'N' AND v_can_intentos <= C_CANT_INT_REV
        LOOP
           BEGIN
        prg_rev_operacion(p_fecha,
                          p_hora,
                          p_cod_usuario,
                              p_cod_mod_padre,
                              p_cod_mad_padre,
                          p_cod_tra_padre,
                          p_cod_usu_reversion,
                          v_hor_reversion,
                          p_es_nocturno,
                          p_concepto);
              v_ins_reversion := 'S';
           EXCEPTION
              WHEN OTHERS THEN
                 ROLLBACK;
                 v_temp          := pai_int.smg_sleep('0.5');
                 v_hor_reversion := fug_obt_hor_disponible(p_fecha, v_hor_reversion, p_cod_usu_reversion, p_es_nocturno);
                 v_ins_reversion := 'N';
                 v_can_intentos  := v_can_intentos + 1;
                 v_men_respuesta := substr(SQLERRM, 1, 4000);
           END;
        END LOOP;
        IF v_ins_reversion = 'S' THEN
          IF v_nro_cta_deb is not NULL THEN
          BEGIN
            --enviamos mail al cliente por reversion del pago a la SET o pago de servicio
            v_res:=pag_ser.fu_env_mail_pag_servicios(p_ws_cod_servicio,v_nro_cta_deb,p_nro_boleta,v_fecha,'N',p_cod_transaccion); 
          EXCEPTION
          WHEN OTHERS THEN
              NULL;
          END;
            -- actualiza a reversado el pago de servicio
            UPDATE bw_pag_servicios a
               SET a.reversado = 'S'
             WHERE a.cod_ws_servicios=p_ws_cod_servicio
               AND a.hora = p_hora
               AND a.fecha = p_fecha
               AND a.reversado = 'N';
          END IF;
        ELSIF  v_ins_reversion = 'N' THEN
          IF v_nro_cta_deb is not NULL THEN
          BEGIN
            --enviamos mail al cliente por reversion del pago a la SET o pago de servicio en el inicio de dia
            v_res:=pag_ser.fu_env_mail_pag_servicios(p_ws_cod_servicio,v_nro_cta_deb,p_nro_boleta,v_fecha,'S',p_cod_transaccion); 
          EXCEPTION
             WHEN OTHERS THEN
              NULL;
          END;
        END IF;                    
          fu_ins_log_mov_cre_batch('ERROR REV: nro_cuenta: ' || v_nro_cuenta || ' p_ws_cod_servicio:' || p_ws_cod_servicio || ' ~ ' || NVL(v_men_respuesta,SQLERRM) );
          -- fallo la reversion, se ingresa para reversar en el inicio de dia
          pag_ser.pr_ins_rev_cobro(p_ws_cod_servicio, p_cod_transaccion); 
        END IF;
  EXCEPTION
     WHEN OTHERS THEN
        ROLLBACK;
        fu_ins_log_mov_cre_batch('ERROR REV: nro_cuenta: ' || v_nro_cuenta || ' p_fecha:' || p_fecha || ', p_hora:' || p_hora ||
                             ', p_cod_usuario:' || p_cod_usuario || ' ~ ' || NVL(v_men_respuesta,SQLERRM) );
        raise_application_error(-20000, NVL(v_men_respuesta,SQLERRM));
  END;
  
  PROCEDURE pr_act_bat_saldos IS
    v_hora    VARCHAR(10);
    v_fecha   DATE;
    v_res     NUMBER(3);
    -- DDSI-212 -- 2017/12 
    v_monto         ge_bat_movimientos.monto%TYPE;
    v_tip_operacion ge_bat_movimientos.tip_operacion%TYPE;
    v_nro_cuenta    ge_cuentas.nro_cuenta%TYPE;
    -- DDSI-212 -- 2017/12 -- Se modifica el cursor para traer todos los registros insertados que no actualizaron el saldo de la cuenta
    CURSOR c_pagos IS
      SELECT b.nro_cuenta, b.cod_moneda, c.cod_modulo, c.cod_modalidad,
             SUM(decode(b.tip_operacion, 'D', b.monto, 0)) mto_debito,
             SUM(decode(b.tip_operacion, 'C', b.monto, 0)) mto_credito
      FROM GE_BAT_MOVIMIENTOS b, ge_cuentas c
      WHERE c.nro_cuenta = b.nro_cuenta
      AND b.est_pro_batch = 'P'
      GROUP BY b.nro_cuenta, b.cod_moneda, c.cod_modulo, c.cod_modalidad;
  
    PROCEDURE lf_act_estados(p_estado IN VARCHAR2) IS
    BEGIN
      BEGIN
        UPDATE GE_BAT_MOVIMIENTOS b
        SET b.est_pro_batch = p_estado
         WHERE b.est_pro_batch NOT IN('R','T')
           AND EXISTS( SELECT 1
                         FROM ge_movimientos m
                        WHERE m.fecha = b.fecha
                          AND m.hora = b.hora
                          AND m.cod_usuario = b.cod_usuario
                          AND m.reversado = 'N'
                          AND m.estado = 'N' );
      EXCEPTION
        WHEN OTHERS THEN
          fu_ins_log_mov_cre_batch('ERROR Marcar actualizar estado ' || ', estado:' || p_estado || ', ' ||SQLERRM);
          RETURN;
      END;
    END;
    
    FUNCTION lf_act_saldos(p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE,
                           p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                           p_saldo IN ge_movimientos.monto%TYPE, p_tipo IN VARCHAR2) RETURN NUMBER IS
      v_fecha  DATE := pag_cal.FU_OBT_FEC_ACTUAL(2);
      v_hora   VARCHAR2(10);
      v_llaveo VARCHAR2(2);
      v_temp   TIMESTAMP;
      
      PROCEDURE lf_act_estados(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_estado IN VARCHAR2) IS
      BEGIN
        BEGIN
          UPDATE GE_BAT_MOVIMIENTOS b
          SET b.est_pro_batch = p_estado          
          WHERE  b.nro_cuenta = p_nro_cuenta
	  AND b.est_pro_batch = 'P';
            fu_ins_log_mov_cre_batch('Marcar actualizar  estado:' || p_estado || ', ' || ' nro_cuenta: ' || p_nro_cuenta);
        EXCEPTION
          WHEN OTHERS THEN
            fu_ins_log_mov_cre_batch('Marcar actualizar  estado:' || p_estado || ', ' ||' nro_cuenta: '||p_nro_cuenta|| ', ' ||SQLERRM);
            raise_application_error(-20000, 'Error en Actualizacion de Saldos Batch: '||SQLERRM); 
        END;
      END;
    BEGIN
      v_hora := to_char(SYSDATE, 'HH24:MI:SS');    
      BEGIN
        v_llaveo := pag_cta.fu_llavear_cuenta(p_COD_MODALIDAD, P_NRO_CUENTA);
        IF (v_llaveo = 'N') THEN
          v_temp   := pai_int.smg_sleep('0.5');
          v_llaveo := pag_cta.fu_llavear_cuenta(p_COD_MODALIDAD, P_NRO_CUENTA);
        END IF;
        IF (v_llaveo = 'N') THEN
          fu_ins_log_mov_cre_batch('ERROR No se pudo llavear la cuenta: ' || P_NRO_CUENTA);
          raise_application_error(-2001, 'ERROR No se pudo llavear la cuenta: ' || P_NRO_CUENTA);
        END IF;
        fu_ins_log_mov_cre_batch('Actualizando cuenta:' || P_NRO_CUENTA || ', Tipo:' || p_tipo ||
                                 ', fecha:' || to_char(V_FECHA,'DD/MM/YYYY') || ':' || v_hora || ', saldo:' || p_saldo);
        pag_cta.g_horario := 'D'; -- DDSI-212 -- 2017/12 -- Para que actualice en tablas diurnas                         
        PAG_cta.PR_ACT_SAL_CTA(P_NRO_CUENTA, p_COD_MODALIDAD, p_tipo, V_FECHA, v_hora, p_saldo, 0, 0, 'N', 'N');                             
        lf_act_estados(p_nro_cuenta, 'T');
        COMMIT; -- para liberar el bloqueo de la cuenta
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          fu_ins_log_mov_cre_batch('ERROR cuenta:' || P_NRO_CUENTA || ' ' || SQLERRM);
          lf_act_estados(p_nro_cuenta, 'E');
          raise_application_error(-20000, 'Error en Actualizacion de Saldos Batch - Cuenta: '||P_NRO_CUENTA||' - '||SQLERRM);
          --RETURN 1;
      END;
      RETURN 0;
    END;
  BEGIN
  
    lf_act_estados('P');
  
    FOR reg IN c_pagos LOOP
      -- DDSI-212 -- 2017/12
      v_nro_cuenta := reg.nro_cuenta;
      if nvl(reg.mto_debito,0) > nvl(reg.mto_credito,0) then
        v_monto := nvl(reg.mto_debito,0) - nvl(reg.mto_credito,0);
        v_tip_operacion := 'D';
      else
        v_monto := nvl(reg.mto_credito,0) - nvl(reg.mto_debito,0) ;
        v_tip_operacion := 'C';
      end if;
      v_res := lf_act_saldos(reg.cod_modalidad, reg.nro_cuenta, v_monto, v_tip_operacion);
    END LOOP;
    
    BEGIN
      INSERT INTO ge_bat_movimientos_his
        (Fecha, hora, cod_usuario, nro_secuencia, monto, nro_cuenta, cod_moneda, cod_oficina,
         cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion, cod_modulo, cod_modalidad,
         nro_documento, est_pro_batch, tip_operacion)
        SELECT Fecha, hora, cod_usuario, nro_secuencia, monto, nro_cuenta, cod_moneda, cod_oficina,
               cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion, cod_modulo,
               cod_modalidad, nro_documento, est_pro_batch, tip_operacion
        FROM ge_bat_movimientos
        WHERE est_pro_batch <> 'N';
      DELETE FROM ge_bat_movimientos WHERE est_pro_batch <> 'N';
    END;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'Error en Actualizacion de Saldos Batch - Cuenta: '||v_nro_cuenta||' - '||SQLERRM);
  END;
 
  -- DDSI-212 -- 2017/12
  /* Funcion para verificar existencia de movimiento para actualizacion de saldo en batch */
  FUNCTION fu_ver_exi_movimiento(p_nro_cuenta      ge_cuentas.nro_cuenta%TYPE, 
                                 p_fecha           ge_movimientos.fecha%TYPE, 
                                 p_hora            ge_movimientos.hora%TYPE,
                                 p_cod_usuario     ge_movimientos.cod_usuario%TYPE,
                                 p_cod_tra_padre   ge_movimientos.cod_tra_padre%TYPE,
                                 p_cod_transaccion ge_movimientos.cod_transaccion%TYPE,
                                 p_monto           ge_movimientos.monto%TYPE) RETURN VARCHAR2 IS
     v_retorno VARCHAR2(1) := 'N';
  BEGIN
     SELECT DISTINCT 'S'
       INTO v_retorno
       FROM GE_BAT_MOVIMIENTOS m
      WHERE m.cod_tra_padre = p_cod_tra_padre
        AND m.fecha = p_fecha
        AND m.monto = p_monto
        AND m.hora = p_hora
        AND m.cod_tra_padre = p_cod_tra_padre
        AND m.cod_transaccion = p_cod_transaccion
        AND m.cod_usuario = p_cod_usuario
        AND m.nro_cuenta = p_nro_cuenta
        AND m.est_pro_batch = 'N';
     RETURN v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        RETURN v_retorno;
  END;

BEGIN
  pre_cam_for_numerico('.,');
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 9; --Modulo caja
END PAG_BAT;
/

