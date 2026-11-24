create or replace package it.paw_prv is

  -- Author  : XPY0042
  -- Created : 24/11/2017 10:44:29 a.m.
  -- Purpose : Validaciones y realización de Pagos a Proveedores de lotes recibidos de otros medios distintos a los de la Banca Web


   /**
   *typ_validarSesion
   *  Tipo  privado utilizado para retornar el estado de
   *    validez de una sesion ademas de informacion relacionada
   *    a la sesion
   */

   G_COD_ENTE GE_ENTES.COD_ENTE%TYPE;

   TYPE typ_validarSesion IS RECORD(
      error                VARCHAR2(1), -- hubo Error?
      nombreRespuesta      VARCHAR2(15), --Nombre del mensaje
      descripcionRespuesta VARCHAR2(200), -- Descripcion del mensaje
      codigoPersona        VARCHAR2(10),  -- Nombre del mensaje
      codigoCanal          VARCHAR2(3),   -- Nombre del mensaje
      codigoEmpresa        VARCHAR2(10),  -- Nombre del mensaje
      codigoPerfil         VARCHAR(20));

  TYPE typ_respuestaLimite IS RECORD(
      error                VARCHAR(1),
      nombreRespuesta      VARCHAR2(15),
      descripcionRespuesta VARCHAR2(200),
      codRespuesta         VARCHAR2(2));

  /**
   Estructura interna para verificar el estado de la caja
   */
   TYPE typ_mensajeCaja IS RECORD(
      error                VARCHAR2(1),
      nombreRespuesta      VARCHAR2(15),
      descripcionRespuesta VARCHAR2(200),
      estadoCaja           VARCHAR2(1),
      tipoCaja             VARCHAR2(1),
      codigoOficinaOrigen  NUMBER(3),
      codigoUsuario        VARCHAR2(10),
      fechaUltimoCierre    DATE);

  TYPE typ_obtenerPermisos IS RECORD(
      error                VARCHAR(1),
      nombreRespuesta      VARCHAR2(15),
      descripcionRespuesta VARCHAR2(200),
      autoriza             BOOLEAN,
      registra             BOOLEAN,
      consulta             BOOLEAN,
      canAutRequeridas     NUMBER);

  FUNCTION fu_ver_prv_hubglobal(p_cod_ente IN NUMBER) RETURN BOOLEAN;
  FUNCTION fu_obt_secuencia(p_fecha date, p_cod_ente number ) RETURN NUMBER;


  PROCEDURE pr_ins_notificaciones(p_cod_ente      IN NUMBER,
                                  p_cod_operacion IN NUMBER,
                                  p_cod_persona   IN VARCHAR2,
                                  p_tipo          IN VARCHAR2,
                                  p_est_notificacion IN VARCHAR2,
                                  p_campo1        IN VARCHAR2 DEFAULT NULL,
                                  p_valor1        IN VARCHAR2 DEFAULT NULL,
                                  p_campo2        IN VARCHAR2 DEFAULT NULL,
                                  p_valor2        IN VARCHAR2 DEFAULT NULL,
                                  p_campo3        IN VARCHAR2 DEFAULT NULL,
                                  p_valor3        IN VARCHAR2 DEFAULT NULL,
                                  p_campo4        IN VARCHAR2 DEFAULT NULL,
                                  p_valor4        IN VARCHAR2 DEFAULT NULL);

   /**
    * Cambia de estado las novedades a informar al global hub
    * Toma todas las novedades desde el ultimo envio
    *
    * @p_estado Indica el estado nuevo
    * @p_tipo  Indica que servicio se va a actualizar
    */
procedure pr_act_estado(p_estado in varchar,p_tipo in varchar2);
/**
* Registra los pagos a proveedores recibidos desde el GlobalHub
* @p_nro_cuenta Nro Cuenta Debito
* @p_monto Monto total (suma de todos los pagos)
* @p_cantidad Cantidad de lineas a pagar
* @p_moneda ISO de la moneda PYG o USD
* @p_fecha Fecha de las órdenes de pago

function fu_ins_glo_hub_pagos(p_nro_cuenta in varchar2, p_monto in number, p_cantidad in number, p_moneda in varchar2,p_fecha in date,p_pagos in typ_globalhubPrvPagos,p_hub_agrupado in varchar2,p_hub_ref_local in varchar2,p_hub_nom_archivo in varchar2) return TYP_RESGLOBALHUBPRV;
*/
FUNCTION fu_obt_cod_ente_globalhub(p_nro_cuenta IN VARCHAR) RETURN TYP_RESGLOBALHUBPRV;

