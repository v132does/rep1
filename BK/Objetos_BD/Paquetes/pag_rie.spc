create or replace package it.pag_rie is

   /**
   || Author  : RAMON BATTAGLIA
   || Created : 12/06/2013
   || Purpose : Paquete para Circuito de Riesgo Operativo
   **/

   -- Iniciar automáticamente el circuito cuando la operación Excede el Monto Máximo
   PROCEDURE PR_OPE_RIESGO
   (  p_fecha         IN ge_mov_autorizaciones.fecha%TYPE,
      p_hora          IN ge_mov_autorizaciones.hora%TYPE,
      p_cod_usuario   IN ge_mov_autorizaciones.cod_usuario%TYPE,
      p_cod_tra_padre IN ge_mov_autorizaciones.cod_tra_padre%TYPE,
      p_cod_mod_padre IN ge_mov_autorizaciones.cod_mod_padre%TYPE,
      p_cod_mad_padre IN ge_mov_autorizaciones.cod_mad_padre%TYPE,
      p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
      p_cod_persona   IN ba_personas.cod_persona%TYPE,
      p_tip_operacion IN ge_mov_autorizaciones.tip_operacion%TYPE,
      p_monto         IN ge_movimientos.monto%TYPE,
      p_nro_documento IN ge_movimientos.nro_documento%TYPE DEFAULT NULL,
      p_cod_moneda    IN ba_monedas.cod_moneda%type,
      p_cotizacion    IN ge_movimientos.cotizacion%TYPE ,
      p_nro_pedido    IN OUT NUMBER
    );

   -- Obtiene el usuario que solicitó el pedido
   FUNCTION FU_OBT_USU_AUTORIZACION (p_referencia wf_circuitos.referencia%TYPE,
                                     p_cod_tip_circuito wf_circuitos.cod_tip_circuito%TYPE)
     RETURN VARCHAR2;

   --- Procedimiento para aprobar los pedidos de Riesgo operativo
   PROCEDURE PR_APR_PEDIDO
   (  p_nro_pedido          IN ge_mov_autorizaciones.nro_pedido%TYPE,
      p_fecha               IN ge_mov_autorizaciones.fecha%TYPE,
      p_hora                IN ge_mov_autorizaciones.hora%TYPE,
      p_cod_usuario         IN ge_mov_autorizaciones.cod_usuario%TYPE,
      p_cod_tra_padre       IN ge_mov_autorizaciones.cod_tra_padre%TYPE,
      p_cod_mod_padre       IN ge_mov_autorizaciones.cod_mod_padre%TYPE,
      p_cod_mad_padre       IN ge_mov_autorizaciones.cod_mad_padre%TYPE,
      p_nro_cuenta          IN ge_mov_autorizaciones.nro_cuenta%TYPE,
      p_cod_persona         IN ge_mov_autorizaciones.cod_persona%TYPE,
      p_mto_mon_fuerte      IN ge_mov_autorizaciones.mto_mon_fuerte%TYPE,
      p_tip_operacion       IN ge_mov_autorizaciones.tip_operacion%TYPE,
      p_nro_documento       IN ge_mov_autorizaciones.nro_documento%TYPE DEFAULT NULL,
      p_cod_usu_autorizador IN ge_mov_autorizaciones.cod_usu_autorizador%TYPE,
      p_concepto            IN ge_mov_autorizaciones.concepto%TYPE,
      p_estado              IN ge_mov_autorizaciones.estado%TYPE,
      p_est_movimiento      IN ge_mov_autorizaciones.est_movimiento%TYPE,
      p_est_cuenta          IN ge_mov_autorizaciones.est_cuenta%TYPE,
      p_observacion         IN ge_mov_autorizaciones.observacion%TYPE
   );
    -- Bloquea el registro para reservarlo para la operacion
     FUNCTION FU_VER_MOV_PENDIENTE
   (  p_cod_usuario ge_mov_autorizaciones.cod_usuario%TYPE,
      p_hora        ge_mov_autorizaciones.hora%TYPE,
      p_fecha       ge_mov_autorizaciones.fecha%TYPE
   ) RETURN BOOLEAN;

   -- Procedimiento para rechazar los pedidos de autorización de Riesgo Operativo
   PROCEDURE PR_RCH_PEDIDO
   (  p_nro_pedido          IN ge_mov_autorizaciones.nro_pedido%TYPE,
      p_fecha               IN ge_mov_autorizaciones.fecha%TYPE,
      p_hora                IN ge_mov_autorizaciones.hora%TYPE,
      p_cod_usuario         IN ge_mov_autorizaciones.cod_usuario%TYPE,
      p_cod_tra_padre       IN ge_mov_autorizaciones.cod_tra_padre%TYPE,
      p_cod_mod_padre       IN ge_mov_autorizaciones.cod_mod_padre%TYPE,
      p_cod_mad_padre       IN ge_mov_autorizaciones.cod_mad_padre%TYPE,
      p_nro_cuenta          IN ge_mov_autorizaciones.nro_cuenta%TYPE,
      p_cod_persona         IN ge_mov_autorizaciones.cod_persona%TYPE,
      p_mto_mon_fuerte      IN ge_mov_autorizaciones.mto_mon_fuerte%TYPE,
      p_tip_operacion       IN ge_mov_autorizaciones.tip_operacion%TYPE,
      p_nro_documento       IN ge_mov_autorizaciones.nro_documento%TYPE DEFAULT NULL,
      p_cod_usu_autorizador IN ge_mov_autorizaciones.cod_usu_autorizador%TYPE,
      p_concepto            IN ge_mov_autorizaciones.concepto%TYPE,
      p_estado              IN ge_mov_autorizaciones.estado%TYPE,
      p_observacion         IN ge_mov_autorizaciones.observacion%TYPE
   );
   -- Procedimiento para Reversar Operaciones
   PROCEDURE PR_REV_OPERACION
   (
      p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
      p_fecha         IN ge_aut_reversiones.fecha%TYPE,
      p_hora          IN ge_aut_reversiones.hora%TYPE,
      p_cod_usuario   IN ge_aut_reversiones.cod_usuario%TYPE,
      p_cod_tra_padre IN ge_aut_reversiones.cod_tra_padre%TYPE,
      p_cod_mod_padre IN ge_aut_reversiones.cod_mod_padre%TYPE,
      p_cod_mad_padre IN ge_aut_reversiones.cod_mad_padre%TYPE,
      p_cod_moneda    IN ba_monedas.cod_moneda%type,
      p_monto         IN ge_movimientos.monto%TYPE,
      p_concepto      IN ge_aut_reversiones.concepto%type,
      p_nro_solicitud IN OUT NUMBER
     );
 
    FUNCTION FU_OBT_GRUPO 
   (   -- Busca el Tipo de Transaccion
     p_cod_modulo     ge_mov_autorizaciones.cod_mod_padre%TYPE,
     p_cod_modalidad  ge_mov_autorizaciones.cod_mad_padre%TYPE,
     p_cod_tra_padre  ge_mov_autorizaciones.cod_tra_padre%TYPE
   )  RETURN NUMBER;
    
 end;
/

