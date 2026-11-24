create or replace package it.PAL_CAM is

  -- Author  : AGUSTIN MEZA
  -- Created : 02/08/2005 03:09:51 p.m.
  -- Purpose : Procedimientos y funciones relacionados con cambios

-- Actualizacion de movimientos pendientes de pasar por Caja
PROCEDURE PR_ACT_MOVIMIENTOS
         (P_COD_USUARIO IN GE_MOVIMIENTOS.COD_USUARIO%TYPE,
          P_FECHA       IN GE_MOVIMIENTOS.FECHA%TYPE,
          P_HORA        IN GE_MOVIMIENTOS.HORA%TYPE,
          P_ESTADO      IN GE_MOVIMIENTOS.ESTADO%TYPE,
          P_NRO_CAJA    IN GE_MOVIMIENTOS.NRO_CAJA%TYPE,
          P_COD_OFI_ORIGEN IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE DEFAULT NULL);
-- actualizacion de posicion de cambios
PROCEDURE PR_ACT_POSICIONES
(p_cod_tip_operacion in varchar2,
 p_cod_moneda in varchar2,
 p_cod_ofi_cambio in number,
 p_monto in number,
 p_mto_equiv in number,
 p_cod_tip_ope_bcp in varchar2 default null);
-- retorna la oficina de cambio de una oficina dada
FUNCTION FU_OBT_OFI_CAMBIO(p_cod_oficina in ba_oficinas.cod_oficina%type)
   return NUMBER;
/* Obtiene la cotizaci�n de venta de una moneda */
FUNCTION FU_OBT_COT_VENTA
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER;
/* Obtiene la cotizaci�n de compra de una moneda */
FUNCTION FU_OBT_COT_COMPRA
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN number;
/* Obtiene la cotizacion de compra cheque de una moneda */
FUNCTION FU_OBT_COT_COM_CHEQUE
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER;
/* Obtiene la cotizacion de venta cheque de una moneda */
FUNCTION FU_OBT_COT_VEN_CHEQUE
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER;
/* Inicializa la posici�n de cambios del d�a */
PROCEDURE PR_INI_DIA_POSICION;
/*Liberaci�n de retenci�n de los l�mites de cambios*/
PROCEDURE PR_LIB_RET_CAMBIOS
(p_fecha in date default null,
 p_nro_cuenta in varchar default null,
 p_anticipada in varchar2 default null,
 p_nro_boleta in varchar2 default null,
 p_tipo in varchar2 default null,
 p_clasificacion in varchar2 default null
 );
/*Inserta la retenci�n de los l�mites de cambios*/
PROCEDURE PR_INS_RET_CAMBIOS
(P_FECHA IN DATE DEFAULT NULL);
/*Obtiene los cargos de las operaciones de cambios*/
PROCEDURE PR_OBT_CARGOS
( p_cod_transaccion  in number,
  p_cod_modalidad in number,
  p_cod_moneda in varchar2,
  p_importe in number,
  p_imp_equivalente in number,
  p_cod_oficina in number,
  p_nro_cuenta in varchar2,
  p_cod_persona in varchar2,
  p_descripcion  IN OUT VARCHAR2,
  p_mto_cargo in out number,
  p_cod_tasa in out number,
  p_val_tasa in out number);
/*Obtiene los impuestos de los cargos de las operaciones de cambios*/
PROCEDURE PR_OBT_IMPUESTOS
  (p_cod_transaccion in number,
   p_cod_modalidad in number,
   p_monto in number,
   p_cod_oficina in number,
   p_tra_impuesto in out number,
   p_impuesto in out number,
   p_cod_tasa in out number,
   p_val_tasa in out number,
   p_cod_moneda in varchar2 default null,
   p_cod_persona in varchar2 default null);
-- devuelve el codigo de retencion valido para un tipo de operacion
function FU_OBT_COD_RETENCION(p_cod_tip_operacion in varchar2,
                              p_cod_banco in number)
return number;
-- proc. para obtener el codigo y fin de retencion
procedure PR_OBT_REtencion(p_cod_tip_operacion in varchar2,
                           p_cod_banco in number,
                           p_nro_cuenta   in varchar2,
                           p_cod_moneda in varchar2,
                           p_cod_ofi_origen in number,
                           p_cod_retencion out number,
                           p_fec_fin_retencion out date);
/* Convertir un monto de una moneda a otra */
FUNCTION FU_CON_MON_A_MONEDA
 (P_COD_MON_ORIGINAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_MON_ORIGINAL IN NUMBER
 ,P_COT_MON_ORIGINAL IN NUMBER default null
 )
 RETURN NUMBER;
/*Inserta la retenci�n de los l�mites de cambios on line*/
PROCEDURE PR_INS_LC_RETENCIONES
(P_LIMITE IN LC_RETENCIONES%ROWTYPE);
/*Libera retencion de Cheques de Cambios*/
PROCEDURE PR_LIB_RET_CAM_CHEQUES
(
p_nro_cuenta in varchar2,
p_nro_boleta in varchar2,
p_mensaje in out varchar2);

 /*genera el movimiento y actualizacion de saldo de una cuenta y muestra coomo salida el mensaje y codigo error*/
PROCEDURE PR_ACT_OPERACION_CON_SALIDA (
     P_FECHA     IN GE_MOVIMIENTOS.FECHA%TYPE DEFAULT NULL
    ,P_HORA      IN GE_MOVIMIENTOS.HORA%TYPE  DEFAULT NULL
    ,P_USUARIO   IN GE_MOVIMIENTOS.COD_USUARIO%TYPE DEFAULT NULL
    ,P_NRO_CUENTA IN GE_MOVIMIENTOS.NRO_CUENTA%TYPE
    ,P_TIP_MOVIMIENTO IN VARCHAR2
    ,P_COD_MONEDA IN GE_MOVIMIENTOS.COD_MONEDA%TYPE
    ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
    ,P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
    ,P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
    ,P_REFERENCIA IN GE_MOVIMIENTOS.REFERENCIA%TYPE
    ,P_COTIZACION IN GE_MOVIMIENTOS.COTIZACION%TYPE
    ,P_COD_MOD_PADRE IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE
    ,P_COD_MAD_PADRE IN GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE
    ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
    ,P_NRO_SECUENCIA IN GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
    ,P_MTO_EQU_LOCAL IN GE_MOVIMIENTOS.MTO_EQU_LOCAL%TYPE DEFAULT NULL
    ,P_NRO_DOCUMENTO IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE DEFAULT NULL
    ,P_COD_ERROR     OUT NUMBER
    ,P_MSG_ERROR     OUT VARCHAR2
    ,P_RES_FECHA     OUT GE_MOVIMIENTOS.FECHA%TYPE
    ,P_RES_HORA      OUT GE_MOVIMIENTOS.HORA%TYPE
    ,P_RES_SECUENCIA OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
    ,P_RES_USUARIO   OUT GE_MOVIMIENTOS.COD_USUARIO%TYPE
    ,P_RES_NRO_DOCUMENTO OUT GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE );

end PAL_CAM;
/

