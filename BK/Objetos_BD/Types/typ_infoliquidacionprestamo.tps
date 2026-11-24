CREATE OR REPLACE TYPE IT."TYP_INFOLIQUIDACIONPRESTAMO"                                          IS OBJECT
  (
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   cantidadCuotas       NUMBER,
   fec_desembolso       DATE,
   fech_pri_venc        DATE,
   nro_documento        VARCHAR2(30),
   moneda               VARCHAR2(35),
   dias_plazo           NUMBER,
   nro_solicitud        NUMBER,
   tasa_tan             NUMBER(20,4),
   tasa_tae             NUMBER(20,4),
   tasa                 NUMBER(20,4),
   total_desembolsar    NUMBER(18,2),
   total_desembolso     NUMBER(18,2),
   for_pago             VARCHAR2(50),
   imagenLogo           VARCHAR2(120),
   entidad              VARCHAR2(120),
   cantidadResumen      NUMBER,
   listaCuotas          typ_listaCuotaPrestamo,
   listaResumen         typ_listaetiquetavalor,
   CONSTRUCTOR FUNCTION typ_infoliquidacionprestamo RETURN SELF AS RESULT
  )
/

