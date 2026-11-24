CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_COMPENSACION(p_fec_actual DATE DEFAULT NULL) IS
   C_GRU_TRA_AC      CONSTANT NUMBER := 101; -- Grupo de Transaccion de Acreditaciones a Comercios
   C_COD_TRA_CRE_PAC CONSTANT ge_transacciones.cod_transaccion%TYPE := 4713;
   C_COD_TRA_DEB_PAC CONSTANT ge_transacciones.cod_transaccion%TYPE := 4714;
   v_fec_actual    DATE := NVL(p_fec_actual, PAG_CAL.FU_OBT_FEC_ACTUAL(3));
   v_cod_oficina   NUMBER := NVL(fug_obt_pardinamico('COD_OFI_TESORERIA'),31);
   v_fec_hab_ant   DATE := PAG_CAL.FU_OBT_FEC_ANT_HAB(v_fec_actual, v_cod_oficina, 1);
   v_nro_lote      NUMBER := TO_NUMBER(TO_CHAR(v_fec_actual, 'YYYYMMDD'));
   v_cod_mon_local ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_redondeo_ml   NUMBER := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 4, NULL, v_cod_mon_local);
   
   --
   r_gmovi           ge_movimientos%ROWTYPE;
   v_hora            ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE := 0;
   v_usuario         ge_movimientos.cod_usuario%TYPE := USER;
   v_tip_mov_rubro   ge_movimientos.tip_mov_rubro%TYPE;
   v_monto           ge_movimientos.monto%TYPE;
   v_mto_equ_local   ge_movimientos.mto_equ_local%TYPE;
   v_cod_transaccion ge_movimientos.cod_transaccion%TYPE;
   v_cod_modulo      ge_movimientos.cod_modulo%TYPE;
   v_cod_modalidad   ge_movimientos.cod_modalidad%TYPE;
   v_concepto        ge_movimientos.concepto%TYPE;
   v_nro_documento   ge_movimientos.nro_documento%TYPE;
   v_cotizacion      ge_movimientos.cotizacion%TYPE;
   v_cod_persona     ge_movimientos.cod_persona%TYPE;
   v_referencia      ge_movimientos.referencia%TYPE;
   v_nro_cuenta      ge_movimientos.nro_cuenta%TYPE;
   v_lugar           varchar2(200);
   --
   v_llaveo VARCHAR2(2);
   v_temp   TIMESTAMP;
   --

   CURSOR c_mov IS
      SELECT a.nro_cuenta, a.cod_moneda, 
             SUM(DECODE(th.tipo, 'C', a.monto, 0)) CREDITO, 
             SUM(DECODE(th.tipo, 'D', a.monto, 0)) DEBITO
        FROM cc_movimientos_his a, ge_gru_transacciones_det b, ge_transacciones tp,
             ge_acr_comercios_his ac, ge_entes e, ge_transacciones th
       WHERE a.cod_tra_padre = b.cod_transaccion
         AND a.cod_mod_padre = b.cod_modulo
         AND a.cod_mad_padre = b.cod_modalidad
         AND b.cod_transaccion = tp.cod_transaccion
         AND a.cod_tra_padre = tp.cod_transaccion
         AND a.fecha = ac.fec_movimiento
         AND a.hora = ac.hor_movimiento
         AND a.nro_documento2 = ac.nro_referencia
         AND ac.cod_ente = e.cod_ente
         AND a.cod_transaccion = th.cod_transaccion
         AND a.cod_modulo = th.cod_modulo
         AND a.cod_modalidad = th.cod_modalidad
         AND b.cod_gru_transaccion = C_GRU_TRA_AC
         AND a.ESTADO = 'N'
         AND a.REVERSADO = 'N'
         AND ac.procesado = 'P' -- P=En Proceso 
         AND ac.nro_lote < v_nro_lote
         AND EXISTS (SELECT 1
                FROM CC_CTA_BANCARIAS c
               WHERE c.nro_cuenta = a.nro_cuenta)
       GROUP BY a.nro_cuenta, a.cod_moneda;

   /*Procedimiento para actualizar estado de proceso de Acreditaciones a Comercios*/
   PROCEDURE lp_act_est_proceso(p_estado IN VARCHAR2, p_est_anterior IN VARCHAR2) IS
      -- Estados: N=Pendiente de Proceso, P=En Proceso, S=Procesado
   BEGIN
      UPDATE ge_acr_comercios_his ac
         SET ac.procesado = p_estado
       WHERE ac.nro_lote < v_nro_lote
         AND ac.procesado = p_est_anterior;
   END;
   --
   /*Procedimiento para mover al Historico las Acreditaciones a Comercios procesadas*/
   PROCEDURE lp_mov_his IS
      -- Estados: N=Pendiente de Proceso, P=En Proceso, S=Procesado
   BEGIN
      -- Insertar registros en el historico
      INSERT INTO ge_acr_comercios_his
         SELECT *
           FROM ge_acr_comercios
          WHERE procesado = 'S';
      -- Borrar de la tabla    
      DELETE FROM ge_acr_comercios
       WHERE procesado = 'S';
   END;
   --
