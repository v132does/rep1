CREATE OR REPLACE TYPE IT."TYP_SOFTTOKENADM"                                          FORCE IS OBJECT
   (
      nro_serial          VARCHAR2(30),
      cod_estado          VARCHAR2(1),
      cod_dispositivo     VARCHAR2(40),
      fec_alta            DATE,
      cod_cliente         VARCHAR2(10),
      nro_documento       VARCHAR2(20),
      nom_completo        VARCHAR2(120),
      num_telefono        VARCHAR2(20),
      cod_per_vinculada   VARCHAR2(10),
      nro_doc_vinculada   VARCHAR2(20),
      nom_comp_vinculada  VARCHAR2(120),
      autorizador         VARCHAR2(1),
      fec_modificacion    DATE,
      fec_ult_solicitud   DATE,
      fec_activacion      DATE,
      cod_usu_activacion VARCHAR(10),
      nom_usu_activacion VARCHAR(80),
      cod_usu_modificacion VARCHAR(10),
      nom_usu_modificacion VARCHAR(80),
      can_sol_activacion  VARCHAR(2),
      observacion         VARCHAR(1000),

      CONSTRUCTOR FUNCTION typ_softtokenAdm RETURN SELF AS RESULT
   )
/

