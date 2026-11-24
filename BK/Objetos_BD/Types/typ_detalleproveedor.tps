CREATE OR REPLACE TYPE IT."TYP_DETALLEPROVEEDOR"                                          FORCE is OBJECT
(
  error                 varchar2(10),
  mensajeRespuesta      varchar2(300),
-- Numero de orden
  numeroOrden          NUMBER(12),
-- Numero de factura
  numeroFactura        VARCHAR2(20),
-- Forma de pago  C-Credito en cuenta, G-Cheque de Gerencia, I-Transferencia SIPAP
  formaPago            VARCHAR2(1),
-- Fecha del pago
  fechaPago            DATE,
-- Numero de comprobante
  numeroComprobante    VARCHAR2(15),
-- Numero de cuenta
  numeroCuentaCredito  VARCHAR2(15),
-- Monto credito
  montoCredito         NUMBER(18,2),
-- Titular de la cuenta
  nombreBeneficiario   VARCHAR2(60),
-- Codigo Moneda
  codigoMoneda         VARCHAR2(3),
-- Concepto de la operacion
  concepto             VARCHAR2(40),
-- Codigo de la operacion
  codigoProceso        VARCHAR2(3),
-- Referencia Facturas
  referenciaFacturas   VARCHAR2(300),
-- entidad beneficiaria
  numeroBanco          VARCHAR2(5),
-- nombre entidad beneficiaria
  descripcionBanco     VARCHAR2(60),
-- tipo de documento del beneficiario
  tipoDocumento        VARCHAR2(3),
-- numero documento del beneficiario SIPAP
  numeroDocumento      VARCHAR2(20),
-- tipo MT SIPAP : 'A' - Alta, 'B' - Baja
  tipoMT               VARCHAR2(1),
-- numero de cuenta sipap beneficiario
  numeroCuentaBeneficiario  VARCHAR2(35),
-- contrato prepactado
  numeroContrato       VARCHAR2(7),
-- mail beneficiario
  mailBeneficiario     VARCHAR2(80),
  -- codigo Swift de la Entidad
   codigoSwift         VARCHAR2(20),
-- estado
   estado_transferencia VARCHAR2(35),
-- situacion
   situacion_transferencia VARCHAR2(35),
  CONSTRUCTOR FUNCTION typ_detalleProveedor RETURN SELF AS RESULT
)
/

