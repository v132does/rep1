CREATE OR REPLACE TYPE IT."TYP_EXTRACTORESUMENES"                                          IS OBJECT
(
   nroCuenta 	    VARCHAR2(20),
   tipoResumen    VARCHAR2(65),
   modalidad        VARCHAR2(100),
   codigoMoneda     VARCHAR2(3),
   fechaInicio      DATE,
   fechaVencimiento DATE,
   montoCapital     NUMBER(18, 2),
   montoInteres     NUMBER(18, 2),
   saldoDisponible  NUMBER(18, 2),
   CONSTRUCTOR FUNCTION typ_extractoResumenes RETURN SELF AS result
)
/

