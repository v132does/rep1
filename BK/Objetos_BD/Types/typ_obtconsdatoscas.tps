CREATE OR REPLACE TYPE IT."TYP_OBTCONSDATOSCAS"                                          FORCE AS OBJECT
(nro_referencia                                  VARCHAR2(33),
tip_identificador                               VARCHAR2(10),
val_identificador                               VARCHAR2(80),
cod_persona										VARCHAR2(10),
tip_consulta                                    VARCHAR2(20),
fecha                                           DATE,
hora                                            VARCHAR2(8),
est_solicitud                                   VARCHAR2(1),
  CONSTRUCTOR FUNCTION TYP_OBTCONSDATOSCAS RETURN SELF AS RESULT
);
/

