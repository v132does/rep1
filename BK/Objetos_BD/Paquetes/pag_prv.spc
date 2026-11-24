CREATE OR REPLACE PACKAGE IT.PAG_PRV IS
 v_tra_spi          varchar2(1) :='N';                
/* Obtener datos parámetros de empresas   pago proveedores */
PROCEDURE PR_OBT_DAT_PROVEEDOR
 (P_EMPRESA IN NUMBER
 ,P_DESCRIPCION OUT VARCHAR2
 ,P_TIP_COMPROBANTE OUT VARCHAR2
 ,P_COD_TRA_PADRE OUT NUMBER
 ,P_CTA_DEBITO OUT VARCHAR2
 ,P_PAG_FAC_ATRASADA OUT VARCHAR2
 ,P_REF_TXT OUT VARCHAR2
 ,P_COD_TRA_DEBITO OUT NUMBER
 ,P_RUB_DEBITO     OUT VARCHAR2
 );
/* Obtener parámetros de ente adicionales */ 
PROCEDURE PR_OBT_PAR_PROVEEDOR
 (P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE
 ,P_COD_TRA_PAD_CREDITO OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TRA_COM_MENSUAL OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TRA_COM_INDIVIDUAL OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TRA_COM_SERVICIO OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_REF_TXT_MON_FUERTE OUT GE_PAR_ENTES.VAL_PARAMETRO%TYPE
 );
/* Insertar en GE_PAG_PROVEEDORES desde el TMP */
PROCEDURE PR_INS_GE_PAG_PROVEEDORES
 (P_COD_EMPRESA IN NUMBER
 ,P_FECHA IN DATE
 ,P_ERROR OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 );
/* Borra Datos de la tabla GE_PAG_PROVEEDORES_TMP */
PROCEDURE PR_ELI_PROV_TMP
 (P_COD_EMPRESA IN NUMBER,
  P_FEC_PROCESO IN DATE DEFAULT NULL,
  P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 );
/* Insertar en la tabla GE_PAG_PRO_FACTURAS desde el TMP */
PROCEDURE PR_INS_GE_PAG_PRO_FACTURAS
 (P_COD_EMPRESA IN NUMBER
 ,P_FECHA IN DATE
 ,P_ERROR OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 );
/* Borra datos del temporal CC_FAC_PAGAR_TMP */
PROCEDURE PR_ELI_FAC_TMP
 (P_COD_EMPRESA IN NUMBER,
  P_FEC_PROCESO IN DATE DEFAULT NULL,
  P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 );
/* Cobra Impuesto ley 125 */
/*PROCEDURE PR_OBT_IMPUESTO
 (P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 );*/
/* Generar los cheques de Pago a Proveedores */
PROCEDURE PR_GEN_CHE_PROVEEDORES
 (P_COD_EMPRESA IN number
 ,P_FEC_PREVISTA IN date
 ,P_CHE_DESDE IN number
 ,P_CHE_HASTA IN number
 );
/*verifica los datos del tmp y procesa si no hay errores*/
PROCEDURE PR_VER_DAT_TMP
(P_COD_ENTE IN ge_entes.cod_ente%type,
 p_fec_pago1 in date,
 p_fec_pago2 in date,
 P_ERROR OUT varchar2,
 p_procesar in varchar2, 
 p_nro_documento in number default null,   -- OMM 26/04/2011 Para hacer Join Con Cabecera
 p_nro_cta_debito in ge_cuentas.nro_cuenta%type default null,
 p_nro_archivo in number default null,
 p_fec_insercion in date default null -- Modificaciones Fecha de Pago a Proveedores
 );
 /*verifica los datos del tmp y procesa si no hay errores (para archivos especiales*/
PROCEDURE PR_VER_DAT_TEMPORALES
(P_COD_ENTE IN ge_entes.cod_ente%type,
 p_fec_pago1 in date,
 P_ERROR OUT varchar2,
 p_procesar in varchar2
 );
/* valida el formato de hora de cierre de pago a proveedores */
PROCEDURE PR_VER_FMT_HOR_CIERRE(p_hor_cierre in ge_par_dinamicos.val_parametro%type);
/*Devolver la secuencia de pago*/
FUNCTION FU_OBT_NRO_SECUENCIA(P_COD_ENTE IN NUMBER,
                              P_FEC_PAGO IN DATE) RETURN NUMBER;
/*Devolver la cuenta en formato IT*/
 FUNCTION Fu_ver_cuenta
 (p_cta in varchar2)
 return varchar2;
 /*Devolver el nro cuenta completo en formato IT*/
 FUNCTION Fu_val_cuenta
 (p_cta in varchar2)
 return varchar2;
