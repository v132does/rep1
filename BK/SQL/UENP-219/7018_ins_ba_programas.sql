begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end;
/
insert into ba_programas
  (cod_programa,
   descripcion,
   cod_tip_programa,
   cod_modulo,
   ubi_ejecutable,
   ubi_fisico,
   des_detallada,
   cod_herramienta,
   observacion,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion,
   ope_mod_cerrado,
   cod_pro_equivalente,
   documento,
   ubi_menu)
values
  ('PR_PRE_CHE_ROGA',
   'OFERTA CHE ROGA',
   4,
   22,
   'exe',
   'exe',
   'TABLA OFERTA CHE ROGA',
   null,
   null,
   user,
   sysdate,
   user,
  sysdate,
   'N',
   null,
   null,
   'Importacion de archivos');

commit;

insert into ba_programas
  (COD_PROGRAMA,
   DESCRIPCION,
   COD_TIP_PROGRAMA,
   COD_MODULO,
   UBI_EJECUTABLE,
   UBI_FISICO,
   DES_DETALLADA,
   COD_HERRAMIENTA,
   OBSERVACION,
   USU_INSERCION,
   FEC_INSERCION,
   USU_MODIFICACION,
   FEC_MODIFICACION,
   OPE_MOD_CERRADO,
   COD_PRO_EQUIVALENTE,
   DOCUMENTO,
   UBI_MENU)
values
  ('PRP_GEN_OFE_CHE_ROGA',
   'GENERA OFERTA DE TABLA TMP',
   4,
   15,
   'BASE DE DATOS',
   'BASE DE DATOS',
   'Genera Oferta en base a tabla temporal',
   null,
   null,
   user,
   sysdate,
  user,
   sysdate,
   'N',
   null,
   null,
   'Importacion de archivos');

commit;
