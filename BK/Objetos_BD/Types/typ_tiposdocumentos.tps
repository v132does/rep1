CREATE OR REPLACE TYPE IT."TYP_TIPOSDOCUMENTOS"                                          IS OBJECT
(
   -- Indica si es un mensaje de error
   error                VARCHAR2(1),
   -- Nombre de la respuesta
   nombreRespuesta      VARCHAR2(15),
   -- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
   -- Cantidad de datos de retorno
   cantidad             NUMBER(3),
   -- Lista de tipos de documentos
   listaTiposDocs   typ_listaConsultaDocumentos,
   CONSTRUCTOR FUNCTION typ_tiposdocumentos RETURN SELF AS result
)
/