/*Formato recibido de Mapfre - Devolver la cuenta en formato IT*/
 FUNCTION Fu_ver_cuenta_map
 (p_cta in varchar2)
 return varchar2;
 /*genera la retención a proveedores de la empresa y retorna un valor para proceso y el monto
 de retención*/
 PROCEDURE PR_GEN_RETENCION(v_cod_ente in number, v_cod_proveedor in number,v_nro_factura in varchar2,
 v_fec_pago in date, v_procesa out varchar2, v_monto_retencion out number);
 /* Proceso para el cobro de comisiones */
 PROCEDURE PR_COB_COMISION(p_cod_comision in varchar2,
                          p_des_comision in varchar2,
                          p_cod_ente in ge_entes.cod_ente%type,
                          p_cod_tra_padre in ge_movimientos.cod_tra_padre%type,
                          p_nro_cta_debito in ge_movimientos.nro_cuenta%type,
                          p_cod_modulo in ge_movimientos.cod_modulo%type,
                          p_cod_modalidad in ge_movimientos.cod_modalidad%type,
                          p_cod_moneda in ge_movimientos.cod_moneda%type,
                          p_monto in ge_movimientos.monto%type,
                          p_cod_oficina in ge_movimientos.cod_oficina%type,
                          p_can_credito in number,
                          p_nro_documento in ge_movimientos.nro_documento%type,
                          p_fecha in ge_movimientos.fecha%type,
                          p_hora in ge_movimientos.hora%type,
                          p_nro_secuencia in out ge_movimientos.nro_secuencia%type,
                          p_error in out varchar2,
                          p_msj_error in out varchar2,
                          p_mov_pendiente varchar2 default 'N');
 /* Proceso invocado por el cierre mensual para el cobro de comisiones mensuales */
 PROCEDURE PR_COB_COM_MENSUAL;
 -- OMM 26/04/2011 Proceso Automático que acredita Pago a Proveedores desde la Web en Cta.
 PROCEDURE PR_PRO_PAGO(p_ente in number default null, p_nro_documento in number default null, 
                       p_error   out    varchar2);
 /* Proceso de pago a proveedores a través de SNP */
 PROCEDURE PR_PRO_PAG_SNP (p_cod_ente in ge_entes.cod_ente%type,
                           p_usuario  in ba_usuarios.cod_usuario%type,
                           p_error    out varchar2,
                           p_fec_pago date default null,
                           p_nro_archivo ge_pag_proveedores.nro_archivo%type default null);
 
 /* Procedimiento para validar un contrato de cambio */
 PROCEDURE PR_VAL_NRO_CONTRATO(p_nro_contrato    IN OUT NUMBER,
                               p_cod_persona     IN ba_personas.cod_persona%TYPE,
                               p_mto_credito     IN NUMBER,
                               p_cod_mon_debito  IN ba_monedas.cod_moneda%TYPE,
                               p_cod_mon_credito IN ba_monedas.cod_moneda%TYPE,
                               p_ope_homebanking IN VARCHAR2,
                               p_cod_mensaje     IN OUT NUMBER,
                               p_mensaje         IN OUT VARCHAR2,
                               p_mto_debito      IN OUT NUMBER);

 /* Obtiene la fecha snp de un periodo */                               
 FUNCTION FU_OBT_FEC_SNP(P_COD_PERIODO IN GE_SNP_HORARIOS.COD_PERIODO%TYPE) 
   RETURN DATE;
 
 /* Obtiene la cantidad de operaciones de cambio de un lote de pago */
 FUNCTION FU_OBT_CAN_OPE_CAMBIO
 (P_COD_ENTE    IN GE_PAG_PROVEEDORES.COD_ENTE%TYPE
 ,P_FEC_PAGO    IN GE_PAG_PROVEEDORES.FEC_PAGO%TYPE
 ,P_COD_MONEDA  IN GE_PAG_PROVEEDORES.COD_MONEDA%TYPE
 ,P_NRO_ARCHIVO IN GE_PAG_PROVEEDORES.NRO_ARCHIVO%TYPE
 ,P_TEMPORAL    IN VARCHAR2 DEFAULT 'N'
 ) RETURN NUMBER;
 
 /* Cambiar la hora de pago SIPAP */
 FUNCTION FU_CAM_FEC_PAGO
 (P_COD_ENTE      IN GE_PAG_PROVEEDORES.COD_ENTE%TYPE
 ,P_FEC_PAGO      IN OUT GE_PAG_PROVEEDORES.FEC_PAGO%TYPE
 ,P_NRO_ARCHIVO   IN OUT GE_PAG_PROVEEDORES.NRO_ARCHIVO%TYPE
 ,P_TEMPORAL      IN VARCHAR2 DEFAULT 'N'
 ,P_FEC_INSERCION IN DATE DEFAULT SYSDATE
 ) RETURN BOOLEAN;
 
 /* verificar lotes de pagos  */
 PROCEDURE PR_VER_OPERACIONES;
 
 /* cancelar lote de pago */
 PROCEDURE PR_CAN_LOTE(p_cod_ente    IN ge_pag_proveedores.cod_ente%TYPE, 
                       p_fec_pago    IN ge_pag_proveedores.fec_pago%TYPE,
                       p_nro_archivo IN ge_pag_proveedores.nro_archivo%TYPE);
 
 /* Notificar lote de pago */
 PROCEDURE PR_NOT_LOTE(p_cod_ente    IN ge_pag_proveedores.cod_ente%TYPE, 
                       p_fec_pago    IN ge_pag_proveedores.fec_pago%TYPE,
                       p_nro_archivo IN ge_pag_proveedores.nro_archivo%TYPE,
                       p_mensaje     IN VARCHAR2);
 /*verifica los datos del tmp y procesa si no hay errores*/
