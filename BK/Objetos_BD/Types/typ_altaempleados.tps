CREATE OR REPLACE TYPE IT."TYP_ALTAEMPLEADOS"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
--Tamaño de lista de empleados
  cantidadEmpleados    NUMBER,
--Numero de documento de proceso
  numeroDocumento      NUMBER(15),
--Cantidad de autorizadores
  cantidadAutorizadores NUMBER,
-- mail de notificacion para el ente
  emailNotificacion    VARCHAR2(100),
-- codigo de moneda
  codigoMoneda         VARCHAR2(3),
-- codigo de entidad de sueldo
  codigoEnte           NUMBER,
-- cuenta parametrizada de nomina
  numeroCuenta         VARCHAR2(15),
-- respuesta limite
  respuestaLimite      VARCHAR2(2),
--Lista de empleados
  listaEmpleados       typ_listaEmpleados,
  CONSTRUCTOR FUNCTION typ_altaEmpleados RETURN SELF AS RESULT
)
/

