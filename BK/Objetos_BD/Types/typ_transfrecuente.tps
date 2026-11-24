CREATE OR REPLACE TYPE IT."TYP_TRANSFRECUENTE"                                          FORCE IS OBJECT
(
-- Número de Transferencia Frecuente
  numeroTransferencia number(10),
-- Número de Cuenta del Solicitante
  cuentaSolicitante varchar2(35),
-- Código de la Moneda
  codigoMoneda varchar2(3),
-- Monto de la Transferencias
  monto number(18),
-- Cuenta de Referencia de la Transferencia (puede ser de la Entidad si es Emitida o Externa si es Recibida).
  cuentaBeneficiario varchar2(35),
-- Nombre del Beneficiario
  nombreBeneficiario varchar2(100),
-- Dirección del Beneficiario
  direccionBeneficiario varchar2(100),
-- Tipo de Documento del Beneficiario
  tipoDocBeneficiario number(3),
-- Número Documento Beneficiario
  numeroDocBeneficario varchar2(20),

  CONSTRUCTOR FUNCTION typ_TransFrecuente RETURN SELF AS RESULT
)
/

