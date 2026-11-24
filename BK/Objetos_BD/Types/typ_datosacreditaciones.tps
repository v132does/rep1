CREATE OR REPLACE TYPE IT."TYP_DATOSACREDITACIONES"                                          IS OBJECT
(
   cuentaDebito        VARCHAR2(15),   -- Numero de Cuenta de Debito.
   bancoDebito         NUMBER(3),      -- Codigo de Banco de Debito
   cuentaCredito       VARCHAR2(15),   -- Numero de Cuenta de Credito.
   bancoCredito        NUMBER(3),      -- Codigo de Banco de Credito
   tipoTransaccion     VARCHAR2(2),    -- Tipo de Transaccion
   tipoOperacion       VARCHAR2(2),    -- Tipo de Transaccion
   numeroBoleta        NUMBER(15),     -- Número de Boleta
   montoTransaccion    NUMBER(18,2),   -- Importe de la transaccion.
   moneda              VARCHAR2(2),    -- Moneda de la transaccion.
   nombreComercio      VARCHAR2(40),   -- Nombre del Comercio o Negocio.
   fechaTransaccion    DATE,           -- Fecha y Hora de la Transaccion. Formato Fecha y Hora
   tipoTarjeta         VARCHAR2(2),    -- Tipo de Tarjeta utilizada en la Operacion
   numeroLote          NUMBER(15),     -- Número de Lote para compensacion
   numeroBoletaExtorno NUMBER(15),     -- Número de Boleta a reversar
   numeroReferencia    NUMBER(15),     -- Número de referencia de la operacion confirmada
   CONSTRUCTOR FUNCTION TYP_DATOSACREDITACIONES RETURN SELF AS RESULT
)
/

