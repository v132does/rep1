CREATE OR REPLACE TYPE it.typ_cta_garantia AS OBJECT (
   nro_cuenta         VARCHAR2(20),
   nro_garantia       NUMBER,
   cod_garantia       VARCHAR2(10),
   mto_aplicado       NUMBER,
   mto_apl_computable NUMBER,
   cod_persona        NUMBER,
   mto_riesgo         NUMBER);
