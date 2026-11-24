CREATE OR REPLACE TYPE IT."TYP_OBTCUOTASPRESTAMO"                                          IS OBJECT
   (
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      numeroPrestamo        VARCHAR2(18),
      cantidadCuotas        NUMBER(3),
      descripcion           VARCHAR2(200),
      nroCtaDebito          VARCHAR2(18),
      estado                VARCHAR2(15),
      mtoCapital            NUMBER(18,2),
      salCapital            NUMBER(18,2),
      salInteres            NUMBER(18,2),
      codMoneda             VARCHAR2(3),
      monto                 NUMBER(18,2),
      fecInicio             DATE,
      tipo                  VARCHAR2(1),
      cuoPagadas            NUMBER(3),
      diasAtraso            NUMBER(4),
      mtoMora               NUMBER(18,2),
      tienePendientes       VARCHAR2(1),
      listaCuotas           typ_listaCuotaPrestamo,
      CONSTRUCTOR FUNCTION typ_obtcuotasprestamo RETURN SELF AS RESULT
   )
/

