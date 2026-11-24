CREATE OR REPLACE TYPE IT."TYP_DATOSTASAS"                                          IS OBJECT(
-- Indica si es un mensaje de error
error VARCHAR2(1),
-- Nombre de la respuesta
nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
descripcionRespuesta VARCHAR2(200),
-- Cantidad de datos de retorno
cantDatos NUMBER(3),
-- Monto límite para comisión fija
mtoLimComision NUMBER(18,2),
-- Comisión fija
mtoComision NUMBER(18,2),
-- Porcentaje de comisión
porComision NUMBER(18,2),
-- Lista de datos
listaDatosTasas typ_listaTasasAdelanto, CONSTRUCTOR FUNCTION typ_datosTasas RETURN SELF AS result)
/

