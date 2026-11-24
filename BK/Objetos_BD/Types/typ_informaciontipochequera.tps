CREATE OR REPLACE TYPE IT."TYP_INFORMACIONTIPOCHEQUERA"                                          IS OBJECT
(
-- Código del tipo de chequera
   codigoTipoChequera VARCHAR2(3),
-- descripción del tipo de chequera    
   descripcion VARCHAR2(35),
-- Cantidad de cheques q acepta el tipo de chequera    
   cantidadCheques VARCHAR2(60),
--  Tipo de chequera <ul><li><b>D:</b>Diferido</li><li><b>V:</b>Vista</li></ul>    
   tipo VARCHAR2(1),
--Cantidad máxima que puede ser solicitada    
   cantidadMaxima NUMBER(5),
--codigoMoneda Moneda a la que se aplica, si es nulo a todos
   codigoMoneda VARCHAR2(3),
--codigoTransaccion Código de transacción
   codigoTransaccion NUMBER(4),
   CONSTRUCTOR FUNCTION typ_informacionTipoChequera RETURN SELF AS result
)
/

