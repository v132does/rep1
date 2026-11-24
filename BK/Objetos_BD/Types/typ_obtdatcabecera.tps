CREATE OR REPLACE TYPE IT."TYP_OBTDATCABECERA"                                          AS OBJECT
(nro_cab_version                           VARCHAR2(20),
 bic_solicitante                           VARCHAR2(500),
 bic_spi                                   VARCHAR2(500),
 ref_mensaje                               VARCHAR2(33),
 nro_ver_mensaje                           VARCHAR2(20),
 nro_ser_comercial                         VARCHAR2(500),
 cod_service                               VARCHAR2(500),
 cod_sender                                VARCHAR2(500),
 cod_receiver                              VARCHAR2(500),
 fecha                                     DATE,
 hora                                      VARCHAR2(15));
/

