CREATE OR REPLACE PACKAGE IT.PAW_BTS IS

  -- Created : 11/05/2021 01:53:12 p.m.
  -- Purpose : logica para transferencia interna con bt services
  
  -- validar cuenta credito
  FUNCTION fu_val_cta_credito(p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                              p_nro_documento IN ba_personas.nro_documento%TYPE DEFAULT NULL,
                              p_monto         IN ge_movimientos.monto%TYPE DEFAULT NULL) RETURN typ_mapa;

  -- verificar movimiento tra. interna
  FUNCTION fu_ver_movimiento(p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                             p_nro_transaccion IN ge_movimientos.nro_documento%TYPE) RETURN typ_mapa;
  
  -- verificar movimiento sipap
  FUNCTION fu_ver_mov_snp(p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                          p_nro_transaccion IN ge_movimientos.nro_documento%TYPE) RETURN typ_mapa;

  -- procesar cuenta debito y acreditar en cuenta puente
  FUNCTION fu_pro_cta_debito(p_nro_operacion    IN ge_movimientos.nro_documento%TYPE,
                             p_nro_cta_debito   IN ge_movimientos.nro_cuenta%TYPE,
                             p_mto_debito       IN ge_movimientos.monto%TYPE,
                             p_mto_credito      IN ge_movimientos.monto%TYPE,
                             p_cod_mon_debito   IN ge_movimientos.cod_moneda%TYPE,
                             p_cod_mon_credito  IN ge_movimientos.cod_moneda%TYPE,
                             p_cot_debito       IN ge_movimientos.cotizacion%TYPE,
                             p_cot_credito      IN ge_movimientos.cotizacion%TYPE,
                             p_cod_usuario      IN ge_movimientos.cod_usuario%TYPE,
                             p_cod_ofi_origen   IN ge_movimientos.cod_ofi_origen%TYPE,
                             p_fec_actual       IN ge_movimientos.fecha%TYPE,
                             p_es_mov_noc       IN VARCHAR2,
                             p_concepto         IN ge_movimientos.concepto%TYPE,
                             p_nro_ope_cambio   IN lc_ope_pendientes.nro_operacion%TYPE DEFAULT NULL,
                             p_msj_error        OUT VARCHAR2) RETURN typ_mensajerespuesta;
 
  -- procesar cuenta para acreditar cliente y debitar en cuenta puente                     
  FUNCTION fu_pro_cta_credito(p_nro_caja       IN cj_cajas.nro_caja%TYPE,
                              p_nro_cuenta     IN ge_cuentas.nro_cuenta%TYPE,
                              p_monto          IN ge_movimientos.monto%TYPE,
                              p_nro_referencia IN VARCHAR2) RETURN typ_mapa;
  
  -- registrar error de envio a bts                        
  FUNCTION fu_reg_error(p_nro_documento     IN VARCHAR2,
                        p_nro_cta_debito    IN ge_cuentas.nro_cuenta%TYPE,
                        p_nro_cta_credito   IN VARCHAR2, 
                        p_cod_mon_credito   IN ba_monedas.cod_moneda%TYPE, 
                        p_mto_credito       IN ge_movimientos.monto%TYPE,
                        p_nro_doc_pendiente IN bw_mov_pendientes.nro_documento%TYPE DEFAULT NULL) RETURN typ_mensajerespuesta;

  -- Marcar documento para verificar
  PROCEDURE pr_ver_pendiente(p_nro_documento IN bw_mov_bts.nro_documento%TYPE);
  
  -- Marcar documento verificado a pendiente
  PROCEDURE pr_pen_verificado(p_nro_documento IN bw_mov_bts.nro_documento%TYPE);
  
  -- Reversar movimientos anteriores
  PROCEDURE pr_rev_tra_anteriores;
  
  -- reversar transfencias
  FUNCTION fu_rev_transferencia(p_nro_documento IN bw_mov_bts.nro_documento%TYPE) RETURN typ_mensajerespuesta;     

  -- marcar transferencia como procesada
  FUNCTION fu_pro_transferencia(p_nro_documento IN bw_mov_bts.nro_documento%TYPE) RETURN typ_mensajerespuesta;
  
  -- procesar sipap recibido
  FUNCTION fu_snp_recibido(p_nro_referencia  IN ge_movimientos.nro_documento%TYPE,
                           p_nro_cta_credito IN ge_movimientos.nro_cuenta%TYPE,
                           p_importe         IN ge_movimientos.monto%TYPE,
                           p_nro_ref_bcp     IN VARCHAR2 DEFAULT NULL) 
                           RETURN typ_mensajeRespuesta;

  -- debito entre ctas. puente para envio snp
  FUNCTION fu_snp_envio(p_nro_referencia  IN ge_movimientos.nro_documento%TYPE,
                        p_nro_cta_ope     IN ge_cuentas.nro_cuenta%TYPE,
                        p_importe         IN ge_movimientos.monto%TYPE,
                        p_nro_ref_bcp     IN VARCHAR2 DEFAULT NULL) 
                        RETURN typ_mensajeRespuesta;
  
    --- Unificación Código BIC SWIFT
  PROCEDURE pr_val_cta_mensajes
   (  p_nro_cuenta IN VARCHAR2,
      p_modo       IN NUMBER,
      p_respuesta  OUT VARCHAR2,
      p_error      OUT VARCHAR2);
END PAW_BTS;
/

