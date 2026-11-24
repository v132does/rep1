CREATE OR REPLACE TYPE IT."TYP_AHOPROGRAMADO"                                          is OBJECT
(
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   concepto             VARCHAR2(100),
   codigoMoneda         VARCHAR2(3),
   montoSolicitado      NUMBER(18,2),
   montoOperacion       NUMBER(18,2),
   montoImpuestos       NUMBER(18, 2),
   cuentaDebito         VARCHAR2(15),
   cuentaCreada         VARCHAR2(15),
   -- M: Mensual, T: Total
   tipAhorro            VARCHAR2(60),
   interesMensual       NUMBER(20,4),
   totalCuotas          NUMBER(3),
   rangoFechaDebito     VARCHAR2(100),
   fechaVencimiento     DATE,
   listaMontos          typ_listapizarra,
   listaPlazos          typ_listapizarraplazos,
  CONSTRUCTOR FUNCTION TYP_AHOPROGRAMADO RETURN SELF AS RESULT
)
/

