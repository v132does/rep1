CREATE OR REPLACE PACKAGE IT.PAG_BAT IS
  --
  -- Author  : Cristhian Benitez
  -- Created : 24/08/2017 01:53:56 p.m.
  -- Purpose : Agrupar las funciones de logica financiera y disponibilizar a otros servicios
   
  /***
  Funcion para registrar movimientos y no actualizar el saldo de la cuenta.
  */
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
                             p_estado IN VARCHAR2 DEFAULT 'N');

  /**
  Actualiza los saldos de las cuentas que tuvieron movimientos mediante pr_act_operacion
  */
  PROCEDURE pr_act_bat_saldos;
  
  PROCEDURE pr_rev_operacion
  (
     p_fecha             IN ge_movimientos.fecha%TYPE,
     p_hora              IN ge_movimientos.hora%TYPE,
     p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
     p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
     p_cod_mad_padre     IN ge_movimientos.cod_mad_padre%TYPE,
     p_cod_tra_padre     IN ge_movimientos.cod_tra_padre%TYPE,
     p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE DEFAULT USER,
     p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE DEFAULT to_char(SYSDATE, 'HH24:MI:SS'),
     p_es_nocturno       IN VARCHAR2 DEFAULT 'N',
     p_concepto          IN VARCHAR2 DEFAULT NULL,
     p_nro_documento     IN ge_movimientos.nro_documento%TYPE DEFAULT NULL,
     p_mov_orden         IN VARCHAR2 DEFAULT NULL,
     p_monto             IN bw_pag_servicios.mto_transaccion%TYPE,
     p_ws_cod_servicio IN bw_pag_servicios.cod_ws_servicios%TYPE,
     p_cod_transaccion IN bw_pag_servicios.nro_transaccion%TYPE,
     p_nro_boleta IN ge_set_pagos.nro_boleta%TYPE
  ) ;
  
  FUNCTION fu_act_sal_bat_estado(p_cod_proveedor IN bw_pag_servicios.cod_proveedor%TYPE)
  RETURN VARCHAR2;
  
  -- DDSI-212 -- 2017/12
  /* Funcion para verificar existencia de movimiento para actualizacion de saldo en batch */
  FUNCTION fu_ver_exi_movimiento(p_nro_cuenta      ge_cuentas.nro_cuenta%TYPE, 
                                 p_fecha           ge_movimientos.fecha%TYPE, 
                                 p_hora            ge_movimientos.hora%TYPE,
                                 p_cod_usuario     ge_movimientos.cod_usuario%TYPE,
                                 p_cod_tra_padre   ge_movimientos.cod_tra_padre%TYPE,
                                 p_cod_transaccion ge_movimientos.cod_transaccion%TYPE,
                                 p_monto           ge_movimientos.monto%TYPE) RETURN VARCHAR2;

END PAG_BAT;
/

