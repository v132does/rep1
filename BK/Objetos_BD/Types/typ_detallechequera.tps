CREATE OR REPLACE TYPE IT."TYP_DETALLECHEQUERA"                                          IS OBJECT
(
--Numero de cheque inicial
   inicio VARCHAR2(7),
-- Numero de fin del cheque
   fin VARCHAR2(7),
-- Numero de solicitud de la chequera
   solicitud VARCHAR2(8),
-- Descripcion de la chequera
   tipo VARCHAR2(20),
-- Descripcion de la chequera
   estado VARCHAR2(20),
--codigo Tipo de chequera, 1-25HVista, 250HVista, etc
   codigoTipoChequera VARCHAR2(1),
   CONSTRUCTOR FUNCTION typ_detalleChequera RETURN SELF AS result
)
/

