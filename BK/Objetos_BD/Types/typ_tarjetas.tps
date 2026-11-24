CREATE OR REPLACE TYPE IT."TYP_TARJETAS"                                          FORCE IS OBJECT
(
-- Número de Tarjeta
   numeroTarjeta VARCHAR2(16),
--Descripcion de la Operación
   descripcion VARCHAR2(150),
--Fecha de la Operación
   fechaOperacion VARCHAR2(8),
-- Importe de la operación
   importe NUMBER(18),
-- Impuesto de la Operación
   impuesto NUMBER(18),
-- Tipo de Movimiento
   tipoMovimiento VARCHAR(1),

   CONSTRUCTOR FUNCTION typ_tarjetas RETURN SELF AS result
)
/

