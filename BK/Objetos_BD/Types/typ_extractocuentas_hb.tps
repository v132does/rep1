CREATE OR REPLACE TYPE IT."TYP_EXTRACTOCUENTAS_HB"                                          force                                          IS OBJECT
(
   nroCuenta               VARCHAR2(20),
   descripcion             VARCHAR2(50),
   nroCuentaCombinada  VARCHAR2(20),
   tasaNominal    NUMBER(20,4),
   tasaEfectiva   NUMBER(20,4),
   fechaExtracto  DATE,
   saldoAnteriorContable   NUMBER(18, 2),
   saldoActualContable     NUMBER(18, 2),
   saldoActualBloqueado    NUMBER(18, 2),
   saldoAnteriorDisponible NUMBER(18, 2),
   saldoActualDisponible   NUMBER(18, 2),

   CONSTRUCTOR FUNCTION typ_extractoCuentas_hb RETURN SELF AS result
)
/

