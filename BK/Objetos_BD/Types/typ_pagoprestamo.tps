CREATE OR REPLACE TYPE IT."TYP_PAGOPRESTAMO"                                          IS OBJECT
   (
      error                 VARCHAR2(1),   
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      numeroCtaDebito       VARCHAR2(17),
      tipoCtaDebito         VARCHAR2(100),
      codMoneda             VARCHAR2(3),
      nombreCtaDebito       VARCHAR2(100),      
      numeroPrestamo        VARCHAR2(18),
      montoOperacion        NUMBER(18,2),
      cotizacion            NUMBER(18,2),
      totalInteres          NUMBER(18,2),
      totalMora             NUMBER(18,2),
      totalCargos           NUMBER(18,2),
      totalImpuestos        NUMBER(18,2),
      resLimite             VARCHAR2(2),
      cantAutorizadores     NUMBER(3),
      nroDocumento          NUMBER(15),
      CONSTRUCTOR FUNCTION typ_pagoPrestamo RETURN SELF AS RESULT
   );
/