BEGIN
   -- Actualizar a estado en Proceso los Pendientes de Proceso
   v_lugar := 'Actualizar estado a En Proceso.';
   lp_act_est_proceso('P', 'N');
   v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, v_usuario, 'N');
   v_lugar := 'Registrar Movimientos.';
   FOR reg IN c_mov
   LOOP
      v_nro_cuenta := reg.nro_cuenta;
      IF NVL(reg.debito, 0) > NVL(reg.credito, 0) THEN
         v_cod_transaccion := C_COD_TRA_CRE_PAC;
         v_tip_mov_rubro   := 'C';
         v_monto           := NVL(reg.debito, 0) - NVL(reg.credito, 0);
      ELSIF NVL(reg.credito, 0) > NVL(reg.debito, 0) THEN
         v_cod_transaccion := C_COD_TRA_DEB_PAC;
         v_tip_mov_rubro   := 'D';
         v_monto           := NVL(reg.credito, 0) - NVL(reg.debito, 0);
      ELSE
         v_monto := 0;
      END IF;
      IF v_monto > 0 THEN
         if v_nro_secuencia > 990 then
            v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, v_usuario, 'N');
            v_nro_secuencia := 0;
         end if;
         v_nro_secuencia := v_nro_secuencia + 1;
         -- generar movimiento --
         r_gmovi.cod_usuario     := v_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         r_gmovi.cod_oficina     := v_cod_oficina;
         r_gmovi.nro_cuenta      := v_nro_cuenta;
         r_gmovi.cod_moneda      := reg.cod_moneda;
         r_gmovi.fec_valor       := v_fec_actual;
         r_gmovi.fecha           := v_fec_actual;
         r_gmovi.cod_tra_padre   := v_cod_transaccion;
         r_gmovi.cod_transaccion := v_cod_transaccion;
         --
         PAG_CTA.PR_OBT_CUENTA(v_nro_cuenta);
         v_cod_modulo    := PAG_CTA.G_CTAS.COD_MODULO;
         v_cod_modalidad := PAG_CTA.FU_OBT_MAD_CUENTA;
         v_concepto      := 'COMP.MOV.PET.ACR.COMERCIOS';
         v_nro_documento := TO_NUMBER(TO_CHAR(v_fec_hab_ant, 'YYYYMMDD'));
         v_referencia    := v_nro_cuenta;
         --Traer el codigo de persona
         BEGIN
            v_cod_persona := fug_obt_cli_principal(reg.nro_cuenta);
         EXCEPTION
            WHEN OTHERS THEN
               v_cod_persona := NULL;
         END;
         IF reg.cod_moneda <> v_cod_mon_local THEN
            v_cotizacion    := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
            v_mto_equ_local := round(trunc(v_monto, 2) * v_cotizacion, NVL(v_redondeo_ml, 0));
         ELSE
            v_cotizacion    := NULL;
            v_mto_equ_local := NULL;
         END IF;
         r_gmovi.monto          := v_monto;
         r_gmovi.cotizacion     := v_cotizacion;
         r_gmovi.mto_equ_local  := v_mto_equ_local;
         r_gmovi.nro_documento  := v_nro_documento;
         r_gmovi.nro_documento2 := NULL;
         r_gmovi.estado         := 'N';
         r_gmovi.cod_ofi_origen := v_cod_oficina;
         r_gmovi.reversado      := 'N';
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.protegido      := 'N';
         r_gmovi.cod_mod_padre  := v_cod_modulo;
         r_gmovi.cod_mad_padre  := v_cod_modalidad;
         r_gmovi.cod_modulo     := v_cod_modulo;
         r_gmovi.cod_modalidad  := v_cod_modalidad;
         r_gmovi.concepto       := v_concepto;
         r_gmovi.referencia     := v_referencia;
         r_gmovi.cod_persona    := v_cod_persona;
         r_gmovi.cod_rubro      := NULL;
         r_gmovi.tip_mov_rubro  := v_tip_mov_rubro;
         --      
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         -- Actualizar Saldo de Cuenta
         v_lugar := 'Actualizar Saldo de Cuenta.';
         pag_cta.g_horario := 'D';
         v_llaveo := pag_cta.fu_llavear_cuenta(v_cod_modalidad, v_nro_cuenta);
         IF (v_llaveo = 'N') THEN
            v_temp   := pai_int.smg_sleep('0.5');
            v_llaveo := pag_cta.fu_llavear_cuenta(v_cod_modalidad, v_nro_cuenta);
         END IF;
         IF (v_llaveo = 'N') THEN
            raise_application_error(-2001, 'ERROR No se pudo llavear la cuenta: ' || v_nro_cuenta);
         END IF;
         PAG_CTA.PR_ACT_SAL_CTA(v_nro_cuenta, v_cod_modalidad, v_tip_mov_rubro, v_fec_actual, v_hora, v_monto, 0, 0, 0, 'N'); 
         --
      END IF;
   END LOOP;
   v_nro_cuenta := NULL;
   -- Actualizar a Procesado los que estaban en Proceso
   v_lugar := 'Actualizar estado a Procesado.';
   lp_act_est_proceso('S', 'P');
   --DDEVOLUT-1132
   /*-- Mover Registros a Historico
   v_lugar := 'Mover Registros a Historico.';
   lp_mov_his;*/
EXCEPTION
   WHEN OTHERS THEN
      IF v_nro_cuenta IS NOT NULL THEN
         Raise_application_error(-20000, 'Error en: '||v_lugar||' nro_cuenta: ' || v_nro_cuenta || ' - ' || SQLERRM);
      ELSE
         Raise_application_error(-20001, 'Error en: '||v_lugar||' - '||SQLERRM);
      END IF;
END;
/

