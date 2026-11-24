CREATE OR REPLACE TYPE IT."TYP_TA_PAGOPRESTAMO"                                          FORCE AS OBJECT
(
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      codigoMoneda          VARCHAR2(3),
      denominacion          VARCHAR2(100),
      numeroPrestamo        VARCHAR2(18),
      montoOperacion        NUMBER(18,2),
      cotizacion            NUMBER(18,2),
      numeroDocumento       NUMBER(15),
      numeroCuotaAvencer    NUMBER(3),
      fechaVencimiento      VARCHAR2(15),
      fechaMovimiento       VARCHAR2(15),

      CONSTRUCTOR FUNCTION typ_ta_pagoPrestamo RETURN SELF AS RESULT
)
/

