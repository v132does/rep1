CREATE OR REPLACE TYPE IT."TYP_OBTENERDATOSCDA"                                          IS OBJECT
   (
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      numeroCuenta          VARCHAR2(18),
      numeroCertificado     NUMBER(7),
      capital               NUMBER(18, 2),
      fechaApertura         DATE,
      sucursal              VARCHAR2(35),
      fechaVencimiento      DATE,
      tasaInteres           NUMBER(20,4),
      tipoCuenta            VARCHAR2(240),
      nroCtaCredito         VARCHAR2(18),
      periodoLiqInteres     VARCHAR2(240),
      descMoneda            VARCHAR2(35),
      codMoneda             VARCHAR2(3),
      plazoDias             NUMBER(18, 2),
      estado                VARCHAR2(240),
      totalInteresACobrar   NUMBER(18,2),
      cantidadCupones       NUMBER(3),
      listaCupones          typ_listaDetalleCuponesCda,
      CONSTRUCTOR FUNCTION typ_obtenerDatosCda RETURN SELF AS RESULT

   )
/

