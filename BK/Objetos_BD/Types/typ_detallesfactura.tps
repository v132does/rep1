CREATE OR REPLACE TYPE IT."TYP_DETALLESFACTURA"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error varchar2(1),
--- Nombre de la respuesta
  nombreRespuesta varchar2(15),
-- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
--Numero de factura  
  nroFactura            varchar2(20),
-- Numero del timbrado  
  nroTimbrado           varchar2(20),
--Periodo de validez de la factura  
  validez               date,
--Fecha de inicio de la vigencia del timbrado de la factura
  fecIniTimFactura      date,
--Número de autorización del timbrado
  nroAutTimbrado        varchar2(20),   
--Fecha de la factura  
  fecha                 date,
--Periodo facturado  
  periodo               varchar2(35),
--Tipo de comprobante 
  tipoComprobante       varchar2(1),
--Tipo de venta  <ul><li><b>CR</b> Credito</li>  <li><b>CO</b> Contado</li></ul>
  tipoVenta             varchar2(2),
--Nro Ruc del emisor  
  nroRucEntidad         varchar2(15),
--Nro de RUC del cliente 
  nroRucCliente         varchar2(20),
--Nombre del emisor  
  nombreEntidad         varchar2(300),
--Nombre del CLiente  
  nombreCliente         varchar2(300),
--Direccion de la oficina asignada al cliente  
  direccionOficina      varchar2(200),
--Direccion de la oficina central de la entidad  
  direccionMatriz       varchar2(200),
--Direccion del cliente  
  direccionCliente      varchar2(200),
--Telefono del cliente  
  telefono              varchar2(50),
--Total sin impuesto  
  totalExento           number(18,2),
--Total grabado 5%  
  gravado5              number(18,2),
--Total grabado 5%  
  gravado10             number(18,2),
--Monto Total  
  totalVenta            number(18,2),
  desTotVenta           varchar2(300),
--Total Impuesto  5%
  impuesto5             number(18,2),
--Total Impuesto 10%
  impuesto10            number(18,2),
--Total IVA  
  totalIva              number(18,2),
--Nro factura referencia  
  nroFacturaRef         varchar2(20),
--Nro Timbrado referencia  
  nroTimbradoRef        varchar2(20),
--Tipo de impresion <ul><li>Original</li>  <li>Copia</ul>  
  tipoImpresion         varchar2(20),
--Tipo de operación V=Venta C=Compra
  tipoOperacion         varchar2(1),  
--Tipo de origen C=Cambios N=Normal
  tipOrigen             varchar2(1),    
--Código de moneda de la operación si es de divisas
  codMoneda             varchar2(3),
--Cotizacion en caso de operaciones de divisas
  cotizacion            number(18,2),
--imagen  logo reporte  
  imagenLogo            varchar2(200),
--Cantidad de listado  
  cantFacturas          number,
  --Listado de detalles
  listaDetallesFacturas         typ_listaDetalleFacturas ,

      CONSTRUCTOR FUNCTION TYP_DETALLESFACTURA RETURN SELF AS RESULT
)
/

