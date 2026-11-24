CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIASNP"                                          FORCE IS OBJECT
(
-- Tipo
  tipo VARCHAR2(2),
-- Número de Referencia
  numeroReferencia NUMBER(15),
-- Valor utilizado para identificar los registros insertados en un lote de procesamiento
  numeroLote VARCHAR2(20),
-- Fecha valor de la transferencias
  fechaValor VARCHAR2(8),
-- Número de Cuenta del Beneficiario
  numeroCtaBeneficiario VARCHAR2(35),
-- Nombre del Beneficiario
  nombreBeneficiario VARCHAR2(120),
-- Entidad
  entidad VARCHAR2(60),
-- Código de Moneda
  codigoMoneda VARCHAR2(3),
-- Monto
  monto NUMBER(18,2),
-- Situación del Mensaje.
  situacion VARCHAR2(30),
-- Estado de la Transferencia
  estado VARCHAR2(15),
-- Origen de la Transacción I = ITGF, H = Homebanking.
  origen VARCHAR2(1),
-- Fecha de Ingreso (carga) del Mensaje al Sistema.
  fechaIngreso VARCHAR2(8),
-- Cuenta de Referencia de la Transferencia (puede ser de la Entidad si es Emitida o Externa si es Recibida).
  numeroCtaSolicitante VARCHAR2(35),
-- Mensaje Swift
  mensajeSwift VARCHAR2(2000),

  CONSTRUCTOR FUNCTION typ_transferenciaSnp RETURN SELF AS result
)
/

