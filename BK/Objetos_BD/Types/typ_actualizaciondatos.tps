CREATE OR REPLACE TYPE IT."TYP_ACTUALIZACIONDATOS"                                          FORCE IS OBJECT
(
--email
  email VARCHAR2(80),
--Tipo de impresion de extracto. C-Impreso,  Z-x Mail,  N-No impreso ó Regional Web X-Envio x mail e impreso.
  tipoExtracto VARCHAR2(1),
--Oficina posee servicio de courrier
  esRetener VARCHAR2(1),
--Oficina Cliente
  oficinaCliente VARCHAR2(35),
--email extracto
  emailExtracto VARCHAR2(80),
--oficina del cliente tiene courrier
  indOficinaCurrier VARCHAR2(1),
--Lista de telefonos
  listaTelefonos typ_listaTelefonos,
--Lista de direcciones
  listaDirecciones typ_listaDirecciones,

  CONSTRUCTOR FUNCTION typ_actualizacionDatos RETURN SELF AS result
)
/

