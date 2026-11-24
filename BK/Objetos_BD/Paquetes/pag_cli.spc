CREATE OR REPLACE PACKAGE IT.pag_cli IS

   PROCEDURE pr_obt_dat_proveedor
   (
      p_empresa          IN NUMBER,
      p_descripcion      OUT VARCHAR2,
      p_cod_tra_padre    OUT NUMBER,
      p_ref_txt          OUT VARCHAR2,
      p_ent_beneficiario OUT VARCHAR2,
      p_cod_tas_com_cli  OUT NUMBER,
      p_cod_tra_com_cli  OUT NUMBER
   );
   PROCEDURE pr_ins_ge_pag_com_cli
   (
      p_cod_ente IN NUMBER DEFAULT NULL,
      p_fecha    IN DATE DEFAULT NULL
   );
   PROCEDURE pr_cre_pag_com
   (
      p_cod_ente IN NUMBER DEFAULT NULL,
      p_nro_lote IN NUMBER DEFAULT NULL,
      p_error    OUT VARCHAR2,
      p_msj_error OUT VARCHAR2
   );
   PROCEDURE pr_ver_cuentas
   (
      p_nro_lote IN NUMBER,
      p_cod_ente IN NUMBER
   );

END pag_cli;
/

