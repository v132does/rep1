CREATE OR REPLACE TYPE IT."TYP_DESCUOTA"                                          IS OBJECT
(
      NRO_CUOTA                      NUMBER(3),
      FEC_VTO_HABIL                  DATE,
      MTO_CAPITAL                    NUMBER(14),
      VAL_INTERES                    NUMBER(20,4),
      VAL_INT_ADELANTADO             NUMBER(20,4),
      FEC_VTO_EXACTO                 DATE,
      SAL_CAPITAL                    NUMBER(18,2),
      SAL_CAP_ANTERIOR               NUMBER(18,2),
      DIA_PERIODO                    NUMBER(6),
      DIA_TRANSCURRIDOS              NUMBER(6),
      DIA_INTERES                    NUMBER(6),
      TIP_CALCULO                    VARCHAR2(1),
      VAL_INT_ORIGINAL               NUMBER(20,4),
      VAL_CUOTA                      NUMBER(18,2),
      COD_BANCO                      NUMBER(3),
      NRO_CHEQUE                     NUMBER(15),
      CTA_LIBRADORA                  VARCHAR2(15),
      COD_MONEDA                     VARCHAR2(3),
      FEC_EMISION                    DATE,
      SAL_FIN_MES                    NUMBER(18,2),
      MTO_SEGURO                     NUMBER(18,2),
      MTO_IVA_SEGURO                 NUMBER(18,2),
      FEC_SEGURO                     DATE,
      MTO_IVA_INTERES                NUMBER(18,2),
      FEC_DEPOSITO                   DATE,
  CONSTRUCTOR FUNCTION typ_descuota RETURN SELF AS result
)

  alter type         "IT"."TYP_DESCUOTA" modify attribute mto_capital number(20,2) cascade
/

