CREATE OR REPLACE TYPE IT."TYP_EXTDNAXML"                                          IS OBJECT
( cod_banco  varchar2(4),
  fec_extracto varchar2(8),
  nro_cuenta varchar2(10),
  ext_xml clob,
  CONSTRUCTOR FUNCTION TYP_EXTDNAXML RETURN SELF AS result
)
/

