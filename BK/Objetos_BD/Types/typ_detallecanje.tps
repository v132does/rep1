CREATE OR REPLACE TYPE IT."TYP_DETALLECANJE"                                          FORCE is object
(
-- Numero de la tarjeta
   nro_tarjeta VARCHAR2(25),
-- Puntos debitados
   puntos number,
-- Numero identificador del sub_canje de bw_canjes_det
   nro_canje NUMBER(12),
-- estado del sub_canje
   estado VARCHAR2(1),
      CONSTRUCTOR FUNCTION typ_detallecanje RETURN SELF AS RESULT
)
/

