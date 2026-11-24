CREATE OR REPLACE TYPE IT."TYP_RESACREDITACIONES"                                          IS OBJECT(
   error                         VARCHAR2(1),               -- Indica si la respuesta es de error o no
   nombreRespuesta               VARCHAR2(15),              -- Codigo de respuesta
   descripcionRespuesta          VARCHAR2(200),             -- Descripcion del codigo de respuesta
   listaDatosAcreditaciones      typ_listaacreditaciones,   -- Lista de Datos de Acreditaciones
   listaMensajesAcreditaciones   typ_lismenacreditaciones,  -- Lista de mensajes a enviar en caso de Error
   CONSTRUCTOR FUNCTION typ_resacreditaciones RETURN SELF AS result
)
/

