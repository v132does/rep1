CREATE OR REPLACE TYPE IT."TYP_REG_SNP_SWIFT"                                          as object
(
  plazo_de   VARCHAR2(10),
  plazo_a    VARCHAR2(10),
  moneda     VARCHAR2(5),
  fecha      DATE,
  monto      VARCHAR2(100)
)
/