PROCEDURE PR_VER_DAT_TMP_DEV
(P_COD_ENTE IN ge_entes.cod_ente%type,
 p_fec_pago1 in date,
 p_fec_pago2 in date,
 P_ERROR OUT varchar2,
 p_procesar in varchar2, 
 p_nro_documento in number default null,   -- OMM 26/04/2011 Para hacer Join Con Cabecera
 p_nro_cta_debito in ge_cuentas.nro_cuenta%type default null,
 p_nro_archivo in number default null,
 p_fec_insercion in date default null -- Modificaciones Fecha de Pago a Proveedores
 );--NVB-2232
 /* Insertar en GE_PAG_PROVEEDORES desde el TMP */
PROCEDURE PR_INS_GE_PAG_PROVEEDORES_DEV
 (P_COD_EMPRESA IN NUMBER
 ,P_FECHA IN DATE
 ,P_ERROR OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 );----NVB-2232
 /* Insertar en la tabla GE_PAG_PRO_FACTURAS desde el TMP */
PROCEDURE PR_INS_GE_PAG_PRO_FACTURAS_DEV
 (P_COD_EMPRESA IN NUMBER
 ,P_FECHA IN DATE
 ,P_ERROR OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 );--NVB-2232
 -- OMM 26/04/2011 Proceso Automático que acredita Pago a Proveedores desde la Web en Cta.
 PROCEDURE PR_PRO_PAGO_DEV(p_ente in number default null, p_nro_documento in number default null,
                           p_nro_movimiento  IN bw_movimientos.nro_movimiento%type default 0, /*BWP-311*/
                       p_error   out    varchar2);--NVB-2232
 /* --NVB-2232-Proceso de pago a proveedores a través de SNP */
 PROCEDURE PR_PRO_PAG_SNP_DEV(p_cod_ente in ge_entes.cod_ente%type,
                           p_usuario  in ba_usuarios.cod_usuario%type,
                           p_cod_error out varchar2,
                           p_error    out varchar2,
                           p_fec_pago date default null,
                           p_nro_archivo ge_pag_proveedores.nro_archivo%type default null,
                           p_nro_documento  IN bw_movimientos.nro_documento%type default 0 /*BWP-526*/);
/* --NVB-2232--Borra Datos de la tabla GE_PAG_PROVEEDORES_TMP */
PROCEDURE PR_ELI_PROV_TMP_DEV
 (P_COD_EMPRESA IN NUMBER,
  P_FEC_PROCESO IN DATE DEFAULT NULL,
  P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 );
 /* --NVB-2232--Borra datos del temporal CC_FAC_PAGAR_TMP */
PROCEDURE PR_ELI_FAC_TMP_DEV
 (P_COD_EMPRESA IN NUMBER,
  P_FEC_PROCESO IN DATE DEFAULT NULL,
  P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 );
 
 PROCEDURE pr_pro_transferencia_prv(rg_msj_mov_tra IN OUT PAS_SNP.rg_msj,
                                   p_cod_error IN OUT number,
                                   p_error        IN OUT VARCHAR2,
                                   p_cod_empresa  varchar2);
END PAG_PRV;
/
