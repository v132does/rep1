CREATE OR REPLACE TYPE IT."TYP_RECAUDACIONES"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                 VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta       VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta  VARCHAR2(200),
--Cuenta a acreditar   
  numeroCuenta          VARCHAR2(15),
--Descripcion Cuenta Ahorro, cta. cte
  descripcionCuenta     VARCHAR2(35),
--Denominacion Cuenta
  denominacionCuenta    VARCHAR2(100),
--Moneda de la operacion
  codigoMoneda          VARCHAR2(3),
--Fecha de la operacion
  fechaOperacion        DATE,
--Codigo Ente
  codigoEnte            NUMBER(5),
--Respuesta de limite de operaciones
  respuestaLimite       VARCHAR2(2),
--Cantidad de firmas para autorizacion  
  cantidadAutorizadores NUMBER,
--Numero de documento de la operacion
  numeroDocumento       NUMBER(15),
--Tamaño de lista de cuentas  
  cantidadCuentas       NUMBER,
--Lista de cuentas a debitar
  listaCuentasDebito    typ_listaDetalleRecaudacion,
  CONSTRUCTOR FUNCTION typ_recaudaciones RETURN SELF AS RESULT
)
/

