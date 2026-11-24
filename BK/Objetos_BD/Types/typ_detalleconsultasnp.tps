CREATE OR REPLACE TYPE IT."TYP_DETALLECONSULTASNP"                                          IS OBJECT
(
   --tipoMensaje         VARCHAR2(1),
   --terminal            VARCHAR2(3),
   --numeroOperacion     NUMBER(10),
   --clave               VARCHAR2(10),
   --modo                VARCHAR2(1),
   --fechaDesde          VARCHAR2(8),
   --fechaHasta          VARCHAR2(8),
   numeroReferencia    NUMBER(20),
   numeroLote          VARCHAR2(20),
   --codigoRespuesta     NUMBER(3),
   tipoMovimiento      VARCHAR2(1),
   fechaOperacion      VARCHAR2(10),
   --numeroCuenta        VARCHAR2(35),
   nombre              VARCHAR2(80),
   entidadFinanciera   VARCHAR2(60),
   moneda              VARCHAR2(30),
   monto               VARCHAR2(17),
   situacion           VARCHAR2(30),
   estado              VARCHAR2(100),
   numeroCuentaCredito VARCHAR2(35),
   numeroCuentaDebito  VARCHAR2(35),
   swiftEntidad        VARCHAR2(20),
   mensajeMt           VARCHAR2(2000),
   CONSTRUCTOR FUNCTION typ_detalleConsultaSnp RETURN SELF AS result
)
/

