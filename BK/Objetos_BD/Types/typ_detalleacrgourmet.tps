CREATE OR REPLACE TYPE IT."TYP_DETALLEACRGOURMET"                                          is OBJECT
(
--Numero de factura
  numeroCuenta          VARCHAR2(20),
--Tipo de cuenta, D: debito, C:credito 
  tipo                  VARCHAR2(1),
-- Descripcion de la cuenta, Caja Ahorro, Cuenta corriente
  descripcionTipoCuenta VARCHAR2(35),
-- Titular de la cuenta
  nombreCuenta          VARCHAR2(50),
-- codigo Moneda
  codigoMoneda          VARCHAR2(3),
--Monto total del credito/debito  
  monto                 NUMBER(16,2),
--Si hubo error validando la cuenta: S-Si, N-No
  error                 VARCHAR2(1),
--Mensaje de la verificacion de la cuenta
  mensajeRespuesta      VARCHAR2(200),
--fecha de proceso 
  fecha                 DATE,
--numero documento de la cuenta
  numeroDocumento       VARCHAR2(20),
  CONSTRUCTOR FUNCTION TYP_DETALLEACRGOURMET RETURN SELF AS RESULT
)
/

