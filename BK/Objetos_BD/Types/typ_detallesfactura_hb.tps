CREATE OR REPLACE TYPE IT."TYP_DETALLESFACTURA_HB"                                          FORCE                                          AS OBJECT
(
  error                         VARCHAR2(1),                -- Indica si es un mensaje de error
  nombreRespuesta               VARCHAR2(15),               -- Nombre de la respuesta
  descripcionRespuesta          VARCHAR2(200),              -- Mensaje de la respuesta
  numeroFactura                 VARCHAR2(20),               -- Numero de factura
  numeroTimbrado                VARCHAR2(20),               -- Numero del timbrado
  validez                       VARCHAR2(40),               -- Periodo de validez de la factura
  fecha                         VARCHAR2(10),               -- Fecha de la factura
  periodo                       VARCHAR2(35),               -- Periodo facturado
  tipoComprobante               VARCHAR2(1),                -- Tipo de comprobante
  tipoVenta                     VARCHAR2(2),                -- Tipo de venta  CR: Credito CO: Contado
  numeroRucEntidad              VARCHAR2(15),               -- Nro Ruc del emisor
  numeroRucCliente              VARCHAR2(20),               -- Nro de RUC del cliente
  nombreEntidad                 VARCHAR2(120),              -- Nombre del emisor
  nombreCliente                 VARCHAR2(120),              -- Nombre del CLiente
  numeroCliente                 VARCHAR2(30),               -- Numero de CLiente
  direccionOficina              VARCHAR2(200),              -- Direccion de la oficina asignada al cliente
  direccionMatriz               VARCHAR2(200),              -- Direccion de la oficina central de la entidad
  direccionCliente              VARCHAR2(200),              -- Direccion del cliente
  telefono                      VARCHAR2(50),               -- Telefono del cliente
  totalExento                   NUMBER(18,2),               -- Total sin impuesto
  gravado5                      NUMBER(18,2),               -- Total grabado 5%
  gravado10                     NUMBER(18,2),               -- Total grabado 10%
  totalVenta                    NUMBER(18,2),               -- Monto Total
  descuentoTotalVenta           VARCHAR2(300),              -- Descuento Total: (mto_exento + mto_gravado_5 + mto_gravado_10 + impuesto_5 + impuesto_10) - des_tot_venta
  impuesto5                     NUMBER(18,2),               -- Total Impuesto  5%
  impuesto10                    NUMBER(18,2),               -- Total Impuesto 10%
  totalIva                      NUMBER(18,2),               -- Total IVA
  codigoMoneda                  VARCHAR(20),                 -- Código de Moneda
  numeroFacturaReferencia       VARCHAR2(20),               -- Nro factura referencia
  numeroTimbradoReferencia      VARCHAR2(20),               -- Nro Timbrado referencia
  tipoImpresion                 VARCHAR2(20),               -- Tipo de impresion: Original, Copia
  cantidadFacturas              NUMBER,                     -- Cantidad de listado
  listaDetallesFacturas         typ_listaDetalleFacturas_hb ,  -- Listado de detalles
  CONSTRUCTOR FUNCTION typ_detallesFactura_hb RETURN SELF AS RESULT
)
/

