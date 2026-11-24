CREATE OR REPLACE TYPE IT."TYP_PAGOSERVICIOS"                                          IS OBJECT
(
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   respuestaLimite      VARCHAR2(2),
   numeroSesion         VARCHAR2(32),
   numeroDocumento     VARCHAR2(15),--NVB-2232
   CONSTRUCTOR FUNCTION typ_pagoservicios RETURN SELF AS result
)
/

