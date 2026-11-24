CREATE OR REPLACE TYPE IT."TYP_DETALLEFACTURA"                                          FORCE  is OBJECT
(--Cantidad de Items
  cantidad              NUMBER(18,2),
  
  codigoCanal           VARCHAR2(3),
  --Monto sin impuestos en la moneda de la operación
  montoExento           NUMBER(18,2),
  --Monto IVA 5%
  gravado5              NUMBER(18,2),
  --Monto IVA 10%
  gravado10             NUMBER(18,2),
  --Fecha de la operacion
  fecha                 DATE,
  --Documento de la operacion
  documento             VARCHAR2(18),
  --Numero de cuenta
  nroCuenta             VARCHAR2(18),
  --Descripcion de la operacion
  descripcion           VARCHAR2(100),
  --Moneda de la operación
  codMoneda             VARCHAR2(3),
  --Cotización de la operación
  cotizacion            NUMBER(18,2),
  --Monto sin impuestos en GS
  montoExentoGs         NUMBER(18,2),  

  CONSTRUCTOR FUNCTION typ_detalleFactura RETURN SELF AS RESULT
)
/

