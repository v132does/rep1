CREATE OR REPLACE TYPE IT."TYP_DETALLEORDTRA"                                          IS OBJECT
( nro_ord_transferencia  varchar2(50),
  nro_item number(18),
  nro_cta_beneficiario varchar2(35),
  denominacion varchar2(1000),
  cod_banco number(10),
  monto number(18,2),
  CONSTRUCTOR FUNCTION typ_detalleordtra RETURN SELF AS result
)
/

