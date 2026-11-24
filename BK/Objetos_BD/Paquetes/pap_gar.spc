CREATE OR REPLACE PACKAGE IT.PAP_GAR IS
/* Obtener moneda de la línea. */
/* Verificar si el crédito posee linea y actualizar el mto aplicado. */
/* Verificar si el crédito posee garantia y actualizar el mto aplicado. */
/* Actualizar el mto aplicado de tipos de garantia por limite */
FUNCTION FU_OBT_MON_LINEA
 (P_NRO_LINEA IN PR_LINEAS.NRO_LINEA%TYPE
 )
 RETURN VARCHAR2;
FUNCTION FU_OBT_MON_GARANTIA
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE
 )
 RETURN VARCHAR2;
/* Obtener monto computable de la garantia */
FUNCTION FU_OBT_VAL_COMPUTABLE
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE
 )
 RETURN NUMBER;
/* Proceso que actualiza el monto aplicado por modalidad */
PROCEDURE PR_ACT_MAD_LIMITE
 (P_NRO_LINEA IN PR_LINEAS.NRO_LINEA%TYPE
 ,P_COD_GARANTIA IN PR_CTA_GARANTIAS.COD_GARANTIA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 );
/* Proceso que actualiza el monto aplicado del limite */
PROCEDURE PR_ACT_LIN_APLICADO
 (P_NRO_LINEA IN PR_CTA_PRESTAMOS.NRO_LINEA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 );
PROCEDURE PR_ACT_GAR_APLICADO
 (P_NRO_GARANTIA IN PR_CTA_GARANTIAS.NRO_GARANTIA%TYPE
 ,P_MON_PRESTAMO IN PR_CTA_PRESTAMOS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 );
/* Proceso que act. el monto aplicado de tipos de garantia por limite */
PROCEDURE PR_ACT_TIP_LIMITE
 (P_NRO_LINEA IN PR_LINEAS.NRO_LINEA%TYPE
 ,P_COD_GARANTIA IN PR_CTA_GARANTIAS.COD_GARANTIA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 );
/*Obtener datos de la garantía*/
PROCEDURE PR_OBT_DAT_GARANTIA
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE,
 P_MTO_APLICADO  IN OUT PR_GARANTIAS.MTO_APLICADO%TYPE,
 P_COD_MONEDA    IN OUT PR_GARANTIAS.COD_MONEDA%TYPE,
 P_TIPO          IN OUT PR_GARANTIAS.TIPO%TYPE,
 P_ESTADO        IN OUT PR_GARANTIAS.ESTADO%TYPE
 );
 /*Obtener monto de operaciones q cubre la garantía para, posteriormente, poder calcular el saldo*/
PROCEDURE PR_OBT_GAR_MONTOS
(p_nro_garantia in pr_garantias.nro_garantia%type
,p_mto_utilizado out pr_garantias.mto_aplicado%type
,p_mto_computable out pr_garantias.mto_aplicado%type
);
/*Obtener monto de operaciones q cubre la garantía para, posteriormente, poder calcular el saldo*/
/*Esto es por tipo de implementación*/
FUNCTION FU_OBT_MTO_OPE_GARANTIA
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE
 )
 RETURN NUMBER;

/*Actualizar el bloqueo de cash con el mayor vto. de préstamo o solicitud,
bloquear saldos, estados, generar movimientos.
Por confirmación y por reversión*/
PROCEDURE PR_PRO_GAR_CASH
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE,
 p_nro_cuenta    in PR_cta_prestamos.NRO_cuenta%TYPE,
 p_nro_solicitud in PR_solicitudes.NRO_solicitud%TYPE,
 p_fec_vencimiento in pr_cta_prestamos.fec_vencimiento%type,
 p_cod_modulo    in PR_cta_prestamos.cod_modulo%TYPE,
 p_cod_modalidad in PR_cta_prestamos.cod_modalidad%TYPE,
 p_cod_oficina   in PR_cta_prestamos.cod_oficina%TYPE,
 p_cod_moneda    in PR_cta_prestamos.cod_moneda%TYPE,
 p_mto_aplicado  in pr_sol_garantias.mto_aplicado%type,
 p_tipo          in varchar2 default 'C'
 );

/* Verificar la aplicacion de una operacion a una garantia */
procedure PR_VER_APL_GARANTIA(
  p_cod_garantia   in     pr_garantias.cod_garantia%type,
  p_nro_garantia   in     pr_garantias.nro_garantia%type,
  p_nro_cuenta     in     varchar2,
  p_cod_moneda     in     pr_garantias.cod_moneda%type,
  p_mto_aplicar    in     number,
  p_mto_computable in out number,
  p_mto_cubierto   in out number,
  p_msj_error      in out varchar2,
  p_nro_linea      in     number default null);

/* Actualizar el monto aplicado de las garantías de una operación */
procedure PR_ACT_APL_GARANTIA(
  p_nro_cuenta     in     varchar2,
  p_mto_aplicar    in     number,
  p_tipo           in     varchar2 default 'A',
  p_msj_error      in out varchar2);

/*Obtener cuenta o solicitud de operaciones relacionadas a la garantia */
FUNCTION FU_OBT_CTA_VIN_GARANTIAS (
  P_NRO_GARANTIA   IN PR_GARANTIAS.NRO_GARANTIA%type
 ,P_COD_GARANTIA IN PR_GARANTIAS.COD_GARANTIA%type)--DYDMR-10177, se agrega el parametro cod_garantia
  return varchar2;

/*Actualizar la Fecha de Firma de Escribania en la tabla de Garantías Hipotecarias y Prenda*/
PROCEDURE PR_ACT_FEC_FIR_ESCRIBANIA(P_NRO_GARANTIA      IN PR_GARANTIAS.NRO_GARANTIA%TYPE,
                                    P_FEC_FIR_ESCRITURA IN PR_GAR_HIPOTECARIAS.FEC_FIR_ESCRITURA%TYPE,
                                    P_NRO_FINCA         IN PR_GAR_HIPOTECARIAS.NRO_FINCA%TYPE,
                                    P_NRO_CONTRATO      IN PR_GAR_VEHICULOS.NRO_CONTRATO%TYPE);

/*Actualizar la Fecha de Inscripción en la tabla de Garantías Hipotecarias, Prenda y Warrants*/
PROCEDURE PR_ACT_FEC_INSCRIPCION(P_NRO_GARANTIA      IN PR_GARANTIAS.NRO_GARANTIA%TYPE,
                                 P_FEC_INSCRIPCION   IN PR_GAR_HIPOTECARIAS.FEC_INSCRIPCION%TYPE,
                                 P_NRO_FINCA         IN PR_GAR_HIPOTECARIAS.NRO_FINCA%TYPE,
                                 P_NRO_CONTRATO      IN PR_GAR_VEHICULOS.NRO_CONTRATO%TYPE,
                                 P_NRO_WARRANTS      IN PR_GAR_WARRANTS.NRO_WARRANTS%TYPE,
                                 P_NRO_CLAMERCA      IN PR_GAR_WARRANTS.CLA_MERCADERIA%TYPE);
END PAP_GAR;
/

