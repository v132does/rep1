CREATE OR REPLACE TYPE IT."TYP_OBTTRANSRECIBIDO004"                                          AS OBJECT
 (nro_ref_externa                               VARCHAR2(33),
  fec_recepcion                                 DATE,
  msj_mx                                        VARCHAR2(4000),
  cod_msj_mx                                    VARCHAR2(20),
  nro_ref_msj_original                          VARCHAR2(33),
  cod_moneda                                    VARCHAR2(3),
  monto                                         NUMBER(18,2),
  fec_valor                                     DATE,
  cod_motivo                                    VARCHAR2(10),
  nro_ref_solicitud                             VARCHAR2(33),
  cod_tip_operacion                             VARCHAR2(3)
  )
/

