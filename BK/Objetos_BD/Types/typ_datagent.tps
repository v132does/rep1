CREATE OR REPLACE TYPE IT."TYP_DATAGENT"                                          IS OBJECT
(
  codPersona      varchar2(10),
  tipoPersona     varchar2(1),
  idAgent         varchar2(10),
  firstName       varchar2(60),
  lastName        varchar2(60),
  email           varchar2(60),

   error                   VARCHAR2(1),   -- Indica si la respuesta es de error o no
   nombreRespuesta         VARCHAR2(15),  -- Codigo de respuesta
   descripcionRespuesta    VARCHAR2(200), -- Descripcion del codigo de respuesta
   
   CONSTRUCTOR FUNCTION TYP_DATAGENT RETURN SELF AS result
)
/

