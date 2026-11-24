CREATE OR REPLACE TYPE IT."TYP_PARAMETRIZACIONINICIALSNP"                                          FORCE IS OBJECT
(
--Indica si es un mensaje de error
  error varchar2(1),
--Código de la respuesta
  nombreRespuesta varchar2(15),
--Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
-- Listado de entidades
  listaEntidades typ_listaEntidadSnp,
-- Listado de Documentos
  listaDocumentos typ_listaDocumentoSnp,
-- Listado de Planillas
  listaPlanillas typ_listaPlanillaSnp,
--Listado de fechas habiles
  listaDiasHabiles typ_listaDiasHabiles,
--Listado de motivos Sipap
  listaMotivosSipap typ_listaMotivosSnp,
--Listado de Monedas
  listaMonedas typ_listaMonedas,
--Listado de Tipos de Transferencias
  listaTipoSipap typ_listaTipoSnp,
  CONSTRUCTOR FUNCTION typ_parametrizacionInicialSnp RETURN SELF AS RESULT
)
/

