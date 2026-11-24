CREATE OR REPLACE TYPE IT."TYP_COMPROBANTEMOVIMIENTO"                                          force as OBJECT
( --  Indica si ocurrio un error 
  error                 varchar2(1),
  --  Nombre de la respuesta 
  nombreRespuesta       varchar2(15),
 -- Mensaje de la respuesta
  descripcionRespuesta  varchar2(200),
 -- Descripcion del tipo de mensaje o movimiento  
  descripcionMovimiento  varchar2(100),
 --  Numero de la cuenta  
  nroCuenta varchar2(17),
  --  Tipo de la cuenta 
  tipoCuenta varchar2(2),
   -- Descripcion del tipo de cuenta
  descTipoCuenta varchar2(35),
 -- Denominacion de la cuenta  
  denominacion varchar2(70),
 -- Moneda de la cuenta  
  codMoneda varchar2(16),
 --Descripcion de la oficina  Origen
  oficinaOrigen varchar2(35),
 --Descripcion de la oficina  Destino
  oficinaDestino varchar2(35),
 --Fecha del comprobante
  fecha varchar2(8),
 --Hora del comprobante  
  hora varchar2(8),
 -- Monto de la operacion  
  monto varchar2(16),
 --Codigo del banco (opcional)  
  codigoBanco number(3),
 -- nroCaja Numero de Caja de la operacion
  nroCaja number(3),
 -- Concepto Descripcion del pago
  concepto varchar2(100),
 -- Referencia Facturas
 referenciaFacturas varchar2(300),
 --
 codigoModulo number (3),
 codigoModalidad number (3),
 -- cantDetalles Cantidad de detalles del comprobante
  cantDetalles number(3),
 -- codigo datos 1 
  codigoDato1 varchar2(20),
  --datoa 1
  dato1 varchar2(20),
  
    
  -- tipo si es transferencia interbancaria mas enviada/recibida
  tipoDetalle varchar2(4),
  
 -- Banco Remitente, Destino 
  bancoDetalle varchar2(200),
  
  -- Nombre Remitente, Destino  
  nombreDetalle varchar2(200),
  
  -- Cuenta Remitente , Destino 
  cuentaDetalle varchar2(100), 
  
  
 -- detallesMovimiento Detalles del movimiento
  detallesMovimiento typ_listaComprobanteDetalleMov,
-- Nro Cuenta origen
   nro_cta_origen VARCHAR2(35),
-- Nro Cuenta destino
   nro_cta_destino VARCHAR2(35),
-- Banco Orgigen
   banco_origen VARCHAR2(40),
-- Banco Destino
   banco_destino VARCHAR2(40),
-- Persona Orgigen
   nombre_origen VARCHAR2(120),
-- Persona Destino
   nombre_destino VARCHAR2(120),
   nro_doc_solicitante          VARCHAR2(20),
   nro_doc_beneficiario         VARCHAR2(20),
      CONSTRUCTOR FUNCTION TYP_COMPROBANTEMOVIMIENTO RETURN SELF AS RESULT
)
/

