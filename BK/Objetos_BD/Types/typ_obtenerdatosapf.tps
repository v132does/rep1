CREATE OR REPLACE TYPE IT."TYP_OBTENERDATOSAPF"                                          FORCE IS OBJECT
   (
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      numeroCuenta          VARCHAR2(18),
      capital               NUMBER(18, 2),
      fechaApertura         DATE,
      sucursal              VARCHAR2(35),
      fechaVencimiento      DATE,
      tasaInteres           NUMBER(20,4),
      nroCtaCapitalizacion  VARCHAR2(18),
      periodoLiqInteres     VARCHAR2(240),
      descMoneda            VARCHAR2(35),
      codMoneda             VARCHAR2(3),
      plazoDias             NUMBER(18, 2),
      estado                VARCHAR2(240),
      totalInteresACobrar   NUMBER(18,2),
      denominacion          VARCHAR2(100),
      periodo               VARCHAR2(100),
      totalGenerado         NUMBER(3),
      totalAtrasado         NUMBER(3),
      totalCobrado          NUMBER(3),
      cantidadDetalles      NUMBER(3),
      listaDetalles         typ_listaDetallesApf,
      CONSTRUCTOR FUNCTION typ_obtenerDatosApf RETURN SELF AS RESULT
   )
/

