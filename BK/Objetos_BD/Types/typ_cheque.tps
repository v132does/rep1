CREATE OR REPLACE TYPE IT."TYP_CHEQUE"                                          IS OBJECT
(
      NRO_CUOTA  NUMBER(3),
      COD_BANCO  NUMBER(3),
      CTA_LIBRADORA    VARCHAR2(20),
      NRO_CHEQUE       NUMBER(15),
      MONTO            NUMBER(18),
      FEC_EMISION      DATE,
      FEC_VENCIMIENTO  DATE,

  CONSTRUCTOR FUNCTION TYP_CHEQUE RETURN SELF AS result
)

  alter type         "IT"."TYP_CHEQUE" modify attribute monto number(20,2) cascade
/

