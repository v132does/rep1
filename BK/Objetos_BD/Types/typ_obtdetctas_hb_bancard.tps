CREATE OR REPLACE TYPE IT."TYP_OBTDETCTAS_HB_BANCARD"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error varchar2(1),
-- Nombre de la respuesta
  nombreRespuesta varchar2(15),
-- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
--Cantidad de cuentas
  cantCuentas NUMBER(3),
-- Lista de cuentas
  listaCuentas typ_listdetcnta_hb_bancard,
  CONSTRUCTOR FUNCTION typ_obtdetctas_hb_bancard RETURN SELF AS RESULT
)
/

