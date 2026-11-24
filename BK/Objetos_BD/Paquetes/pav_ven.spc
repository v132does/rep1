create or replace package it.PAV_VEN is
  -- Variables Públicas
  r_log           TA_LOGS%ROWTYPE;
  --
  c_fec_actual    CONSTANT DATE := pag_cal.fu_obt_fec_actual(15);
  c_mon_local     CONSTANT GE_CUENTAS.COD_MONEDA%TYPE := pag_gen.fu_obt_mon_local;
  --
  g_nro_cuenta    GE_CUENTAS.NRO_CUENTA%TYPE;
  g_cod_modulo    BA_MODULOS.COD_MODULO%TYPE;
  g_cod_modalidad GE_MODALIDADES.COD_MODALIDAD%TYPE;
  g_cod_oficina   BA_OFICINAS.COD_OFICINA%TYPE;
  g_cod_moneda    GE_CUENTAS.COD_MONEDA%TYPE;
  g_cotizacion    GE_COTIZACIONES.VAL_COMPRA%TYPE;
  g_dias          NUMBER;
  g_secuencia     GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;
  g_hor_movim     GE_MOVIMIENTOS.HORA%TYPE;
  --
  g_nro_reg       NUMBER;
  --
  g_tip_implementacion GE_PAR_GENERALES.TIP_IMPLEMENTACION%TYPE := fug_obt_tip_implementacion;
  --*******************************************--
  -- Public function and procedure declarations
  /* Realizar asientos contables por el cambio de estado del préstamo. */
  PROCEDURE PR_INS_ASIENTO( p_cod_tra_padre   IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
                            p_cod_transaccion IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE,
                            p_monto           IN GE_MOVIMIENTOS.MONTO%TYPE,
                            p_concepto        IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
                            p_estado          IN GE_MOVIMIENTOS.EST_CUENTA%TYPE );
  /* Recupera monto previsión de ge_cla_operaciones. */
  FUNCTION FU_OBT_PREVISION( P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE ) RETURN NUMBER;
end PAV_VEN;
/

