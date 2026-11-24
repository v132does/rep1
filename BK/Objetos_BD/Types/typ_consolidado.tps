CREATE OR REPLACE TYPE IT."TYP_CONSOLIDADO"                                          IS OBJECT
(
   codigoresultado       VARCHAR2(3),
   descripcionresultado  VARCHAR2(100),
   periodo               VARCHAR2(6),
   codtipodocumento      VARCHAR2(3),
   numerodocumento       VARCHAR2(15),
   nrogpv                VARCHAR2(40),
   nombres               VARCHAR2(255),
   apellidos             VARCHAR2(60),
   fechanacimiento       VARCHAR2(8),
   tipovinculo           VARCHAR2(100),
   tipooperacion         VARCHAR2(3),
   desoperacion          VARCHAR2(100),
   codcuentasaldocapital VARCHAR2(18),
   codactividaddestino   VARCHAR2(6),
   region                VARCHAR2(100),
   codigomoneda          VARCHAR2(3),
   diasatraso            VARCHAR2(5),
   deudaactiva           VARCHAR2(18),
   deudavendida          VARCHAR2(18),
   deudaincobrable       VARCHAR2(18),
   deudafideicomiso      VARCHAR2(18),
   montocontingencia     VARCHAR2(18),
   montoprevision        VARCHAR2(18),
   clasificacionsistema  VARCHAR2(2),

   CONSTRUCTOR FUNCTION typ_consolidado RETURN SELF AS result
)
/

