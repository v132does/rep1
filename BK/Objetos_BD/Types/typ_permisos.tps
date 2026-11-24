CREATE OR REPLACE TYPE IT."TYP_PERMISOS"                                          as object
(
-- Author  : XPY0040
-- Created : 4/17/2019 5:39:30 PM
-- Purpose : 
/**
   * Guarda los permisos de un usuario para una persona juridica
   * @param error Indica si ocurrio un error recuperando la clave del usuario
   * @param nombreRespuesta Indica el nombre del mensaje
   * @param descripcionRespuesta Indica una descripcion de la respuesta
   * @param autoriza Indica si la persona tiene el permiso para autorizar operaciones(A)
   * @param registra Indica si la persona tiene el permiso para registrar operaciones(I)
   * @param consulta Indica si la persona tiene el permiso para registrar consultar()
   */
-- Attributes
  error                VARCHAR(1),
  nombreRespuesta      VARCHAR2(15),
  descripcionRespuesta VARCHAR2(200),
  autoriza             varchar2(1),
  registra             varchar2(1),
  consulta             varchar2(1),
  canAutRequeridas     NUMBER,

-- Member functions and procedures
  CONSTRUCTOR FUNCTION typ_permisos RETURN SELF AS RESULT
)
;
/

