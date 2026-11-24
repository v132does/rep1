CREATE OR REPLACE TYPE IT."TYP_OBTINFPENDIENTE"                                          AS OBJECT
(nro_referencia                                 VARCHAR2(33),
 nro_ref_externa                                VARCHAR2(33),
 cod_msj_mx                                     VARCHAR2(8),
 fecha                                          DATE,
 hora                                           VARCHAR2(8),
 tipo_limite                                    VARCHAR2(20),
 tipo_informe                                   VARCHAR2(20),
 nro_cta_solicitante                            VARCHAR2(35),
 cod_swi_solicitante                            VARCHAR2(20),
 cod_moneda                                     VARCHAR2(3),
 monto                                          NUMBER(18,2));
/

