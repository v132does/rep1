CREATE OR REPLACE TYPE IT.TYP_DETALLEDAS force      is OBJECT
(
tipoDocumento    varchar2(5), --tipo de documento del cliente CI , RUC, etc.
nroDocumento     varchar2(20), --Numero de documento del cliente
nombre           varchar2(120),
monto            number(18,2), --monto de la cuota
tipoCuenta       varchar2(5), --si la cuenta es AH o CC
nroCuenta        varchar2(15), --numero de la cuenta del cliente
descPlan         varchar2(100), -- desc. del plan
fecInicio        varchar2(20),
fecFin           varchar2(20),
error            VARCHAR2(1),
mensajeRespuesta VARCHAR2(200),

CONSTRUCTOR FUNCTION typ_detalledas RETURN SELF AS RESULT
)
/
