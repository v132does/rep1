CREATE OR REPLACE TYPE IT."TYP_PERMISOUSUARIO"                                          FORCE is OBJECT
(
-- Codigo Mensaje
  codigoMensaje      VARCHAR2(3),
-- Descripcion Mensaje
  descripcionMensaje VARCHAR2(60),
-- Permiso para registra
  consulta           VARCHAR2(1),
-- Permiso para registra
  ingresa            VARCHAR2(1),
-- Permiso para registra
  autoriza           VARCHAR2(1),
  canAutRequeridas   NUMBER,
  CONSTRUCTOR FUNCTION typ_permisoUsuario RETURN SELF AS RESULT
)
/

