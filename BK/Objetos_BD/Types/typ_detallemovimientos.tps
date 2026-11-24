CREATE OR REPLACE TYPE IT."TYP_DETALLEMOVIMIENTOS"                                          is OBJECT
(
--Indica si es un mensaje de error
  error varchar2(1),
--Nombre de la respuesta
  nombreRespuesta varchar2(15),
--Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
-- Cantidad de movimientos
  cantMovimientos NUMBER(8),
--Listado de movimientos
  listaMovimientos typ_listaMovimientos,
-- Cantidad de tarjetas
  cantidadTarjetas       NUMBER(8),
--Listado de los nombres de las tarjetas
  listaNombreTarjetas    typ_listaNombreTarjetas,
  CONSTRUCTOR FUNCTION typ_detalleMovimientos RETURN SELF AS RESULT
)
/

