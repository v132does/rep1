CREATE OR REPLACE TYPE IT."TYP_SOLICITUDPAGOSPI"                                          FORCE AS OBJECT
(
      error                    VARCHAR2(1),
      nombreRespuesta          VARCHAR2(100),
      descripcionRespuesta     VARCHAR2(2000),
      referenciaExterna        VARCHAR2(100),
      codigoSolicitud          NUMBER(20),
      nombreEntidadSolicitante VARCHAR2(60),
      nombreSolicitante        VARCHAR2(100),
      nombreEntidadReceptor    VARCHAR2(60),
      CONSTRUCTOR FUNCTION typ_solicitudPagoSpi RETURN SELF AS RESULT
)
/

