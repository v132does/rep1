CREATE OR REPLACE TYPE IT."TYP_DETALLETARJETA"                                          force                                       is OBJECT
(
-- Nombre de la tarjeta
  nombreEmbozado       VARCHAR2(25),
-- Número de la tarjeta
  numeroTarjeta        VARCHAR2(25),
-- Fecha de Vencimiento
  fechaVencimiento     DATE,
-- Tipo de relación con la cuenta de la tarjeta
  tipoRelacion         VARCHAR2(1),
-- Código de la persona vinculada al plástico
  codPersona           VARCHAR2(10),
-- Número de cuenta de la tarjeta
  nroCuenta            VARCHAR2(15),
-- Tipo de tarjeta
  descripcion          VARCHAR2(80),
-- Afinidad de la tarjeta
  afinidad             VARCHAR2(240),
-- Moneda de la tarjeta
  codMoneda            VARCHAR2(3),
  CONSTRUCTOR FUNCTION typ_detalletarjeta RETURN SELF AS RESULT
)
/

