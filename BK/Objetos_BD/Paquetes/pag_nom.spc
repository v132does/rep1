create or replace package it.pag_nom is

  -- Author  : FQUINTANA
  -- Created : 03/04/2013 10:18:56 a.m.
  -- Purpose : Procesos correspondientes a Generación de Líneas y cancelación de Ctas. de Nóminas.
  v_fec_actual DATE := pag_cal.fu_obt_fec_actual(5);
  v_hora                ge_movimientos.hora%type;
  v_nro_secuencia       ge_movimientos.nro_secuencia%type;

  -- Obtiene el monto de la Línea de Sobregiro
  FUNCTION FU_MTO_LIN_SOBREGIROS(P_NRO_CUENTA        IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_ENTE          IN GE_ENTES.COD_ENTE%TYPE,
                                 P_TIP_CALCULO       IN VARCHAR2,
                                 P_CAN_MES_CALCULO   IN NUMBER,
                                 P_CAN_MES_RECALCULO IN NUMBER) return number;
  FUNCTION FU_OBT_LIN_SOBREGIRO(P_NRO_CUENTA VARCHAR2,
                                P_DOCUMENTO  VARCHAR2,
                                P_TIPO       VARCHAR2) RETURN VARCHAR2;

  /* Obtiene la cantidad de Pagos correspondientes a Nóminas
  posterior a la fecha de Inicio de Sobregiro*/
  FUNCTION FU_OBT_CAN_PAGOS(P_NRO_CUENTA VARCHAR2, P_TIP_CALCULO VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION FU_OBT_CAU_CAN_MASIVA(P_TIP_CAUSA          VARCHAR2,
                                 P_NRO_CUENTA         GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_ENTE           GE_ENTES.COD_ENTE%TYPE,
                                 P_CTA_SIN_MOVIMIENTO VARCHAR2)
    RETURN VARCHAR2;

  PROCEDURE PR_GEN_LIN_SOBREGIRO(P_NRO_CUENTA        IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_ENTE          IN GE_ENTES.COD_ENTE%TYPE,
                                 P_TIP_CALCULO       IN VARCHAR2,
                                 P_MTO_SOB_SUELDO    IN NUMBER DEFAULT 0,
                                 P_MTO_SOB_AGUINALDO IN NUMBER DEFAULT 0);

  PROCEDURE PR_PRO_LIN_SOBREGIRO(P_NRO_CUENTA  IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL,
                                 P_COD_ENTE    IN GE_ENTES.COD_ENTE%TYPE DEFAULT NULL,
                                 P_TIP_CALCULO IN VARCHAR2 DEFAULT NULL);

  PROCEDURE PR_CAN_TAR_DEBITO(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE);

  /* Cancela el Débito Automático asociado a una cuenta */
  PROCEDURE PR_CAN_DEB_AUTOMATICO(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE);

  /* Inserta en el Log de Pago de Cancelación de Pago de Nominas */
  PROCEDURE PR_INS_LOG(p_nro_cuenta       IN ge_cuentas.nro_cuenta%TYPE,
                       p_cod_error        IN ge_log_pag_nominas.cod_error%TYPE,
                       p_descripcion      IN VARCHAR2,
                       p_cod_usu_oficial  IN VARCHAR2 default null,
                       p_cod_ente         IN VARCHAR2,
                       p_ind_desvinculado IN VARCHAR2 default 'N',
                       p_nro_lote         IN NUMBER default null);

  /* Valida las cuentas para su cancelación. Similar a AMCANCEL */
  function FU_VAL_CUENTA(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                         P_NRO_LOTE IN GE_TELEGRAMAS.NRO_LOTE%TYPE)
    return boolean;
  /* Obtiene las Cuentas de Nomina de Clientes que recibieron Colasionados*/
  PROCEDURE PR_CAN_NOMINA;

  -- RABP-PCC 11-11-2013:
  -- Desviculamos del ente, lac Ctas registradas en el LOG de Cancelacion Masiva despues de un cierto tiempo --
  PROCEDURE PR_PRO_DESVINCULACION;
  PROCEDURE PR_EXO_MOV_PENDIENTE(P_NRO_CUENTA        IN ge_cuentas.nro_cuenta%TYPE,
                                 P_COD_MODULO        IN ge_cuentas.cod_modulo%type,
                                 P_COD_MODALIDAD     IN ge_cuentas.cod_modalidad%type,
                                 P_COD_MONEDA        IN ge_cuentas.cod_moneda%type,
                                 P_COD_OFICINA       IN ge_cuentas.cod_oficina%type,
                                 P_COD_SUB_MODALIDAD IN ge_cuentas.cod_sub_modalidad%type);
  
  /*Cobro de cargos si el saldo no supera el monto mínimo de cancelación*/ 
  PROCEDURE PR_COB_CARGO(P_NRO_CUENTA        IN ge_cuentas.nro_cuenta%TYPE,
                         P_COD_MODULO        IN ge_cuentas.cod_modulo%TYPE,
                         P_COD_MODALIDAD     IN ge_cuentas.cod_modalidad%TYPE,
                         P_COD_OFICINA       IN ge_cuentas.cod_oficina%TYPE,
                         P_COD_MONEDA        IN ge_cuentas.cod_moneda%TYPE,
                         P_SAL_DISPONIBLE    IN number,
                         P_CAUSA             IN ge_telegramas.cod_cau_cancelacion%TYPE);
  
  /*Verifica autorización*/
  
  PROCEDURE PR_VER_AUTORIZACION(P_TRA_PROHIBIDA IN OUT   VARCHAR2,
                                P_MODULO     IN     NUMBER,
                                P_MODALIDAD  IN     NUMBER,
                                P_OFICINA    IN     NUMBER,
                                P_NRO_CUENTA     IN       VARCHAR2,
                                P_COD_TRA_PADRE    IN     NUMBER,
                                P_COD_TRANSACCION    IN     NUMBER,
                                P_EXIMIDO    IN OUT   VARCHAR2 );

end pag_nom;
/

