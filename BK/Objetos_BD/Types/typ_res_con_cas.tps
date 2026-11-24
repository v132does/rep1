CREATE OR REPLACE TYPE IT."TYP_RES_CON_CAS"                                          FORCE AS OBJECT
(
      error                  VARCHAR2(1),
      nombreRespuesta        VARCHAR2(100),
      descripcionRespuesta   VARCHAR2(2000),
      tip_doc_cliente        VARCHAR2(10),
      nro_doc_cliente        VARCHAR2(80),
      nombre                 VARCHAR2(120),
      apellido               VARCHAR2(120),
      nro_cuenta             VARCHAR2(35),
      cod_mon_cta            VARCHAR2(3),
      tip_cuenta             VARCHAR2(3),
      cod_swi_participante   VARCHAR2(20),
      nom_swi_participante   VARCHAR2(60),
      err_cas                VARCHAR2(4000),
      CONSTRUCTOR FUNCTION typ_res_con_cas RETURN SELF AS RESULT
)
/

