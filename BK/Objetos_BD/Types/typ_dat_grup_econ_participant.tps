CREATE OR REPLACE TYPE IT."TYP_DAT_GRUP_ECON_PARTICIPANT"                                          force IS OBJECT
(
  documentTypeId   varchar2(3),  -- codigo de tipo de documento
  documentTypeName varchar2(4), -- abretiatura de descripcion de tipo de documento
  documentNumber   varchar2(20), -- nro de documento
  codPersona       varchar2(10),  -- codigo de persona
  CONSTRUCTOR FUNCTION TYP_DAT_GRUP_ECON_PARTICIPANT RETURN SELF AS RESULT
)
/

