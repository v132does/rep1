CREATE OR REPLACE TYPE IT."TYP_CLAVE_VALIDACION"                                          as object
(
  -- Author  : XPG0671
  -- Created : 29/8/2019 22:26:59
  
  -- Indica si es un mensaje de error
  error varchar2(1),
  -- Nombre de la respuesta
  nombreRespuesta varchar2(15),
  -- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
  
  tipoClaveValidacion varchar2(12),
  codigoTipoMEnsaje VARCHAR2(3),

  CONSTRUCTOR FUNCTION TYP_CLAVE_VALIDACION RETURN SELF AS RESULT
)
/

