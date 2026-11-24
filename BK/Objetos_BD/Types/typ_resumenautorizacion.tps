CREATE OR REPLACE TYPE IT."TYP_RESUMENAUTORIZACION"                                          FORCE IS OBJECT(
  numeroDocumento             VARCHAR2(15),  -- Número de Comprobante
  fecha                       VARCHAR2(20),  -- Fecha de la Operación
  descripcion                 VARCHAR2(35),  -- Descripción de la Operación
  numeroCuenta                VARCHAR2(17),  -- Número de Cuenta
  moneda                      VARCHAR2(3),   -- Moneda
  monto                       VARCHAR2(18),  -- Monto de la operación que requiere Autorización
  estado                      VARCHAR2(10),  -- Estado de la autorización: A: 'Anulada', C: 'Confirmada', P: 'Pendiente'
  autorizacionesRequeridas    VARCHAR2(3),   -- Numero de Autorizaciones Requeridas
  autorizacionesFaltantes     VARCHAR2(3),   -- Numero de Autorizaciones Faltantes
  CONSTRUCTOR FUNCTION typ_resumenAutorizacion RETURN SELF AS RESULT
)
/

