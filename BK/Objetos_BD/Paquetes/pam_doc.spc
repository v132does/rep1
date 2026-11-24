CREATE OR REPLACE PACKAGE IT.PAM_DOC is

-- Author  : GUSTAVO BENITEZ
-- Created : 30/01/2008 08:53:11 a.m.
-- Purpose : Package de Mesa de Dinero

	--Obtener datos de la operacion
	PROCEDURE PR_OBT_DATOS(P_NRO_CUENTA IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
								  RP_PDOCU     IN OUT MD_CTA_DOCUMENTOS%Rowtype);
	--Compra de los Documentos
	PROCEDURE PR_COM_DOCUMENTOS(P_NRO_CUENTA     IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
										 P_MTO_DESEMBOLSO IN MD_CTA_DOCUMENTOS.MONTO%Type,
										 P_COD_OFI_ORIGEN IN BA_OFICINAS.COD_OFICINA%TYPE,
										 P_MTO_GARANTIA   IN MD_GARANTIAS.MONTO%TYPE,
										 P_FECHA          IN DATE,
										 P_HORA           IN VARCHAR2,
										 P_NRO_SECUENCIA  IN OUT Varchar2);
	--Obtener el monto de venta del documento
	PROCEDURE PR_OBT_MTO_VENTA(P_NRO_CUENTA  IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
										P_MTO_COBRADO IN MD_CTA_DOCUMENTOS.SAL_VAL_PRESENTE%TYPE,
										P_TOT_CAPITAL IN OUT MD_CTA_DOCUMENTOS.SAL_VAL_PRESENTE%TYPE,
										P_TOT_INTERES IN OUT MD_CTA_DOCUMENTOS.SAL_INTERES%Type);
	--Realiza la venta del documento
	PROCEDURE PR_VTA_DOCUMENTO(P_NRO_CUENTA         IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
										P_MTO_COBRADO        IN MD_CTA_DOCUMENTOS.MONTO%TYPE,
										P_COD_OFI_ORIGEN     IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE,
										P_CONCEPTO           IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
										P_FECHA              IN GE_MOVIMIENTOS.FECHA%TYPE,
										P_HORA               IN OUT GE_MOVIMIENTOS.HORA%TYPE,
										P_NRO_SECUENCIA      IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%Type,
										P_COD_TRA_PADRE      IN NUMBER default 999,
										P_COD_MOD_PADRE      IN NUMBER,
										P_COD_MAD_PADRE      IN Number,
										P_MTO_GARANTIA       IN GE_MOVIMIENTOS.MONTO%TYPE Default Null,
										p_MTO_INTERES        IN NUMBER Default Null,
										p_MTO_INT_DESCONTADO IN NUMBER Default Null,
										P_MTO_IMPUESTO       IN NUMBER Default Null,
										P_MTO_CARGO          IN NUMBER Default Null,
										P_TAS_VENTA          In MD_CTA_DOCUMENTOS.VAL_TASA%Type Default Null,
										P_NRO_CUPON          IN NUMBER DEFAULT NULL,
                    P_EST_MOVIMIENTO     IN VARCHAR2 DEFAULT 'N');
	-- Obtener tasa efectiva y nominal del documento
	PROCEDURE PR_OBT_TAS_DOCUMENTO(P_NRO_CUENTA IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
											 P_VAL_TAE    IN OUT NUMBER,
											 P_VAL_TAN    IN OUT NUMBER);
	/* Recupera minima cuota vencida de la operacion */
	FUNCTION FU_OBT_MIN_CUO_VENCIDA(P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE,
											  P_FECHA      IN PR_CUOTAS.FEC_VENCIMIENTO%TYPE)
		RETURN NUMBER;
	/* Recupera MAXIMA cuota vencida de la operacion A LA FECHA*/
	FUNCTION FU_OBT_MAX_CUO_VENCIDA(P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE,
											  P_FECHA      IN PR_CUOTAS.FEC_VENCIMIENTO%TYPE)
		RETURN NUMBER;
	/* Devuelve si una operacion es activa o pasiva */
	FUNCTION FU_OBT_TIP_OPERACION(p_nro_cuenta in varchar2) return varchar2;
	/* pago de operaciones pasivas */
	PROCEDURE PR_PAG_OPERACION(p_nro_cuenta         in varchar2,
										p_NRO_CUO_DESDE      in number,
										p_NRO_CUO_HASTA      in number,
										p_MTO_A_PAGAR        in number,
										p_MTO_CAPITAL        in number,
										p_MTO_INTERES        in number,
										p_MTO_INT_DESCONTADO in number,
										p_MTO_INT_MORATORIO  IN NUMBER,
										P_MTO_IMPUESTO       IN NUMBER,
										P_MTO_CARGO          IN NUMBER,
										P_MTO_GARANTIA       IN NUMBER,
										p_cod_ofi_origen     in number,
										p_fecha              in date,
										p_hora               in varchar2,
										p_nro_secuencia      in out number);
	/* Realiza el pago automatico de prestamos AFD */
	PROCEDURE PR_PAG_OPERACION_AFD_AUTO (
		P_NRO_CUENTA       IN  MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
		P_COD_RUBRO_SIPAP  IN  CB_RUBROS.COD_RUBRO%TYPE,
		P_NRO_CUOTA        IN  NUMBER,
		P_COD_RESPUESTA    OUT VARCHAR2,
		P_MSJ_RESPUESTA    OUT VARCHAR2
	);
	--Realiza la confirmacion de prestamos y call money recibido
	PROCEDURE PR_CON_OPERACION(P_NRO_CUENTA     IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
										P_COD_OFI_ORIGEN IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE,
										P_CONCEPTO       IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
										P_FECHA          IN GE_MOVIMIENTOS.FECHA%TYPE,
										P_HORA           IN OUT GE_MOVIMIENTOS.HORA%TYPE,
										P_NRO_SECUENCIA  IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%Type,
										P_COD_TRA_PADRE  IN NUMBER default 999,
										P_COD_MOD_PADRE  IN NUMBER,
										P_COD_MAD_PADRE  IN Number);
	-- cambio de tasa
	PROCEDURE PR_CAM_TASA(p_nro_cuenta   VARCHAR2,
								 p_val_tasa_nva NUMBER,
								 P_fec_vigencia in date);
	-- Calcula el interes
	FUNCTION FU_CAL_INTERES
	 (P_FEC_INICIO IN MD_CTA_DOCUMENTOS.FEC_INICIO%TYPE
	 ,P_FEC_VENCIMIENTO IN MD_CTA_DOCUMENTOS.FEC_VENCIMIENTO%TYPE
	 ,P_MTO_CAPITAL IN MD_CTA_DOCUMENTOS.MONTO%TYPE
	 ,P_VAL_TASA IN PR_CTA_PRESTAMOS.VAL_TASA%TYPE
	 ,P_DIVISOR IN MD_CTA_DOCUMENTOS.DIA_ANO%TYPE
	 )
	 RETURN NUMBER;

  ---Proceso de Actualización de Operaciones REPO
  PROCEDURE PR_ACT_OPE_REPO(P_NRO_CUENTA     IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
                            P_ACCION         IN VARCHAR2,
                            P_NRO_SECUENCIA  IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE,
                            P_HORA           IN OUT GE_MOVIMIENTOS.HORA%TYPE);
  --- FIELDESK-159387 / MDD-128 — Reasignacion garantia FLI (venta documentos)
  FUNCTION fu_calc_disp(p_nro_cuenta IN md_cta_documentos.nro_cuenta%TYPE) RETURN NUMBER;
  FUNCTION fu_suma_fli_vigente(p_nro_cuenta    IN md_cta_documentos.nro_cuenta%TYPE,
                               p_nro_documento IN md_cta_documentos.nro_documento%TYPE DEFAULT NULL)
    RETURN NUMBER;
  --- sal_restringido ≤ monto
  FUNCTION fu_ok_rest_vs_monto(p_nro_cuenta IN md_cta_documentos.nro_cuenta%TYPE) RETURN VARCHAR2;
  FUNCTION fu_es_venta_documento(p_nro_cuenta IN md_cta_documentos.nro_cuenta%TYPE,
                                 p_nro_cupon  IN NUMBER DEFAULT NULL) RETURN BOOLEAN;
--- p_es_parcial='S': rest solo el faltante; FLI solo si tras A sigue sin DISP.
---                     remanente de rest (y FLI si no hace falta) queda en origen.
--- p_es_parcial='N' (default): limpia rest + FLI del origen (RFC I10).
  PROCEDURE pr_reasigna_reserva_fli(p_nro_cuenta    IN  md_cta_documentos.nro_cuenta%TYPE,
                                    p_monto_deseado IN  md_cta_documentos.monto%TYPE,
                                    p_cod_error     OUT NUMBER,
                                    p_des_error     OUT VARCHAR2,
                                    p_es_parcial    IN  VARCHAR2 DEFAULT 'N');
end PAM_DOC;
/

