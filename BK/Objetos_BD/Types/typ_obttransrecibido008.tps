CREATE OR REPLACE TYPE IT."TYP_OBTTRANSRECIBIDO008"                                          AS OBJECT
(nro_ref_externa                                VARCHAR2(33),
  fecha                                         DATE,
  hora                                          VARCHAR2(15),
  cod_msj_mx                                    VARCHAR2(20),
  msj_mx                                        VARCHAR2(4000),
  moneda                                        VARCHAR2(3),
  monto                                         NUMBER(18,2),
  fec_valor                                     DATE,
  nom_solicitante                               VARCHAR2(120),
  tip_doc_solicitante                           VARCHAR2(15),
  doc_solicitante                               VARCHAR2(20),
  cta_solicitante                               VARCHAR2(35),
  swi_participante_sol                          VARCHAR2(20),
  cta_participante_sol                          VARCHAR2(15),
  swi_participante_ben                          VARCHAR2(20),
  cta_participante_ben                          VARCHAR2(15),
  nom_beneficiario                              VARCHAR2(300),
  tip_doc_beneficiario                          VARCHAR2(15),
  doc_beneficiario                              VARCHAR2(20),
  cta_beneficiario                              VARCHAR2(35),
  concepto                                      VARCHAR2(140),
  cod_transaccion                               VARCHAR2(3),
  observacion                                   VARCHAR2(1000),
  ind_instruccion                               VARCHAR2(35),
  swi_sub_pte_solicitante                       VARCHAR2(20),--SPI Fase2
  cta_sub_pte_solicitante                       VARCHAR2(35),
  nro_ref_solicitud                             VARCHAR2(33)
  );
/

