CREATE OR REPLACE TYPE IT."TYP_OBTEDICLICAS"                                          FORCE AS OBJECT
   (
      nro_referencia      VARCHAR2(33),
      cli_recordID        VARCHAR2(33),
      est_cliente         VARCHAR2(20),
      fec_vto_documento   DATE,
      apodo               VARCHAR2(30),
      inf_adicional       VARCHAR2(2000),
      det_adicional_pv    VARCHAR2(2000),
      tip_edicion         VARCHAR2(3),
      error               VARCHAR2(2000),
      tip_canal           VARCHAR2(4),
      CONSTRUCTOR FUNCTION TYP_OBTEDICLICAS RETURN SELF AS RESULT
   )
/

