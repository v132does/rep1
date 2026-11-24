CREATE OR REPLACE TYPE IT."TYP_DETALLECANCELACIONSNP"                                          force IS OBJECT
(

   numeroReferencia         NUMBER(15),
   numeroSecuenciaLote      VARCHAR2(20),
   fechaValor               DATE,
   numeroCuentaBeneficiario VARCHAR2(35),
   nombreBeneficiario       VARCHAR2(120),
   entidad                  VARCHAR2(60),
   moneda                   VARCHAR2(35),
   monto                    NUMBER(18, 2),
   CONSTRUCTOR FUNCTION typ_detallecancelacionsnp RETURN SELF AS result
)
/

