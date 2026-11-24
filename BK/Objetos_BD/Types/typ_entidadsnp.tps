CREATE OR REPLACE TYPE IT."TYP_ENTIDADSNP"                                          FORCE IS OBJECT
(
-- Código Swift
  codigoSwift varchar2(20),
-- participante
  participante varchar2(60),
-- Cuenta en Guaranies
  ctaBcpGsLiquidacion varchar2(34),
-- Cuentas en Dolares
  ctaBcpUsdLiquidacion varchar2(34),

  CONSTRUCTOR FUNCTION typ_entidadSnp RETURN SELF AS RESULT
)
/

