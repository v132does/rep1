CREATE OR REPLACE TYPE IT."TYP_SALDODIARIO"                                          is OBJECT
(
-- Fecha del saldo
  fecha  date,
-- Monto del saldo  
  saldo  number(18,2),
-- Categoria de riesgo en la fecha del cierre  
  categoriaRiesgo  varchar2(1),
      CONSTRUCTOR FUNCTION typ_saldoDiario RETURN SELF AS RESULT
)
/

