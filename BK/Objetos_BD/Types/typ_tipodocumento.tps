CREATE OR REPLACE TYPE IT."TYP_TIPODOCUMENTO"                                          FORCE IS OBJECT
(
--Codigo
  codigoTipoDocumento VARCHAR2(3),
--Descripcion
  descripcion VARCHAR2(60),
--Abreviatura
  abreviatura VARCHAR2(4),
--Tipo de persona
  tipoPersona VARCHAR2(1),
  CONSTRUCTOR FUNCTION typ_tipoDocumento RETURN SELF AS result
)
/

