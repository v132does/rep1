CREATE OR REPLACE TYPE IT."TYP_GEOLOCALIZACIONESPRONET"                                          FORCE IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Código de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Cantidad de Bocas de Pago de Pronet
   cantGeolocalizaciones NUMBER(3),
-- Lista de Geolocalizaciones
   informacionGeolocalizaciones typ_listaGeolocalizacionPronet,
   CONSTRUCTOR FUNCTION typ_geolocalizacionesPronet RETURN SELF AS result
)
/