/**
* Obtiene el codigo de ente asociado al cliente global
* @p_nro_cuenta Nro Cuenta Debito
* @return Nro de Ente  
*/
function fu_obtenerEnte(p_nro_cuenta IN VARCHAR) RETURN number;
/**
* Obtiene el codigo de persona asociado al ente
* @p_CodEnte Nro de ente
* @return Codigo de persona  
*/
function fu_obtenerCodPersona(p_CodEnte in number ) return varchar2;

FUNCTION fu_obt_glo_hub_nro_archivo(p_cod_ente IN VARCHAR2) RETURN NUMBER;

FUNCTION fu_insertarLineaPago(NRO_ORDEN IN NUMBER, NRO_FACTURA IN VARCHAR2, TIP_COMPROBANTE IN VARCHAR2,
                              FOR_PAGO IN VARCHAR2, NRO_CHEQUE IN NUMBER, NRO_CTA_CREDITO IN VARCHAR2,
                              FEC_INGRESO IN DATE, FEC_PAGO IN DATE, MONTO IN NUMBER, NRO_RECIBO IN NUMBER,
                              BENEFICIARIO IN VARCHAR2, CONCEPTO IN VARCHAR2, ESTADO IN VARCHAR2, COD_ENTE IN NUMBER,
                              COD_PROCESO IN NUMBER, COD_MONEDA IN VARCHAR2, TIP_CARGA IN VARCHAR2,
                              COD_MON_RECIBIDO IN VARCHAR2, REF_FACTURAS IN VARCHAR2, REFERENCIA IN VARCHAR2,
                              MON_TOT_RECIBO IN NUMBER, RET_FAC_PROVEEDOR IN NUMBER, DES_FAC_PROVEEDOR IN NUMBER,
                              RET_FACTURAS IN NUMBER, DES_SUCURSAL IN VARCHAR2, TIPO IN VARCHAR2,
                              NRO_CTA_DEBITO IN VARCHAR2, NRO_SECUENCIA IN NUMBER, NRO_ARCHIVO IN NUMBER,
                              COD_TIP_DOC_BENEFICIARIO IN NUMBER, NRO_DOC_BENEFICIARIO IN VARCHAR2,
                              NRO_CTA_BENEFICIARIO IN VARCHAR2, ENT_BCA_BENEFICIARIO IN NUMBER, IND_VALOR IN VARCHAR2,
                              DIR_BENEFICIARIO IN VARCHAR2, TIP_FACTURA IN NUMBER, NRO_CON_CAMBIO IN NUMBER,
                              BEN_DIR_CORREO IN VARCHAR2, NRO_ORD_ARCHIVO IN NUMBER, COD_ONE_BANK IN VARCHAR2,
                              TIP_ACREDITAMIENTO IN VARCHAR2, TIP_TRANSFERENCIA IN VARCHAR2, MSJ_RESPUESTA IN VARCHAR2,
                              DES_RESPUESTA IN VARCHAR2, ERROR IN VARCHAR2, ISO_COD_ERROR IN VARCHAR2,
                              ISO_DES_ERROR IN VARCHAR2, p_nro_cuenta IN VARCHAR2, p_moneda IN VARCHAR, p_ente IN NUMBER,
                       p_nro_archivo IN NUMBER, p_fecha IN DATE, p_hub_agrupado IN VARCHAR2, p_hub_ref_local IN VARCHAR2,
                       p_hub_nom_archivo IN VARCHAR2,p_hub_nom_agrupado in varchar2) RETURN NUMBER;

  PROCEDURE pr_pro_archivo(p_nro_archivo IN NUMBER,
                           p_cod_ente    IN NUMBER,
                           p_nom_agrupado IN VARCHAR2,
                           p_error       OUT VARCHAR2);
                           
FUNCTION fu_insertarCabecera(p_nro_archivo IN NUMBER, p_ente IN NUMBER, p_can_pagos IN NUMBER, p_mon_total IN NUMBER,
                             p_nro_cuenta IN VARCHAR2, p_fec_pago IN DATE, p_archivo IN CLOB,p_nom_agrupado in varchar2) RETURN NUMBER;
FUNCTION fu_realizarPagosArchivo(p_nom_agrupado IN VARCHAR2) RETURN NUMBER;

PROCEDURE pr_ver_pag_global;

end paw_prv;
/

