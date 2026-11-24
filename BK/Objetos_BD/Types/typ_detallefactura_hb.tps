CREATE OR REPLACE TYPE IT."TYP_DETALLEFACTURA_HB"                                          FORCE AS OBJECT
(
  cantidad              NUMBER(4),            -- Cantidad de Items
  precioUnitario        NUMBER(18,2),         --Precio unitario
  codigoCanal           VARCHAR2(3),          -- Código de Canal
  montoExento           NUMBER(18,2),         -- Monto sin impuestos
  gravado5              NUMBER(18,2),         -- Monto IVA 5%
  gravado10             NUMBER(18,2),         -- Monto IVA 10%
  fecha                 VARCHAR2(10),         -- Fecha de la operacion
  documento             VARCHAR2(18),         -- Documento de la operacion
  numeroCuenta          VARCHAR2(18),         -- Número de Cuenta
  descripcion           VARCHAR2(30),         -- Descripción de la Operación
  CONSTRUCTOR FUNCTION typ_detalleFactura_hb RETURN SELF AS RESULT
)
/

