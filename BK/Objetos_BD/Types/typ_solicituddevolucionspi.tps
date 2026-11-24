CREATE OR REPLACE TYPE IT."TYP_SOLICITUDDEVOLUCIONSPI"                                          FORCE AS OBJECT
(
      error                  VARCHAR2(1),
      nombreRespuesta        VARCHAR2(100),
      descripcionRespuesta   VARCHAR2(2000),
      referenciaExterna      VARCHAR2(100),
      codigoSolicitud         NUMBER(20),
      CONSTRUCTOR FUNCTION typ_solicitudDevolucionSpi RETURN SELF AS RESULT
)
/

