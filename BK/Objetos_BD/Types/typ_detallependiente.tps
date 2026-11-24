CREATE OR REPLACE TYPE IT."TYP_DETALLEPENDIENTE"                                          FORCE is OBJECT
(
-- Numero de documento
  numeroDocumento          NUMBER(15),
-- fecha y hora del movimiento
  fechaHora                DATE,
-- Descripcion del movimiento
  descripcion              VARCHAR2(60),
-- Numero de cuenta a debitar
  numeroCuenta             VARCHAR2(17),
-- Codigo Moneda
  codigoMoneda             VARCHAR2(3),
-- Monto del movimiento
  monto                    NUMBER(18,2),
-- Estado del movimiento
  estado                   VARCHAR2(10),
-- Cantidad de firmas requeridas
  autorizacionesRequeridas NUMBER,
-- Cantidad de firmas faltantes
  autorizacionesFaltantes NUMBER,
  --modulo de la cuenta
  codModulo           NUMBER,
-- cantidad
  cantidad                  NUMBER,
  -- persona que registro la operacion
  perRegistro               VARCHAR2(200),
  -- codigo de la operacion
  codTipOperacion           VARCHAR2(3),
  -- campo etiqueta
  etiqueta                  VARCHAR2(50),
  -- campo dato
  dato                      VARCHAR2(50),
  -- campo etiqueta 2
  etiqueta2                 VARCHAR2(50),
  -- campo dato 2
  dato2                     VARCHAR2(50),
  -- tipo de pago
  tipPago                   VARCHAR2(1),
  -- tipo de cuenta debito
  tipoCuenta                VARCHAR2(50),
  datosCantidad             NUMBER,
  datosAdicionales     typ_listaClaveValor,
  CONSTRUCTOR FUNCTION typ_detallependiente RETURN SELF AS RESULT
)
/

