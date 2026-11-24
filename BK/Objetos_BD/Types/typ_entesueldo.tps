CREATE OR REPLACE TYPE IT."TYP_ENTESUELDO"                                          FORCE AS OBJECT
(
 codigoEnte      NUMBER(5),      -- Código de Ente.
 descripcion     VARCHAR2(60),   -- Descripción del ente
 codigoPersona   VARCHAR2(10),   -- Código de la Persona Relacionada.
 tipo            VARCHAR2(2),    -- Tipo de Ente (Seguro, Concesionario, Pago de Sueldos, Pago a Proveedores, etc.).
 moneda          VARCHAR2(5),    -- Moneda
   CONSTRUCTOR FUNCTION typ_enteSueldo RETURN SELF AS RESULT
)
/

