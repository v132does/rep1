CREATE OR REPLACE TYPE IT."TYP_NOMBRETARJETA"                                          FORCE AS  OBJECT
(
  numeroTarjeta            VARCHAR2(25),  -- Nro de Tarjeta
  nombre                   VARCHAR2(26),  -- Nombre
  tipo                     VARCHAR2(1),  -- Tipo T-titular, A-adicional
  vigente                  VARCHAR2(1),  -- Vigente S, No vigente N
  CONSTRUCTOR FUNCTION typ_nombreTarjeta RETURN SELF AS RESULT
)
/

