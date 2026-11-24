CREATE OR REPLACE TYPE IT."TYP_RESPUESTAHISCOTIZACIONES"                                          IS OBJECT
(
   error                 VARCHAR2(1),
   nombreRespuesta       VARCHAR2(15),
   descripcionRespuesta  VARCHAR2(200),
   cantidad              NUMBER(3),
   historicoCotizaciones typ_listaHisCotizaciones,
   CONSTRUCTOR FUNCTION typ_respuestaHisCotizaciones RETURN SELF AS result
)
/

