CREATE OR REPLACE TYPE IT."TYP_RESPUESTACONTRATOCAMBIO"                                          IS OBJECT
(
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   contratosCambio      typ_listaContratosCambio,
   CONSTRUCTOR FUNCTION typ_respuestaContratoCambio RETURN SELF AS result
)
/

