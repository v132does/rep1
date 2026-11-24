CREATE OR REPLACE TYPE IT."TYP_PERMISOSUSUARIOS"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- Cantidad de usuarios vinculados
  cantidad             NUMBER,
-- lista de usuarios vinculados
  listaPermisos        typ_listaPermisoUsuario,
  CONSTRUCTOR FUNCTION typ_permisosUsuarios RETURN SELF AS RESULT
)
/

