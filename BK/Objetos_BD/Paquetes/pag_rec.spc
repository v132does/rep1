create or replace package it.PAG_REC is

  -- Author  : XPY0094
  -- Created : 23/01/2014 08:51:33 a.m.
  -- Purpose : Funciones y Procedimientos necesarios para el cobro de servicios de recaudaciones.

  -- Obtiene la dirección de mail para indicar el remitente del mail a enviar al cliente
  c_dir_mail   ba_personas.dir_correo%type  := fug_obt_pardinamico('DIR_MAIL_RECAUDACION') ;

  -- Inserta los errores en la tabla ge_pag_recaudaciones_err
  PROCEDURE PR_INS_LOG(
                        RG_GPREC IN GE_PAG_RECAUDACIONES_ERR%ROWTYPE
                       );

  -- Obtiene el siguiente número de archivo para los registros a importar.
  FUNCTION FU_OBT_SIG_NUM_ARCHIVO(
                        P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,
                        P_FEC_OPERACION IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE
                        )
     RETURN NUMBER;

  --Valida los datos de la importación de datos.
  PROCEDURE PR_VAL_DATOS(
                         P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,
                         P_FECHA IN GE_CALENDARIOS.FEC_ACTUAL%TYPE,
                         P_NRO_ARCHIVO IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                         P_PROCESO IN VARCHAR2
                        );
  --Obtener datos de los parámetros.
  PROCEDURE PR_OBT_DAT_SERVICIOS(
                        P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,
                        P_NRO_CTA_DEBITO IN GE_PAG_RECAUDACIONES.NRO_CTA_DEBITO%TYPE default null,
                        P_NRO_ARCHIVO IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                        P_FEC_OPERACION IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE,
                        P_SER_COSTO IN OUT VARCHAR2,
                        P_FEC_INI_CONTRATO IN OUT DATE,
                        P_FEC_FIN_CONTRATO IN OUT DATE,
                        P_CTA_RECAUDADORA_GS IN OUT VARCHAR2,
                        P_CTA_RECAUDADORA_USD IN OUT VARCHAR2,
                        P_CTA_RECAUDADORA_EUR IN OUT VARCHAR2,
                        P_COD_TRA_PADRE IN OUT VARCHAR2,
                        P_SER_ACTIVO IN OUT VARCHAR2,
                        P_CAN_DIA_PAGO IN OUT VARCHAR2
                                 );
  PROCEDURE PR_SRC_ATTACH_XLS(p_cod_ente IN ge_entes.cod_ente%TYPE DEFAULT NULL);

  PROCEDURE PR_COB_CARGOS ;

  PROCEDURE PR_OBT_CARGOS (
                      P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE,
                      P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                      P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE,
                      P_CANTIDAD IN NUMBER,
                      P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE,
                      P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE,
                      P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE,
                      P_COD_TRA_CARGO IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE,
                      P_IVA_INCLUIDO  IN VARCHAR2 DEFAULT 'S',
                      P_COD_TAS_CARGO IN OUT GE_MOVIMIENTOS.COD_TASA%TYPE,
                      P_VAL_TAS_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
                      P_VAL_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
                      P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE,
                      P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE,
                      P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
                      P_VAL_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE ) ;
  
  -- actualizar el estado de un pago
  FUNCTION FU_ACT_EST_RECAUDACION(P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,                                
                                  P_NRO_ARCHIVO IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                                  P_FEC_OPERACION IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE,
                                  P_ESTADO IN GE_PAG_RECAUDACIONES.ESTADO%TYPE) RETURN NUMBER;
  -- eliminar detalles temporales
  FUNCTION FU_ELI_TEMPORAL(
                      P_COD_ENTE      IN GE_ENTES.COD_ENTE%TYPE,
                      P_NRO_ARCHIVO   IN GE_PAG_RECAUDACIONES_TMP.NRO_ARCHIVO%TYPE,
                      P_FEC_OPERACION IN GE_PAG_RECAUDACIONES_TMP.FEC_OPERACION%TYPE) RETURN NUMBER;
  
  -- eliminar detalles de error
  FUNCTION FU_ELI_ERRORES(
                      P_COD_ENTE      IN GE_ENTES.COD_ENTE%TYPE,
                      P_NRO_ARCHIVO   IN GE_PAG_RECAUDACIONES_TMP.NRO_ARCHIVO%TYPE,
                      P_FEC_OPERACION IN GE_PAG_RECAUDACIONES_TMP.FEC_OPERACION%TYPE) RETURN NUMBER;
  
  -- Inserta en la tabla GE_PAG_RECAUDACIONES
  PROCEDURE PR_INS_GE_PAG_RECAUDACIONES(
                      P_COD_ENTE      IN GE_PAG_RECAUDACIONES.COD_ENTE%TYPE,
                      P_NRO_ARCHIVO   IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                      P_FEC_OPERACION IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE,
                      P_ERROR         OUT VARCHAR2);
  
  /* Funcion que valida la fecha de pago.
      0 : Fecha Valida
     -1 : Rango de fecha excedido
     -2 : Fecha menor a actual
     -3 : Fecha no habil
   */
  FUNCTION FU_VAL_FEC_PAGO(P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE,
                           P_FEC_PAGO IN DATE) RETURN NUMBER;
  
  --Valida los datos de la importación de datos.
  PROCEDURE PR_VAL_TEMPORAL(P_COD_ENTE      IN GE_ENTES.COD_ENTE%TYPE,
                            P_FEC_OPERACION IN GE_CALENDARIOS.FEC_ACTUAL%TYPE,
                            P_NRO_ARCHIVO   IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                            P_PROCESO       IN VARCHAR2);
  
  -- procesa el cobro de la recaudacion
  PROCEDURE PR_COB_ONLINE(P_COD_ENTE        IN GE_PAG_RECAUDACIONES.COD_ENTE%TYPE,
                        P_FEC_OPERACION   IN GE_PAG_RECAUDACIONES.FEC_OPERACION%TYPE,
                        P_NRO_ARCHIVO     IN GE_PAG_RECAUDACIONES.NRO_ARCHIVO%TYPE,
                        P_NRO_CTA_CREDITO IN GE_PAG_RECAUDACIONES.NRO_CTA_CREDITO%TYPE,
                        P_CANTIDAD        OUT NUMBER,
                        P_MTO_DEBITADO    OUT NUMBER,
                        P_CAN_ERROR       OUT NUMBER,
                        P_MTO_DEB_ERROR   OUT NUMBER,
                        P_MSJ_ERROR       OUT VARCHAR2);

  -- envio de notificacion
  PROCEDURE PR_ENV_NOTIFICACION;
                              --procesa el cobro cargando varios debitos y un sólo credito por el total
  --Se llama en el proceso independiente 99- SERVICIO DE RECAUDACIONES y en el cierre 107-PROCESO SERVICIO DE RECAUDACIONES
  PROCEDURE PR_COB_SER_REC(
                        P_CIERRE IN VARCHAR2 DEFAULT 'S',
                        P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL,
                        P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE DEFAULT NULL
                        );
  ---
  PROCEDURE PR_ENV_MAI_COBROS;
  ---
  PROCEDURE PR_SRC_ATTACH_XLS_CIE(p_cod_ente IN ge_entes.cod_ente%TYPE DEFAULT NULL);
                  
end PAG_REC;
/

