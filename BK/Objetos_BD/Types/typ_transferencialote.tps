CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIALOTE"                                          FORCE IS OBJECT
(
  -- Author  : XPY0040
  -- Created : 26/09/2018 10:59:23 a.m.
  -- Purpose : Retorno de una solicitud de transferencia
  
  --Resultado de la consulta
  error                 VARCHAR2(1),
  --Codigo del resultado
  nombreRespuesta       VARCHAR2(15),
  --Descripcion del resultado
  descripcionRespuesta  VARCHAR2(200),
  -- Respuesta de limites de operaciones
  resLimite             VARCHAR2(2),
  --Agrupados del lote
  NumeroLote            NUMBER(10),
  -- Codigo de persona beneficiaris
  CodigoPersona         VARCHAR2(10),
  -- Numero de cuenta debito
  NumeroCuenta          VARCHAR2(15),
  -- Codigo de moneda del debito
  CodigoMoneda          VARCHAR(3),
  -- Monto del debito
  Monto                 NUMBER(18, 2),
  -- Fecha de pago
  FechaPago             DATE,
  -- Numero de cuenta credito
  NroCuentaCredito      VARCHAR2(16),
  -- Codigo swift de banco de la cuenta credito
  CodigoBanco           VARCHAR2(20),
  -- Numero de documento del beneficiario
  NumeroDocBeneficiario VARCHAR2(20),
  -- Tipo de documento del documento del beneficiario
  CodigoDocBeneficiario number(3),
  -- Nombre del beneficiario
  NombreBeneficiario    VARCHAR2(120),

  -- Codigo de la moneda de la cuenta credito
  CodigoMonedaCredito   VARCHAR2(3),
  MontoCredito          number(18,2),
  -- Concepto de la transferencia
  Concepto              VARCHAR2(100),
  /*
   Estado de la transferencia: <br/>
   <li>
   <ul> <b>N:</b> Nuevo.</ul>
   <ul> <b>E:</b> Error.</ul>
   <ul> <b>P:</b> Pagado.</ul>
   <ul> <b>A:</b> Agendado.</ul>
  */
  CodigoEstado          VARCHAR2(1),
  -- Numero de referencia de la transferencia
  NroReferencia         NUMBER(15),
  /*
   Tipo de la transferencia: <br/>
   <li>
   <ul> <b>E:</b> Envios (instruidos por el cliente logueado).</ul>
   <ul> <b>S:</b> Solicitados  (solicitados por el cliente logueado).</ul>
   <ul> <b>P:</b> Pedidos  (solicitados por otros clientes).</ul>
  */
  Tipo                  VARCHAR2(1),
  -- cotizacion para el debito
  cotizacionDebito      NUMBER(14,8),
  -- cotizacion para el credito
  cotizacionCredito     NUMBER(14,8),
  -- numero documento de operacion
  nroDocumento          NUMBER(15),
  nombreBcoDestino      VARCHAR2(120),
  nombreCuentaDebito    VARCHAR2(100),
  prioridad             VARCHAR2(3),
  tipoCargo             VARCHAR2(3),
  CONSTRUCTOR FUNCTION typ_transferencialote RETURN SELF AS RESULT
)
/

