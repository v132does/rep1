CREATE OR REPLACE TYPE IT."TYP_OBTSOLDEVPENDIENTE056"                                          AS OBJECT
 (nro_referencia                                VARCHAR2(33),
  fec_solicitud                                 DATE,
  hor_solicitud                                 VARCHAR2(15),
  swi_pte_sol_remitente                         VARCHAR2(20),
  swi_pte_sol_receptor                          VARCHAR2(20),
  nro_ref_msj_original                          VARCHAR2(33), ---ref del pacs008 original
  cod_msj_original                              VARCHAR2(20),--version del mensaje del pago original
  fec_msj_original                              DATE,
  hor_msj_original                              VARCHAR2(15),
  fec_valor_original                            DATE,
  cod_mot_devolucion                            VARCHAR2(8),
  des_mot_devolucion                            VARCHAR2(240),
  monto                                         NUMBER(18,2),
  tip_pte_remitente                             VARCHAR2(20),
  tip_pte_receptor                              VARCHAR2(20),
  CONSTRUCTOR FUNCTION TYP_OBTSOLDEVPENDIENTE056 RETURN SELF AS RESULT
  )
/

