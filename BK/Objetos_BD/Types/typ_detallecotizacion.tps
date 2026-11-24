CREATE OR REPLACE TYPE IT."TYP_DETALLECOTIZACION"                                          FORCE as OBJECT
  (
  -- Descripcion de la moneda
    moneda           varchar2(30),
    -- Cotizacion de la compra para banca electronica
    electronicaCompra varchar2(16),
    -- Cotizacion de la venta para banca electronica
    electronicaVenta  varchar2(16),
    -- Cotizacion de la compra de pizarra
    efectivoCompra    varchar2(16),
    -- Cotizacion de la venta de pizarra
    efectivoVenta     varchar2(16),
    -- Cotizacion de la compra de pizarra
    chequeCompra    varchar2(16),
    -- Cotizacion de la venta de pizarra
    chequeVenta     varchar2(16),
    -- Cotizacion de conversion
    conversion      varchar2(16),
      CONSTRUCTOR FUNCTION typ_detallecotizacion RETURN SELF AS RESULT
  )
/

