CREATE OR REPLACE TYPE IT."TYP_KYCDATOS"                                          is OBJECT
(
-- Error S/N 
  error                    VARCHAR2(1),
-- Mensaje
  mensaje                  VARCHAR2(200),
-- Tipo de Documento
  tipoDocumento            VARCHAR2(10),
-- Fecha de Nacimiento
  fechaNacimiento          VARCHAR2(10),
-- País de Origen
  paisOrigen               VARCHAR2(60),
-- País de Residencia
  PaisResidencia           VARCHAR2(60),
-- Tipo de Iva
  tipIva                   VARCHAR2(20),
-- Fecha de Alta de la Persona
  fechaAlta                VARCHAR2(10),
-- Oficina del Cliente  
  oficinaCliente           VARCHAR2(60),
-- Oficina del Gestor
  oficinaGestor            VARCHAR2(60),
-- Actividad Primaria
  actividadPrimaria        VARCHAR2(100),
-- Estado Civil
  estadoCivil              VARCHAR2(100),
-- Ocupación 
  ocupacion               VARCHAR2(60),
-- Dirección Principal
  direccionPrincipal       VARCHAR2(500),
-- Lugar de Trabajo
  lugarTrabajo             VARCHAR2(100),
-- Monto Ingreso Laboral
  mtoIngreso               VARCHAR2(20),
-- Situación Laboral
  situacionLaboral         VARCHAR2(60),
-- Vínculos
  vinculos                 VARCHAR2(60),
-- Año Facturación
  anhoFacturacion          VARCHAR2(10),
-- Monto Facturación
  mtoFacturacion           VARCHAR2(20),
-- Moneda Acciones al Portador
  monAccionesPortador      VARCHAR2(10),
-- Cantidad de Transacciones de Débito
  canTransaccionesDebito   VARCHAR2(10),
-- Cantidad de Transacciones de Crédito
  canTransaccionesCredito  VARCHAR2(10),
-- Monto Promedio de Débito
  mtoPromedioDebito        VARCHAR2(20),
-- Monto Promedio de Crédito
  mtoPromedioCredito       VARCHAR2(20),
-- Fecha Actividad Esperadas
  fecActividaddesEsperadas VARCHAR2(10),
-- Indicador PEP
  indPep                   VARCHAR2(10),
-- Segmento Actividad
  segmentoActividad        VARCHAR2(100),
-- Capital Operativo
  capitalOperativo         VARCHAR2(20),
-- Razón Comercial
  razonComercial           VARCHAR2(100),
-- Ramo
  ramo                     VARCHAR2(100),
-- Fecha de Constitución
  fechaConstitucion        VARCHAR2(10),
-- Indicador de Importador o Exportador
  importaExporta           VARCHAR2(100),
-- Cantidad de Empleados
  cantidadEmpleados        VARCHAR2(10),
-- Cantidad de Socios
  cantidadSocios           VARCHAR2(10),
-- Cantidad de Sucursales
  cantidadSucursales       VARCHAR2(10),
-- Indicador de Acciones al Portador
  accionesAlPortador       VARCHAR2(10),
-- Capital Suscrito
  capitalSuscrito          VARCHAR2(20),
-- Capital Integrado
  capitalIntegrado         VARCHAR2(20),
-- Cantidad Acciones al Portador
  canAccionesPortador      VARCHAR2(10),
-- Url del Caso CRM
  urlCrm                   VARCHAR2(300),

  CONSTRUCTOR FUNCTION TYP_KYCDATOS RETURN SELF AS RESULT
)
/

