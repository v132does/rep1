CREATE OR REPLACE TYPE IT."TYP_CONSOLICITUD"                                          AS OBJECT
(
   codigoerror          NUMBER(3),                        --Codigo de error
   nombrerespuesta      VARCHAR2(100),                    --Nombre de error
   descripcionrespuesta VARCHAR2(200),                    --Descripcion de error
   --cantidadDetalles     VARCHAR2(3),                      --Cantidad de detalles
   nroSolicitud         NUMBER(7),                        --Nro de la Solicitud
   descripcion          VARCHAR2(35),                      --Descripcion
   monto                NUMBER(18,2),                     --Monto del prestamo
   diaPlazo             NUMBER(4),                        --Plazo en dias
   fecVencimiento       DATE,                             --Fecha de Vencimiento
   codPersona           VARCHAR2(10),                     --Codigo de Persona
   fecInicio            DATE,                             --Fecha de la Solicitud
   totPrestamo          NUMBER(18,2),                     --Monto total del prestamo
   codModulo            NUMBER(3),                        --Codigo de Modulo
   codModalidad         NUMBER(3),                        --Codigo de Modalidad
   desModalidad         VARCHAR2(35),                     -- Descripcion de Modalidad
   codMoneda            VARCHAR2(3),                      --Codigo de Moneda
   codOficina           NUMBER(3),                        --Codigo de oficina
   fecPriVencimiento    DATE,                             --Fecha de primer vencimiento
   valTasa              NUMBER(20,4),                     --Tasa de interes
   canCuotas            NUMBER(6),                        --Cantidad de cuotas
   totCargos            NUMBER(18,2),                     --Total cargos
   totInteres           NUMBER(18,2),                     --Total interes
   --listaconcargos       typ_listaconcargo        ,                --Detalles de Cuotas
   CONSTRUCTOR FUNCTION typ_consolicitud RETURN SELF AS RESULT
)
/

