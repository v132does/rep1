CREATE OR REPLACE TYPE IT."TYP_ADMINISTRACIONDATOS"                                          FORCE IS OBJECT
(
-- Indica si es un mensaje de error
  error VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
--email
  email VARCHAR2(80),
--Tipo extracto
  tipoExtracto VARCHAR2(1),
--oficina del cliente tiene courrier
  indOficinaCurrier VARCHAR2(1),
--Oficina Cliente
  oficinaCliente VARCHAR2(35),
--Oficina posee servicio de courrier
  esRetener VARCHAR2(1),
--Cantidad de detalles
  cantidad number,
--lista de telefonos
  listaTelefonos typ_listaTelefonos,
--lista de direcciones
  listaDirecciones typ_listaDirecciones,
  CONSTRUCTOR FUNCTION typ_administracionDatos RETURN SELF AS result
)
/

