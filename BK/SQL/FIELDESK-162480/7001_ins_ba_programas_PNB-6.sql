begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/

insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OPE_MOD_CERRADO, UBI_MENU)
values ('PAS_LCR.PR_PRO_GEN_LCR', 'REPROCESO DE INFORME LCR', 8, 11, 'BASE DE DATOS', 'BASE DE DATOS', 'Genera los datos necesarios para el informe LCR.', user, sysdate, user, sysdate, 'S', 'INICIO DE DIA CONTABLE');

commit;
