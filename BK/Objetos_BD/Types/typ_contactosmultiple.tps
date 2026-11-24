CREATE OR REPLACE TYPE IT."TYP_CONTACTOSMULTIPLE"                                          FORCE IS OBJECT
(
   nom_contacto     VARCHAR2(30),
   nro_contacto     VARCHAR2(20),
   cta_contacto     VARCHAR2(20),
   ori_contacto     VARCHAR2(1),
   ban_contacto     VARCHAR2(30),
   cod_swift        VARCHAR2(20),
   nro_documento    VARCHAR2(20),
   tip_documento    VARCHAR2(3),
   cod_moneda       VARCHAR2(3),
   tip_cuenta       VARCHAR2(35),
   mail             VARCHAR2(99),
   cod_per_contacto VARCHAR2(10),
   CONSTRUCTOR FUNCTION typ_contactosmultiple RETURN SELF AS RESULT
)
/

