CREATE OR REPLACE TYPE IT."TYP_ARC_SEGUROS"                                          IS OBJECT
(
--Indica si es un mensaje de Error
error VARCHAR2(1),
--Nombre de la Respuesta
nombreRespuesta VARCHAR2(15),
--Desripcion de la Respuesta
descripcionRespuesta VARCHAR2(200),
--Archivo BASE64
arc_base64 CLOB,
--Constructor del TYPE
CONSTRUCTOR FUNCTION typ_arc_seguros RETURN SELF AS RESULT
)
/

