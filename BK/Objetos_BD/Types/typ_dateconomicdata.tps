CREATE OR REPLACE TYPE IT."TYP_DATECONOMICDATA"                                          IS OBJECT
(
  idActividadEco      varchar2(6), -- cod rubro primario
  actividadEco        varchar2(60),

   error                   VARCHAR2(1),   -- Indica si la respuesta es de error o no
   nombreRespuesta         VARCHAR2(15),  -- Codigo de respuesta
   descripcionRespuesta    VARCHAR2(200), -- Descripcion del codigo de respuesta
   
   CONSTRUCTOR FUNCTION TYP_DATECONOMICDATA RETURN SELF AS result
)
/

