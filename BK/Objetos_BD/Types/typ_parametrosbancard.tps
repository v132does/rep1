CREATE OR REPLACE TYPE IT."TYP_PARAMETROSBANCARD"                                          FORCE AS OBJECT
(
  error                VARCHAR2(1), --Indicador de error
  nombreRespuesta      VARCHAR2(15), --Nombre del mensaje
  descripcionRespuesta VARCHAR2(200), --Descripcin de la respuesta

  tipoOperacion number(1), -- indica la operación a enviar
                          --1- -Consulta de Saldo
                          -- 2- -Extracto al día
                          --3- -Ciclos de Extractos anteriores
                          -- 4- -Pago de Tarjeta de Crédito
                          --5- -Pagos vía Infonet Cobranzas
                          --6-  -Consulta Gral. Infonet Cob.
                          --7- -Préstamos Dinámicos

  tipoSolicitud VARCHAR2(1), --indica si los datos corresponden a desarrollo o produccion
                             --1 desarrollo -- 2 produccion

  contrasena    VARCHAR2(30),
  puerto        VARCHAR2(4),
  usuario       VARCHAR2(15),
  ipWebservices VARCHAR2(30),
  indSecure     VARCHAR2(1),
  server        VARCHAR2(30),

  CONSTRUCTOR FUNCTION typ_parametrosBancard RETURN SELF AS RESULT
)
/

